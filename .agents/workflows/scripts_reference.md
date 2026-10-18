# Fuzzzy Ink — Scripts Reference

> Quick reference for every project script and the commands the build actually uses. AI personas should use these instead of manual operations. Every command below was run on 2026-09-13 against the v1.0.0-rc.1 line; the ones marked **BROKEN** fail as described — use the recipe next to them.

---

## Shell Scripts (Project Root)

### `./exp.sh` — Barrel File Generator
**When to use:** After creating or deleting any `.dart` file under `lib/src`.
**What it does:** Runs `scripts/exporter.py` to regenerate the barrel chain in `lib/src/` (union-only: it adds exports, it never removes one for a deleted file — delete stale `export` lines by hand).
**Usage:**
```bash
./exp.sh
git checkout -- lib/src/core/l10n/l10n.dart                                  # known side effect, revert unless your task owns it
rm -f lib/src/core/l10n/generated_localizations/generated_localizations.dart  # ditto
```
`lib/rust_bridge/` is outside `lib/src` on purpose — the exporter never sees the generated bridge.

### `./loc.sh` — Localization Helper — **BROKEN**
**Why:** it `source`s `./scripts/runner.sh`, which does not exist in the repo (`./loc.sh: line 14: ./scripts/runner.sh: No such file or directory`); the underlying `scripts/add_localizations.py` also imports `yaml` (PyYAML), which is not installed on the build Mac.
**Recipe:** add the key to both `lib/src/core/l10n/app_en.arb` and `app_ka.arb` by hand (Georgian is required — no untranslated keys), then:
```bash
fvm flutter gen-l10n
```

### `./m.sh` — Content Merger (AI Context Dump) — **BROKEN**
**Why:** it calls `python`, which is not on PATH on this Mac (only `python3`). **It still exits 0** after `python: command not found`, so a caller cannot trust its exit code — check for the output file instead.
**Recipe:**
```bash
python3 scripts/merge_contents.py lib/src/fuzzzy_ink     # → scripts/outputs/fuzzzy_ink.txt (gitignored)
```

### `./buildrunner.sh` — Isar Codegen — **BROKEN (twice)**
**Why:** it runs a bare `flutter pub run build_runner …` (no `fvm` → `flutter: command not found`), and `fvm dart run build_runner build --delete-conflicting-outputs` answers `Could not find package build_runner` — `build_runner` and `isar_generator` left `dev_dependencies` on 2026-05-10. The committed `*.g.dart` files are the schema.
**Recipe (when a `stored_*.dart` model changes):** regenerate in a scratch package outside the repo with `isar ^3.1.0+1`, `build_runner ^2.4.0`, `isar_generator ^3.1.0+1` (resolves `isar_generator 3.1.0+1` / `analyzer 5.13.0` / `build_runner 2.4.13` under Dart 3.11): copy the model in, run `dart run build_runner build --delete-conflicting-outputs`, copy the `.g.dart` back. Generate the *unchanged* model first and diff it byte-identical against the committed file to prove the generator matches (HQ `log/F2-8.md` §2). Then add/remove the schema in `Isar.open` (`lib/src/core/dependency_injection.dart`). Re-adding the two dev deps to `pubspec.yaml` is a deliberate `chore`, not a side effect.

### `./sbom.sh` — CycloneDX SBOMs
**When to use:** After any dependency bump (Cargo or pub) — CI fails on drift.
```bash
./sbom.sh rust             # regenerate documents/security/sbom/rust.cdx.json  (needs cargo-cyclonedx 0.5.9)
./sbom.sh flutter          # regenerate documents/security/sbom/flutter.cdx.json (cdxgen 12.8.4 via npx)
./sbom.sh rust --check     # drift gate (what CI runs); ./sbom.sh flutter --check likewise
```

---

## FVM (Flutter Version Manager)

The project uses FVM. **Always prefix Flutter/Dart commands with `fvm`:**
```bash
fvm flutter pub get
fvm flutter analyze                                            # clean tree-wide since E1 (--fatal-infos/--fatal-warnings are the default)
fvm dart format --output=none --set-exit-if-changed lib test   # read-only check; NEVER a bare `fvm dart format .` (it would rewrite files and descend into rust_builder/)
fvm flutter test                                               # 240 tests; needs the release core, see "Rust core" below
fvm flutter gen-l10n
```

Current Flutter version: `3.41.7` / Dart `3.11.5` (see `.fvmrc`).

