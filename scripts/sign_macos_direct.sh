#!/usr/bin/env bash
#
# Signs a finished macOS app for distribution outside the Mac App Store (Developer ID), with the
# hardened runtime and the app sandbox of macos/Runner/Release.entitlements, refuses to continue
# unless the signed app really carries the sandbox entitlement, then notarizes and staples it.
#
#   scripts/sign_macos_direct.sh <path/to/App.app> <bundle id>
#
# Every input comes from the environment (the release-tag job's repository secrets); nothing is
# read from a file in the repository and no value is ever printed. Missing inputs are named and the
# script stops before touching anything:
#   MACOS_DEVELOPER_ID_P12_BASE64      Developer ID Application certificate + private key (.p12, base64)
#   MACOS_DEVELOPER_ID_P12_PASSWORD    its export password
#   MACOS_DEVELOPER_ID_PROFILE_BASE64  Developer ID provisioning profile for the bundle id (base64); needed
#                                      because the app uses the data-protection keychain
#   APPLE_TEAM_ID                      the team that owns both
#   APP_STORE_CONNECT_PRIVATE_KEY_BASE64, APP_STORE_CONNECT_KEY_IDENTIFIER, APP_STORE_CONNECT_ISSUER_ID
#                                      an App Store Connect API key, for notarytool
# documents/security/RELEASE.md §2 and §6.2 describe the release this belongs to.

set -euo pipefail

app=${1:?usage: sign_macos_direct.sh <App.app> <bundle id>}
bundle_id=${2:?usage: sign_macos_direct.sh <App.app> <bundle id>}

required=(
  MACOS_DEVELOPER_ID_P12_BASE64
  MACOS_DEVELOPER_ID_P12_PASSWORD
  MACOS_DEVELOPER_ID_PROFILE_BASE64
  APPLE_TEAM_ID
  APP_STORE_CONNECT_PRIVATE_KEY_BASE64
  APP_STORE_CONNECT_KEY_IDENTIFIER
  APP_STORE_CONNECT_ISSUER_ID
)
missing=()
for name in "${required[@]}"; do
  [ -n "${!name:-}" ] || missing+=("$name")
done
if [ ${#missing[@]} -gt 0 ]; then
  echo "::error::macOS release signing is not set up: ${missing[*]} missing. The release tag stops here rather than ship an unsigned, unsandboxed app."
  exit 1
fi
[ -d "$app" ] || { echo "::error::no app at $app"; exit 1; }

work=$(mktemp -d)
keychain="$work/signing.keychain-db"
keychain_password=$(uuidgen)
cleanup() {
  security delete-keychain "$keychain" >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT
umask 077

# A throwaway keychain that holds only the Developer ID identity, for this run only.
printf '%s' "$MACOS_DEVELOPER_ID_P12_BASE64" | base64 --decode > "$work/identity.p12"
security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 3600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
security import "$work/identity.p12" -k "$keychain" -P "$MACOS_DEVELOPER_ID_P12_PASSWORD" -T /usr/bin/codesign >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain" >/dev/null
security list-keychains -d user -s "$keychain" $(security list-keychains -d user | tr -d '"')

identities=$(security find-identity -v -p codesigning "$keychain" | grep -c '"Developer ID Application: ' || true)
if [ "$identities" -ne 1 ]; then
  echo "::error::expected exactly one Developer ID Application identity in MACOS_DEVELOPER_ID_P12_BASE64, found $identities."
  exit 1
fi
identity=$(security find-identity -v -p codesigning "$keychain" | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p')

# The profile is embedded; the entitlements are Release.entitlements (sandbox included) plus the
# identifiers the profile grants, so the data-protection keychain works under Developer ID.
printf '%s' "$MACOS_DEVELOPER_ID_PROFILE_BASE64" | base64 --decode > "$app/Contents/embedded.provisionprofile"
entitlements="$work/entitlements.plist"
cp macos/Runner/Release.entitlements "$entitlements"
/usr/libexec/PlistBuddy -c "Add :com.apple.application-identifier string $APPLE_TEAM_ID.$bundle_id" "$entitlements"
/usr/libexec/PlistBuddy -c "Add :com.apple.developer.team-identifier string $APPLE_TEAM_ID" "$entitlements"

# Inside out: every nested framework and library first, then the app with its entitlements.
while IFS= read -r -d '' nested; do
  codesign --force --options runtime --timestamp --keychain "$keychain" --sign "$identity" "$nested"
done < <(find "$app/Contents/Frameworks" -depth \( -name '*.framework' -o -name '*.dylib' \) -print0)
codesign --force --options runtime --timestamp --keychain "$keychain" --sign "$identity" \
  --entitlements "$entitlements" "$app"

# The point of signing: the shipped app must be sandboxed and its signature intact.
codesign --verify --strict --deep --verbose=2 "$app"
codesign -d --entitlements "$work/signed.plist" --xml "$app" 2>/dev/null
if [ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "$work/signed.plist" 2>/dev/null)" != "true" ]; then
  echo "::error::the signed app does not carry com.apple.security.app-sandbox."
  exit 1
fi
if /usr/libexec/PlistBuddy -c 'Print :com.apple.security.network.client' "$work/signed.plist" >/dev/null 2>&1 \
  || /usr/libexec/PlistBuddy -c 'Print :com.apple.security.network.server' "$work/signed.plist" >/dev/null 2>&1; then
  echo "::error::the signed app carries a network entitlement; the release app must have none."
  exit 1
fi

# Notarize and staple, so Gatekeeper accepts the download without an override.
printf '%s' "$APP_STORE_CONNECT_PRIVATE_KEY_BASE64" | base64 --decode > "$work/notary.p8"
ditto -c -k --keepParent "$app" "$work/notarize.zip"
status=$(xcrun notarytool submit "$work/notarize.zip" --key "$work/notary.p8" \
  --key-id "$APP_STORE_CONNECT_KEY_IDENTIFIER" --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
  --wait --output-format json | jq -r .status)
if [ "$status" != "Accepted" ]; then
  echo "::error::notarization ended with status '$status' (xcrun notarytool log <id> shows why)."
  exit 1
fi
xcrun stapler staple "$app"
spctl --assess --type execute --verbose=2 "$app"
echo "signed, sandboxed and notarized: $app"
