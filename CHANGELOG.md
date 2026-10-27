# Changelog

All notable changes to Fuzzzy Ink are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- **One master password over every key**, chosen at the first run ("good" strength or better, cannot be switched
  off), and a **printable recovery key** shown once, which opens the app if the password is forgotten. Builds before
  this one start fresh.
- **The whole app locks itself** after the idle time you choose (5 minutes by default) and shortly after you leave
  it; a Lock button locks at once. Wrong passwords start a growing wait after five tries, kept across restarts.
- **My safe** opens with the master password, or with a password of its own; the recovery key opens it either way.
- **Links** on `https://ink.fuzzzycore.com/{invite,accept,message}#…` (the part after `#` never reaches a server),
  a QR code, or a `.fuzz` file, from one Share button. The old `fuzzylink://` scheme is gone.
- **Lock and Open**, a page per person with their history, and the redesign with Fuzzzy Cast.
- **Open `.fuzz` files from other apps** (Android, iPhone, Mac): the file goes to Open, which asks before it opens
  a message or a person's file, or connects a reply.
- **"Needs a newer Fuzzzy Ink"**: something made by a newer version of the app says so instead of "damaged".
- **Computer keys:** ⌘ (Mac) or Ctrl + L opens Lock, + O opens Open, + comma opens Settings, + Shift + L locks the
  app.

### Security
- **My safe's own password means a new key.** Giving the safe its own password now draws a new safe key, re-locks
  every item under it and draws a new recovery key, shown right away; someone who knew the master password before,
  or who made a recovery key of their own with it, can no longer open the safe.
- **A link or a file from another app never opens or connects anything by itself.** A message link (or file)
  asks "Open the message from {name}?" first, a reply asks "Connect with {name}?", and the "someone else answered
  your invite" warning shows only for a reply that really answers your invite. Message links no longer carry the
  chat's id.
- **Nothing plain leaves by accident.** Only locked output (and, behind a switch, a safe password) can be copied;
  password, recovery-key, message and opened-item fields offer no Copy, Share, Look Up or other apps' text actions
  (Translate and the like), and keyboards are asked not to learn what is typed. A copied safe password is cleared
  after 30 seconds, now also in the background on Android, and kept out of Windows clipboard history and the cloud
  clipboard; every copy is cleared when the app locks.
- **Private screens** (unlock, recovery key, My safe, opened messages and files, a person's page, Basics) are kept
  out of screenshots, recordings and the app switcher on Android, iPhone, macOS and Windows. On a phone the app
  switcher shows no picture of any screen (iPhone, and Android 13 and later).
- **The app keeps only locked files.** Plain copies exist only while a file is shown, saved or shared, in a private
  folder wiped right after, when the app locks and at every launch (picked files on iPhone included). Nothing is
  written to Downloads or the Files app any more. A received file is kept under the name its sender sealed inside
  it.
- **Every form that takes the master password counts wrong tries**, My safe's own password has its own count, and
  setting the device clock forward or back no longer ends a wait or skips the lock.
- **Erase everything** also clears preferences, remembered replies, picked files and a waiting link, and the
  database file is compacted at the next launch.
- **Fingerprint unlock** accepts strong biometrics only and asks every time.
- **The safety number shows its version**, so two app versions that compute it differently show different versions
  instead of different digits that look like an attack. The digits of 1.1.1 and later are unchanged.
- **Any file name can be received.** A name the partner chooses is made safe on both sides (characters Windows
  forbids, device names such as `CON`, trailing dots, very long names) instead of making the file impossible to
  receive.
- **One copy of the app per device.** A second copy of the app can no longer open the same chats at the same time
  (which could corrupt a chat or reuse a message key); deleting a chat overwrites its saved state in place first.
- **Builds:** outside build steps are pinned to exact commits with the least permissions; checks also run on the
  integration branch; every package install enforces the lock file; the build service's Rust installer is pinned by
  checksum; store builds compile the encryption core with the pinned Rust version and lock file; release builds are
  signed only with the real keys from the build service and stop when a key is missing; the patched `ctutils` and
  `tokio` versions are in. The production link files trust the production app only. Development builds no longer
  log opened messages.

### Changed
- **The app is called Fuzzzy Ink** (was Fuzzzy Seal) wherever a person sees the name: the home-screen and window
  titles on every platform, the welcome and unlock screens, the Face ID and biometric prompts, and the text sent with a
  shared invitation, acceptance or message, in English and Georgian. The identifiers changed too, from 1.1.1 on:
  the app id is `com.fuzzzycore.ink` (1.1.0 was `com.fuzzzytechnologies.fuzzy_chat`, so a 1.1.0 install never
  updates to this app — install it fresh), the Dart package is `fuzzzy_ink`, and the safety-number domain
  separator is `FUZZZYINK_SAFETY_NUMBER_V1`, so a 1.1.0 device shows different safety-number digits.
- **Files go where you put them.** The app no longer writes plain files to `Downloads/Fuzzzy Ink/` on Android or to a
  Documents folder visible in the iPhone Files app: you save or share each file through the system, and the app
  keeps only the locked copy. Files saved by earlier builds stay where they are and are not moved. My safe moved to
  the app's private folder (it was in Documents, where iPhone's Files app and cloud folders could see it).

