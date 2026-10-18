# Fuzzzy Ink — Project Context

> This document provides a complete understanding of the project without looking at the code. It is maintained by the [DOCUMENTER] persona. Refreshed for the 2026 cryptographic hardening (v1.0.0-rc.1 line, branch `agent/chat-harden-rust-crypto-core`).

---

## 1. Core Overview

| Field              | Value |
|--------------------|-------|
| **Project Name**   | Fuzzzy Ink |
| **Package Name**   | `fuzzzy_ink` (app) + `fuzzy_crypto_core` (Rust crate, `rust/fuzzy_crypto_core`) |
| **Target Platforms**| Android, Windows, macOS, Linux (shipped by CI). iOS builds but is not in the App Store. **Web is unsupported at runtime** — the encryption core is native code. |
| **SDK Constraint** | Dart `>=3.3.0 <4.0.0` (frb's generated web shim needs `extension type`) |
| **Flutter Version**| `3.41.7` / Dart `3.11.5` (managed via FVM — `.fvmrc`; every command is `fvm flutter …` / `fvm dart …`) |
| **Rust Toolchain** | `1.98.1` + clippy + rustfmt (`rust/fuzzy_crypto_core/rust-toolchain.toml`); `flutter_rust_bridge_codegen` 2.13.0 |
| **Target Audience**| Privacy-focused individuals, journalists, lawyers, executives, anyone needing offline-first secure messaging |
| **Core Value Proposition** | A personal, offline encryption system disguised as a chat interface. Messages are "fuzzed" (encrypted) locally and can be shared across any public channel. Only the paired recipient can "unfuzz" (decrypt). Zero servers, zero metadata, zero tracking. |
| **Security documents** | `documents/security/PROTOCOL.md` (the protocol, byte for byte) · `THREAT_MODEL.md` · `RELEASE.md` · `HARDENING_2026.md` · `SECURITY.md` (reporting). They are the truth about the cryptography; this file only points at them. |

## 2. Technical Stack

### Two halves, one bridge

- **Dart / Flutter (`lib/`)** — UI, BLoC state, Isar persistence, secure-storage plumbing. **No cryptographic code is written in Dart.**
- **Rust (`rust/fuzzy_crypto_core/`)** — every primitive and every protocol step. Reached through `flutter_rust_bridge` 2.13.0; the generated Dart binding is `lib/rust_bridge/` (codegen output, analyzer-excluded), the generated Rust side is `src/frb_generated.rs`. The only `lib/` importer of `package:fuzzzy_ink/rust_bridge/…` is the adapter `lib/src/core/encryption_services/crypto_core_service/*` (plus `initializer.dart` for `FuzzyCryptoCoreLib.init()`); in `test/`, only `test/helpers/crypto_core_test_init.dart` and `test/src/core/rust_bridge_smoke_test.dart`.
- **Key material never crosses the bridge.** Keys live in `#[frb(opaque)]` handles (`CryptoCore`, `VaultKey`, `FileJob`); Dart holds only ciphertext, wrapped blobs and the plaintext the user asked for.
- **`rust_builder/`** is the frb plugin shell that compiles the crate per platform through vendored **cargokit** (CMake on Linux/Windows, CocoaPods on macOS/iOS, Gradle on Android). Nothing in it is hand-maintained.
- **Version lockstep (three places, all `2.13.0`):** `pubspec.yaml` `flutter_rust_bridge: 2.13.0`, `Cargo.toml` `flutter_rust_bridge = "=2.13.0"`, and the codegen that wrote `lib/rust_bridge/` (`codegenVersion` in `frb_generated.dart`). Bump all three together or nothing builds.

### Rust crate dependencies (`rust/fuzzy_crypto_core/Cargo.toml`, resolved by `Cargo.lock`, every build `--locked`)

| Crate | Version | Purpose |
|---|---|---|
| `vodozemac` | `=0.10.0` (`default-features = false`) | Olm double ratchet — pairing, per-message keys, `SessionConfig::version_1()`, unmodified |
| `chacha20poly1305` | `=0.11.0` | XChaCha20-Poly1305 — every AEAD use (files, local state, password blobs, vault) |
| `aead-stream` | `=0.6.0` | STREAM (BE32) construction for the `0x04` file container |
| `argon2` | `=0.6.0` | Argon2id (m = 64 MiB, t = 4, p = 1) — password → key |
| `sha2` | 0.11.0 | Fingerprints (safety number). No `hkdf` dependency: it became callerless with F2-12 (per-chat history keys) and was removed in the closing pass; the only HKDF in the core is vodozemac's own |
| `subtle` / `zeroize` / `getrandom` | 2.6.1 / 1.9.0 / 0.4.3 | Constant-time comparison, wiping, CSPRNG |
| `flutter_rust_bridge` | `=2.13.0` | The bridge runtime |
| `base64`, `serde`, `serde_json`, `thiserror` | 0.22.1, 1.0.x, 1.0.x, 2.0.x | url-safe blob text, sealed state serialisation (JSON is used only on disk, never on the wire), error type |

Profiles: `[profile.dev.package.argon2] opt-level = 3` (so `cargo test` and debug app unlocks stay usable); `[profile.release]` `opt-level = 3, lto = "thin", strip = true, codegen-units = 1, panic = "unwind"`. `.cargo/config.toml` adds `--remap-path-prefix` so release cores are reproducible (`RELEASE.md`). **Never build with `--cfg fuzzing`** (vodozemac's signature check becomes a no-op).

### Dart dependencies (`pubspec.yaml`)

| Package                | Constraint | Purpose |
|------------------------|-----------|---------|
| `bloc` / `flutter_bloc` | ^8.1.2 / ^8.1.3 | State management |
| `get_it`               | ^8.0.0    | Service locator / DI (`sl`) |
| `go_router`            | ^13.0.1   | Routing — fully wired (`MaterialApp.router`, `AppRouter`) |
| `isar` / `isar_flutter_libs` | ^3.1.0+1 | Local NoSQL database (chats, messages, prefs, vault index) — **not encrypted by Isar**; sensitive columns hold Rust-sealed blobs |
| `flutter_secure_storage` | ^9.2.2  | OS keychain/keystore — holds the **wrapped** store key (`crypto_store_key_v1`) and biometric flags |
| `biometric_storage`    | ^5.0.1    | Biometric-gated storage of the unlock password (chat + vault scopes) |
| `shared_preferences`   | ^2.3.2    | Onboarding, theme, locale, last tab |
| `flutter_rust_bridge`  | `2.13.0` (exact) | Dart side of the bridge |
| `fuzzy_crypto_core`    | `path: rust_builder` | The Rust core as a Flutter plugin |
| `fuzzzy_ui_kit`        | git `fuzzzy-bot/fuzzy_design` @ `6ad9802…` (pinned ref) | The company design system (`FuzzzyTextField`, tokens…). **Never fork or vendor it.** |
| `app_links`            | ^7.0.0    | `fuzzylink://` deep links |
| `path_provider` / `path` | ^2.0.11 / ^1.9.0 | App support / documents directories, path joins |
| `uuid`                 | ^4.5.1    | Chat ids (uuid v4 — an identifier, not a secret) |
| `file_picker`, `desktop_drop`, `flutter_dropzone` | ^8.0.5, ^0.6.0, ^4.0.0 | File selection / drag-and-drop |
| `share_plus`, `url_launcher` | ^10.1.2, ^6.3.1 | Share sheet, links |
| `permission_handler`   | ^12.0.0   | Runtime permissions |
| `vibration`            | ^2.0.1    | Haptics |
| `logger`               | ^2.4.0    | Logging (`logger` global) |
| `marionette_flutter`   | ^0.6.0    | QA instrumentation — initialised **only** in `main_development.dart` under `kDebugMode` |

Removed in v1.0.0-rc.1 (do not re-add): the vendored PointyCastle fork under `packages/`, `crypto`, `build_runner` / `isar_generator` (gone since 2026-05-10 — see `scripts_reference.md` for the Isar codegen recipe).

### Dev Dependencies

| Package                | Constraint | Purpose |
|------------------------|-----------|---------|
| `very_good_analysis`   | ^5.1.0    | Lint rules (`analysis_options.yaml` excludes `lib/rust_bridge/**`, `rust_builder/**`, `**/*.g.dart`, `l10n/**`, `code_generators/**`) |
| `bloc_test`, `mocktail` | ^9.1.4, ^1.0.0 | Cubit tests, mocks |
| `marionette_mcp`       | ^0.6.0    | The Marionette MCP server (`.mcp.json`) |
| `flutter_launcher_icons` | ^0.13.1 | App icons |

## 3. High-Level Architecture

```mermaid
graph TB
    subgraph EntryPoints["Entry Points"]
        MD[main_development.dart — MarionetteBinding in debug]
        MS[main_staging.dart]
        MP[main_production.dart]
    end

    subgraph AppShell["App Shell — lib/src/app/"]
        INIT[Initializer — FuzzyCryptoCoreLib.init → DI]
        APP[App / MainShellPage + drawer]
        ROUTER[AppRouter — GoRouter, auth redirect]
        GBP[GlobalBlocProviders / GlobalBlocListeners]
        THEME_CUBIT[ThemeCubit]
        L10N_CUBIT[LocalizationCubit]
    end

    subgraph CoreLayer["Core Layer — lib/src/core/"]
        DI[DependencyInjection — GetIt, Isar.open]
        CCS[CryptoCoreService — the ONLY rust_bridge importer in lib/]
        FPH[FileProcessingHandler / FileProcessingProgress]
        LINK[FuzzyLink — deep links]
        PREFS[PreferencesService]
        PSS[PasswordStrengthService]
        L10N[Localizations — en, ka]
        ERROR[DefaultFailure + UI failures]
    end

    subgraph Features["Feature Modules — lib/src/"]
        FC[fuzzzy_ink/ — pairing, connected chat, files, safety number]
        FA[fuzzy_auth/ — app lock, biometrics]
        FV[fuzzy_vault/ — encrypted notes / passwords / files]
        FB[fuzzy_basics/ — password-only text & file fuzzing]
    end

    subgraph UIKit["UI — lib/src/ui_kit/ (in-tree) + fuzzzy_ui_kit (git dep)"]
        THEME[UiKitTheme, UiColors, UiTextStyles]
        WIDGETS[FuzzyScaffold, FuzzyHeader, FuzzyButton, FuzzzyTextField…]
    end

    subgraph Bridge["lib/rust_bridge/ — GENERATED (flutter_rust_bridge 2.13.0)"]
        FRB[api/{core,pairing,files,passwords,vault,formats,health}.dart + error.dart]
    end

    subgraph Rust["rust/fuzzy_crypto_core/ — the crypto core"]
        API[api/ — frb surface]
        STORE[store — Argon2id-wrapped store key, sealed chat state files]
        PAIR[pairing — Olm (vodozemac)]
        MSG[messages — text envelope, counters]
        FILES[files — STREAM container, FileJob]
        PW[passwords — 0x05 blobs]
        VAULT[vault — VaultKey, 0x20 items]
        SAFETY[safety — safety number]
    end

    MD & MS & MP --> INIT --> DI
    APP --> ROUTER
    FC & FA & FV & FB --> CCS
    CCS --> FRB --> API
    API --> STORE & PAIR & MSG & FILES & PW & VAULT & SAFETY
    FC & FA & FV --> DI
```

## 4. Key Architectural Differences from General Guide

The general architecture guide (`.agents/general_guide/flutter_architecture.md`) is written for a typical client-server Flutter app. Fuzzzy Ink deviates in these critical ways:

| Aspect | General Guide | Fuzzzy Ink Reality |
|--------|--------------|-------------------|
| **Network Layer** | HTTP Client stack with Dio, interceptors, API endpoints | **NONE.** Fully offline. No HTTP clients, no remote API. |
| **Data Sources** | Remote data sources hitting APIs | **Local only.** Isar DB + `flutter_secure_storage` + `biometric_storage` + `shared_preferences` + the Rust store directory |
| **Repository Pattern** | Catches HTTP exceptions, returns sealed responses | Catches **local storage / bridge** exceptions. Same sealed pattern; `CryptoCoreService` maps every Rust `CoreError` to a `CryptoCoreResponse` (`CryptoCoreSuccess | CryptoCoreFailure`) before a repository sees it. |
| **Cryptography** | (none) | A **Rust crate behind FFI**. Dart never holds a key; `CryptoCoreService` is the single adapter; everything else is documented in `documents/security/PROTOCOL.md`. |
| **Routing** | GoRouter with named routes | GoRouter, path constants on `AppRouter`, redirect-based auth gate (`architecture_state.md` §4) |
| **UI Kit** | Separate `packages/ui_kit/` package | Two layers: the in-tree `lib/src/ui_kit/` (theme extensions, Fuzzy* widgets) **and** the pinned git dep `fuzzzy_ui_kit` (imported directly as `package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart` where a kit widget is used — the one sanctioned second import) |
| **Imports** | per-feature | One barrel: `import 'package:fuzzzy_ink/lib.dart';` (re-exports `src/src.dart`). In `lib/`, only `crypto_core_service.dart` and `initializer.dart` may import `package:fuzzzy_ink/rust_bridge/…` (in `test/`: `helpers/crypto_core_test_init.dart` and `src/core/rust_bridge_smoke_test.dart`); `package:isar` is imported only by `dependency_injection.dart`, the `storage_models/` and the `local_data_sources/`. |
| **Code Generators** | Mason bricks for feature scaffolding | `code_generators/bricks/` exists (local / single-entity / remote bricks); Isar `.g.dart` files are committed and there is **no build_runner in the pubspec** (`scripts_reference.md`) |
| **QA** | manual | Marionette-instrumented dev entrypoint + `.mcp.json`; benchmark tile in Settings gated on the `development` flavor |

## 5. Supported Locales

- `en` — English
- `ka` — Georgian (ქართული) — every key needs both (`lib/src/core/l10n/app_{en,ka}.arb`, then `fvm flutter gen-l10n`)
