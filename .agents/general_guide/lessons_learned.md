# Fuzzzy Ink — Lessons Learned (Long-Term AI Memory)

> This document contains hard-won knowledge from past bugs and architectural decisions. The [DOER] and [REVIEWER] personas MUST consult this file before any action to avoid repeating historical mistakes.
> FN-006 … FN-013 were added by the 2026 hardening build (v1.0.0-rc.1); `log/F*.md` references point at the build record in FuzzyCore HQ, `flow/fuzzy-chat-hardening/log/`.

---

## Resolved Anti-Patterns

### AP-001: Never Throw from Repositories
**Problem:** Repositories throwing exceptions force cubits to use try/catch, leading to inconsistent error handling and forgotten catch blocks.
**Resolution:** Repositories return sealed class responses (`Success | Failure`). Cubits use exhaustive `switch`. No try/catch in BLoC layer.
**Rule:** If you write try/catch in a Cubit, you are violating the architecture.

### AP-002: Never Use Service Locator in Repositories or Cubits
**Problem:** Accessing dependencies via `sl.get<T>()` everywhere hides dependencies and makes testing impossible.
**Resolution:** Only local data sources may access `sl` directly (for DB/storage instances). Repositories receive data sources via constructor injection. Cubits receive repositories via constructor injection.
**Rule:** Constructor injection for repos and cubits. Service locator only at data source boundary.

### AP-003: Never Import Feature Files Directly
**Problem:** Importing `package:fuzzzy_ink/src/fuzzzy_ink/data/models/some_model.dart` creates tight coupling.
**Resolution:** Always import through the root barrel: `import 'package:fuzzzy_ink/lib.dart';` (it re-exports `src/src.dart`).
**Rule:** One import. `import 'package:fuzzzy_ink/lib.dart';` is the only project import you write. Two sanctioned exceptions: `package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart` where a kit widget is used, and `package:fuzzzy_ink/rust_bridge/…` **only** in `lib/` inside `crypto_core_service.dart` and `initializer.dart`; in `test/`, only `test/helpers/crypto_core_test_init.dart` and `test/src/core/rust_bridge_smoke_test.dart` (the bridge smoke test imports the generated API directly by design).

### AP-004: Never Skip Barrel Files
**Problem:** Missing barrel exports cause "undefined" errors.
**Resolution:** Every directory has a barrel file. Every new `.dart` file gets exported in its parent barrel immediately.
**Rule:** After file creation, the user must be prompted to run `./exp.sh`.

### AP-005: Never Hardcode Colors, Text Styles, or Spacing
**Problem:** Hardcoded values make theme changes impossible and lead to inconsistency.
**Resolution:** Use theme extensions: `context.uiColors`, `context.uiTextStyles`.
**Rule:** If you type `Color(`, `TextStyle(`, or a magic number for padding, you are violating the architecture.

### AP-006: Never Introduce Network Dependencies
**Problem:** Fuzzzy Ink is designed as a 100% offline, zero-server encryption tool. Network dependencies break the security model.
**Resolution:** All data operations use local storage (Isar, SecureStorage, SharedPreferences, file system). Encrypted outputs are shared via external channels by the user.
**Rule:** If you import `dio`, `http`, or any networking package, you are violating the architecture.

### AP-007: Never Write Cryptography in Dart
**Problem:** The pre-2026 app carried a vendored pure-Dart crypto stack (removed in v1.0.0-rc.1): slow (1.2 MB/s files), unauthenticated pairing, tags checked after plaintext had been written.
**Resolution:** Every primitive and protocol step runs in `rust/fuzzy_crypto_core` behind `flutter_rust_bridge`; Dart holds only ciphertext, wrapped blobs and opaque handles (`CryptoCore`, `VaultKey`, `FileJob`). `CryptoCoreService` is the single adapter. Spec: `documents/security/PROTOCOL.md`.
**Rule:** No `Random.secure`, no hash/KDF/AEAD/signature code, no key bytes in Dart. If a feature needs a new cryptographic operation, it is a Rust `api/` function + codegen, never a Dart helper. Never add a Dart crypto package to `pubspec.yaml`.

