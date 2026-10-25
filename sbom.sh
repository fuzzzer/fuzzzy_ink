#!/usr/bin/env bash
# CycloneDX SBOMs for both halves of the app, committed under documents/security/sbom/ (F5-3).
#   ./sbom.sh rust|flutter            regenerate documents/security/sbom/<half>.cdx.json
#   ./sbom.sh rust|flutter --check    regenerate to a temp file and fail if it differs from the committed one (CI drift gate)
# Pinned tools: cargo-cyclonedx 0.5.9 (`cargo install --locked cargo-cyclonedx@0.5.9`; bump it here and in
# .github/workflows/main.yaml together) and cdxgen 12.8.4 with every package under it locked by
# tools/sbom/package-lock.json (exact versions and integrity hashes, installed by `npm ci` with no install
# scripts; bump with `npm install --package-lock-only --ignore-scripts @cyclonedx/cdxgen@<version>` there).
set -euo pipefail
cd "$(dirname "$0")"
half=${1:-}
mode=${2:-}
out=documents/security/sbom/$half.cdx.json
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
case $half in
  rust)
    cargo cyclonedx --version | grep -q ' 0\.5\.9$' || { echo "sbom.sh: need cargo-cyclonedx 0.5.9 (have: $(cargo cyclonedx --version))"; exit 1; }
    # --target all: the crate ships for android/ios/macos/windows/linux, so the SBOM lists every target's deps
    cargo cyclonedx --manifest-path rust/fuzzy_crypto_core/Cargo.toml --format json --spec-version 1.5 --target all --override-filename rust.cdx
    # cargo's package id for the crate itself is path+file://<absolute checkout path>, percent-encoded (a space
    # is %20), so it differs per checkout. Rewrite it to the repo-relative form in every string, whatever the
    # checkout path is or how it is encoded; a plain text substitution of "$PWD" missed encoded paths.
    jq 'walk(if type == "string"
             then gsub("path\\+file://[^#\"]*/rust/fuzzy_crypto_core#"; "path+file:///rust/fuzzy_crypto_core#")
             else . end)' rust/fuzzy_crypto_core/rust.cdx.json > "$tmp/new.json"
    rm rust/fuzzy_crypto_core/rust.cdx.json
    if grep -q 'path+file:///[^r]' "$tmp/new.json"; then
      echo "sbom.sh: an absolute checkout path survived in the Rust SBOM"; exit 1
    fi
    ;;
  flutter)
    # `**/build/**` keeps cargokit's copies of build_tool/pubspec.lock in local build output out of the BOM
    npm ci --prefix tools/sbom --ignore-scripts --no-audit --no-fund --loglevel=error
    tools/sbom/node_modules/.bin/cdxgen -t flutter --spec-version 1.6 --exclude '**/build/**' --exclude 'tools/**' -o "$tmp/new.json" .
    ;;
  *)
    echo "usage: $0 rust|flutter [--check]"
    exit 2
    ;;
esac
if [ "$mode" = --check ]; then
  # serial number, timestamps and cdxgen's dated annotation change on every run; the components must not
  volatile='del(.serialNumber, .metadata.timestamp, .annotations)'
  if diff <(jq -S "$volatile" "$out") <(jq -S "$volatile" "$tmp/new.json"); then
    echo "$out is current"
  else
    echo "$out is stale: run ./sbom.sh $half and commit the result"
    exit 1
  fi
else
  jq . "$tmp/new.json" > "$out"   # pretty-printed so a dependency bump is a readable diff
  echo "wrote $out"
fi