## [1.1.0] — 2026-09-13

The cryptography was rebuilt from the ground up. The app had not launched, so every format was broken on purpose:
there is no migration path and no compatibility code. Full write-up: [`documents/security/HARDENING_2026.md`](documents/security/HARDENING_2026.md);
before/after glossary and mind-map: [`documents/security/WHAT_CHANGED.md`](documents/security/WHAT_CHANGED.md).

### Added
- **Rust crypto core** `rust/fuzzy_crypto_core` behind `flutter_rust_bridge` 2.13.0 — Dart never sees a key. Built only from
  audited crates: `vodozemac` 0.10.0 (Olm double ratchet), `chacha20poly1305` + `aead-stream` (XChaCha20-Poly1305 / STREAM),
  `argon2` (Argon2id, 64 MiB / t = 4), `sha2`, `subtle`, `zeroize`, `getrandom`.
- **Forward secrecy:** every message and file is encrypted under a key used exactly once; a blob unfuzzes once, on the device it
  was meant for. Pairing blobs are Ed25519-signed; a **60-digit safety number** and a shield indicator let both people rule out a
  man-in-the-middle.
- **Files:** chunked STREAM containers (1 MiB) — a tampered or truncated file is refused before a byte reaches the disk.
  Throughput ≈ 580 MB/s on an Apple-silicon Mac (was 1.2 MB/s).
- **Sealed history:** received text history is sealed per chat under a random per-chat key held only on that device, behind the
  app-lock password (owner decision D-1); **chat archive export** as a password-sealed file; **About encryption** page, onboarding
  slide and README copy stating the trade-offs (single-use blobs, 63-behind window, files in the clear, chat id in links).
- **App lock, vault, Basics** now keep a wrapped key rather than a verification token; Basics passphrases go through Argon2id.
- **Evidence for an audit:** `documents/security/{PROTOCOL,THREAT_MODEL,RELEASE}.md`, byte-exact test vectors, CycloneDX SBOMs,
  `SECURITY.md` + `security.txt` (GitHub private vulnerability reporting enabled).
- **Release pipeline:** every `v*` tag publishes `SHA256SUMS` and SLSA build-provenance attestations; the Rust core is rebuilt on
  two independent runners and the shipped Linux and Android cores are gated byte-identical to the rebuild.
- Marionette instrumentation of the development flavour for live QA; a file-encryption benchmark tile (development flavour only).

### Changed
- Wire and on-disk formats: every blob, file container, state file and wrapped key starts with `FUZZ 01 <type>`; old blobs
  and files are not readable. Version `1.0.0+1` → `1.1.0+2`.
- The app opts out of OS/cloud backups on every platform; keychain items are device-only.

### Removed
- The pure-Dart crypto stack and the vendored PointyCastle fork (RSA-4096/OAEP + AES-GCM, one long-lived key per chat) —
  deleted, not kept behind a flag. All nine findings of the 2026 hardening brief (F-1 … F-9) are closed.

[1.1.0]: https://github.com/fuzzzy-bot/fuzzy_chat/releases/tag/v1.1.0
