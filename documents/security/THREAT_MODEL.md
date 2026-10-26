# Fuzzzy Ink — Threat Model

**Status:** describes the code in `rust/fuzzy_crypto_core` (crate 0.1.0) and the Flutter app around it on the
`agent/chat-harden-rust-crypto-core` branch, format version 1. Its companion is [`PROTOCOL.md`](PROTOCOL.md),
which says *what the bytes are and what the code checks*; this document says *what that buys, against whom,
and what it does not*. Every defended claim below names the `PROTOCOL.md` section that specifies the
mechanism and, where one exists, the test that pins it. Where this document and the code disagree, the code
is the truth and this document has a bug — file it (see [`SECURITY.md`](../../SECURITY.md)).

**Audience:** a security reviewer preparing an audit, and the reader of a MASA / CRA-style assessment who
needs the assets, the adversaries, the controls and the honest gaps in one place. Nothing here restates a
byte layout; those live in `PROTOCOL.md` and are pinned by the vectors in [`vectors/`](vectors/README.md).

**How to read the claims.** A control is stated only if the crate enforces it and a section of
`PROTOCOL.md` describes it. "Test:" names the Rust test (`module::tests::name`, all under
`rust/fuzzy_crypto_core/src/`) or the Dart test file that exercises the property; `cargo test --locked` and
`fvm flutter test` run every one of them in CI on every push. A limitation is stated wherever a control has
one. Nothing in this document is aspirational.

---

## 1. Assets

What an attacker wants, in the order the product cares about it.

