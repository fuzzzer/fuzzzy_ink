# Changelog

All notable changes to Fuzzzy Ink are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- **The app is called Fuzzzy Ink** (was Fuzzzy Seal) wherever a person sees the name: the home-screen and window
  titles on every platform, the welcome and unlock screens, the Face ID and biometric prompts, and the text sent with a
  shared invitation, acceptance or message, in English and Georgian. Identifiers stay as they were — the app id
  `com.fuzzzycore.seal`, the Dart package, the safety-number domain separator. New files on Android now land in
  `Downloads/Fuzzzy Ink/`; files saved earlier stay in `Downloads/Fuzzzy Seal/` and are not moved.
- **Files land where the user can find them.** A fuzzed file (on send) and an unfuzzed file (on receive) go to
  `Downloads/Fuzzzy Ink/<chat name>/` on Android (MediaStore, no storage permission on API 29+) and to the app's
  Documents folder on iOS, now visible in the Files app. The bubble shows the file's name and that place instead
  of a path; a picker's `null-` name artefact is dropped. "Show" is back on Android and iOS and opens the folder in
  the system file manager; "Open" and "Share File" go by content URI with an explicit type. The action pill stacks
  into rows so every action fits a 360dp phone.

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