---

## Historical Bugs & Fixes

### BUG-001: Safe Registration Required for GetIt
**Context:** Standard `GetIt.registerSingleton<T>()` throws if already registered (common during hot restarts or in test setups).
**Fix:** Use the custom `safeRegisterSingleton` / `safeRegisterLazySingleton` extensions that internally check `sl.isRegistered<T>()`.
**Lesson:** Always use the `safe*` registration variants provided in the project.

---

## Framework Nuances & Best Practices

### FN-001: Dart 3 Sealed Classes for Repository Responses
**Nuance:** Sealed classes are the backbone of our error handling. They enable compile-time safety via exhaustive `switch` statements. Adding a new failure type will cause a compile error wherever it's not handled.
**Pro-Tip:** Embrace this. When adding a new failure case, add it to the sealed hierarchy and let the compiler guide you to all the places that need to be updated.

### FN-002: `part of` Directive for Cubit State
**Nuance:** State files use the `part of 'my_cubit.dart';` directive. This means the state file is lexically part of the cubit file; it can access the cubit's imports but cannot have its own `import` statements.
**Pro-Tip:** All necessary imports for the state must be placed in the main cubit file.

### FN-003: Isar Schema Changes Need Codegen — `./buildrunner.sh` Is Broken
**Nuance:** Isar storage models (`stored_*.dart`) have committed `.g.dart` twins. `./buildrunner.sh` is **broken** (no `fvm`, and `build_runner`/`isar_generator` left the pubspec on 2026-05-10), so regeneration goes through a scratch package — recipe in `.agents/workflows/scripts_reference.md` §Isar. Deleting a collection needs no codegen (only its own `.g.dart` goes; drop it from the `Isar.open` list in `dependency_injection.dart`).
**Pro-Tip:** A generated file that differs from what `isar_generator 3.1.0+1` emits is a review finding — diff the unchanged model first to prove the generator matches (`log/F2-8.md` §2).

### FN-004: Cryptographic Work Runs on frb's Thread Pool — Never on a Dart Isolate
**Nuance:** Every `CryptoCoreService` call is an `async` frb function executed on the Rust thread pool; Argon2id (64 MiB, ~130 ms release on a Mac) and file jobs never block the UI isolate. The old isolate-based file path (`Isolate.run`, `FileEncryptionIsolateArguments`) was deleted with the Dart stack in v1.0.0-rc.1.
**Pro-Tip:** Do not wrap a core call in `Isolate.run`/`compute` — the handle is not sendable and the work is already off-thread. Two semantics to respect instead: (1) the `CryptoCore` handle is behind frb's *fair* `RwLock`, so `encrypt_text` waits behind a running chat-mode file job (F3-1 review N1) — password-mode jobs run without the handle for that reason; (2) store-key calls (`createStoreKey`, `openStore`, `rewrapStoreKey`) queue on `_argon2Queue` in Dart and behind `ARGON_LOCK` in Rust, so only one 64 MiB Argon2 block exists per process — do not "parallelise" them.

### FN-005: Biometric Storage Requires Biometric-Only Flags
**Nuance:** `biometric_storage` package defaults `darwinBiometricOnly` to `false`, which allows device passcode as fallback on iOS/macOS (`.userPresence`). To enforce actual biometric-only access, both `androidBiometricOnly: true` and `darwinBiometricOnly: true` must be set in `StorageFileInitOptions`. Note: `androidBiometricOnly` is ignored on API < 30.
**Pro-Tip:** When biometrics change (finger add/remove, Face ID re-enrollment), `.biometryCurrentSet` invalidates the stored key. `retrievePassword()` returns `null` — always handle this gracefully by falling back to manual password entry.

### FN-006: frb `StreamSink` Functions Cannot Return an Error — Check `errorMessage` Before `isComplete`
**Nuance:** frb 2.13 runs a Rust function with a `StreamSink` parameter *unawaited* and returns the Dart `Stream` synchronously, so a Rust `Err` would surface as an unhandled async exception. `encrypt_file`/`decrypt_file` therefore return `()` and report every outcome, errors included, as the terminal `FileProgress` event (`error_message` set, `is_complete: true`) — `log/F3-1.md` §deviation 1.
**Pro-Tip:** In Dart consumers (`FileProcessingHandler`, the file cubits) test `errorMessage` **first**, then `isComplete`. Pass `job: &FileJob` by reference so pause/cancel stay callable; a by-value opaque parameter panics in frb's owned decode while Dart still holds the handle (FACTS, F4-1).

