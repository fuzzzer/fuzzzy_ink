# Fuzzzy Ink — Architecture State

> This is the living snapshot of the application's implementation. Updated by the [DOCUMENTER] persona after each lifecycle. Snapshot: tip of `agent/chat-harden-rust-crypto-core` (v1.0.0-rc.1 line, 2026-09-13). The cryptography itself is specified in `documents/security/PROTOCOL.md` — this file names the Dart/Rust pieces and where they live, it does not restate the protocol.

---

## 1. Feature Implementation Status

### fuzzzy_ink/ (Core Feature)
- [x] **Chat Creation** — `bloc/chat_creation_cubit/`, `ui/pages/chat_creation_page/`
- [x] **Chat List** — `bloc/chat_general_data_list_cubit/`, `ui/pages/chat_list_page/` (invited vs connected tiles, floating toolbox)
- [x] **Connected Chat (Message View)** — `bloc/connected_chat_cubit/`, `ui/pages/connected_chat_page/` (header, settings toolbox, message input, sent/received text + file areas)
- [x] **Pairing — Invitation (Sender)** — `bloc/handshake_cubit/`, `ui/pages/chat_invitation_page/` (invitation `0x01` from the core; re-display via `currentInvitation`)
- [x] **Pairing — Invitation Acceptance (Receiver)** — `bloc/invitation_acceptance_cubit/`, `ui/pages/invitation_acceptance_page/` (acceptance `0x02`)
- [x] **Pairing — Readers** — `bloc/invitation_reader_cubit/`, `bloc/acceptance_reader_cubit/` (`peekChatId` + signature-checked completion; `invalidSignature` / `wrongChat` / `invitationAlreadyUsed` failures)
- [x] **Acceptance Export** — `ui/pages/acceptance_export_page/`
- [x] **Safety Number** — `bloc/safety_number_cubit/`, `ui/pages/safety_number_page/` (Signal-style 60-digit fingerprint, "mark verified" persisted in the chat's sealed state)
- [x] **File Encryption/Decryption (chat mode)** — `bloc/file_processing_cubit/`, `bloc/chat_file_injector_cubit/`, progress displays under `ui/widgets/file_processing_progresses_displays/` (`FileJob` progress/cancel from the core, `.part` output until the last tag verifies)
- [x] **File Benchmark (development flavor only)** — `bloc/file_benchmark_cubit/`, a Settings tile gated on `isFileBenchmarkEnabled` (`appFlavor == 'development'`)
- [x] **Onboarding** — `ui/pages/onboarding_page/`
- [x] **Settings** — `ui/pages/settings_page/` (theme, locale, chat authentication entry, benchmark tile)

### fuzzy_auth/ (App Lock)
- [x] **Auth Store** — `bloc/fuzzy_auth_store/` (`FuzzyAuthStore`, 5-state lifecycle: `initial` (boot, store opening — gated like locked), `noAuthRequired`, `locked`, `unlocking`, `authenticated`; `hasAccess` = authenticated ∨ noAuthRequired)
- [x] **User Auth Preferences** — `bloc/fuzzy_user_auth_preferences_cubit/` (enable / change / disable password, biometric toggle)
- [x] **Auth Settings Page** — `ui/pages/fuzzy_user_auth_page/`
- [x] **Chat Unlock Page** — `ui/pages/chat_unlock_page/` (password + biometric unlock)
- [x] **Chat Auth Repository** — `data/repositories/chat_auth_repository.dart` (the wrapped store key **is** the verifier — see §4)
- [x] **Biometric Auth Repository** — `data/repositories/biometric_auth_repository.dart` (`biometric_storage`, scopes `chat` / `vault`)

### fuzzy_vault/ (Encrypted Vault)
- [x] **Vault Auth** — `bloc/vault_auth_cubit/`, `ui/pages/{vault_entry_page,vault_create_page,vault_unlock_page}/` (own password, own `VaultKey` handle, auto-lock minutes)
- [x] **Items / Groups / Search** — `bloc/{vault_items_cubit,vault_groups_cubit,vault_search_cubit}/`, `ui/pages/vault_home_page/`, `ui/pages/vault_item_editor_page/` (notes, passwords, files; move to group)
- [x] **Export** — `bloc/vault_export_cubit/`, `data/repositories/vault_export_repository.dart`
- [x] **Vault Crypto Repository** — `data/repositories/vault_crypto_repository.dart` (init / unlock / rewrap / seal / open on the core; `PasswordStrengthService` gate)

### fuzzy_basics/ (Standalone, password-only encryption)
- [x] **Basic Encryption (text)** — `bloc/basic_encryption_cubit/`, `ui/pages/basic_encryption_page/` (`0x05` password-sealed blobs; a failed decrypt clears the previous result)
- [x] **Custom File Processing** — `bloc/custom_file_processing_cubit/` (`0x04` container, password mode)

### app/ (App Shell)
- [x] **Theme / Localization** — `globals/bloc/{theme_cubit,localization_cubit}/`
- [x] **Global BLoC Providers / Listeners** — `globals/global_bloc_{providers,listeners}.dart`
- [x] **Bootstrap / AppBlocObserver** — `components/bootstrap.dart`
- [x] **Initializer** — `initializer.dart` (`FuzzyCryptoCoreLib.init()` **before** `DependencyInjection.inject()`)
- [x] **GoRouter** — `app_router.dart` (shell route with `MainShellPage` + drawer for `/` and `/vault`)
- [x] **FuzzyLink Listener** — `components/fuzzy_link_listener.dart`

### core/services/fuzzy_link/ (Deep Link Feature)
- [x] `FuzzyLinkService` (app_links), `FuzzyLinkParser` (URI → payload), `FuzzyLinkGenerator`, `FuzzyLinkHandler` (reception, validation, auth gating, routing), `components/{fuzzy_link_payload,fuzzy_link_type}.dart`. A `fuzzylink://` location reaching the router is redirected to `/` — it belongs to the handler, never to a page.

### core/encryption_services/ (the bridge adapter)
- [x] **`CryptoCoreService`** — `crypto_core_service/crypto_core_service.dart`: owns the process's single `CryptoCore` handle; store key create/open/rewrap/close; pairing (`createInvitation`, `currentInvitation`, `acceptInvitation`, `currentAcceptance`, `completeHandshake`, `deleteChat`); text (`encryptText`/`decryptText`); files (`encryptFileForChat`, `decryptFileForChat`, `encryptFileWithPassword`, `decryptFileWithPassword` → `FileProcessingHandler`); password blobs (`passwordSealText`/`passwordOpenText`, `passwordSealBytes`/`passwordOpenBytes`); local seal (`sealLocal`/`openLocal`); safety number (`safetyNumber`, `markVerified`, `isVerified`); vault (`vaultInit`, `vaultUnlock`, `vaultRewrap`, `vaultSeal`, `vaultOpen`); `benchmarkFiles`. Every call returns `CryptoCoreResponse<T>` (`CryptoCoreSuccess | CryptoCoreFailure(CryptoCoreFailureType)`); Argon2id calls are serialised through one queue; `storeLocked` short-circuits when no store is open.
- [x] **`components/`** — `FileProcessingHandler` / `FileProcessingProgress` (pause/cancel + progress stream over the core's `FileJob`), `CryptoCoreInvitation`, `CryptoCoreAcceptance`, `CryptoCoreReceivedFile`, `CryptoCoreVaultInit`, `FileBenchmarkResult`, `CryptoCoreFailureType`.

---

## 2. Cubit / BLoC Registry

| Cubit | State | Feature | File |
|-------|-------|---------|------|
| `ThemeCubit` | `ThemeState` | app | `lib/src/app/globals/bloc/theme_cubit/` |
| `LocalizationCubit` | `LocalizationState` | app | `lib/src/app/globals/bloc/localization_cubit/` |
| `ChatCreationCubit` | `ChatCreationState` | fuzzzy_ink | `lib/src/fuzzzy_ink/bloc/chat_creation_cubit/` |
| `ChatGeneralDataListCubit` | `ChatGeneralDataListState` | fuzzzy_ink | `lib/src/fuzzzy_ink/bloc/chat_general_data_list_cubit/` |
| `ConnectedChatCubit` | `ConnectedChatState` | fuzzzy_ink | `lib/src/fuzzzy_ink/bloc/connected_chat_cubit/` |
| `HandshakeCubit` | `HandshakeState` | fuzzzy_ink | `lib/src/fuzzzy_ink/bloc/handshake_cubit/` |
| `InvitationReaderCubit` | `InvitationReaderState` | fuzzzy_ink | `lib/src/fuzzzy_ink/bloc/invitation_reader_cubit/` |
| `InvitationAcceptanceCubit` | `InvitationAcceptanceState` | fuzzzy_ink | `lib/src/fuzzzy_ink/bloc/invitation_acceptance_cubit/` |
| `AcceptanceReaderCubit` | `AcceptanceReaderState` | fuzzzy_ink | `lib/src/fuzzzy_ink/bloc/acceptance_reader_cubit/` |
| `SafetyNumberCubit` | `SafetyNumberState` | fuzzzy_ink | `lib/src/fuzzzy_ink/bloc/safety_number_cubit/` |
| `ChatFileInjectorCubit` | `ChatFileInjectorState` | fuzzzy_ink | `lib/src/fuzzzy_ink/bloc/chat_file_injector_cubit/` |
| `FileProcessingCubit<T>` | `FileProcessingState` | fuzzzy_ink | `lib/src/fuzzzy_ink/bloc/file_processing_cubit/` |
| `FileBenchmarkCubit` | `FileBenchmarkState` | fuzzzy_ink | `lib/src/fuzzzy_ink/bloc/file_benchmark_cubit/` |
| `FuzzyAuthStore` | `FuzzyAuthState` | fuzzy_auth | `lib/src/fuzzy_auth/bloc/fuzzy_auth_store/` (class in `fuzzy_auth_cubit.dart`) |
| `FuzzyUserAuthPreferencesCubit` | `FuzzyUserAuthPreferencesState` | fuzzy_auth | `lib/src/fuzzy_auth/bloc/fuzzy_user_auth_preferences_cubit/` |
| `VaultAuthCubit` | `VaultAuthState` | fuzzy_vault | `lib/src/fuzzy_vault/bloc/vault_auth_cubit/` |
| `VaultItemsCubit` | `VaultItemsState` | fuzzy_vault | `lib/src/fuzzy_vault/bloc/vault_items_cubit/` |
| `VaultGroupsCubit` | `VaultGroupsState` | fuzzy_vault | `lib/src/fuzzy_vault/bloc/vault_groups_cubit/` |
| `VaultSearchCubit` | `VaultSearchState` | fuzzy_vault | `lib/src/fuzzy_vault/bloc/vault_search_cubit/` |
| `VaultExportCubit` | `VaultExportState` | fuzzy_vault | `lib/src/fuzzy_vault/bloc/vault_export_cubit/` |
| `BasicEncryptionCubit` | `BasicEncryptionState` | fuzzy_basics | `lib/src/fuzzy_basics/bloc/basic_encryption_cubit/` |
| `CustomFileProcessingCubit<T>` | `CustomFileProcessingState` | fuzzy_basics | `lib/src/fuzzy_basics/bloc/custom_file_processing_cubit/` |

Registered as singletons in `dependency_injection.dart`: `FuzzyAuthStore`, `VaultAuthCubit`; as factories: `VaultItemsCubit`, `VaultGroupsCubit`, `VaultSearchCubit`, `VaultExportCubit`. The rest are created where they are provided (`GlobalBlocProviders` / page-level `BlocProvider`).

---

## 3. Repository & Service Registry

| Repository / Service | Feature | File | Talks to |
|-----------|---------|------|------|
| `CryptoCoreService` | core | `lib/src/core/encryption_services/crypto_core_service/crypto_core_service.dart` | `lib/rust_bridge/api/*` (the Rust core) |
| `CryptoStoreKeyRepository` | fuzzzy_ink | `lib/src/fuzzzy_ink/data/repositories/crypto_store_key_repository/` | `flutter_secure_storage` key `crypto_store_key_v1` (wrapped store key, `0x10`, base64) + `CryptoCoreService` (`read`, `write`, `ensureStoreKey`, `rewrap`) |
| `ChatGeneralDataListRepository` | fuzzzy_ink | `lib/src/fuzzzy_ink/data/repositories/chat_general_data_list_repository/` | Isar `StoredChatGeneralData` |
| `MessageDataRepository` | fuzzzy_ink | `lib/src/fuzzzy_ink/data/repositories/message_data_repository/` | Isar `StoredMessageData` — stores `encryptedMessage` **and** `sealedPlaintext` (a `0x20` local seal under the chat's own history key, base64) so history is readable without re-decrypting; seals with `CryptoCoreService.sealLocal(chatId:, bytes:)` and opens with `openLocal(chatId:, blob:)` (owner decision D-1, F2-12) |
| `ChatPreferencesRepository` | fuzzzy_ink | `lib/src/fuzzzy_ink/storage/local_data_sources/chat_preferences_repository.dart` | Isar `StoredChatPreferences` |
| `UserAuthPreferencesRepository` | fuzzy_auth | `lib/src/fuzzy_auth/data/repositories/user_auth_preferences_repository.dart` | Isar `StoredUserAuthPreferences` (a cache of the lock state — the blob is the truth) |
| `ChatAuthRepository` | fuzzy_auth | `lib/src/fuzzy_auth/data/repositories/chat_auth_repository.dart` | `CryptoStoreKeyRepository` + `CryptoCoreService` (`isChatAuthEnabled`, `setupPassword`, `verifyPassword`, `changePassword`, `disableAuth`) |
| `BiometricAuthRepository` | fuzzy_auth | `lib/src/fuzzy_auth/data/repositories/biometric_auth_repository.dart` | `biometric_storage` (`fuzzy_biometric_password_{chat,vault}`) + secure-storage flags `biometric_enabled_{chat,vault}` |
| `VaultCryptoRepository` | fuzzy_vault | `lib/src/fuzzy_vault/data/repositories/vault_crypto_repository.dart` | `CryptoCoreService` vault calls + `PasswordStrengthService` |
| `VaultRepository` | fuzzy_vault | `lib/src/fuzzy_vault/data/repositories/vault_repository.dart` | `VaultItemLocalDataSource`, `VaultGroupLocalDataSource` (Isar), `VaultFileDataSource` (files), `VaultCryptoRepository` |
| `VaultExportRepository` | fuzzy_vault | `lib/src/fuzzy_vault/data/repositories/vault_export_repository.dart` | the three vault data sources |
| `PreferencesService` | core | `lib/src/core/services/preferences_service/` | `shared_preferences` |
| `PasswordStrengthService` | core | `lib/src/core/services/password_strength_service/` | pure Dart scoring (not cryptography) |
| `FuzzyLinkService` / `FuzzyLinkHandler` | core | `lib/src/core/services/fuzzy_link/` | `app_links`, router, `ChatGeneralDataListRepository`, `FuzzyAuthStore`, `CryptoCoreService` |

Removed in v1.0.0-rc.1: `KeysRepository`, the RSA/AES key store repository, `StoredChatSecurityData`, the four Dart encryption services, `secure_bytes_generation.dart`, `lib/stash/`. Do not look for them and do not re-create them.

---

## 4. Navigation (GoRouter)

The app uses **GoRouter** via `MaterialApp.router`. Path constants live on `AppRouter`; navigation is `context.push/go/pop()`. The router instance is cached at `AppRouter.routerInstance` for non-widget callers (`FuzzyLinkHandler`).

| Constant | Path | Page | Extra |
|-------|------|------|-------|
| `home` | `/` | `ChatListPage` (inside `MainShellPage` shell route) | — |
| `vaultHome` | `/vault` | `VaultEntryPage` → create / unlock / home (shell route) | — |
| `vaultItemEditor` | `/vault/editor` | `VaultItemEditorPage` | `VaultItemEditorPagePayload` |
| `onboarding` | `/onboarding` | `OnboardingPage` | — |
| `chatUnlock` | `/chat-unlock` | `ChatUnlockPage` | — |
| `chatCreate` | `/chat/create` | `ChatCreationPage` | — |
| `chatInvitation` | `/chat/invitation` | `ChatInvitationPage` | `ChatInvitationPagePayload` |
| `chatAccept` | `/chat/accept` | `InvitationAcceptancePage` | `String?` (prefill) |
| `chatAcceptanceExport` | `/chat/acceptance-export` | `AcceptanceExportPage` | `AcceptanceExportPagePayload` |
| `chatConnected` | `/chat/connected` | `ConnectedChatPage` | `ConnectedChatPagePayload` |
| `chatVerify` | `/chat/verify` | `SafetyNumberPage` | `ChatGeneralData` |
| `settings` | `/settings` | `SettingsPage` | — |
| `auth` | `/auth` | `FuzzyUserAuthPage` | — |
| `basics` | `/basics` | `BasicEncryptionPage` | — |

Redirect order: `fuzzylink://` locations → `/` (handler's job) → onboarding gate (`PreferencesService.hasSeenOnboarding`) → auth gate. Initial location = `PreferencesService.lastSelectedTab`.

### Chat Authentication Gate (store key)
- **One key for everything local.** At boot `FuzzyAuthStore.checkAuthStatus()` calls `CryptoStoreKeyRepository.ensureStoreKey('')` — a fresh install gets a random 32-byte store key wrapped under the empty password (`0x10` blob, Argon2id, AAD `store-key`) in secure storage. The password is never persisted; there is **no separate verification token**: the wrapped blob unwraps only under the right password, so it is the verifier.
- **Lock enabled = the blob does not open under `''`.** `ChatAuthRepository.isChatAuthEnabled()` tries `openStore('')`; failure means a password is set. `StoredUserAuthPreferences.isAuthenticationOnceEnabled` is only a cache and is repaired when it disagrees with the blob.
- **Status:** `locked` when enabled, else `noAuthRequired` (the store is then already open). `initial` is the boot window while `openStore` runs and is gated like `locked`.
- `AppRouter.redirect()` sends any protected route → `/chat-unlock` while `!status.hasAccess`; unprotected routes: `onboarding`, `chatUnlock`, `settings`, `auth`, `basics`.
- **Unlock** = `openStore(wrapped, password)` (one Argon2id run); the open handle stays in `CryptoCoreService` until `lock()` closes it (every later core call answers `storeLocked`). Biometric unlock reads the password from `biometric_storage` and takes the same path.
- **Enable / change / disable password** = `CryptoStoreKeyRepository.rewrap(old → new)` = one `rewrap_store_key` call (unwrap + wrap = two Argon2id runs, one secure-storage write). **Nothing else is re-encrypted** — chat state files and message seals are keyed by the store key, which never changes. (`reencryptAllKeys` and its two-phase commit were removed in v1.0.0-rc.1.)
- **Timing truth:** a *debug* Flutter build ships the crate's dev profile, so Argon2id runs ≈ 10 s each on the Android emulator (change-password ≈ 20 s). Measure on `--profile`/`--release` only (≈ 6.7 s emulator, 260 ms Mac). Never "fix" this in Dart.
- `FuzzyUserAuthPreferencesCubit` orchestrates `enableAuth`, `changePassword`, `disableAuth`, biometric toggles; each verifies the current password first (`verifyPassword` = a full `openStore`) so the localized "incorrect password" message is produced before any rewrap.

### Vault Gate
- Independent password. `VaultCryptoRepository.initializeVault` → `vaultInit` returns the master key wrapped under the password (`0x10`, AAD `vault-key`), stored as `StoredVaultMetadata.verificationTokenBase64`. `unlock` returns an opaque `VaultKey` handle held by `VaultAuthCubit`; `close()` zeroises it on lock / auto-lock. Password change = `vaultRewrap` of the blob only; items (`0x20`, AAD `vault-item`) are never re-encrypted.

### Deep Link Flow (FuzzyLink)
1. `FuzzyLinkListener` wraps `MaterialApp.router`, initializes `FuzzyLinkHandler` on mount.
2. Handler listens to `FuzzyLinkService.onLinkReceived` + checks the initial link (cold start).
3. URI → `FuzzyLinkParser.parse()` → validation → auth gating → `AppRouter.routerInstance.push()`.
4. If the app is locked the payload waits in `_pendingPayload` and is processed after unlock via `GlobalBlocListeners`.
5. Security checks: self-invitation detection, duplicate acceptance detection, expiration validation; the blob's chat id is only a routing hint until the core's signature check passes.

---

## 5. Data Storage Map

| What | Where | Technology | Form |
|---|---|---|---|
| Per-chat crypto state (Olm account + session, counters, verified flag, last invitation/acceptance) | `<app support dir>/fuzzy_crypto_store/<chatId>.state` (+ transient `.state.tmp`) | Rust core, files | `0x20` seal under the store key; written tmp → fsync → rename **before** any encrypt/decrypt result is returned |
| Wrapped store key | `flutter_secure_storage` key `crypto_store_key_v1` | OS keychain / keystore (`ThisDeviceOnly`; macOS dev flavor uses the login keychain) | `0x10` blob, base64 |
| Chat metadata (`StoredChatGeneralData`), chat prefs, messages (`StoredMessageData`: `encryptedMessage` + `sealedPlaintext`), auth prefs, vault index (`StoredVaultItem`, `StoredVaultGroup`, `StoredVaultMetadata`) | `<app support dir>` | Isar 3 (7 schemas in `Isar.open`) | Isar is **not** encrypted; every sensitive column holds a Rust-sealed blob |
| Vault item contents, `vault.meta` | `<app documents dir>/{items/,.tmp/,vault.meta}` (`VaultFileDataSource`) | files | `0x20` under the vault master key (optionally `0x05` again under a per-item password) |
| Biometric-gated passwords | `biometric_storage` `fuzzy_biometric_password_{chat,vault}` + flags `biometric_enabled_*` in secure storage | OS biometric keystore | plaintext password behind biometrics (invalidated when biometrics change) |
| Onboarding, theme, locale, last tab | `shared_preferences` | prefs | plain |
| Outgoing blobs / files | wherever the user shares them | `Fuzz/` + base64url text envelope; `.fuzz` files (`FUZZ 01 04`) | see `PROTOCOL.md` §6 |

OS/cloud backups are opted out on every platform (`test/platform/backup_opt_out_test.dart` pins the manifests; `THREAT_MODEL.md` §2.8).

---

## 6. Cryptography

**All of it lives in `rust/fuzzy_crypto_core`.** Dart has no primitive, no KDF, no MAC, no protocol code; `CryptoCoreService` is the single adapter and `lib/rust_bridge/` is generated. Read, in this order, before touching anything under `rust/` or the adapter:

1. `documents/security/PROTOCOL.md` — roles, pairing (Olm via vodozemac, signed invitation `0x01` / acceptance `0x02`), safety number, every wire format (`FUZZ 01 <type>`), inner header and the ordered receive checks, the 64-bit counter window, the STREAM file container `0x04`, password blobs `0x05`, wrapped keys `0x10`, local seals `0x20`, local state, error codes, test vectors.
2. `documents/security/THREAT_MODEL.md` — assets, trust boundaries (FFI, secure storage, Isar, files, clipboard, backups), attacker classes, explicit non-goals, the forward-secrecy trade-off, supply chain.
3. `documents/security/HARDENING_2026.md` — what was replaced and why, the nine findings, throughput before/after, statements an auditor should hold us to.
4. `documents/security/RELEASE.md` — release procedure, attestations, reproducible core (`.cargo/config.toml` remaps, CI `rust-repro` jobs).

Crate layout (`rust/fuzzy_crypto_core/src/`): `api/` (the frb surface — `core`, `pairing`, `messages`, `files`, `passwords`, `vault`, `safety`, `local`, `formats`, `health`), `store` (store key wrap/unwrap, sealed state files, atomic writes, chat-id validation), `state` (`ChatState`, residue-free serialisation), `pairing`, `messages`, `counters`, `files`, `passwords`, `vault`, `safety`, `formats` (codec), `error` (`CoreError` — payload-free variants, exhaustively mirrored by `CryptoCoreFailureType`: `UnsupportedFormat`, `InvalidSignature`, `InvitationAlreadyUsed`, `WrongChat`, `Replay`, `TooOld`, `Corrupt`, `WrongPassword`, `StoreLocked`, `UnknownChat`, `Io`, `Cancelled`, `Internal`), `vectors` (test-only, asserts `documents/security/vectors/`). Tests: `cargo test --locked` (161), Dart `fvm flutter test` (240), CI matrix in `.github/workflows/main.yaml`.

The pure-Dart stack that preceded it is archived at `legacy/dart_crypto/` (22 September 2026): its own package, its own tests (54, all passing), excluded from the app analyzer, not a dependency of the app, and not switchable — the two stacks cannot read each other's blobs. Never import it from `lib/`; never add it to `pubspec.yaml`. Read `legacy/dart_crypto/README.md` before touching it.

Rules that are not negotiable: no hand-rolled primitives (only the pinned crates); no key material across the bridge (opaque handles, `&VaultKey` / `&FileJob` by reference); no `#[frb(sync)]` on anything touching keys, Argon2 or an AEAD; every blob starts with `FUZZ 01 <type>`; persist ratchet state before returning a result; never `--cfg fuzzing`; no migration shims for the removed Dart stack.

---

## 7. Technical Debt & Known Issues

- [ ] `./buildrunner.sh`, `./loc.sh`, `./m.sh` are broken (no `fvm` / `build_runner` not a dev dep; `scripts/runner.sh` missing; `python` vs `python3`). Recipes in `.agents/workflows/scripts_reference.md`. A `chore` commit may fix the scripts; adding `build_runner` + `isar_generator` back to the pubspec is a deliberate decision (lock churn), not a side effect.
- [ ] `./exp.sh` is union-only (never drops an export for a deleted file) and rewrites `lib/src/core/l10n/l10n.dart` + creates `generated_localizations/generated_localizations.dart` on every run — revert that side effect unless your task owns it; delete stale exports by hand.
- [ ] Change-password overlay is two Argon2id runs inside `rewrap_store_key` (T-0330): ≈ 6.7 s on the emulator in profile. A `rust/**` follow-up could reuse one Argon2 block buffer across unwrap + wrap.
- [ ] `chatStatus` reconcile at chat open (F2-7 review nit) — still open; `ChatAuthRepository.changePassword` returns `bool`, not the `CryptoCoreFailureType`.
- [ ] `FuzzyUserAuthPreferencesCubit` has no bloc test (the change-password path is covered at repository level).
- [ ] The in-tree `lib/src/ui_kit/` and the git-dep `fuzzzy_ui_kit` coexist; migration of the remaining in-tree widgets to the kit is additive work, never a fork.
- [ ] Post-compromise security needs a DH round trip (a stolen state file decrypts the receiving chain until the peer replies and we read it) — documented in `PROTOCOL.md` §14/§17 and `THREAT_MODEL.md`. Owner decision D-1 is answered (2026-09-13): sealed history stays, under a per-chat history key (F2-12); the archive export (F2-10) and the trade-off copy (F2-11) follow.
- [ ] macOS signing is an owner gate (no Apple Development identity on the build Mac); iOS builds but is not shipped; every `flutter build ios` dirties `ios/` with 3.41.7 migrations — commit that deliberately, never as a side effect.
- [ ] FuzzyLink message deduplication (timestamp/nonce) and UX extras (QR codes, clipboard detection) remain V2 items.