| # | Asset | Where it lives | Protected by |
|---|---|---|---|
| A1 | **Message plaintext in transit** (text typed by a user, encrypted into a `Fuzz/` blob) | only inside a `0x03` blob, on whatever channel the users chose | the Olm session's per-message key (§4 below; `PROTOCOL.md` §7, §8, §14) |
| A2 | **File plaintext in transit** | only inside a `0x04` container | a random per-file key sealed in one Olm message + STREAM chunks (`PROTOCOL.md` §9) |
| A3 | **Identity keys of a chat** (one Ed25519 + one Curve25519 key pair per chat per device) and the **one-time key** | inside the Olm `Account` pickle in the sealed state file | the store key (`PROTOCOL.md` §3, §10.3) |
| A4 | **Session state** (the double-ratchet chains — including the current *receiving chain key* — skipped message keys, the counter window) **and the chat's history key** (A7's key) | the sealed state file `<chat_id>.state` | the store key; atomic write, save-before-return (`PROTOCOL.md` §10.3). A copy of this file is the post-compromise asset of §4.3 and §4.5: it decrypts every message the peer generates on the current receiving chain until the peer has received a new ratchet key from this device (§4.3) — and, opened, it yields that chat's history key, so a state copy plus the store key also reads that chat's local history (A7), no other chat's |
| A5 | **The master key** and **the store key** (32 bytes each, one per install) | the master key exists in the clear only for the length of one call (first run, open, password change, recovery, new recovery key, and the vault calls that use the master key) and is never kept; the store key only inside the unlocked process. At rest: the master key as two `0x10` blobs (under the master password, and under the recovery key while one is kept), the store key as a `0x20` under the master key, the recovery lock (a public key) as a `0x20` under the store key, all in the platform secure storage | Argon2id-derived KEK from the master password or the recovery key; there is no state without a password (`PROTOCOL.md` §10.2, §11) |
| A5a | **The recovery key** (152 random bits + a check byte) | shown once; then wherever the user printed or saved it — never in the app | the user. It opens the master key exactly like the master password and, through its recovery lock, a vault with its own password (§4.3, R37) |
| A6 | **The vault key** and **vault item content** | the wrapped vault key in the `vault.meta` file (JSON field `verificationToken`): a `0x20` under the master key by default, or a `0x10` under the vault's own password; items as `0x20` files under `items/`, each bound to its id and version; all in the app-private vault folder `<app support directory>/vault/` (§2.5) — not in Isar | the master password (default) or the vault's own password — and, for a vault with its own password, the recovery key, through a `0x11` box sealed to the recovery lock (secure storage `vault_key_recovery_v2`, only while a recovery key is kept); sealed items (`PROTOCOL.md` §6.10, §10.6). The master password alone does not open a vault with its own password — not even together with a copy of `vault.meta` taken while the master password still opened it: giving the vault its own password draws a **new** vault key, re-seals every item under it and commits in one rename, and draws a **new** recovery key in the same step, shown to the user then, so no recovery key made earlier with the master password opens the vault (security review 2026-10-26). What that does not cover: someone who learns the vault's own password, or who holds the recovery key shown at the switch, or who copied an item *file* before the switch and also kept the old `vault.meta` (that copy is the item's content at that time, R33). Independent of the chat store: neither the store key nor any history key (A7) opens a vault item, and the vault key opens no chat history |
| A7 | **Local message history** (sent *and* received **text** plaintext; a received file row holds its kept file key instead, under its own AAD `kept-file-key` ‖ chat id, `PROTOCOL.md` §9.6, see A12) | `StoredMessageData.sealedPlaintext`, one `0x20` seal per row, AAD `local-seal` ‖ chat id ‖ row (the row's direction byte and blob text, so a seal opens only on its own row) | **that chat's history key** — 32 random bytes drawn with the chat's Olm account and kept only inside the chat's sealed state (A4), so it is protected by the store key and, through it, the master password (`PROTOCOL.md` §3, §10.4). Owner decision D-1 (§8): design (a) with a per-chat key. One chat's key opens no other chat's history and not the peer device's copy of the same chat; a captured **store key** still opens every state and therefore every history key — the per-chat key bounds a history-key leak, not a store-key leak |
| A8 | **The master password** and **a vault's own password** | typed by the user, never kept in the app's state after the unlock; optionally copied into the OS biometric-gated keystore when biometric unlock is enabled (§2.3) | the OS; the user |
| A9 | **Metadata**: chat names, chat ids, timestamps, message counts and ordering, file names, sizes and the stored paths of the kept sealed files (A12), the ciphertext blobs themselves, vault item titles/tags/groups/types | plaintext columns of the Isar database | **not protected** — an explicit non-goal (§7.4, `PROTOCOL.md` §10.5) |
| A10 | **Peer authenticity** — that the person at the other end of a chat is the person the user thinks | the safety number (`PROTOCOL.md` §5) | the users' out-of-band comparison |
| A11 | **Availability of history**: that a blob a user already read stays readable | the local seal (A7) | the master password, and the recovery key if the password is forgotten; the ratchet makes the blob itself single-use by design (§7.6) |
| A12 | **Unfuzzed file plaintext at rest** — every file a user opens, saves or shares (chat, Basics, vault) | since 2026-10-26 the app keeps only sealed files (`<app support>/sealed_files/chats/<safe chat name> (<chat id prefix>)/`, `sealed_files/basics/`, `vault/`); a plain copy exists only for one use, in a fresh folder of `<app support>/handoff/`, shown in the app or given to the system save dialog or share sheet (`PROTOCOL.md` §9.6, §10.5) | **the app:** kept received files are sealed like text history (kept key under the chat's history key, A7); hand-off copies are wiped right after use, when the chat or Basics page closes, and at every launch; nothing is written to a user-visible folder, Downloads, MediaStore or the Files app; deleting a chat deletes its files (§2.5). **Not protected:** a hand-off copy while it is in use, and a file once the user saved or shared it — that file is the user's (§7.13, R36). The archive export (A7 as a file, `PROTOCOL.md` §9.5) is the same class once saved: plaintext under a user-chosen password, outside forward secrecy (R35) |

Not an asset of this model: the users' real-world identities (the protocol has no notion of them), the
existence of the app on a device, or the fact that two people exchange blobs (§7.4).

---

## 2. Trust boundaries

### 2.1 The device and the operating system

Everything below assumes the OS, its keystore and the app's process are sound. A compromised OS, a rooted or
jailbroken device with hostile software, a kernel-level keylogger, a screen recorder, a debugger attached to
the process — all of these are **outside** the model (§7.1). The crate is a library inside the app process
and shares its memory; it cannot defend the process from the process.

### 2.2 The FFI boundary (Dart ↔ Rust)

Drawn exactly as `PROTOCOL.md` §13 describes it, and the single most important boundary in the app:

- **Crosses into Rust:** passwords as strings (moved into wiped buffers on the first line of every API
  function), wrapped `0x10` blobs, `Fuzz/` texts and container paths (attacker-controlled input), chat ids
  (shape-validated on entry), plaintext the user typed, output paths, the verified flag.
- **Crosses back to Dart:** ciphertext (`Fuzz/` texts, `0x10`/`0x20`/`0x05` blobs), the plaintext the user
  asked to see, the safety-number string, status enums, progress events, file names, and thirteen
  payload-free error variants (`PROTOCOL.md` Appendix B) — never a key, a path, a digit of a secret or OS
  error text.
- **Never crosses:** the master key, the store key, KEK, history keys, the vault key, file keys, Olm accounts, sessions,
  message keys, state-file bodies. They live in four opaque handles (`CryptoCore`, `VaultKey`,
  `FileTicket`, `FileJob`) that Dart holds by reference. Every function that touches a key is asynchronous;
  the only synchronous functions (`blob_type_of`, `peek_chat_id`, the `FileJob` controls) touch no key.
  Test: `api::vault::tests::key_never_serialises`; the F4-4 review's whole-tree grep (`PROTOCOL.md` §13,
  and §9 below) found no cryptographic code left in Dart.

What the boundary does **not** do: it cannot wipe Dart's side. A password typed into a text field is a Dart
`String` — immutable, garbage-collected, copyable by the VM — until the process exits, and the bridge's
serialisation buffer that carried it into Rust is freed without wiping (inherent to `flutter_rust_bridge`;
recorded by the F2-2 review). Finding F-8 is therefore closed for **key material** (all of it is in Rust)
and residual for **passwords on the Dart side** (§10, R19).

### 2.3 Platform secure storage

The master key's blobs are the only key material the crate needs the OS to keep: `flutter_secure_storage` keys
`master_key_password_v2` (`0x10`), `master_key_recovery_v2` (`0x10`, only while a recovery key is kept),
`store_key_wrap_v2` (`0x20`), `recovery_lock_v2` (`0x20`, the recovery lock under the store key) and
`vault_key_recovery_v2` (`0x11`, only for a vault with its own password), each ≤ 150 characters of base64, plus
the sealed auto-lock settings — Keychain on
macOS/iOS, Keystore-backed on Android, DPAPI on Windows, libsecret on Linux (`PROTOCOL.md` §10.1). Each is far
below the smallest known platform limit (Windows Credential Manager, 2 560 bytes). **A secure storage that
cannot be read at launch fails closed:** the app shows that it stays locked and offers a retry; it never shows
the chat list and opens no store (`FuzzyAuthStore.checkAuthStatus`, test
`fuzzy_auth_cubit_test.dart` "a secure storage error at launch fails closed"; security review 2026-10-22).

Two things the reader must know:

1. **macOS development flavour uses the login keychain**, not the data-protection keychain
   (`lib/src/core/constants/default_constants.dart`: `usesDataProtectionKeychain: appFlavor != 'development'`).
   The data-protection keychain needs a provisioned signature and this project's build machine holds no
   Apple certificate (owner decision D-3); unsigned developer builds would otherwise throw at boot. Staging
   and production builds use the data-protection keychain. A development build's wrapped key is readable
   by any process the same macOS user runs and allows via the keychain prompt (`PROTOCOL.md` §17.8).
2. **Biometric unlock stores the password itself.** When a user enables biometric unlock for the master password
   or the vault, the *password* is written to a `biometric_storage` entry
   (`lib/src/fuzzy_auth/data/repositories/biometric_auth_repository.dart`, entry
   `fuzzy_biometric_password_<scope>`, on Android `fuzzy_biometric_password_v2_<scope>`) that the OS
   releases only after a successful biometric prompt, on every read (`authenticationValidityDurationSeconds:
   -1`). The crate never sees this: it receives the password as if typed. Per platform (`biometric_storage`
   5.0.1 as configured in that repository): **Android** — the password is encrypted under a Keystore key
   made with `setUserAuthenticationParameters(0, AUTH_BIOMETRIC_STRONG)` (no device PIN, no validity
   window; the key is used through a `CryptoObject` behind the prompt; StrongBox-backed where the device has
   it; `setInvalidatedByBiometricEnrollment` is left at its default, so enrolling a new fingerprint or face
   invalidates the key and the copy is deleted on the next read), ciphertext in the app's private
   directory. Copies written before this (key version 2) sat under a key that also accepted the device PIN
   and stayed open 30 s after any unlock; key parameters cannot change after creation, so on the first start
   after the update such a copy is deleted with its key and the user turns biometrics on again (security
   review 2026-10-22, item 2); **iOS/macOS** — a Keychain item with
   `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` and `.biometryCurrentSet` (`darwinBiometricOnly: true`), so enrolling a new finger or face invalidates the
   entry, and it is **always** in the data-protection keychain — the development-flavour login-keychain
   exception of item 1 does *not* extend to the biometric copy (an unsigned development build cannot enable
   biometrics at all); **Linux and Windows** — `canAuthenticate` reports the hardware unavailable, so the
   feature cannot be enabled and no password copy ever exists there. The consequence is that with
   biometrics on, the strength of the master password is the strength of the OS biometric gate, not of the password
   (§4.3, §10 R20).

There is **no "lock off"** any more: the master password is set at the first run, must reach the "good" strength
bar, and cannot become empty — the crate refuses an empty password before any Argon2 run (`PROTOCOL.md` §6.8,
§10.2; test `api::core::tests::the_empty_password_is_gone`). Builds before 2026-10-26 could wrap the store key
under `""`; such an install starts fresh at the first run, which erases the app's own data (`PROTOCOL.md` §10.1).

### 2.4 The Isar database

The app's database is **not encrypted as a whole** (Isar 3 community build; verified during planning). The
boundary inside it is column-level and the reader must not assume more than this:

| Sealed (ciphertext) | Plaintext |
|---|---|
| `StoredMessageData.sealedPlaintext` — a `0x20` local seal per message (`PROTOCOL.md` §10.4) | `StoredMessageData.encryptedMessage` — the `Fuzz/` blob text (ciphertext, but a record that a message exists, its length and its time) |
| — (the wrapped vault key — a `0x20` under the master key, or a `0x10` under the vault's own password — is **not** in Isar: it is the `verificationToken` field of the vault's `vault.meta` file, §2.5; the `StoredVaultMetadata` collection is still declared but never written) | chat names, chat ids, timestamps, message ordering and counts, file names and sizes, chat status, vault item **titles, tags, group and type**, user preferences (the verified flag has no Isar mirror — the Rust flag in the sealed state is the only truth) |

Vault item *content* is not in Isar at all: one `0x20` file per item (optionally wrapped again in a `0x05`
under a per-item password) in the vault folder `<app support directory>/vault/items/` (§2.5, `PROTOCOL.md`
§10.1, §10.6).

A copy of the database without the password (and without the OS keystore) is therefore: every message's
ciphertext, every message's *sealed* plaintext (unreadable), and every piece of metadata in the clear (§7.4).

### 2.5 The file system

- **The store directory** `<app support>/fuzzy_crypto_store/` holds one sealed state file per chat, mode
  `0o600` on unix, written tmp → fsync → rename → directory fsync (`PROTOCOL.md` §10.3). Every path under it
  is built from a shape-validated chat id and asserted to stay inside the directory (`PROTOCOL.md` §2). Test:
  `api::pairing::tests::chat_id_is_validated_before_anything_else`,
  `store::tests::crash_between_write_and_rename_leaves_a_stale_tmp_that_is_ignored`.
- **The `.part` contract** (`PROTOCOL.md` §9.3): every decrypted file is written to `<output>.part`, created
  `0o600` only after the header parsed and the key was derived, and each chunk's plaintext is written only
  after its tag verified. Success = fsync → close → rename over `<output>`. Any other exit — error, cancel,
  panic — unlinks the `.part` through a drop guard. Tests: `files::tests::tamper_one_byte_mid_file_no_plaintext_written`,
  `files::tests::tamper_leaves_no_partial_output`, `files::tests::cancel_deletes_part`. The one gap: a
  process **kill** (not a crash the guard can see) leaves the `.part` until the next job over the same
  output truncates it (`PROTOCOL.md` §17.11).
- **Outputs are user-directed.** The receiver chooses the directory; the peer chooses only a bare file
  *name* (no `/`, `\`, NUL, control bytes, `.`/`..`, ≤ 255 bytes; `PROTOCOL.md` §7.3). Test:
  `files::tests::original_name_is_bounded_and_free_of_control_characters`. The core does not display-sanitise
  the name and its final rename replaces an existing output; the app shows names without direction controls,
  never hands a plain file to another app to open (since 2026-10-26 it shows images and text itself and
  offers Save for anything else, so a received program cannot be run from the app), and never names an
  existing file as the output (`name (1).ext`, …) (R14–R15, mitigated 2026-10-22).
- **The app keeps sealed files only; plaintext is the user's (A12, since 2026-10-26).** The app's private
  storage holds the chat containers (sent, and received ones kept with their kept key, `PROTOCOL.md` §9.6),
  the Basics password containers and the vault items — all under `<app support>/` (`sealed_files/chats/<safe
  chat name> (<chat id prefix>)/`, `sealed_files/basics/`, `vault/`), never in a user-visible folder. A plain file
  exists only for one use, in a fresh folder of `<app support>/handoff/`: shown in the app (images, text), given
  to the system save dialog or the share sheet, and wiped right after, when the chat or Basics page closes, and at
  every launch — the launch sweep also deletes the file picker's cache copies, Android's old share staging
  (`cache/user_files`, `cache/share_plus`), the archive working file and, on a phone, the old Basics
  `Working Folder` (`UserFileStore.wipeTemporaryPlainCopies`; test
  `test/src/core/services/user_file_store/user_file_store_test.dart`). Nothing goes to Android's public
  Downloads or MediaStore, Android holds no storage permission, its FileProvider serves the hand-off folder
  only (never the store key or the vault; `test/platform/user_files_test.dart`), and iOS no longer exposes
  Documents to the Files app. Deleting a chat deletes its files folder and rows (and its state, so every kept
  key). What remains: a hand-off copy is plaintext in user-private storage while it is used (default file mode;
  a process kill leaves it until the next launch; an Android share target may still be reading when the app
  wipes it on return); a kept received file is as readable as the chat's text history to whoever holds the store
  key (`PROTOCOL.md` §9.6, A7); and a file the user saves or shares is the user's, outside every guarantee
  (R36, `PROTOCOL.md` §10.5, §17.15).
- **The archive export's working file (`PROTOCOL.md` §9.5).** An export writes the chat's rows as plaintext JSON
  lines to `<app support directory>/chat_archive_<chat id>.jsonl` (default file mode inside a user-private
  directory — Dart cannot set `0o600`), seals it into a password-mode `0x04` container, and deletes the lines in a
  `finally` on every in-process exit (success, nothing-to-export, seal failure, exception). A process **kill**
  mid-seal leaves the plaintext file until the next launch, whose sweep deletes it (since 2026-10-26). On Android
  and iOS the *sealed* container is written to the hand-off folder, given to the save dialog (iOS: the share
  sheet's "Save to Files") and wiped right after (sealed bytes only). The export runs only on an open store; a
  locked store returns before the file is created. R35.
- **The vault folder** `<app support directory>/vault/` holds `vault.meta` (JSON: the wrapped vault key — a `0x20`
  under the master key or a `0x10` under the vault's own password — the vault id and timestamps; everything but the
  wrapped key in plaintext, and since 2026-10-26 no auto-lock value), `items/<item id>.vault` (one `0x20` blob per
  item, bound to its id and version) and `.tmp/` (atomic-write temp files), written tmp → flush
  → rename (`VaultFileDataSource`). It lies under the Application Support directory, out of the user-visible
  folders on every platform and excluded from backups wherever §2.8 can exclude it (on Windows that directory
  is the Roaming AppData folder, which a domain roaming profile copies to a server, as it already does the
  store directory). Builds before 2026-10-22 used the **documents directory itself** as
  the vault folder: on iOS the Files app and a paired computer's Finder showed `vault.meta` and the item files
  (`UIFileSharingEnabled`, kept for chat files), and on Windows and Linux they sat loose in the user's own
  Documents folder, which a cloud client (OneDrive) may sync. At every start, before the vault is used,
  `VaultLocationMigration` moves such a vault into the private folder: a marker is written first; each file is
  renamed, or on another volume copied → flushed → size-checked → renamed, and only then its old copy deleted;
  `vault.meta` moves last; while the marker exists, or when the move failed before writing it (the old
  `vault.meta` could not be read), the vault neither opens nor accepts writes and offers no new vault, and the
  next start retries. Only the vault's own files are moved or deleted (a `vault.meta` that parses as the vault's,
  `items/*.vault` files that start with `FUZZ`, the vault's temp files, then those folders only if empty); a
  vault already in the private folder is never overwritten (the old one is then left where it was). The
  move cannot recall a copy made before it: a cloud sync, desktop backup or Finder copy of the documents
  directory taken earlier still holds the wrapped key for offline guessing (§4.3). The vault's
  "delete everything" (`clearAll`, no caller today) refuses any folder not named `vault`.
- **A second copy of the app cannot open the store** while the first has it open: an exclusive OS file lock
  refuses it (`Io`), so two processes never race one chat's state or reuse a message key (`PROTOCOL.md` §17.10).
  Test: `store::tests::state::a_second_copy_of_the_app_cannot_open_the_store`.
- **A prepared receive that never runs has already spent the file's message.** A `FileTicket` dropped
  between `prepare_file_receive` and `run_file_job` — a process kill, a UI flow abandoned — consumed the
  Olm message at prepare time (`PROTOCOL.md` §9.4 "Semantics a consumer must know"); the container is then
  `Replay`, the same class as R9 with a different trigger. The app's guard against preparing a file that is
  still arriving is a heuristic: two length samples 500 ms apart (`file_processing_cubit.dart`,
  `_isInputStable`); a stalled download passes it and burns the step.

### 2.6 The clipboard and the screen

Blobs move by copy and paste. While a `Fuzz/` text is on the clipboard it is readable by any app the OS lets
read the clipboard; the app does not clear it. Plaintext shown on screen is readable by anything that can
read or capture the screen. Both are outside the model (§7.2, §7.3). The app never decrypts a blob
automatically: a message is decrypted only when the user presses send on a pasted `Fuzz/` text
(`lib/src/fuzzzy_ink/ui/pages/connected_chat_page/connected_chat_page.dart`, `_sendText`), a file only when
the user picks it. An app link (`https://ink.fuzzzycore.com/…`, below) **prefills** the input field and
navigates; it decrypts nothing (§7.5).

### 2.7 The transport channel — the app has none

Fuzzzy Ink has no network code, no server, no directory, no push, no key server (`PROTOCOL.md` §1, §13:
"the crate never reads … the network"). Every blob travels by whatever channel the users choose — SMS,
e-mail, another messenger, a QR code, paper. The model therefore assumes the strongest channel adversary:
**everything on the channel can be read, modified, replayed, reordered, delayed or dropped**, and says
nothing about the channel's own security. The users' choice of channel is theirs.

App links (`https://ink.fuzzzycore.com/invite#<payload>`, `…/accept#<payload>`, `…/message#<payload>`) are
an app-layer convenience wrapper around the same blob — base64 JSON with the blob, a version and a type. The
payload sits only after the `#`, the part of a URL a browser never sends to the web server, so the link page
never receives it. They are verified Android App Links and iOS/macOS universal links (the domain declares the
app), so another app cannot claim them the way it could claim the old `fuzzylink://` scheme, which is removed
on every platform. Links carry no expiry; the core never saw one anyway (`PROTOCOL.md` §4.6). They are
subject to everything above; see §7.4 for what the message link adds in the clear.

### 2.8 OS and cloud backups

**Fixed in `6ecd9f1`** (`fix(platform): exclude the crypto store and local db from OS backups`): the app now
opts out of platform backups everywhere, and the keychain items are `ThisDeviceOnly`. Concretely —
Android: `android:allowBackup="false"` plus `res/xml/backup_rules.xml` (`fullBackupContent`, API ≤ 30)
and `res/xml/data_extraction_rules.xml` (`dataExtractionRules`, API 31+, both `<cloud-backup>` and
`<device-transfer>`) excluding every domain (`root`, `file`, `database`, `sharedpref`, `external`);
iOS / macOS: `NSURLIsExcludedFromBackupKey` set at launch on the Application Support directory that
holds `fuzzy_crypto_store/` and the Isar database (`ios/Runner/AppDelegate.swift`,
`macos/Runner/MainFlutterWindow.swift`); and `IOSOptions` / `MacOsOptions` accessibility
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly` on both `FlutterSecureStorage` instances
(`default_constants.dart`; `biometric_storage` already wrote `WhenPasscodeSetThisDeviceOnly`). Pinned by
`test/platform/backup_opt_out_test.dart` and `test/src/core/constants/default_constants_test.dart`.
One limit of the darwin half: `kSecAttrAccessible…ThisDeviceOnly` is enforced by the data-protection keychain
only; the **macOS development flavour** keeps its item in the login keychain (§2.3), where the attribute is
accepted but not enforced, so that flavour's item still travels with a Time Machine copy of the keychain file.
Staging and production use the data-protection keychain and are covered.

**Before the fix — the per-platform analysis that motivated it.** Everything in the bullets below describes
builds *older than* `6ecd9f1` (nothing opted out of backups; the key item used the plugin's default
accessibility) and is kept because it says what a backup taken by such a build can still do today:

- **Android.** `AndroidManifest.xml` sets neither `android:allowBackup` nor `android:dataExtractionRules`,
  so Auto Backup copies `files/` (the store directory and the Isar database) and shared preferences to the
  user's Google account by default. The `0x10` store-key entry in shared preferences is AES-encrypted under
  a key that is itself wrapped by an `AndroidKeyStore` RSA key (the plugin's default,
  `encryptedSharedPreferences: false`); Keystore keys are never backed up and do not survive an uninstall,
  and Auto Backup restores only at install time. **Consequence:** sealed state and the plaintext metadata
  leave the device; the restored key entry is undecryptable on *any* device, the same one included, so a
  restored install holds sealed state without its key — every chat and every message is lost (A11). An
  Android backup is *not* a usable copy of the key (R33 does not arise from it).
- **iOS.** Application Support (the store directory and the Isar database) is in iCloud Backup and
  encrypted Finder backups by default, and the store-key item is written with the plugin's default
  accessibility `kSecAttrAccessibleWhenUnlocked` **without** `ThisDeviceOnly`
  (`flutter_secure_storage-9.2.4/lib/options/ios_options.dart`), which Apple migrates in encrypted backups
  — **to a new device as well**. **Consequence:** sealed state, the database *and the wrapped key* all
  restore; with the app lock off the restored key opens under the empty string, so history restores and an
  iOS backup **is a usable, permanent copy** of the key (R33); with the lock on, the backup holds the
  `0x10` blob for offline guessing (§4.3).
- **macOS.** Time Machine (no iCloud device backup on macOS) backs up Application Support and the user's
  keychains. In the **development flavour** the item lives in the login keychain (§2.3), whose file is in
  Time Machine and opens with the login password — the iOS consequence applies to that flavour. For
  staging/production (data-protection keychain) whether a Time Machine restore yields a usable item was not
  measured here; the conservative assumption for confidentiality is that it may, and for availability that
  it may not.
- **Linux / Windows.** There is no platform backup to opt out of; whatever the user backs up carries the
  store directory and the database. The key sits in the login keyring (libsecret; encrypted under the login
  password) or in an encrypted file under Roaming AppData whose key is in Credential Manager (DPAPI,
  user-scoped). A full user-profile backup restored under the same account and password opens it by design
  of those stores (not measured here); a file-only copy of the store directory does not.
  **Windows is not "no cloud".** OneDrive folder backup — switched on by default on many Windows 11 set-ups —
  uploads the user's Documents folder, and with it every file the user saves there (builds before 2026-10-26
  also left unfuzzed files in `Documents/Fuzzzy Ink/<chat folder>/`; the app now keeps only sealed files, under
  Roaming AppData, §2.5). The store, the database, the sealed files and the vault are under Roaming AppData,
  which OneDrive does not upload, but a managed (domain) roaming profile copies it to a server at sign-out. Neither can be opted out of by the app.

In every case the **metadata non-goal extends to the backup provider and to anyone who holds the account**
(§7.4, T24): the Isar database leaves the device in the clear wherever a backup exists. The vault's `0x10`
blob is not in that database but in `vault.meta` (§2.5): since 2026-10-22 it sits beside the database under
Application Support and every statement above about the database applies to it; before that it sat in the
documents directory — on iOS shown in the Files app, on Windows and Linux in the user's own Documents folder.

With the fix in `6ecd9f1` the availability corollary is uniform: an OS backup no longer carries the store,
the database or (on darwin) a migratable key item, so a restore cannot recover history — on top of "a new
device cannot re-read old blobs" (§8). What remains (R34): Linux and Windows have no platform backup to opt
out of, so a user's own full-profile backup still carries the store directory and the database (on Windows also
OneDrive's upload of Documents, which carries whatever files the user saved there, and a domain roaming
profile); and the exclusion attribute on darwin is set on the directory at launch, so a backup taken before the first launch
of `6ecd9f1` or later may still hold the older files. History reaches a cloud only by the user's own act: the
archive export (F2-10, `PROTOCOL.md` §9.5) is a password-sealed file the user places wherever they like — not
a return to OS backups.

---

## 3. Adversaries

| Id | Adversary | Capabilities assumed |
|---|---|---|
| **ADV-1 Passive channel observer** | reads every blob ever sent on the channel, forever | harvests ciphertext; correlates blobs by time, size and channel metadata; cannot touch a device |
| **ADV-2 Active attacker on the channel** | ADV-1 plus: modifies, replaces, replays, reorders, drops and injects blobs, including during pairing | the man-in-the-middle case; may run the app themselves and pair with both victims |
| **ADV-3 Malicious peer** | a legitimately paired counterpart | crafts hostile blobs and containers, hostile file names, hostile Argon2 headers; tries to make the victim's device misbehave, consume state, or leak |
| **ADV-4 Device thief** | physical possession of a device — switched off, OS-locked, or seized with the OS session open and the app process alive | in two sub-cases: **without** the master password or the recovery key (and no biometric), or **with** one of them (or with the victim's finger/face while the OS session is open) |
| **ADV-5 Malware on an unlocked device** | code running as the same OS user while the app is unlocked | reads the app's files and database, the clipboard, the screen; on desktop, the same user's keystore entries |
| **ADV-6 Harvest-now-decrypt-later** | ADV-1 with a future computer | keeps today's blobs to break them when the underlying problems become tractable |
| **ADV-7 Supply chain** | a hostile or compromised dependency, tool, CI runner or release step | ships a build whose bytes are not the reviewed code |

An adversary who controls the victim's OS is not on this list (§7.1).

---

## 4. What we defend, per adversary

### 4.1 ADV-1 — passive observer

- **Confidentiality of every message and file.** Each text blob is an Olm v1 message under a per-message
  key (`PROTOCOL.md` §8.1, §14 step 1); each file's content is sealed under a random 32-byte key that
  exists only inside one Olm message (`PROTOCOL.md` §9.4). Test: `api::messages::tests::round_trip_both_directions`,
  `api::files::tests::chat_mode_round_trip_multi_chunk_both_directions`.
- **Forward secrecy.** A message key is deleted on use and the deletion is persisted before the plaintext
  is returned (`PROTOCOL.md` §14 steps 2–3). A blob captured on the channel and a device state snapshot taken
  *after* the blob was read cannot decrypt it. Tests: `api::messages::tests::forward_secrecy` and
  `api::files::tests::forward_secrecy_for_files` assert `MissingMessageKey` at the **Olm layer**, not merely
  an API refusal (the F2-4 review required exactly this). This is a statement about the *past*: the same
  snapshot decrypts every message the peer generates on its current receiving chain until the peer has
  received a new ratchet key from the victim (§4.3, R32) — the passive observer never has such a snapshot, which is why it appears under the device
  adversaries and not here.
- **Nothing in the clear on a message blob but the Olm ciphertext**: no chat id, no counter, no sender
  (`PROTOCOL.md` §6.5). The observer learns "a Fuzzzy Ink message of this length was sent" and nothing more
  from the bytes.
- **What ADV-1 still gets:** the existence, timing, length and channel metadata of every blob; the pairing
  blobs' public keys and the chat id inside them (`PROTOCOL.md` §6.3–6.4; nothing secret is in a pairing
  blob); and — if the sender used "Copy as link" — the chat id in the message link (§7.4).

### 4.2 ADV-2 — active attacker on the channel

- **Tampered message or file → rejected, no state change.** Every Olm message carries a MAC; every file
  chunk carries a 16-byte Poly1305 tag with the whole container header and the chunk index as AAD; a failed
  check leaves the state file byte-identical and writes no plaintext (`PROTOCOL.md` §7.2 check 3, §9.2).
  Tests: `api::messages::tests::tampered_blob_corrupt`, `files::tests::truncated_mid_chunk_detected`,
  `files::tests::truncated_at_boundary_detected`, `files::tests::appended_bytes_detected`,
  `files::tests::reordered_or_duplicated_chunks_detected`, `api::files::tests::tampered_chat_header_corrupt`.
- **Replay → rejected.** A consumed message key is gone (`Replay` from Olm's `MissingMessageKey`,
  `PROTOCOL.md` §7.2 check 3) and, behind it, the per-direction 64-bit counter window refuses a seen counter
  (`PROTOCOL.md` §8.2). Tests: `api::messages::tests::replay_rejected`, `api::files::tests::replayed_file_rejected`,
  `counters::tests::replay_of_the_highest_is_rejected`.
- **Reordering, dropping, delaying → tolerated within the windows, refused beyond them** (§7.7).
  Tests: `api::messages::tests::out_of_order_within_window`, `counters::tests::out_of_order_within_the_window_is_accepted_then_replay`,
  `counters::tests::counter_below_the_window_is_too_old`.
- **A blob moved between chats or directions → rejected.** The inner header binds chat id, both identity
  keys and direction inside the authenticated plaintext, checked in constant time after decryption
  (`PROTOCOL.md` §7.1–7.2); in practice a cross-chat blob already dies at the Olm MAC. Tests:
  `api::messages::tests::cross_chat_rejected`, `api::messages::tests::wrong_inner_header_is_rejected_without_state_change`,
  `api::files::tests::wrong_chat_rejected_before_any_write`.
- **A tampered pairing blob → rejected before anything is used.** Both pairing blobs are Ed25519-signed
  over every byte including the envelope (domain-separated by the type byte), verified with
  `verify_strict` over the received bytes, before the chat id or any key in the blob is used
  (`PROTOCOL.md` §4.1). Tests: `pairing::tests::signature_covers_the_envelope`,
  `api::pairing::tests::tampered_invitation_rejected`, `api::pairing::tests::tampered_acceptance_rejected`.
- **A replayed or re-signed acceptance → the one-time key survives, the chat completes only once.** Every
  "already used" case is enumerated in `PROTOCOL.md` §4.5; a rejected acceptance never consumes the one-time
  key. Tests: `api::pairing::tests::second_acceptance_rejected`,
  `api::pairing::tests::two_accepters_race_only_the_first_completes`,
  `api::pairing::tests::resigned_acceptance_under_another_identity_rejected`,
  `api::pairing::tests::wrong_inner_header_is_corrupt_and_keeps_the_otk` (eleven dishonest handshake headers),
  `api::pairing::tests::regenerate_invalidates_old`.
- **Man-in-the-middle during pairing → detectable, not prevented.** An attacker who replaces *both* pairing
  blobs holds two sessions and relays. The safety number — a 60-digit (~199-bit) fingerprint of both
  identity keys and the chat id, identical on both sides only if no substitution happened — exposes this
  **when the users compare it out of band** (`PROTOCOL.md` §5, §17.1). Until they do, the chat works and is
  *not* authenticated. The attacker's cost to defeat the comparison is not 2¹⁹⁹: the attacker chooses
  *both* substitute identity keys and needs only a **collision** between the number A sees (over A's real
  key and the attacker's key towards A) and the number B sees (over the attacker's key towards B and B's
  real key) — a birthday search of ≈ 2¹⁰⁰ work over the two grindable inputs (`PROTOCOL.md` §5 "Strength").
  Infeasible, but the reader should carry the right exponent. This is the honest statement of finding F-2's
  closure: the control exists, is real, and depends on a user action. Tests: `api::safety::tests::symmetric`, `api::safety::tests::unpaired_chat_is_unknown`
  (no flag before keys exist), `api::safety::tests::verified_flag_survives_reload` (the flag dies with the keys).
  Low-order Curve25519 points in either pairing blob are refused by vodozemac and reported `Corrupt` with
  no state written (`PROTOCOL.md` §4.3 step 1, §4.4 step 3; F2-3 review, 22/22 degenerate points).
- **A version-2 or unknown-format blob → refused, never guessed** (`PROTOCOL.md` §6.2, §12).

### 4.3 ADV-4 — device thief

**Without the master password or the recovery key** (device off or OS-locked, app not running, or the app
locked — by the Lock button, the idle time or the time in the background; no biometric enrolment usable):

- Every state file (identity keys, sessions, skipped keys, the chat's history key) is XChaCha20-Poly1305
  ciphertext under the store key, and every local seal of history is ciphertext under the history key of its
  chat, which exists only inside that chat's state file (`PROTOCOL.md` §10.3, §10.4). Without the store key the
  thief has neither. Tests: `store::tests::wrong_store_key_cannot_open`,
  `store::tests::corrupt_missing_and_foreign_files`, `store::tests::local::tamper_detected`,
  `api::local::tests::cross_chat_seal_rejected`, `api::local::tests::history_key_survives_reload`.
- The store key exists only as a `0x20` under the master key, and the master key only as `0x10` blobs under
  `Argon2id(password, m = 64 MiB, t = 4, p = 1)` with a random salt — the master password (strength "good" or
  better) and the recovery key (152 random bits) — in the OS secure storage (`PROTOCOL.md` §10.2, §11).
  Offline guessing costs one 64 MiB Argon2id run per candidate (≈ 0.12–0.14 s per guess on a 2021 laptop,
  release build); in the app, wrong master passwords start growing waits after five. Tests:
  `master::tests::password::wrong_password_rejected`,
  `master::tests::password::tampered_blob_is_wrong_password_not_a_panic`,
  `api::core::tests::a_store_wrap_from_another_device_does_not_open`.
- The vault key is wrapped under the master key by default (`0x20`, AAD `vault-key-wrap`) or under the vault's
  own password (`0x10`, AAD `vault-key`) and then also sealed to the recovery lock (`0x11`, AAD
  `vault-key-recovery`, opened only by the recovery key); vault items are sealed under it, each bound to its id
  and version (`PROTOCOL.md` §6.10, §10.6). A vault gets its own password only by moving to a **new** vault key
  and a **new** recovery key at once (`vault_use_own_password`, then `vault_reseal` per item and one atomic
  commit, `PROTOCOL.md` §10.6): a copy of the old `vault.meta` plus the master password yields the old key, which
  opens nothing the vault holds afterwards, and a recovery key somebody made earlier with the master password
  opens neither the new box nor, once the app has replaced the wrap, the master key. Tests:
  `vault::tests::wrong_password`, `vault::tests::seal_open_tamper_detected`,
  `vault::tests::item_is_bound_to_its_id_and_version`,
  `api::vault::tests::its_own_password_draws_a_new_key_the_old_wrapping_cannot_reach`,
  `api::vault::tests::a_recovery_key_planted_earlier_does_not_open_the_switched_vault`,
  `api::vault::tests::the_recovery_key_shown_at_the_switch_opens_the_vault`,
  `master::tests::recovery_lock::only_the_recovery_key_of_the_lock_opens_a_box`;
  `test/src/fuzzy_vault/storage/local_data_sources/vault_file_data_source_test.dart` (a stop before the commit
  keeps the old vault, after it the move is finished).
- **Limit — the recovery key.** Whoever holds the printed or saved recovery key opens the master key exactly
  like the master password, and sets a new one — and opens a vault with its own password too, giving it a new
  password or putting it back under the master password. It is not guessable (152 bits; a full Argon2id run per
  guess against the recovery wrap, and 2¹⁵¹ hash-and-X25519 operations on average against the public lock), so
  its protection is where the user keeps it — the app tells the user to keep it away from the device. A user who
  skipped it has none (no recovery wrap, lock or vault box is stored); a new key ends the old one — its wrap, lock
  and vault box are deleted at once (R37).
- **Limit — biometrics.** With biometric unlock enabled the password sits in the OS biometric keystore
  (§2.3); a thief who can satisfy the biometric prompt has it.
- **What the thief gets regardless:** every plaintext column of §2.4 — who the user talks to (chat names),
  when, how much, file names, and the ciphertext blobs. Files the app keeps are sealed (A12, since
  2026-10-26); a file the user saved or shared earlier is wherever the user put it, readable by anyone who can
  read that place (§2.5, R36).
- **Limit — a password change rotates no key, with one exception.** Changing the master password, using the
  recovery key, making a new recovery key, changing the vault's own password or putting the vault back under the
  master password only *re-wraps* the same 32-byte master key or vault key (`PROTOCOL.md` §10.2 "nothing else is
  keyed by the password", §10.6). The one rotation is the vault getting its own password, which draws a new vault
  key (above); the master key and the store key are never rotated. So a copy of the secure-storage blobs taken
  with an old password (or an old recovery key) known — a macOS development-flavour keychain read, a
  Linux/Windows user-profile backup (§2.8) — stays openable with that old password forever. The same holds for the vault's `0x10` blob
  (`vault.meta`, §2.5), which travels with any copy of the vault folder, plus the vault password. The only remedy is to delete every
  chat and the vault (or wipe the app) — R33.

**With the master password** (or the recovery key, or the unlocked device in hand):

- The thief reads the local history (A7) exactly as the user would, and can send and receive as the user
  in every chat from then on. This is not a cryptographic failure; it is the scope of the master password. The
  per-chat history key changes nothing here — the store key opens every state file and each state file
  carries its chat's history key. Honestly stated: the per-chat key limits the blast radius of a *history-key*
  leak (one chat's history, on one device), not of a *store-key* or password leak (every chat).
- **A device seized while the app is unlocked is this case with no password needed** — but only until the
  whole-app auto-lock: after the idle time without a touch (1, 5 — the default — 15 or 30 minutes), once the
  app has been in the background for the chosen time (at once, 1 minute — the default — or 5 minutes), or at
  once with the Lock button. Locking closes the store (its key and every cached state are wiped in the core)
  and the vault. The times are sealed under the store key, so editing a file cannot loosen them (`PROTOCOL.md`
  §10.7). Residual: up to the idle time with the app in the foreground (R21).
- **What the ratchet still bounds — past messages.** Blobs the user had already read *before* the theft are
  gone from the state — their keys were deleted on use (`PROTOCOL.md` §14 step 3) — so a blob captured on the
  channel earlier cannot be re-decrypted from the seized state; only the sealed local copy exposes it.
  Unread blobs outstanding at the time of theft are decryptable up to the windows of §7.7.
- **What the ratchet does not bound — post-compromise, until the peer ratchets.** A copy of a chat's state
  file (A4) holds the current **receiving chain key**. From it the thief derives the message key of the
  next unread message on that chain **and of every later message the peer generates on the same chain**.
  The copy stops working exactly when this device sends a message carrying a new ratchet key **and the peer
  has received it**: the peer's next message is then on a chain the copy does not hold. No read on the
  victim's device is required for that — the peer's first message after receiving the victim's is already
  unreadable to the copy, whether or not the victim ever opens it (vodozemac advances the sending ratchet on
  receipt of a new remote ratchet key; `PROTOCOL.md` §8.1, §14 point 3, §17.14, verified against the crate).
  Messages the peer generated on the old chain *before* receiving the victim's message remain readable by
  the copy. Until that happens the copy keeps decrypting new traffic in that direction as it appears on the
  channel — with no action needed on the stolen device — and nothing in the protocol forces the victim to
  send. Forward secrecy (the past) holds; post-compromise security (the future) is otherwise **not
  provided**. No mitigation is in scope for this version; it is listed as limitation R32. The sending
  direction is not affected by the copy in this way: the thief can *send* as the victim (below) but reads the
  victim's own outgoing messages only from the sealed local history.
- **Impersonation forward, not backward.** The chat's identity keys are long-lived; possessing them allows
  impersonation in that chat from then on, never the recovery of past message keys (`PROTOCOL.md` §17.13).
  There is no revocation; the peer's remedy is to delete and re-pair, which produces a new safety number.

### 4.4 ADV-3 — malicious peer

A paired peer is trusted with exactly one thing: the plaintext the user chooses to send them. Everything a
peer *sends* is treated as attacker-controlled input:

- **Hostile blobs cannot crash, hang or over-allocate the receiver.** Every decoder reads through a
  bounds-checked cursor; no length field drives an allocation; a short or trailing input is `Corrupt`; no
  input can panic (`PROTOCOL.md` §6.2). Evidence: the F2-1/F2-3/F2-4/F3-1/F3-2/F4-1 reviewer fuzz runs
  (≈ 440 000 mutants across every wire format, zero panics, zero false accepts), plus the committed
  `formats::tests::truncated_payloads_are_corrupt_not_unsupported`,
  `api::files::tests::fuzz_flips_on_the_key_message_never_panic_or_leak`,
  `store::tests::foreign_or_broken_blobs_are_errors_not_panics`.
- **Hostile Argon2 headers are capped.** A pasted `0x05` blob, a received container or a tampered `0x10`
  blob dictates the KDF cost; the decoder refuses `m > 256 MiB` or `t > 16` (and anything `argon2` itself
  rejects) **before allocating a single block**, and all Argon2 runs in the process are serialised by one
  lock taken before the buffer is allocated (`PROTOCOL.md` §11). Worst accepted header: 256 MiB × 16 passes
  ≈ 2 s on a laptop, of the order of ten seconds on a phone, never an OOM (`PROTOCOL.md` §17.9). Test:
  `files::tests::oversized_argon2_params_rejected_before_any_write`.
- **A peer cannot steer the receiver's file system, nor block a file with its name.** The original name is
  made safe as a bare *name* on both sides — separators, Windows-forbidden, control and direction characters
  replaced, trailing dots and spaces removed, device names such as `CON` prefixed, shortened to 120 bytes
  (`PROTOCOL.md` §7.3). The receiver picks the directory. Tests:
  `files::tests::safe_file_name_makes_every_name_receivable`,
  `api::files::tests::hostile_peer_names_are_received_under_a_safe_name`.
- **A peer cannot make the receiver spend a message on an incomplete file.** The structural check of
  `PROTOCOL.md` §9.2 step 3 runs before the Olm message is opened, so a header-only or truncated container
  is `Corrupt` with nothing consumed. Test: `api::files::tests::incomplete_container_rejected_before_the_message_is_spent`.
- **A peer cannot re-bind a file key to other chunks or another prefix.** The chunk AAD is the entire
  header, Olm body included (`PROTOCOL.md` §9.4 "Binding"). Test: `api::files::tests::rebound_key_message_is_corrupt`.
- **A peer cannot impersonate the other direction or another chat** (§4.2, inner header).
- **Limits:** a peer *can* make the receiver consume a message on a container whose chunks are then
  corrupt (`PROTOCOL.md` §17.5; §7.8 below) — the file must be re-sent, and the UI says so; a peer can
  choose a file name that looks like another (Unicode direction override — no longer shown, R14) or collides
  with an existing output (it is then saved as `name (1).ext`, R15); a peer can flood the ratchet windows so that the victim's older unread blobs become
  undecryptable (§7.7) — a denial of *old* messages, never a disclosure.

### 4.5 ADV-5 — malware on an unlocked device

Largely a non-goal (§7.1), stated here so the boundary is visible:

- **Defended:** nothing the malware can read from disk is plaintext except the metadata of §2.4, a hand-off
  copy while the user opens, saves or shares a file, files the user saved or shared (A12, §2.5) and, for the
  seconds an export runs, the archive's working file (§2.5, R35); keys never
  cross to Dart and are wiped in Rust on drop (`PROTOCOL.md` §13 "Inside the crate"); there is no logging of
  any secret; the state file body is serialised into an exactly-sized wiped buffer so no partial copy of a
  key is left on the heap by buffer growth (`PROTOCOL.md` §10.3; test:
  `store::tests::state_body_is_exactly_sized_with_full_skipped_key_stores`); the Argon2 block buffer is
  owned by the crate and wiped after each run (`PROTOCOL.md` §11).
- **Not defended:** a process running as the same OS user on a desktop can read the unlocked app's memory,
  the clipboard, the screen and — on Linux (libsecret) and on a development-flavour macOS build — the
  keystore entries that hold the wrapped master key (still under the master password). On Android the app
  sandbox and Keystore stop a non-root app; root is a compromised OS. Once the app is unlocked the store stays
  open until the whole-app auto-lock or the Lock button closes it (§4.3, R21).
- **Post-compromise, explicitly.** Malware that copies the store directory while the app is unlocked holds
  every chat's sealed state file (A4); it opens them with the store key, which is in the unlocked process's
  memory while the app is unlocked.
  As in §4.3: past messages stay unrecoverable (their keys are gone), but each chat's current receiving
  chain key decrypts the next unread message and every later message the peer generates on that chain
  until the peer has received a new ratchet key from the victim (the victim sends; the peer receives — no
  victim read is needed), and the identity keys allow impersonation until the chat is deleted. The exposure
  is therefore not "one snapshot", it is "one snapshot plus the future of every chain it holds until the
  victim sends and the peer receives". No mitigation in scope (R32).
- **A captured store key or vault key is permanent.** Malware that read either key from the unlocked
  process keeps opening every present *and future* state file, local seal and vault item after the user
  changes the master password, uses the recovery key, or re-pairs: a password change re-wraps the same key and
  nothing is re-sealed (§4.3, R33). Only deleting every chat and the vault ends it.

### 4.6 ADV-6 — harvest-now-decrypt-later

Stated honestly because the product invites it: users are told blobs are safe to leave anywhere, so blobs
sit in inboxes for years.

- **Today's protection:** X25519 (3DH + ratchet), AES-256-CBC + HMAC-SHA256 (Olm v1 message layer),
  XChaCha20-Poly1305, Argon2id, Ed25519, SHA-512. The symmetric layers are not threatened by a quantum
  computer at the parameters used. The **asymmetric** layer is: a cryptographically relevant quantum
  computer breaks X25519, recovers the 3DH secret of a recorded pairing, and with the recorded blobs
  recovers every message key of that chat. Forward secrecy does not help against this — it protects
  against *state* compromise, not against breaking the key agreement itself.
- **No post-quantum component ships in this version.** vodozemac is X25519-only; a hybrid ML-KEM + X25519
  pre-key exchange is a deliberate later project, sequenced after this protocol has been audited so that
  two protocol migrations are never stacked. The clock is NIST IR 8547 (ECC-256 deprecated by 2030,
  disallowed after 2035). This is non-goal §7.9 and residual R22.
- **What the user can do now:** pair over a channel the harvester does not see (the pairing blobs are the
  only thing whose recording matters for this attack; a message blob alone is useless without the session
  secret), and treat long-secrecy content accordingly.

### 4.7 ADV-7 — supply chain

See §9. The short version: every crate, direct and transitive, is fixed by `Cargo.lock` and built `--locked`
(the four protocol crates and the bridge are additionally `=`-pinned); a dependency upgrade that changes
any byte of any format fails the committed-vector test; the Rust core is built twice on independent
runners and the hashes must agree, and the Linux bundle ships exactly that core; every release artifact is
listed in `SHA256SUMS` and covered by a GitHub build-provenance attestation; both SBOMs are drift-checked in
CI. What this does not prove: correctness (an attestation says who built the bytes); the Flutter AOT layer
is not reproducible; and, **as of `v1.0.0-rc.1`, the Android APK's core is not byte-identical to the
reproduced library** (§9.2 — one linker flag plus the packaging strip; matched byte-for-byte after the tag,
gated by `attest` from the next tag).

---

## 5. Threat table

Threat → control → where specified → finding of the owner's brief it closes → residual risk or limitation.
Findings F-1 … F-9 are the nine defects the hardening brief opened (§6).

| # | Threat | Control | `PROTOCOL.md` | Closes | Residual / limitation |
|---|---|---|---|---|---|
| T1 | Compromise of one device reveals past messages | Double ratchet, per-message keys deleted on use, deletion persisted before plaintext returns | §8.1, §14, §10.3 | F-1 | Sealed local history is as strong as the master password and the recovery key (D-1, §8); unread blobs within the windows remain decryptable from a seized state (§7.7) |
| T2 | Compromise of one device reveals future messages | Fresh DH on every ratchet step (Olm) — a copied receiving chain dies when this device sends a new ratchet key and the peer has received it; the peer's next message is on a chain the copy lacks (no victim read needed) | §8.1, §14 point 3, §17.14 | F-1 (past) | **Post-compromise is not provided until the peer ratchets**: a copied state file decrypts every message the peer generates on the current receiving chain until then, and nothing forces the victim to send (R32). Identity keys are long-lived per chat: impersonation forward is possible, no revocation (`PROTOCOL.md` §17.13) |
| T3 | MITM substitutes keys during pairing | Ed25519-signed pairing blobs bind each blob to the key inside it; 60-digit safety number over both identity keys + chat id; verified flag cannot pre-date or outlive the keys | §4.1, §5, §17.1 | F-2 | Detection only, and only when users compare out of band; defeating the comparison is a birthday search of ≈ 2¹⁰⁰ over the attacker's two substitute keys (not 2¹⁹⁹); no commitment round, so an SAS scheme would add nothing (`PROTOCOL.md` §17.1) |
| T4 | Ciphertext bound to nothing (re-routing between chats / directions / versions) | Inner header inside the Olm plaintext: version, chat id, sender and recipient identity keys, direction, counter, content type; constant-time key comparison; ordered validation chain that changes no state on failure | §7.1, §7.2 | F-3 | Not in the clear by design (`PROTOCOL.md` §6.5) — the paste target is the open chat; a cross-chat paste surfaces as `Corrupt`, not `WrongChat` |
| T5 | Replay of a captured blob | Olm consumed keys (`MissingMessageKey` → `Replay`) + per-direction 64-bit counter window | §7.2 check 3, §8.2 | F-4 | The window is stricter than Olm (§7.7); a genuine replay is refused before the window is consulted |
| T6 | Reordered / never-delivered blobs break the session | Olm skipped-key store (40 per chain, 5 chains, gap ≤ 2000) + counter window (63 behind the newest accepted) | §8.1–8.3 | F-4 | Product limits: > 40 unread per chain loses the oldest; > 63 behind the newest accepted in a direction is `TooOld` |
| T7 | Tampered file lands on disk as apparently valid output | STREAM: per-chunk 16-byte tag, header ‖ index as AAD, explicit last-chunk flag; plaintext written only after the tag; `.part` unlinked on any failure | §9.1–9.3 | F-5 | Process kill leaves a `.part` (`PROTOCOL.md` §17.11); in chat mode a corrupt chunk has already consumed the key message (`PROTOCOL.md` §17.5; §7.8 here) |
| T8 | Truncation or extension of a file | Last-chunk flag in the nonce; tail `< 16` fails structurally before any output | §9.2 | F-5 | — |
| T9 | Non-standard, non-interoperable cryptography | RSA/OAEP handshake deleted; only audited crates, no primitive written here; every format starts `FUZZ` + version + type | §12, §15 | F-6 | Olm v1 is Matrix's construction with an 8-byte MAC (T15) |
| T10 | Unmaintained vendored crypto fork receives no upstream fixes | PointyCastle fork and every pure-Dart crypto path deleted; `Cargo.lock` + `--locked` (protocol crates also `=`-pinned), `cargo audit` in CI, Dependabot weekly on cargo / pub / actions | §15; §9 below | F-7 | `flutter_rust_bridge` is deliberately excluded from Dependabot and bumped by hand in lockstep (§9.3) |
| T11 | Key material cannot be wiped | Every secret in Rust is `Zeroizing`/`ZeroizeOnDrop`; no `Debug`/`Clone` on key types; exact-size serialisation; wiped Argon2 buffer; nothing key-shaped crosses the FFI | §13, §10.3, §11 | F-8 | Passwords on the Dart side and the bridge buffer are not wipeable (§2.2, R19) |
| T12 | File encryption unusably slow (product defect, and a reason users skip it) | Native STREAM at 576–605 MB/s on an Apple-silicon laptop (release), median 60 / 424 MB/s encrypt / decrypt on an API 35 emulator (profile), versus 1.2 MB/s before | §9 | F-9 | Debug builds ship the crate's dev profile (7 MB/s) — timing only in profile/release; `poly1305` has no NEON backend so the laptop ceiling is ≈ 580 MB/s |
| T13 | Thief reads state files, history or vault from a powered-off device | State files sealed under the store key; each chat's history sealed under that chat's own history key, which lives inside its state file (so under the store key too); vault items under the vault key; the store key and (by default) the vault key wrapped under the master key, the master key under Argon2id of the master password and of the recovery key (a vault with its own password: under Argon2id of that password, and sealed to the recovery lock, which only the recovery key opens); the wrapped blob doubles as the password verifier; no empty password | §10.2–10.6, §11 | — | Biometric copy of the password (§2.3); the recovery key wherever the user keeps it (R37); OS keystore is the floor. The per-chat history key does not add a gate against a thief who has the store key or the password — it limits what a leaked *history key* (one chat's state opened, or the key read from the unlocked process) exposes to that one chat. Kept files are sealed under this row (A12); files the user took out are T25 |
| T14 | Thief or malware reads metadata | none | §10.5 | — | **Non-goal** (§7.4): chat names, timestamps, counts, sizes, blob texts, vault titles/tags are plaintext |
| T15 | MAC forgery against Olm's 8-byte tag | No oracle: every decryption is a human paste; a failed check changes nothing (test `api::messages::tests::tampered_blob_corrupt`); nothing decrypts automatically; no network to signal success | §17.6; §7.5 below | — | Stated as a known limitation; an untruncated MAC is vodozemac's `experimental-session-config` (R23) |
| T16 | Olm encoding malleability | Inherent to Olm; vodozemac re-encodes what it MACs; only canonically-equivalent encodings of the *same* message are accepted, same key consumption | §17.7 | — | Not a forgery; documented so an "accepted mutant" in a fuzzer is not mistaken for a bypass |
| T17 | Hostile KDF parameters exhaust memory or hang the device | Caps `m ≤ 256 MiB`, `t ≤ 16` checked before allocation; one Argon2 buffer per process | §11, §17.9 | — | Up to ≈ 10 s of CPU on a phone per hostile blob, by the user's own paste |
| T18 | Path traversal via a peer-chosen chat id or file name | Chat id shape-validated at every entry; blob chat ids only ever *compared*; file names validated as bare names on both sides | §2, §7.3 | — | Display and overwrite mitigated in the app (R14–R15): direction controls not shown, risky types not opened, existing files never replaced |
| T19 | Unauthenticated `peek_chat_id` used to route a pasted pairing blob | Documented as a routing hint; every operation that acts on the id re-verifies the signature; the Dart side uses it only for a read-only lookup and for deleting a core state that has no database record | §13; F2-7 review | — | R16 |
| T20 | State and message key lost to a crash mid-operation | Atomic write, save-before-return, cache evicted on any failure; a crash between Olm decrypt and write leaves the key → user re-pastes; a crash after the write has already returned the plaintext | §10.3 | — | The app-layer database write after a successful core call is not in the same transaction (R17–R18) |
| T21 | Wrong-type / wrong-role blob accepted under the right password | AAD domains: `master-key`, `master-key-recovery`, `vault-key` for `0x10`; `vault-key-recovery` for `0x11`; `store-key-wrap`, `vault-key-wrap`, `chat-state ‖ chat_id`, `local-seal ‖ chat_id ‖ row`, `vault-item ‖ version ‖ id`, `app-setting ‖ name`, `recovery-lock` for `0x20`; the first 31 bytes for `0x05`; storage-only types refused on paste | §6.7–6.9, §10 | — | Tests: `vault::tests::master_key_and_vault_key_domains_are_separate`, `master::tests::under_master::roles_keys_and_tampering_are_corrupt`, `master::tests::recovery_lock::only_the_recovery_key_of_the_lock_opens_a_box`, `formats::tests::recovery_box_round_trip_and_strict_length`, `formats::tests::pasted_rejects_storage_only_kinds`, `store::tests::corrupt_missing_and_foreign_files` |
| T27 | Someone with file access swaps or rolls back stored data: a history seal moved to another row or flipped between sent and received, a vault item file copied over another or replaced by an older copy, the vault's auto-lock switched off in `vault.meta`, the app's auto-lock loosened in its settings, the recovery lock swapped for one whose secret they hold | History seals bound to chat id ‖ direction ‖ blob text; vault items bound to id ‖ version; the vault's auto-lock is a constant of the app, not in `vault.meta`; the app's auto-lock times sealed under the store key and limited to the offered choices; the recovery lock sealed under the store key (a swapped lock is `Corrupt`, and nothing is sealed to it) | §10.4, §10.6, §10.7 | security review 2026-10-22 | Rolling back a vault item **and** its database row together, or the whole device to an older snapshot, is not detected — there is no trusted counter (R38); the vault index accepts a file one version ahead of its row (a stop between the two writes) |
| T28 | An unlocked app left on a desk or switched away from; the lock switched off; a forgotten password | One master password, set at the first run, "good" strength, cannot be switched off; whole-app auto-lock on idle and in the background, Lock button; a printable recovery key, shown once, kept only when the user confirms it is saved; an explicit warning that without the password or the key nobody can bring the data back; "erase everything and start over" as the way out | §10.2, §10.7 | owner request 2026-10-25 | The idle time with the app in the foreground (R21); the recovery key's safety is the user's (R37) |
| T22 | Post-quantum adversary records pairing blobs and messages | none in this version | §17.12 | — | **Non-goal** (§7.9); hybrid ML-KEM is the next protocol project (R22) |
| T23 | A dependency, toolchain or CI runner ships different bytes than reviewed | `Cargo.lock` + `--locked`, committed vectors fail on any byte change, two-runner reproducible Rust core, `SHA256SUMS` + provenance attestation, SBOM drift gates | §12, §15, Appendix A; [`RELEASE.md`](RELEASE.md) | — | Flutter AOT not reproducible; as of `v1.0.0-rc.1` the Android APK's core differs from the reproduced library by one linker flag's `.hash` section (`RELEASE.md` §5, §9.2 — matched byte-for-byte after the tag with cargokit's link flags plus the packaging strip; `attest` gates both shipped cores against the rebuild from the next tag), and rc.1's compare gate was inert (evidence = the two `rust-repro-*` artifacts + review); release tags are signed with the real keys or stop — Android key from secrets, macOS Developer ID + sandbox check + notarization, Windows signing a placeholder (`RELEASE.md` §2, 2026-10-26); non-tag CI builds are unsigned proofs; a build with `--cfg fuzzing` would silently disable signature checks (§9.4) |
| T24 | OS / cloud backup carries the store, the plaintext metadata and (per platform) the wrapped key off the device | Opted out everywhere since `6ecd9f1`: Android `allowBackup="false"` + `fullBackupContent` + `dataExtractionRules` (cloud backup and device transfer) excluding every domain; darwin `NSURLIsExcludedFromBackupKey` on Application Support at launch + `ThisDeviceOnly` keychain items | §10.5; §2.8 here; `test/platform/backup_opt_out_test.dart` | manifest + rules + darwin-source assertions; merged manifest checked with `aapt2` | Before the fix: metadata readable by the backup provider on every platform; on **iOS** (and the macOS development flavour) the key item restored even to a new device (R33 copy case). After it: no platform backup carries the store, the database or the key; Linux/Windows have no platform backup to opt out of (a user's own profile backup still carries the store directory — R34) |
| T25 | Unfuzzed file plaintext read from the device (thief, malware, another app or user on a desktop, a profile backup) | Since 2026-10-26 the app keeps only sealed files in private storage; a plain copy lives for one use in the private hand-off folder and is wiped right after, when the page closes and at every launch, together with the picker's cache copies and old share staging; Android: no storage permission, no Downloads/MediaStore, FileProvider limited to the hand-off folder; iOS: Documents no longer shown in the Files app; no plain file is handed to another app to open | §9.6, §10.5, §17.15; §2.5, §7.13 here | `user_file_store_test.dart`, `user_files_test.dart`, `file_processing_cubit_test.dart`, `chat_file_cubit_test.dart` | A hand-off copy is plaintext while in use (default file mode; a kill leaves it until the next launch; an Android share target may still read after the app wipes on return); a file the user saved or shared is the user's ("protect it like any other file", About encryption, README); R36 |
| T26 | The archive export leaks history: plaintext residue during or after the seal, or a weak archive password guessed offline | Plaintext JSON lines exist only in the app-support directory for the seal's duration and are deleted in `finally`; the store must be open; the dialog refuses weak/fair passwords; the container is Argon2id (m = 64 MiB, t = 4) password mode (§9.5, §11); share staging holds sealed bytes only | §9.5, §11; §2.5 here | — | A process **kill** mid-seal leaves `chat_archive_<chat id>.jsonl` until the next launch, whose sweep deletes it (since 2026-10-26); the archive is outside forward secrecy by design — its security is the password; R35 |

---

## 6. The nine findings of the brief

| Finding | Closed by | Deferred? |
|---|---|---|
| **F-1** No forward secrecy (one long-lived symmetric key per chat) | Olm double ratchet via vodozemac; T1–T2; tests `api::messages::tests::forward_secrecy`, `api::files::tests::forward_secrecy_for_files` | No. The *product* consequence (single-use blobs, local history) is owner decision D-1 (§8), implemented per the brief's recommendation |
| **F-2** Unauthenticated handshake | Ed25519-signed pairing blobs + 60-digit safety number + verified flag; T3 | No. The brief named vodozemac's emoji SAS; the build ships a Signal-style safety number instead (owner decision D-2, recorded as reversible; reason in §7.10) |
| **F-3** Empty AAD | Inner header inside the Olm plaintext (chat id, keys, direction, counter, version, content type); AAD on every local and password format; T4, T21 | No |
| **F-4** No replay or ordering protection | Olm consumed keys + per-direction counter window; T5–T6 | No |
| **F-5** File decryption releases unverified plaintext | STREAM chunks, tag before write, `.part` guard; T7–T8 | No |
| **F-6** Non-standard OAEP | The RSA handshake is deleted, not fixed; T9 | No |
| **F-7** Vendored, unsynced PointyCastle fork | Deleted with the whole pure-Dart crypto stack; `rg -i pointycastle` over `lib`, `test`, `pubspec.*` is empty (F4-4 review); T10 | No |
| **F-8** Unwipeable key material | All key material in Rust, zeroised; T11 | Closed for keys; residual for Dart-side passwords (R19) — Dart structurally cannot fix that part |
| **F-9** Pure-Dart bulk crypto ≈ 1.2 MB/s | Native STREAM; measured 576–605 MB/s laptop release, 60 / 424 MB/s emulator profile; T12 | No |

Nothing among F-1 … F-9 is deferred. What *is* deferred is listed as non-goals in §7 and as residual risks
in §10: post-quantum, formal verification of the handshake, iOS/App Store, sealing of Isar metadata. The archive
export and the owner-facing trade-off copy that D-1 gated are built (F2-10, F2-11; R10 closed).

---

## 7. What we do not defend — explicit non-goals

Each item is a boundary of the model, not an oversight. A reviewer who finds an attack inside one of these
has found a fact we already state, not a finding against the protocol.

### 7.1 A compromised OS or device

Root or jailbreak with hostile software, a debugger on the process, a malicious keyboard, a kernel
keylogger, firmware or hardware implants, a compromised keystore. The crate runs inside the app's process
and trusts the OS for memory isolation, randomness (`getrandom`), file permissions and the keystore
(`PROTOCOL.md` §3, §13). Malware running as the same OS user on a desktop is in this category (§4.5).

### 7.2 Screen capture

Plaintext must be shown to be read. Screenshots, screen recording, shoulder surfing, accessibility services
that read the widget tree — out of scope. The app sets no secure-window flag.

### 7.3 Clipboard sniffing

A blob on the clipboard is readable by any app the OS allows. That is ciphertext (harmless to ADV-1 beyond
metadata), but a *decrypted* message the user copies is plaintext on the clipboard. The app does not clear
or time out the clipboard.

### 7.4 Metadata

The database is not encrypted as a whole (§2.4, `PROTOCOL.md` §10.5). Chat names, chat ids, timestamps,
message ordering and counts, file names and sizes, the ciphertext blobs, vault item titles, tags, group and
type are plaintext on disk. A thief without the password learns *who* (as named by the user), *when* and
*how much*, never *what* — and so did whoever held an OS/cloud backup made before `6ecd9f1`, which opts the
database out of platform backups (§2.8, R34; a user's own Linux/Windows profile backup still carries it).
Sealing chat names and vault titles is the same `seal_local` call on more columns —
a documented follow-up, not this build (R11).

Also in the clear, at the app layer only: a **"Copy as link"** message link
(`https://ink.fuzzzycore.com/message#<base64 JSON>`, `lib/src/core/services/fuzzy_link/`) carries the
**chat id** next to the blob so the receiving app can open the right chat. The raw `Fuzz/` blob never does
(`PROTOCOL.md` §6.5). A user who shares links rather than blobs gives an observer a stable identifier that
groups every link of one chat (only the device that opens the link sees it: it sits after the `#`). The leak is
metadata-only: the receiving app uses `c` for a read-only database lookup and navigation, the crate takes
the chat id from the database record, and a blob under the wrong `c` dies at the Olm MAC with no state
change; an observer who saw the pairing blobs already knows the chat id. This is a product choice inherited
from before the hardening; it is recorded as R12 for the owner (decision D-7), with both costs stated there.

### 7.5 The 8-byte Olm v1 MAC — and why no forgery oracle exists here

Olm v1 truncates HMAC-SHA256 to 8 bytes per message (`PROTOCOL.md` §4, §17.6). A forgery attack on a
truncated MAC needs an **oracle** that answers "did this ciphertext verify?" quickly and many times — the
classic setting is a server that decrypts on arrival. Fuzzzy Ink has none:

1. **The user is the oracle.** The only way a message blob reaches `decrypt_text`, or a container reaches
   `prepare_file_receive`, is a human pasting it into the open chat and pressing send, or picking a file
   (§2.6). Every trial is a human action; the ~2⁶³ expected trials of a blind forgery do not happen.
2. **A failed trial changes nothing and says nothing new.** The Olm decrypt runs on a copy of the session;
   a MAC failure leaves the state file byte-identical and reports the same payload-free `Corrupt` as any
   structural fault (`PROTOCOL.md` §7.2). Tests: `api::messages::tests::tampered_blob_corrupt` (a real MAC
   failure, state file byte-identical), `api::messages::tests::wrong_inner_header_is_rejected_without_state_change`
   (the post-MAC belt), and the reviewer fuzz runs asserting byte-identical state after every rejection.
3. **A successful MAC forgery still has to pass the inner header.** The decrypted bytes must be a valid
   inner header naming this chat, both identity keys, the right direction and a fresh counter, or the
   result is `Corrupt`/`WrongChat` with no state change — indistinguishable from a MAC failure to anyone
   but the user holding the device.
4. **There is no network to signal anything.** The crate has no network code; the app has no server; a
   deep link prefills a text field and decrypts nothing (§2.6).

**The design rule that keeps this true, stated for every future change:** *no code path may ever decrypt
a message or file automatically on paste, on link open, on clipboard change or on file arrival, and no
code path may report a decryption outcome to anything outside the device.* Adding either would turn the
user-as-oracle argument into a real oracle and would require revisiting this section and, most likely, the
MAC length (R23). Pairing blobs are not affected by the MAC length at all: they are authenticated by a full
64-byte Ed25519 signature (`PROTOCOL.md` §4.1).

### 7.6 Single decrypt — a blob is readable once, on one device

By design (F-1): a message key is destroyed on use. Re-pasting a blob that was already read is `Replay`;
a new device cannot read old blobs; the sender cannot read its own output (`PROTOCOL.md` §14). History
therefore lives in the local seal (A7) under the chat's own history key, which is what D-1 (§8) decided.

### 7.7 The windows — 40 keys, 5 chains, gap 2000, and 63 counters behind

Two independent limits, either of which can refuse a blob first (`PROTOCOL.md` §8):

- **Olm's** (vodozemac's constants, not tunable without a fork): at most 40 skipped message keys per
  receiving chain, at most 5 receiving chains, a message more than 2000 ahead of the chain is refused. A
  peer who generates more than 40 blobs before the other side reads any of them loses the oldest.
- **This protocol's** counter window: per direction, a counter more than 63 behind the newest accepted one
  is `TooOld` even if Olm could still decrypt it. The window is stricter than Olm, never looser
  (`PROTOCOL.md` §8.2 "Parity with Olm"); whether to widen it or make it per-chain is an open product
  decision (R2).

Both are availability limits on *old, unread* blobs; neither ever discloses anything.

### 7.8 A corrupt chat-mode file consumes its message

The file's Olm message is opened — and the ratchet advanced — before the chunks are verified, because the
alternative would keep the message key alive while the file key sits outside the store (`PROTOCOL.md`
§17.5, §9.4). A damaged container must be re-sent; a retry is `Replay`; the UI says so. A cancelled receive
is equally terminal (R13).

### 7.9 No post-quantum cryptography

X25519 only (§4.6). Harvest-now-decrypt-later against the key agreement is **not** defended in this version.

### 7.10 No deniability claims

Pairing blobs are signed with long-lived identity keys and the signatures are kept in the state file for
re-display; a signed invitation or acceptance is a cryptographic proof that a device holding that key
produced it. Olm messages themselves use MACs (deniable in principle), but this protocol makes no
deniability claim and its safety number is a fingerprint of signing keys. (This is also why the brief's
emoji SAS was not used: without a commitment round a two-blob SAS is grindable by an active attacker, and
vodozemac's SAS secret cannot be persisted across the days between invitation and acceptance — D-2.)

### 7.11 Once the user sends plaintext

A user who pastes plaintext into the channel instead of a blob, or who shares a screenshot, or who tells
the peer the safety number over a channel the attacker controls, is outside every control here.

### 7.12 Transport security, multi-device, groups, key rotation, web

- **No transport security claim of any kind** — the app has no transport (§2.7).
- **No multi-device for one user, no group chats** (`PROTOCOL.md` §1).
- **No rotation of a chat's identity keys** — delete and re-pair (`PROTOCOL.md` §17.12).
- **No web build.** `flutter_rust_bridge` generates a web shim, but the app is neither built nor tested
  for the web and no claim is made for it.
- **No anti-forensics.** Deleting a chat overwrites its state file with zeros before unlinking, best effort
  on flash storage (`PROTOCOL.md` §10.3 "Delete"); nothing else is promised about remanence, journaling file
  systems, backups the OS takes, or swap.
- **No post-compromise security beyond what Olm's ratchet gives — and Olm heals only once the peer
  ratchets.** A compromised state file keeps decrypting the peer's messages on the current receiving chain
  until this device has sent a message carrying a new ratchet key *and the peer has received it*; the
  peer's next message is then on a chain the attacker does not hold. No read on the victim's device is
  needed, and nothing forces the victim to send (`PROTOCOL.md` §8.1, §14 point 3, §17.14). The identity keys stay
  compromised regardless and the attacker can impersonate in that chat until it is deleted (§4.3, §4.5, T2,
  R32). No mitigation ships in this version.

### 7.13 Files the user takes out, and exported archives

A file is unfuzzed so that it can be used. The app keeps it sealed and unfuzzes it only for one use — shown in
the app, saved through the system save dialog, or shared through the share sheet — and wipes that copy right
after (§2.5, A12). From the moment the user saves or shares it, the file is the user's and the app makes no
claim about it: it is not sealed, the master password does not gate it, deleting the chat does not remove it, and any
process or person who can read the place the user chose reads it (T25, R36). The same is true of an exported
chat archive once it leaves the app: it is the chat's plaintext under the password the user chose, outside
forward secrecy (`PROTOCOL.md` §9.5, T26, R35). A kept received file has the protection of text history, not
forward secrecy (`PROTOCOL.md` §9.6, §8). The product copy says this plainly (About encryption; README).

---

## 8. The forward-secrecy trade-off — owner decision D-1, answered 2026-09-13: design (a) with a per-chat key

The brief reserved one product decision for the owner: what happens to history once blobs are single-use.
The question was asked on 2026-09-11 and answered on 2026-09-13: **GO on design (a)**, with one addition —
each chat's history is sealed under a key that belongs to that chat, not under an app-wide key (implemented
as F2-12, `PROTOCOL.md` §3, §10.4). The record below is quoted verbatim from the studio's decision register
(`OWNER_DECISIONS.md` in the hardening flow; the `plans/…` paths it cites are internal to that register, not
to this repository).

> ## D-1 · Plaintext at rest (the decision the brief reserved for the owner)
> Full text: `plans/fuzzzy_ink_hardening_plan_2026-09-11.md` §B.8. Short form:
> - The ratchet makes every blob single-use: decrypt once, on one device, never again (that is F-1 closed).
> - Sent messages MUST be stored locally regardless (a sender cannot decrypt its own output) — not optional.
> - Recommended (a): store received plaintext too, sealed with XChaCha20-Poly1305 under a per-install key
>   protected by the app-lock password, because Isar 3 is NOT encrypted on its own (verified). Plus a
>   40-message skipped-key window (vodozemac's constant), a password-protected archive export, and plain UI
>   copy that a new device cannot re-read old blobs.
> - Alternative (b): received messages stay ciphertext-only; history shows "unfuzzed once" placeholders.
> **Answer (2026-09-13): GO on (a)** — store received history sealed at rest, BUT seal each chat's history under a
> **per-chat key derived from that chat's initial key material** (not the app-wide local key), as defence in
> depth; the app-lock password stays the outer gate. Implemented as feature F2-12 before F2-10/F2-11.
>
> ## Note for D-1 copy (2026-09-12, from F2-4 review)
> Besides "each blob unfuzzes once, on one device", the history copy must state: a blob more than **63 messages
> behind** the newest one you already read (per direction) can no longer be unfuzzed. Planner may revisit
> Olm-parity later; the core ships the stricter rule.

**What is implemented** (`PROTOCOL.md` §3, §10.4, §17.3):

- Sent and received **text** plaintext are sealed per row under **the chat's history key** — 32 random bytes drawn
  when the chat's Olm account is created (`create_invitation` on A, `accept_invitation` on B), stored only
  inside that chat's sealed state file, AAD `local-seal` ‖ chat id (‖ row since 2026-10-26) — and kept in
  `StoredMessageData.sealedPlaintext`; the row also keeps the blob text. File rows carry no seal — the received
  file is a plain file on disk (§2.5, §7.13) and the row holds its path. A tag failure, a chat the store does
  not know, or a locked store reads the row as an empty message (flagged `isUnreadable` since F2-10), never a throw
  (`test/src/fuzzzy_ink/data/repositories/message_data_repository_test.dart`, incl. "sealed in chat A … reads
  as empty in chat B"; Rust `api::local::tests::{history_key_differs_per_chat, cross_chat_seal_rejected,
  history_key_survives_reload, delete_chat_makes_history_unreadable}`).
- **"Derived from the chat's initial key material", as built:** the key is drawn from the CSPRNG at the same
  moment as the chat's identity keys and lives with them, not HKDF-derived from the Curve25519 identity
  secret — vodozemac 0.10.0 gives no public accessor for that secret (the `AccountPickle` fields are private),
  and a fresh random key has the same property without parsing vodozemac's private pickle layout in library
  code. The owner's intent — one chat's key opens no other chat's history — holds either way.
- **What the per-chat key does and does not buy, honestly:** it bounds a *history-key* leak to one chat on one
  device (A's and B's keys for the same chat are independent; nothing crosses the wire). It does **not** bound a
  *store-key* or master-password leak: the store key opens every state file and each state file carries its
  chat's history key, so whoever has the store key reads every chat's history exactly as before (§4.3, T13,
  R33). Deleting a chat destroys its key with its state; its sealed rows are unreadable from then on by design.
- The sealed copy is therefore exactly as strong as the master password (and the recovery key, its second way
  in); there is no "lock off" and no `""` wrap since 2026-10-26 (§2.3, §4.3).
- Design (b) remains a small app-layer change (do not call `seal_local` on receive; show a placeholder); the
  protocol is unchanged either way.

**Built on D-1 (both landed 2026-09-13):** the password-protected **archive export** — "Export chat archive" in
each chat's settings, a password-mode `0x04` container of JSON lines that opens in Basics → file decryption,
no import path (F2-10; `PROTOCOL.md` §9.5; T26, R35) — and the owner-facing **trade-off copy** (F2-11): an
onboarding slide, the chat-creation success notice, an "About encryption" page under Settings, and the README.
The copy says: *each fuzzed message can be unfuzzed once, on this device only; a blob more than 63 messages
behind the newest one you already read can no longer be unfuzzed; a new device or a fresh install cannot
re-read old blobs and there is no cloud copy; the readable **text** history is sealed per chat under a key only
this device holds; **files** are kept sealed too and a file the user saves or shares is theirs (2026-10-26);
"Copy as link" carries the chat id; biometric unlock keeps the password in the OS keystore; the chat store
does not lock itself.* R10 is closed by this. What the copy does not say in as many words: that a password
change re-keys nothing already copied (R33) — stated here and in `HARDENING_2026.md` §6 instead.

Also relevant to this model, as decided on 2026-09-13: **D-2** safety number accepted; **D-3** macOS signing and
**D-6** the Android keystore move to the owner's Codemagic pipeline (a signed macOS build additionally needs the
`com.apple.security.files.user-selected.read-write` entitlement for the file picker and the archive save panel);
**D-5** private vulnerability reporting is enabled, the `security@` route and the website's `security.txt` are
owner/ops items (R29); **D-7** keep the chat id in message links and state it (done in the copy); **D-10** the
hardened build ships as `v1.1.0`. D-4 (build fully, then test) and D-8/D-9 were applied.

---

## 9. Supply chain

### 9.1 What is pinned and checked on every push

- **Toolchains:** Rust 1.98.1 (`rust/fuzzy_crypto_core/rust-toolchain.toml`), Flutter 3.41.7 / Dart 3.11.5 (`.fvmrc`),
  NDK 28.2.13676358, `cargo-ndk` 4.1.2 (`RELEASE.md` §4). The app builds (CI and Codemagic store builds)
  compile the core through cargokit, which since 2026-10-26 uses the toolchain of `rust-toolchain.toml` and
  `--locked` (§9.4).
- **Build steps:** every third-party GitHub Action in `.github/workflows/main.yaml` is pinned to a full commit
  (its version in a comment), so its author cannot swap the code behind a tag; the workflow token has no
  permissions by default and each job is granted only `contents: read` (the `attest` job adds the
  `id-token` and `attestations` writes it needs). Since 2026-10-26.
- **Dependencies:** the pin that matters is **`Cargo.lock` + `--locked`** on every build, CI and release
  alike — every crate, direct and transitive, resolves to the locked version or the build fails. On top of
  that, `Cargo.toml` carries exact `=` pins for the four crates that implement the protocol (`vodozemac`,
  `chacha20poly1305`, `aead-stream`, `argon2`) and for `flutter_rust_bridge`; the remaining direct
  dependencies (`sha2`, `zeroize`, `getrandom`, `subtle`, `base64`, `serde`, `serde_json`, `thiserror`)
  are caret ranges fixed by the lockfile. The audited crates and their audits are listed in
  `PROTOCOL.md` §15; `cargo audit` runs in the `rust` job
  ([`.github/workflows/main.yaml`](../../.github/workflows/main.yaml)).
- **Format drift is a test failure.** Nineteen machine-generated vectors are committed and
  `vectors::committed_vectors_match` fails `cargo test` if any byte any format produces changes — so a
  dependency upgrade that alters output is a deliberate act, never an accident (`PROTOCOL.md` §12,
  Appendix A; [`vectors/README.md`](vectors/README.md)).
- **SBOMs:** CycloneDX for the Rust crate ([`sbom/rust.cdx.json`](sbom/rust.cdx.json), `cargo cyclonedx`,
  every target) and for the Flutter app ([`sbom/flutter.cdx.json`](sbom/flutter.cdx.json), cdxgen 12.8.4
  from `pubspec.lock`; cdxgen and everything under it installed by `npm ci` from the committed
  `tools/sbom/package-lock.json`, exact versions and integrity hashes, no install scripts); both committed, both regenerated in CI by `./sbom.sh … --check`, which fails the
  build if the committed file drifts from the lockfiles. An independent reviewer validated both against the
  CycloneDX schema and cross-checked every `Cargo.lock` entry (F5-3 review).
- **Dependabot** ([`.github/dependabot.yaml`](../../.github/dependabot.yaml)) watches cargo, pub and
  GitHub Actions weekly.

### 9.2 Release integrity ([`RELEASE.md`](RELEASE.md))

- **Reproducible Rust core — with one honest limit.** Two independent runners build `libfuzzy_crypto_core`
  for the Linux host and for `aarch64-linux-android`; `rust-repro-compare` fails the workflow if any hash
  differs or if a runner path survives in the binary (a real gate from the commit after `v1.0.0-rc.1`; on
  the rc.1 run itself it was inert — see the caveat below). The only machine path a release library embeds is
  `CARGO_HOME` inside registry-crate panic strings, remapped by [`.cargo/config.toml`](../../.cargo/config.toml)
  for desktop builds and seeded through `CARGO_ENCODED_RUSTFLAGS` in the `android` job (cargokit sets that
  variable, which makes cargo ignore the config file's rustflags). **What is established as of
  `v1.0.0-rc.1` (`RELEASE.md` §5):** the two runners reproduce each other on both targets, and the **Linux
  bundle's shipped core is byte-identical** to the reproduced library (`b13462d8…`). The **Android APK's
  core at that tag is not**: the shipped `ad625a3a…` and the reproduced `b8e30d0c…` differ only by a SysV
  `.hash` section plus its `DT_HASH` entry (cargokit links with `--hash-style=both`, `cargo ndk` 4.1.2 does
  not) — `.text`, `.rodata`, both relocation tables, `.dynsym`, imports and `.comment` are otherwise equal.
  After the tag, `RELEASE.md` §5 records the rest of the gap: with cargokit's link flags plus the Android
  Gradle plugin's `llvm-strip --strip-debug` the rebuild is byte-identical to the APK core (`ad625a3a…`,
  run 34721691080); the `rust-repro` job now applies both, and from the next tag on `attest` extracts the
  shipped Linux and APK cores and fails the tag run unless their hashes are in the rebuild's `SHA256SUMS`
  (`RELEASE.md` §4 "What we do not promise"; the Windows and macOS cores are attested and path-clean but not
  gated against a rebuild). The rebuild recipe is `RELEASE.md` §4, not restated here. Two caveats
  `RELEASE.md` §5 records and this document inherits: the
  rc.1 hashes are established by the two `rust-repro-*` artifacts of the tag run plus an independent
  review, **not** by the compare gate, which was inert on that run (`diff && echo` under `set -e`; fixed on
  the commit after the tag); and the host matters — reproduce on a Linux x86_64 host, as CI does.
- **`SHA256SUMS` and provenance.** On a `v*` tag, every artifact is listed in `SHA256SUMS` and
  `actions/attest-build-provenance` signs a SLSA provenance statement over that list (Sigstore, keyless);
  `gh attestation verify` ties a file to the repository, workflow, tag and run that built it. The pipeline
  is on the branch; the first attested tag (`v1.0.0-rc.1`) is cut by the release procedure of `RELEASE.md`
  §1 and its measurements are recorded in `RELEASE.md` §5 when the tag run completes.
- **What is not proven:** correctness (provenance is not a review); the Flutter AOT output is not
  bit-for-bit reproducible (build paths and ids embedded — an upstream Dart SDK limitation). Signing
  (since 2026-10-26): a release tag signs the Android APK with the real key from repository secrets, signs,
  sandbox-checks and notarizes the macOS app with a Developer ID certificate, and signs the Windows exe and core
  (a placeholder step until a certificate is chosen) — or stops, naming the missing secrets; no throwaway key
  exists anywhere. Until the owner adds those secrets, no release tag can complete (`RELEASE.md` §2). iOS is
  built and signed on Codemagic and sent to TestFlight, not here.

### 9.3 The lockstep rule for the bridge

`flutter_rust_bridge` is pinned three ways and must move as one — the Rust crate (`=2.13.0`), the Dart
package (`2.13.0`) and the codegen that wrote `lib/rust_bridge/**` (`codegenVersion 2.13.0`). A mismatch
fails the build; Dependabot cannot group across ecosystems, so **every** bridge bump is excluded from
Dependabot and done by hand with the codegen re-run. The generated bridge is committed; each feature's
reviewer re-ran `flutter_rust_bridge_codegen generate` and confirmed a byte-identical result. There is no
CI gate for codegen drift (R24).

### 9.4 Things a reviewer of the build must know

- **The vendored `cargokit`** (`rust_builder/cargokit/`, the frb 2.13.0 integration template) builds the
  crate from source on every platform. It is upstream apart from the integrator's prelude comment (F1-2
  review) and two marked changes (2026-10-26): `builder.dart` takes the toolchain from the crate's
  `rust-toolchain.toml` (upstream uses the `cargokit.yaml` channel, default "stable", so a store build
  compiled the core with whatever stable was current) and passes `--locked`; `rustup.dart` recognises a
  version-numbered toolchain as installed. Each is commented "Fuzzzy Ink change" — re-apply them if
  cargokit is ever re-vendored. Its own `build_tool/pubspec.lock` is not under Dependabot.
- **Never build with `--cfg fuzzing`.** Under that cfg vodozemac's `Ed25519PublicKey::verify` is a no-op
  and every pairing signature would silently pass. A standing comment at the top of
  `rust/fuzzy_crypto_core/src/lib.rs` records it; no CI job sets it; a reviewer should grep for it in any
  future workflow change (`PROTOCOL.md` §15).
- **The private UI-kit dependency.** `fuzzzy_ui_kit` is a git dependency on a private repository reached in
  CI through a read-only deploy key held as an Actions secret. It contains no cryptography; it is on this
  list because it is the one dependency an outside builder cannot fetch without that key.
- **Android 16 KB page alignment** of the native library is a CI gate (the `android` job), a platform
  requirement rather than a security control, listed so the reviewer does not wonder what the step is.

---

## 10. Residual risks and open questions

Each item names its source: a `PROTOCOL.md` section, an owner decision, or the independent review of the
feature that introduced or found it (the per-feature review records of the hardening build, kept in the
studio's flow directory; the review ids below are those records).

| # | Residual risk / open question | Source | Owner |
|---|---|---|---|
| R1 | **MITM until the safety number is compared.** Pairing authenticates blobs to keys, not to people; detection needs the users to compare 60 digits out of band. | `PROTOCOL.md` §17.1; F2-3 review row 4; F2-5 review §2 | product (UX must keep pushing verification) |
| R2 | **Counter window stricter than Olm** — a blob > 63 behind the newest accepted in its direction is refused although Olm could decrypt it; also the older-chain case. Widen, or make per-chain? | `PROTOCOL.md` §8.2, §17.2; F2-4 review N1 | planner |
| R3 | **D-1 answered (2026-09-13): design (a) with a per-chat history key** — implemented (F2-12). Residual: the key is random-with-the-account rather than HKDF-derived from the identity secret (vodozemac exposes none); equivalent in effect, stated in §8 and `PROTOCOL.md` §3. | §8; `PROTOCOL.md` §3, §10.4, §17.3 | closed |
| R4 | **The empty-string wrap — closed 2026-10-26.** The master password is set at the first run and cannot be switched off; the crate refuses an empty password; an install from before starts fresh (`PROTOCOL.md` §10.1, §10.2). | `PROTOCOL.md` §10.2 | closed |
| R5 | **Isar metadata in plaintext**, including vault item titles/tags/group/type and the blob texts. | `PROTOCOL.md` §10.5; F5-1 log §5 | follow-up: seal more columns |
| R6 | **8-byte Olm v1 MAC.** No oracle exists today (§7.5); the guarantee is a design rule, not a cryptographic one. An untruncated MAC exists as vodozemac's `experimental-session-config` (`SessionConfig::version_2()`), off by default and not enabled here. | `PROTOCOL.md` §17.6; hardening plan §H (internal) | audit question (R23) |
| R7 | **Olm encoding malleability** — canonically-equivalent encodings of one message are accepted (same plaintext, same key consumption). | `PROTOCOL.md` §17.7; F2-3 review row 8; F2-4 review row 7 | none (inherent) |
| R8 | **The file-key message is not bound to `chunk_size` / `nonce_prefix` at prepare time** — any single-bit change to the 24 non-Olm header bytes passes `prepare_file_receive`, consumes the message, and only then fails at chunk 0 (AAD). Folding those fields into the `0x02` body would refuse before spending the step, at the price of a layout change. | `PROTOCOL.md` §9.4 "Binding"; F3-2 review §2 (2 209 header variants) and N5 | planner (format v2 candidate) |
| R9 | **Corrupt or cancelled chat-mode file consumes its message** — terminal for that container. | `PROTOCOL.md` §17.5; F3-2 review §3/N4; F3-3 review N2 | product copy |
| R10 | **Archive export and trade-off copy — built** (F2-10 `d2a2f15`, F2-11 `57ad6d4` + `f88774b`, 2026-09-13). History leaves the app by the export (R35) or by copying messages; the copy states the single-use rule, the 63-behind window, the new-device rule, the text-only seal and the files-in-the-clear fact (§8). | §8; `PROTOCOL.md` §9.5 | closed |
| R11 | **`getMessagesForChat` degrades on a locked store**: every text row reads as an empty string with a logged warning. Since F2-10 the row carries `isUnreadable` (set when the seal is absent, malformed, or the core answers `Corrupt` / `UnknownChat` / `StoreLocked`) and the archive export returns `storeLocked` before it touches the file system, so a blank-rows archive cannot be produced; an unreadable row exports as `"unreadable": true`. The UI still renders such a row as an empty message (only the export reads the flag). | F2-8 review §8; F2-10 review §1–3 | closed (residual: the UI shows `''`, not a marker — product) |
| R12 | **The "Copy as link" message link carries the chat id in the clear**; pairing links carry `exp`. The raw blob does not. Both options have a cost, for D-7: **keep `c`** — a stable per-chat identifier on every message link (metadata only, §7.4); **drop `c`** — link routing disappears, because the blob carries no chat id (`PROTOCOL.md` §6.5) and the only way to route without one would be to trial-decrypt across every chat's session on link open, which the §7.5 rule forbids — a message link could then only prefill the currently open chat or ask the user to pick one. | §7.4; hardening plan §H (internal) rule "no chat id in the clear without a threat-model note" | owner |
| R13 | **A cancelled chat receive** shows no failure reason, and the next attempt on the same container reads "already unfuzzed". | F3-3 review N2 | product copy |
| R14 | **Peer-chosen file names are not display-safe** (a Unicode direction override is a valid name). **Mitigated 2026-10-22 (security review item 4):** every shown file name has its direction controls and control characters removed (`UserFileNames.forDisplay`). **Since 2026-10-26** the app never hands a plain file to another app to open: images and text are shown in the app, anything else offers Save only, so the extension denylist and "Show in folder" are gone with the risk they guarded. Remaining: a file the user saves and then opens from their own file manager is theirs to judge; the failed-files snackbar prints the *input* container name unsanitised. | `PROTOCOL.md` §7.3; F3-2 review N1; F3-3 review §1; security review 2026-10-22 | product |
| R15 | **Output collisions overwrite silently** (`<chat>/<originalName>`), and the name is now peer-chosen. **Mitigated 2026-10-22 (security review item 5):** the app picks the output path before the core runs and never picks an existing name or one with a `.part` beside it — `name (1).ext`, `name (2).ext`, … (`UserFileNames.uniqueOutputPath`, for chat receive and send and both Basics directions); since 2026-10-26 chat files go to the app-private `sealed_files/chats/<safe chat name> (<first 8 of the chat id>)/` and Basics files to `sealed_files/basics/`, and plain copies to a fresh hand-off folder per use, so nothing the app writes can land in a user folder or another chat's. The core is unchanged (its final rename still replaces), so a file another program creates under the chosen name *while* a job runs is replaced. | `PROTOCOL.md` §9.3, §10.5; F3-3 review N3; security review 2026-10-22 | product |
| R16 | **`peek_chat_id` is unauthenticated** by design; the Dart side uses the peeked id for a read-only lookup and — only when no database record exists — to delete an orphaned core state before re-accepting. A crafted invitation naming an id this device holds hits the own-invitation guard. | `PROTOCOL.md` §13; F2-7 review §2 | none (documented) |
| R17 | **Handshake half-commit window**: the core persists `complete_handshake` before the database record is updated; a kill between them leaves the record "invited" while the core is connected, and every retry is `InvitationAlreadyUsed` until the chat is deleted and re-paired. Recoverable; one chat wide. | F2-7 review nit 2 | developer (reconcile from `chat_status` at chat open) |
| R18 | **Seal failure on write stores the row with a null seal** — reachable if the store closes between `decrypt_text` and `seal_local`. Since the whole-app auto-lock (2026-10-26) the store can close while a chat is open: a lock in that instant leaves the received text unreadable (the blob itself is already spent). | F2-8 review §2; R21 | product (hold the lock while a decrypt is in flight) |
| R19 | **Passwords on the Dart side are not wipeable** (Dart `String`; the bridge's serialisation buffer is freed unwiped). Key material is unaffected. | §2.2; F2-2 review nits; brief F-8 | none (language limit) |
| R20 | **Biometric unlock stores the password** in the OS biometric keystore (Android: Keystore key with `AUTH_BIOMETRIC_STRONG` only and timeout 0 — a prompt on every read, invalidated by a new enrolment; iOS/macOS: data-protection Keychain, `WhenPasscodeSetThisDeviceOnly` + `biometryCurrentSet`, no reuse window; not available on Linux/Windows); unlocking is then as strong as the OS biometric gate. | §2.3; `biometric_auth_repository.dart`; `biometric_storage` 5.0.1 | product copy |
| R21 | **Auto-lock and manual lock — built 2026-10-26.** The whole app locks after the idle time (default 5 minutes), after the time in the background (default 1 minute; "at once" available) and on the Lock button; locking closes the store and the vault. Residual: the idle time with the app open in the foreground; "at once" also locks while a system file picker or share sheet is in front. | §4.3, §4.5 | product (times are the owner's call) |
| R22 | **No post-quantum component**; harvest-now-decrypt-later on the X25519 key agreement is undefended. Hybrid ML-KEM + X25519 on the pre-key exchange is the next protocol project, after this one is audited. | §4.6, §7.9; `PROTOCOL.md` §17.12 | owner (sequencing) |
| R23 | **Open audit question — MAC length.** Should a format version 2 adopt vodozemac's untruncated-MAC session config, given that the oracle argument rests on a product rule rather than on the primitive? | §7.5; R6 | auditor → owner |
| R24 | **No CI gate for bridge-codegen drift** — reviewers re-run the generator per feature; a stale `lib/rust_bridge/**` would be caught by a human, not a job. | §9.3 | ops |
| R25 | **Argon2id cost on low-end devices.** Unlock ≈ 1.0 s on an API 35 arm64 emulator (release core), ≈ 0.13 s on an Apple-silicon laptop; a hostile-header worst case of ≈ 10 s on a phone; debug builds ship the crate's dev profile and take ≈ 10 s per KDF. The parameters (`m = 64 MiB`, `t = 4`) are data, not format, so a later build may tune them without a version bump. | `PROTOCOL.md` §11, §17.9; F2-6 QA; F4-1 review | product (measure on real low-end hardware) |
| R26 | **Windows secure-storage size limit** is not an issue for the ≈ 140-character wrapped blob (limit 2 560 bytes) but it is the reason nothing larger must ever be stored there. | hardening plan §B.6 (internal) | none (documented) |
| R27 | **macOS development flavour uses the login keychain**; staging/production use the data-protection keychain. Never ship the development flavour. | `PROTOCOL.md` §17.8; D-3 | ops |
| R28 | **Release signing:** prepared without keys (2026-10-26) — release tags sign with the real Android key, a Developer ID macOS identity (sandbox checked, notarized) and a Windows certificate (placeholder), or stop; the keys and certificates themselves are not yet provided. iOS: Codemagic → TestFlight. | `RELEASE.md` §2, §6 | owner (keys, certificates, which Android key signs the download) |
| R29 | **Disclosure surface, partly done (D-5):** GitHub private vulnerability reporting **enabled** 2026-09-13 (`SECURITY.md` and `security.txt` name the advisories URL, commit `365e8bd`); the `security@fuzzzycore.com` route is **not yet confirmed** (Cloudflare Email Routing is owner-only; `contact@` stays the advertised address until then); `security.txt` on the website is **written but not deployed** (`fuzzzy_core_website` PR #1). | D-5; `SECURITY.md`; `security.txt` | owner (mail route) / website deploy |
| R30 | **Two processes on one store**: refused by an exclusive lock since 2026-10-26 (the second gets `Io`). `.part` files survive a process kill. | `PROTOCOL.md` §17.10–17.11 | lock (two processes); none for `.part` (documented) |
| R31 | **Pairing has no timeout**: a pending chat keeps its account and one-time key until accepted, regenerated or deleted; the link-level `exp` is a hint the core never checks. | `PROTOCOL.md` §4.6 | product |
| R32 | **No post-compromise security until the peer ratchets.** A copied state file (thief with the password, malware on an unlocked device, a user-made backup of the store directory) holds the current receiving chain key of each chat and decrypts every message the peer generates on that chain until this device sends a message carrying a new ratchet key and the peer has received it — the peer's next message is then on a chain the copy lacks; no victim read is required, and messages the peer generated before receiving it stay readable by the copy. Nothing forces the victim to send. Past messages stay protected (forward secrecy). No mitigation in scope; candidates (forcing a ratchet step on every send, or re-keying on unlock) are a protocol change for a later version. | `PROTOCOL.md` §8.1, §14 point 3 (verified against the crate: a copy of B's state opened three messages A generated afterwards, and got `Corrupt` on A's first message after A had received B's reply), §17.14; F5-1 security audit finding M1 | planner (format v2 candidate); product copy |
| R33 | **No store re-key, and a vault re-key only when the vault gets its own password; a leaked key outlives every other password change.** `change_master_password`, `recover_master_password`, `new_recovery_key`, `vault_rewrap`, `vault_use_master_password` and `vault_recover` re-wrap the *same* 32-byte keys; nothing is re-sealed. Since 2026-10-26 `vault_use_own_password` draws a new vault key and the app re-seals every item to it (security review M1), so a vault key leaked before that switch opens nothing written after it; it is the only re-key path. A store key or vault key read from the unlocked process, or a copy of the secure-storage blobs whose (old) password or recovery key is known — a macOS development-flavour login-keychain read, a Linux/Windows user-profile backup (§2.8; **not** an Android backup, whose entry is Keystore-bound; since `6ecd9f1` no platform backup carries the item) — opens every present and future state file — and, through the history key each state file carries, every chat's local seals — and vault item after any password change, recovery or re-pair. The per-chat history key (F2-12) does not change this: it is sealed *under* the store key, not beside it. Remedy today: delete every chat and the vault, or wipe the app (deleting one chat does destroy that chat's history key). Format v2 candidate: re-key = re-seal all state under a fresh store key. | `PROTOCOL.md` §10.2, §10.6; F4-1 review ("the master key never changes"), F4-2 review §2; §4.3, §4.5 | planner (format v2); product copy |
| R34 | **OS / cloud backups — fixed in `6ecd9f1`** (`allowBackup="false"` + `fullBackupContent` + `dataExtractionRules` on Android; `NSURLIsExcludedFromBackupKey` on Application Support and `ThisDeviceOnly` keychain items on darwin). Residual: Linux and Windows have no platform backup to opt out of, so a user's own full-profile backup still carries the store directory, the database and the vault folder (the key stays in the login keyring / DPAPI store); on Windows, OneDrive folder backup (often on by default) uploads Documents and with it every file the user saved there (and the unfuzzed files builds before 2026-10-26 left in `Documents/Fuzzzy Ink/`), and a domain roaming profile copies Roaming AppData; on darwin the exclusion is applied to the directory at launch, so a backup made before the first launch of a build ≥ `6ecd9f1` may still hold the older files; the **macOS development flavour** keeps its key item in the login keychain, where `ThisDeviceOnly` is not enforced (only the data-protection keychain enforces it), so that flavour's item still travels with a Time Machine copy of the keychain file; and the product copy says "a new device, or a fresh install, cannot re-read old blobs, and there is no cloud copy" (README, F2-11) rather than naming OS backups explicitly — sufficient for the user, noted for the copy's next pass. | §2.8; T24; `AndroidManifest.xml`, `res/xml/*.xml`, `AppDelegate.swift`, `MainFlutterWindow.swift`, `default_constants.dart`; owner decision D-8 | product copy (F2-11) |
| R35 | **The archive export is plaintext under a password, outside forward secrecy — by design — and its working file is not `0o600`.** During an export the chat's rows exist in the clear as `<app support>/chat_archive_<chat id>.jsonl` for the seal's duration (default file mode; Dart cannot set `0o600` — routing the temp through the crate's `store::create_tmp` would close that); a process kill mid-seal leaves the file until the next launch, whose sweep deletes it (2026-10-26); on Android and iOS the sealed container goes through the private hand-off folder to the save dialog and is wiped right after (sealed bytes only). Once exported, the archive's only protection is the user's password against offline Argon2id-bounded guessing (the dialog refuses weak/fair passwords); a lost archive is the chat's history, readable by whoever guesses the password, forever. | §2.5, §7.13, T26; `PROTOCOL.md` §9.5, §11; F2-10 review N1–N2 | developer (`0o600` via a Rust temp helper) — non-blocking; boot sweep done 2026-10-26 |
| R36 | **Files the user takes out are in the clear.** Since 2026-10-26 the app keeps only sealed files and wipes every plain copy after its one use (A12, §2.5); what remains plain: a hand-off copy while it is shown, saved or shared (user-private storage, default file mode, wiped on use, on page close and at launch; a process kill or an Android share target that reads late are the gaps), and every file the user saves or shares — the product's purpose (a file is decrypted in order to be used), stated in the About-encryption page and the README. Builds before 2026-10-26 wrote unfuzzed files to Documents / Android Downloads; no migration removes those (pre-launch). | §2.5, §7.13, A12, T25; `PROTOCOL.md` §9.6, §10.5, §17.15 | product |
| R37 | **The recovery key is a second password for everything the master password opens.** Printed or saved by the user (the app offers the system save dialog — a file the user can print — and never the clipboard); whoever finds it opens the app. A skipped key leaves none; a new key deletes the old wrap, lock and vault box at once. It also opens a vault that has its own password (owner, 2026-10-26: a `0x11` box sealed to the recovery lock), so a vault's own password guards against someone with the master password, not against the recovery key; a new key needs the vault's password to keep that vault recoverable. The key that opens such a vault is always one the user was shown when the vault got its own password, or later with the vault's password — giving the vault its own password ends the earlier key and shows a new one (security review 2026-10-26), so a key made by somebody else with the master password before then opens nothing. Without a kept recovery key such a vault is lost with its password (said where the user chooses it). | `PROTOCOL.md` §10.2, §10.6 | product (copy) |
| R38 | **Rollback of a vault item together with its database row**, or of the whole device to an older snapshot, is not detected: the item's version lives in the plaintext index, and there is no trusted counter. Swapping items, or putting back an older file alone, is detected. | `PROTOCOL.md` §10.6; T27 | none (documented) |

---

## 11. What an audit should focus on

In descending order of what a finding would be worth to the product. Everything else in this document has
either been independently re-derived (vectors, goldens) or fuzzed by a reviewer at least once; these are the
places where a fresh pair of eyes changes the risk.

1. **The post-compromise window (R32) and the user-as-oracle argument (§7.5).** For R32: confirm from
   vodozemac's receiver-chain code how long a copied chain key stays live under realistic paste-messenger
   traffic (the victim may receive many peer messages before ever sending one), and whether the product should
   force a ratchet step or re-key on unlock in a later format. For §7.5: confirm there is no code path —
   deep link, clipboard listener, file watcher, share sheet, notification — that decrypts without a user
   action, and no path that reports an outcome off the device; then take a position on R23: is a product
   rule an acceptable basis for an 8-byte MAC, or should format version 2 move to the untruncated session
   config?
2. **The validation chain order (`PROTOCOL.md` §7.2) and the "no state change on failure" invariant.**
   `with_state_mut` + save-before-return is the property every replay and forward-secrecy claim rests on.
   Read `store.rs` `with_state_mut`, `messages.rs` `decrypt_payload`, `pairing.rs` `complete_handshake` and
   the file `prepare_*` pair; try to construct an input that mutates cached or on-disk state before the
   last check passes.
3. **Pairing and the safety number (`PROTOCOL.md` §4–5).** The signature domains, the ordered checks, what
   the handshake header binds, whether the number transitively pins every 3DH input as §5 claims, and the
   two-leg collision bound (≈ 2¹⁰⁰, §4.2). Formal modelling of this handshake in Tamarin is a planned
   follow-up; an auditor's informal attack search here is the next best thing.
4. **The file-key binding gap (R8)** and whether it should be closed in the format rather than at the AAD.
5. **The local-state key hierarchy (`PROTOCOL.md` §3, §10–11).** Store key → state files → one random history
   key per chat (F2-12: is it really unreachable without the store key, and does the AAD `local-seal` ‖ chat id ‖ row
   hold?) and the AAD domains; the master key above the store key and the vault key, its two wraps (master password,
   recovery key) and the recovery key's encoding and check byte; the recovery lock (X25519 from the recovery key
   through an X9.63 SHA-256 KDF, sealed under the store key) and the `0x11` box that lets the recovery key, and not
   the master password, open a vault with its own password; the row binding of history seals and the
   id/version binding of vault items; the caps on attacker-controlled Argon2 headers;
   the single Argon2 lock taken before allocation.
6. **The FFI boundary (`PROTOCOL.md` §13).** Grep the generated `lib/rust_bridge/**` for anything
   key-shaped; confirm every function touching a key is asynchronous and every opaque handle is held by
   reference only (a by-value opaque parameter would panic in frb's owned decode).
7. **Zeroization on the Rust side** — including the exact-size serialisation of pickles (`state.rs`) and
   the wiped Argon2 buffer — and an honest statement of what the Dart side cannot wipe (R19).
8. **Metadata and what leaves the device (§7.4, §2.8, §7.13, R5, R12, R33, R34, R35, R36)** — whether the plaintext
   columns, the chat id in message links, the residual backup paths after the opt-out, the absence of any re-key,
   the plain hand-off copies while a file is in use and the archive export's working-file residue are acceptable
   for the product's threat population.
9. **The windows (§7.7)** — whether 40 / 5 / 2000 / 63 match how people will actually use a paste-based
   product, and whether `TooOld` and `Replay` are surfaced clearly enough that a user does not mistake a
   window limit for tampering.
10. **The supply chain (§9)** — reproduce the Rust core hash from the published procedure, verify one
    attestation, diff the SBOMs against the lockfiles, and check no workflow ever sets `--cfg fuzzing`.

What an audit should **not** spend time on: the byte layouts (pinned by vectors and re-derived
independently in Python by every feature's reviewer), the deleted pure-Dart stack (gone, grep-verified), and
the primitives themselves (vodozemac, RustCrypto AEADs and password-hashes — already audited, see
`PROTOCOL.md` §15).