### Running the app
```bash
fvm flutter run --flavor development -t lib/main_development.dart -d macos           # dev entrypoint = Marionette-instrumented in debug
fvm flutter run --flavor development -t lib/main_development.dart -d emulator-5554
fvm flutter run --profile --flavor development -t lib/main_development.dart -d emulator-5554   # the ONLY build that measures crypto timings honestly
```
`--flavor` is mandatory on every run/build (the Xcode projects define only flavored configs). `cargo`/`rustup` must be on the PATH of that shell (`. ~/.cargo/env`). Unsigned macOS proof builds: prefix with `FLUTTER_XCODE_CODE_SIGNING_ALLOWED=NO FLUTTER_XCODE_CODE_SIGNING_REQUIRED=NO FLUTTER_XCODE_CODE_SIGN_IDENTITY=""`.

---

## Rust core (`rust/fuzzy_crypto_core`)

Toolchain: `rust-toolchain.toml` pins `1.98.1` (+ clippy, rustfmt); `flutter_rust_bridge_codegen` 2.13.0 is a user-level cargo install. Run from the crate directory unless a `--manifest-path` is given.

```bash
. "$HOME/.cargo/env"                                  # once per shell
cd rust/fuzzy_crypto_core
cargo fmt --check
cargo clippy --all-targets --locked -- -D warnings
cargo test --locked                                   # 161 tests, ≈ 3.5 min (Argon2id at 64 MiB in the dev profile, argon2 itself opt-level 3)
cargo build --release --locked                        # → target/release/libfuzzy_crypto_core.{dylib,so}, what `fvm flutter test` loads
cargo run --release --locked --example bench_file -- 16 1024   # file-container throughput, MB/s per direction (16 MiB and 1 GiB temp files; `-- 16` alone is quick)
cargo audit --file Cargo.lock                         # cargo-audit 0.22.2 (CI runs it too)
```

### Bridge codegen (after ANY change under `rust/fuzzy_crypto_core/src/api/`)
```bash
flutter_rust_bridge_codegen generate          # from the repo root (reads flutter_rust_bridge.yaml); shells out through fvm, formats its output
flutter_rust_bridge_codegen generate --watch  # while iterating
```
Writes `lib/rust_bridge/**` and `rust/fuzzy_crypto_core/src/frb_generated.rs` — **commit them**; a second run must produce no diff (reviewers check). Never run `flutter_rust_bridge_codegen integrate` on this repo (it overwrites `rust_builder/`). The "Skip parsing … Cannot parse array length" and "RustAutoOpaque suggested" INFO lines are normal.

### `flutter test` and the core
`test/helpers/crypto_core_test_init.dart` loads `rust/fuzzy_crypto_core/target/release/libfuzzy_crypto_core.{dylib,so}` through `ExternalLibrary.open` — build it first (`cargo build --release --locked`), and rebuild it after any Rust change or the Dart tests run against a stale core. Every test that touches the core calls `initCryptoCoreForTests()` in `setUpAll`.

### Env lines for a Flutter build shell
```bash
. "$HOME/.cargo/env"                                             # cargo + rustup for cargokit
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools   # NDK resolved via Gradle's ndkVersion, not ANDROID_NDK_HOME
export PATH="$ANDROID_HOME/platform-tools:$PATH"                  # the SDK adb (the brew adb has hung in _dyld_start)
```

---

## CI (`.github/workflows/main.yaml`)

Runs on every push to `main` / `agent/**`, tags `v*`, and PRs: **rust** (fmt, clippy, test, audit, SBOM gate) · **flutter-test** (release core, `pub get`, format, analyze, test, SBOM gate) · **android** (release APK with a throwaway keystore, 16 KB page-size gate) · **linux** · **windows** (`windows-2022`) · **macos** (unsigned, x86_64 + arm64) · **rust-repro ×2 + rust-repro-compare** (reproducible core) · **attest** (tags only). Watch a run: `gh run watch <id> -R fuzzzy-bot/fuzzy_chat --exit-status`. Release procedure: `documents/security/RELEASE.md`.

---

## Python Scripts (scripts/)

| Script | Purpose |
|--------|---------|
| `exporter.py` | Auto-generates barrel files for `lib/src/` (used by `./exp.sh`) |
| `add_localizations.py` | Adds localization entries to ARB files (unreachable through `./loc.sh`, and needs PyYAML — see above) |
| `merge_contents.py` | Merges directory contents into a single text file (`python3 scripts/merge_contents.py <path>`) |
