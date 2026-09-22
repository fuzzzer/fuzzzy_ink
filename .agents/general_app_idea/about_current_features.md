# Fuzzzy Seal: About Current Features

## 1. Local Chat Spaces
- **Offline Generation**: The app creates isolated data environments representing a "chat" with a specific person. Each chat's keys and ratchet state live in one sealed file in the Rust core's store (`fuzzy_crypto_store/<chatId>.state`).
- **Link Handshake System**: Connect securely using copy/paste codes (or a `fuzzylink://` deep link).
  - *Invitation*: The initiator generates an invite code — a signed blob carrying their identity keys, a one-time key and the chat identifier.
  - *Acceptance*: The receiver pastes the invite code, generates an acceptance code containing their signed part of the handshake.
  - *Verification*: The initiator pastes the acceptance code back in; both signatures are checked and the channel is active. An invitation can be used once (`invitationAlreadyUsed` afterwards); a blob pasted into the wrong chat is rejected (`wrongChat`).
- **Safety Number**: Every connected chat shows a 60-digit safety number (12 groups of 5) computed from both identity keys. Both parties compare it out of band and can mark the chat **verified**; the flag survives restarts.

## 2. Text Fuzzing (Encryption/Decryption)
- Inside a connected chat, any typed text is encrypted (Fuzzed) upon pressing send — an Olm double-ratchet message with a fresh key per message.
- Fuzzed text always starts with `Fuzz/` followed by base64url.
- Pasting a fuzzed text into the chat input and pressing send decrypts it and adds the plain text to the local chat view.
- **Single-use blobs**: a message decrypts exactly once on one device; pasting it again answers "already read" (`replay`). The sender cannot decrypt their own output. Messages more than 63 behind the newest accepted one in that direction are refused (`tooOld`).

## 3. File Fuzzing
- Send files by selecting or dragging them; they are streamed into a `.fuzz` container (`FUZZ 01 04`) in 1 MiB authenticated chunks, with progress, pause and cancel. The file key rides inside one chat message.
- Receiving an encrypted file decrypts it inside the chat; output is written to a `.part` file and renamed only after the last chunk's tag verifies — a tampered file leaves no plaintext behind.
- Throughput is native (hundreds of MB/s on a phone or laptop); a Settings benchmark tile exists in the development flavor.

## 4. App Lock (optional)
- A chat password wraps the store key (Argon2id); unlock opens the store for the session, lock closes it. Biometrics can stand in for the password. Changing the password re-wraps one blob — nothing else is re-encrypted.

## 5. Fuzzy Vault
- A separate password-protected vault for notes, passwords and files, with groups, search, export and auto-lock. Its master key never leaves the core; items are sealed under it (optionally again under a per-item password).

## 6. Fuzzy Basics
- Standalone, no chat needed: fuzz text or files under a password only (`FUZZ 01 05` blobs / `0x04` containers in password mode) to share with anyone who knows the password.

## 7. Local Storage
- All messages (ciphertext plus a locally sealed copy of the plaintext for history), chat states and wrapped keys are stored entirely on the device; nothing is readable without the store key, and the store key is readable only with the (possibly empty) app-lock password. OS/cloud backups are opted out.
- No remote server connectivity exists or is required, isolating the data. The full protocol is in `documents/security/PROTOCOL.md`.