### FN-007: A Debug Flutter Build Ships the Crate's *Dev* Profile — Never Time Crypto in Debug
**Nuance:** cargokit builds the crate without `--release` for a debug app; only `argon2` is `opt-level = 3`. Measured: file path **7 MB/s** in debug vs 400–600 MB/s in profile/release; Argon2id ≈ 10 s per run on the Android emulator in debug (change-password = 2 runs ≈ 20 s) vs ≈ 3 s in release and 0.13 s on the Mac — `log/F3-4.md` §7.2, `log/F4-4.md` §7, T-0330.
**Pro-Tip:** Any timing acceptance (unlock, change-password overlay, throughput) is measured on `fvm flutter run --profile --flavor development -t lib/main_development.dart` or a release build. Marionette is `kDebugMode`-only, so drive profile builds with adb/uiautomator. Before a timed pass on the shared emulator run `adb shell am kill-all` (or relaunch it with `-memory 4096`, `log/F4-4.md` §8.3) — a memory-starved 2 GB guest turned a 1 s unlock into 13 s. Marionette answers "Server error" for the first ~10 s after a debug launch (JIT); wait for a non-empty `get_interactive_elements`.

### FN-008: Confirm Analyzer Claims in a Clean Clone — a Stray `.dart_tool/` Masks Errors
**Nuance:** `fvm flutter analyze` needs `- rust_builder/**` in `analyzer.exclude` (next to `lib/rust_bridge/**`): on a fresh checkout the vendored cargokit `build_tool/` is analysed and fails with 40+ `uri_does_not_exist` errors. A leftover gitignored `rust_builder/cargokit/build_tool/.dart_tool/` (from an ad-hoc `pub get` in that folder) resolves those imports and the tree *looks* clean without the exclude — `log/F1-2.md` §Review, fix `066d4b1`.
**Pro-Tip:** Verify analyzer/exclude claims in `git clone --no-checkout … && git checkout <sha>`, never in the working tree. Never run `pub get` inside `rust_builder/cargokit/build_tool/`.

### FN-009: Codegen Runs Immediately Before the Commit, and Its Output Is Committed
**Nuance:** `lib/rust_bridge/**` and `src/frb_generated.rs` are generated by `flutter_rust_bridge_codegen generate` (2.13.0, it shells out through `fvm` and runs `dart format` on its output). They are committed, `analysis_options.yaml`-excluded, and must be byte-identical to a fresh run at the commit — every reviewer re-runs codegen and expects an empty `git status` (`log/F2-1.md`, `F3-1.md`, `F3-3.md`).
**Pro-Tip:** Sequence: edit `rust/**/api/*.rs` → `cargo test --locked` → `flutter_rust_bridge_codegen generate` → `fvm flutter analyze` → commit *including* the generated files. `lib/rust_bridge/` lives outside `lib/src` on purpose so `./exp.sh` never touches it. Data-carrying Rust enums abort codegen (they need `freezed`, which this app does not carry — `log/F2-1.md` §4.1): keep `CoreError` variants payload-free. Never run `flutter_rust_bridge_codegen integrate` on this repo — it overwrites `rust_builder/`. Keep the three `2.13.0` pins in lockstep (`pubspec.yaml`, `Cargo.toml`, `codegenVersion`).

### FN-010: Shared Worktree — Stage Exact Content, Never a Pathspec Commit on a Contested File
**Nuance:** Several workers commit from one worktree. A pathspec commit (`git commit <path>`) takes *working-tree* content, so on a file another feature is editing it sweeps their hunks into your commit (F2-9 collisions, `_COMMON.md` §Shared-worktree). A shared index holding someone else's staged work is the same trap.
**Pro-Tip:** Stage your exact bytes per file (`git hash-object -w <file> | xargs -I{} git update-index --cacheinfo 100644,{},<path>` or `git add -p` accepting only your hunks), verify `git diff --cached --stat` lists only your paths, then a bare `git commit -F msg`. When the shared index is dirty with foreign work, use a private index: `GIT_INDEX_FILE=<tmp> git read-tree HEAD && GIT_INDEX_FILE=<tmp> git add <paths> && GIT_INDEX_FILE=<tmp> git commit -F msg` (`log/F3-4.md` §7.1) — and never `git worktree add` with `GIT_INDEX_FILE` exported. Self-check builds run in a detached scratch worktree (`git worktree add --detach <scratch> <sha>`) so another developer's broken WIP cannot poison your run (`log/F2-9.md`). `./exp.sh` is union-only and always rewrites `l10n/l10n.dart` + creates `generated_localizations.dart` — revert that side effect unless your task owns it (`log/F2-6.md` §1).

### FN-011: Disk Hygiene — a Rust Scratch Clone Is ~1.5 GB, and the Disk Hit 0 Bytes Once
**Nuance:** Every reviewer/self-check clone carries `rust/**/target` (≈ 0.4–1.5 GB) plus `build/`. On 2026-09-12 accumulated scratch trees filled the disk to 0 bytes mid-build (`_COMMON.md` §Disk hygiene).
**Pro-Tip:** `df -h /` before creating a scratch tree; delete it at the end of the task (`git worktree remove`/`rm -rf` + `git worktree prune`), including its `target/` and `build/`. A `--shared` clone under the session scratchpad is the cheapest reviewer checkout.

### FN-012: Flavors, Signing and Platform Churn on Every Build
**Nuance:** The Xcode projects only define flavored configs — `fvm flutter build macos --debug` without `--flavor development` fails before reaching frb (`log/F1-2.md`). macOS `Debug-development` is Manual-signed for a team this Mac has no identity for: unsigned proof builds need `FLUTTER_XCODE_CODE_SIGNING_ALLOWED=NO FLUTTER_XCODE_CODE_SIGNING_REQUIRED=NO FLUTTER_XCODE_CODE_SIGN_IDENTITY=""`. Flutter 3.41.7 rewrites `macos/Podfile` + pbxproj deployment targets (committed once — do not revert) and dirties 8 `ios/` files on every `build ios` (UIScene migration — never let it ride along in an unrelated commit, `log/F1-3.md`).
**Pro-Tip:** Always `--flavor development -t lib/main_development.dart` for dev runs. `cargo`/`rustup` must be on the PATH of the shell that runs `flutter build` (`. ~/.cargo/env`); cargokit resolves the NDK from Gradle's `ndkVersion`, not `ANDROID_NDK_HOME`. On macOS a stale `rust/fuzzy_crypto_core/target/release/*.dylib` is loaded *before* the packaged framework on non-packaged runs (frb `ioDirectory`, `log/F1-4.md`) — rebuild it or delete it before trusting a desktop run. Android 16 KB pages come free with cargokit (`-Wl,-z,max-page-size=16384`); CI gates `arm64-v8a`/`x86_64` LOAD segments at `0x4000`.

### FN-013: Protocol Facts That Look Like Bugs and Are Not
**Nuance:** (1) **The sender cannot decrypt its own output** — pasting your own sent blob back answers `corrupt`/`wrongChat`, by design of Olm (F2-4 review). (2) **A blob decrypts exactly once, on one device** — a second paste is `replay`; a copy of the chat's state file decrypts the receiving chain only until the next DH round trip (`PROTOCOL.md` §14, `THREAT_MODEL.md`). (3) **The 64-bit counter window refuses anything more than 63 behind the newest accepted message per direction** (`tooOld`) — stricter than Olm's 40-key store, a product limit, not a defect. (4) A `Corrupt`/`WrongPassword` answer never says which — the AEAD cannot tell a wrong password from a tampered blob. (5) Lock state truth is the wrapped store-key blob, not the auth preference.
**Pro-Tip:** Map these to the existing `CryptoCoreFailureType` cases and their localized copy; do not add retries, "fix-ups" or new error variants for them.

