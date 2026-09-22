# Fuzzzy Ink — Protocol Specification, format version 1

**Status:** normative for the code in `rust/fuzzy_crypto_core` (crate `fuzzy_crypto_core` 0.1.0) on the
`agent/chat-harden-rust-crypto-core` branch. Where this document and the code disagree, the code is the
truth and the document has a bug — file it. Every layout below is pinned by a machine-generated vector in
[`vectors/`](vectors/README.md) that `cargo test` checks against the crate on every build.

**Audience:** a cryptographer or security reviewer reading the protocol *before* the code. Nothing here
assumes knowledge of the app; everything here can be verified with `xxd`, a hex editor and the vectors.

**Companion documents:** the threat model is `THREAT_MODEL.md` (F5-2, separate); the reasoning behind the
design is `HARDENING_2026.md` (F5-5). This document only says *what the bytes are and what the code checks*.

---

## 0. Conventions

- Offsets are decimal byte offsets from the start of the blob or file; `a..b` is half-open (`a` inclusive,
  `b` exclusive). Multi-byte integers are **big-endian** everywhere (`u16 BE`, `u32 BE`, `u64 BE`).
- `‖` is byte concatenation. Hex is lowercase. `0x..×n` means the byte repeated `n` times.
- "AEAD" means XChaCha20-Poly1305 (24-byte nonce, 16-byte tag, tag appended to the ciphertext); "KDF" means
  Argon2id; "Olm" means the Olm v1 double ratchet as vodozemac implements it (`SessionConfig::version_1()`).
- Every error the core reports is one of 13 payload-free variants of `CoreError`
  ([`error.rs#L11`](../../rust/fuzzy_crypto_core/src/error.rs#L11)); Appendix B lists them. Tables below name the
  variant a check produces.
- Links of the form `file.rs#Lnn` point at the line that defines the constant or check in the crate at the
  commit this document ships with.
- "Vector: `name`" refers to `vectors/name.hex` (bytes), `vectors/name.txt` (the paste-able text form,
  where one exists) and `vectors/name.json` (every input the vector was built from).

---

## 1. Scope and non-goals

**In scope.** Everything the crate `fuzzy_crypto_core` does:

1. pairing two devices into one chat through two pasted blobs (invitation, acceptance) that establish an
   Olm session on a one-time key;
2. text messages and files on that session, with per-message forward secrecy, replay and ordering rules;
3. a safety number for out-of-band authentication of the pairing;
4. the device-local state: a store key wrapped under the app-lock password, sealed per-chat state files,
   sealed local copies of message plaintext, a vault master key and sealed vault items;
5. password-sealed blobs and files for the "Basics" tools that need no chat at all.

**Non-goals.**

- No transport. Fuzzzy Ink is 100 % offline: every blob travels by copy and paste through whatever channel
  the users choose (SMS, e-mail, another messenger, a QR code). The protocol never sees that channel and
  makes no assumption about it beyond "an attacker may read, modify, replay and reorder anything on it".
- No server, no directory, no key server, no push. There is nothing to be online for.
- No cross-chat identity: every chat has its own fresh key material on each device. Two chats between the
  same two people share nothing cryptographically (§3).
- No group chats, no multi-device for one user, no key rotation of the identity keys of an existing chat.
- No deniability claims and no post-quantum claims (Known limitations, §17).
- The Dart/Flutter layer above the crate (UI, database, clipboard handling) is out of scope here except
  where §13 draws the boundary between the two.

---

## 2. Roles and identifiers

| Term | Meaning |
|---|---|
| **A, the inviter** | The device that creates a chat. It generates the Olm account and the one-time key, publishes the **invitation**, and later completes the handshake from the acceptance. Direction byte `0x00 = A→B`. |
| **B, the accepter** | The device that pastes the invitation. It generates its own Olm account, creates the outbound session on A's one-time key, and publishes the **acceptance**. Direction byte `0x01 = B→A`. |
| **Device / store** | One installation of the app. It owns exactly one *store*: a directory `<app support dir>/fuzzy_crypto_store/` ([`store.rs#L25`](../../rust/fuzzy_crypto_core/src/store.rs#L25)) of sealed state files and one 32-byte **store key**. A device is a store; the protocol has no other notion of identity. |
| **chat_id** | A UUID v4 in its canonical lowercase text form, chosen by A's app when the chat is created. It names the chat on both devices and is a file-name component on disk, so it is validated by **shape** before any other use: exactly 36 bytes, `[0-9a-f]` everywhere except a `-` at offsets 8, 13, 18 and 23 ([`store.rs#L258`](../../rust/fuzzy_crypto_core/src/store.rs#L258)). The version and variant nibbles are *not* checked. Anything else is `Corrupt`. The wire codec itself only requires 1..=255 bytes of UTF-8; the shape check runs at every API entry that takes a chat id from Dart, and inside the crate a chat id read out of a blob is only ever *compared* with an already-validated one, never used as a path (the one function that hands a blob's chat id to Dart unvalidated, `peek_chat_id`, is discussed in §13). |
| **Blob** | A binary message with the 6-byte envelope of §6.2, exchanged as `Fuzz/` text (§6.1). Types `0x01`–`0x05`. |
| **Container** | A file with the `0x04` envelope (§9). Files are never turned into text. |
| **Storage-only blobs** | Types `0x10` and `0x20` never travel: the paste decoder refuses them ([`formats.rs#L63`](../../rust/fuzzy_crypto_core/src/formats.rs#L63)). |

---

## 3. Key material per chat

Everything below is generated by the crate with the OS CSPRNG (`getrandom::fill`, the only randomness
source in the crate) and never leaves it in the clear (§13).

| Key | Owner | Lifetime | Purpose |
|---|---|---|---|
| **Olm `Account`** (Ed25519 signing key pair + Curve25519 identity key pair + one-time keys) | one per **chat per device** | from chat creation to chat deletion | vodozemac's account. A creates hers when the chat is created; B creates his when accepting. There is deliberately no account shared between chats: a compromise, a fingerprint or a mistake in one chat says nothing about another. |
| **One-time key** (Curve25519) | A only | until the handshake completes | A generates exactly one (`generate_one_time_keys(1)`, then `mark_keys_as_published()`) and puts its public half into the invitation. vodozemac deletes the private half the moment the first valid acceptance decrypts (§4.3). No chat ever publishes a second one. |
| **Olm `Session`** | both, one per chat | from acceptance (B) / completion (A) to chat deletion | the double ratchet. B's is outbound (created from A's identity key + one-time key), A's is inbound (created from B's pre-key message). Both persist as vodozemac pickles inside the sealed state file (§10.3). |
| **Message keys** | derived by the ratchet | one message | never stored beyond the ratchet's skipped-key store (§8.1); deleted on use. |
| **File key** (32 random bytes) | sender, per file | one container | drawn per chat-mode file, sealed inside one Olm message in the container header (§9.4). |
| **Store key** (32 random bytes) | one per device | for the life of the install | seals every state file (§10.3) — and, through them, every history key. Exists only wrapped (§10.2) outside a running process. |
| **History key** (32 random bytes) | one per **chat per device** | from chat creation to chat deletion | seals that chat's message history (§10.4) and nothing else (owner decision D-1). Drawn from the CSPRNG at the same moment as the chat's Olm account — `create_invitation` on A, `accept_invitation` on B — and stored as the `history_key` field of the chat's sealed state (§10.3, [`state.rs#L78`](../../rust/fuzzy_crypto_core/src/state.rs#L78)); it never crosses the wire, so A's and B's history keys for one chat are unrelated. It is **not** derived from the identity secret: vodozemac 0.10.0 exposes no accessor for the account's Curve25519 secret (`Account::curve25519_key()` is the public key and `AccountPickle`'s fields are private), and a fresh random key gives the same property — one chat's key opens no other chat's history — without parsing vodozemac's private pickle layout in library code. Regenerating an invitation (§4.2) or deleting a chat (§10.3) replaces or destroys the key; no history exists before the first message, so nothing is orphaned by regeneration. Vector: `local_seal_chat` (fixed key `55×32`). |
| **KEK** | derived | per unwrap | `Argon2id(password, salt, m, t, p)`, 32 bytes (§11). Wraps the store key and the vault master key; is the key of a password-sealed blob and of a password-mode file. |
| **Vault master key** (32 random bytes) | one per vault | for the life of the vault | seals vault items (§10.6). Wrapped under the vault password exactly like the store key, in its own AAD domain. |

The identity keys of A and B are the only long-lived public values a peer ever learns; they are what the
safety number (§5) commits to.

---

## 4. Pairing

The full flow, then each step's rules. All vodozemac calls use `SessionConfig::version_1()` (Olm v1:
X25519 triple Diffie-Hellman pre-key exchange, HKDF-SHA256 ratchets, AES-256-CBC + HMAC-SHA256 truncated to
8 bytes per message).

```
A: create_invitation(chat_id)                         B: accept_invitation(chat_id, invitation)
   Account::new()                                        verify signature, chat_id
   generate_one_time_keys(1); mark_keys_as_published     Account::new()
   Invitation{chat_id, A_curve, A_ed, A_otk} + sig  ───▶ session = create_outbound_session(A_curve, A_otk)
   state: Inviter, session None                          prekey = session.encrypt(handshake inner header)
                                                         Acceptance{chat_id, B_curve, B_ed, prekey} + sig
A: complete_handshake(chat_id, acceptance)          ◀─── state: Accepter, session Some, send_counter 1
   verify signature, chat_id
   create_inbound_session(B_curve, prekey)   ← consumes the one-time key
   check the decrypted handshake header
   state: session Some, peer keys, recv bitmap 1
```

### 4.1 Signatures

Both pairing blobs end in a 64-byte Ed25519 signature by the blob's own author (A's `a_ed25519` for the
invitation, B's `b_ed25519` for the acceptance) over **every byte before the signature, the 6-byte envelope
included** ([`pairing.rs#L24`](../../rust/fuzzy_crypto_core/src/pairing.rs#L24)). The envelope's type byte is
therefore the domain separator between the two signing domains: the same field bytes relabelled under the
other type do not verify. Verification is `ed25519-dalek`'s `verify_strict` through vodozemac's
`Ed25519PublicKey::verify` ([`pairing.rs#L34`](../../rust/fuzzy_crypto_core/src/pairing.rs#L34)), always over
the **received** bytes, never over a re-encoding. A key or signature that does not parse is
`InvalidSignature`.

Order of checks on every pasted pairing blob ([`pairing.rs#L89`](../../rust/fuzzy_crypto_core/src/pairing.rs#L89),
[`#L157`](../../rust/fuzzy_crypto_core/src/pairing.rs#L157)):

1. the Dart-supplied `chat_id` has the uuid shape (`Corrupt`) — before the store is touched;
2. text envelope and outer envelope decode (`UnsupportedFormat`); the blob is of the expected type
   (`UnsupportedFormat`); the payload parses with no trailing bytes (`Corrupt`);
3. **signature** verifies under the key carried in the blob (`InvalidSignature`);
4. the blob's `chat_id` equals the caller's (`WrongChat`).

Nothing from the blob is used before step 3 passes. Note what step 3 does and does not prove: it binds the
blob to *some* Ed25519 key — the one inside the blob. Binding that key to a *person* is the safety number's
job (§5); until it is compared, an attacker who replaces both blobs in transit is in the middle (§17).

### 4.2 Invitation (A) and regeneration

`create_invitation` ([`api/pairing.rs#L32`](../../rust/fuzzy_crypto_core/src/api/pairing.rs#L32)):
a brand-new account, exactly one one-time key, the signed `0x01` blob (§6.3). The state written is
`{role: Inviter, session: None, send_counter: 0, recv_highest: 0, recv_seen_bitmap: 0, last_invitation:
Some(blob)}`. Calling it again while the chat is still pending **regenerates**: a new account replaces the
old one in the state file, so the old invitation can never be completed (an acceptance built on it fails with
`InvitationAlreadyUsed` — vodozemac reports `MissingOneTimeKey`, because the new account never held that key).
Calling it on a connected chat is `Internal` (a programming error; the UI never offers it).

### 4.3 Acceptance (B) and the handshake message

`accept_invitation` ([`api/pairing.rs#L47`](../../rust/fuzzy_crypto_core/src/api/pairing.rs#L47),
[`pairing.rs#L105`](../../rust/fuzzy_crypto_core/src/pairing.rs#L105)): after §4.1, a chat that already has state
on B is `Internal` (B never re-accepts; recovery from a stale invitation is delete-chat then accept). Then:

1. `Account::new()`; `session = account.create_outbound_session(version_1, a_curve25519, a_one_time_key)`.
   vodozemac refuses a non-contributory (low-order) Curve25519 point here; the crate reports `Corrupt`.
2. The **handshake inner header** (§7) is built: `chat_id`, `sender_ed25519 = B_ed`, `recipient_ed25519 =
   A_ed`, `direction = 0x01 (B→A)`, `counter = 0`, `content_type = 0x00 (handshake)`, empty body — 116 bytes
   for a 36-byte chat id. Vector: `inner_header_handshake`.
3. `session.encrypt(header)` — necessarily a **pre-key message** on a fresh outbound session (anything else is
   `Internal`). Its `to_bytes()` (282 bytes for the 116-byte plaintext: PKCS#7-padded to 128 bytes = eight AES-CBC blocks, plus Olm's
   envelope) goes into the signed `0x02` blob (§6.4).
4. State: `{role: Accepter, session: Some, peer_curve25519: A_curve, peer_ed25519: A_ed, send_counter: 1,
   recv_highest: 0, recv_seen_bitmap: 0, last_acceptance: Some(blob)}`. **`send_counter` starts at 1** because
   the handshake occupied B→A counter 0.

B's chat is *connected* from this moment: B can already encrypt to A (every such message stays a pre-key
message until B has decrypted something from A — Olm semantics, both decryptable by A's session).

### 4.4 Completion (A) and one-time-key consumption

`complete_handshake` ([`api/pairing.rs#L68`](../../rust/fuzzy_crypto_core/src/api/pairing.rs#L68),
[`pairing.rs#L173`](../../rust/fuzzy_crypto_core/src/pairing.rs#L173)), after §4.1 and inside one atomic
state mutation (§10.3 — the file is written only if every step passes, and is byte-identical otherwise):

1. `role == Inviter` and `session.is_none()`, else `InvitationAlreadyUsed` — this catches a second
   acceptance for a chat that already completed, and an accepter pasting an acceptance into its own chat,
   before any Olm work.
2. `PreKeyMessage::from_bytes(prekey_msg)` (`Corrupt`).
3. `account.create_inbound_session(version_1, b_curve25519, &prekey)`. vodozemac checks, in this order: the
   pre-key message's identity key equals `b_curve25519` (`MismatchedIdentityKey`), the session config
   version, that the account still holds the private one-time key (`MissingOneTimeKey`), the 3DH is
   contributory, and the embedded message decrypts — and **only then** removes the private one-time key
   (`vodozemac-0.10.0/src/olm/account/mod.rs`, `create_inbound_session` → `remove_one_time_key_helper`).
   The crate maps `MissingOneTimeKey` and `MismatchedIdentityKey` to `InvitationAlreadyUsed`, everything else
   to `Corrupt`.
4. The decrypted plaintext must be a valid inner header (`Corrupt`, including an unknown inner version) with
   `chat_id == state.chat_id`, `sender_ed25519 == acceptance.b_ed25519` **and** `recipient_ed25519 ==
   state.our_ed25519` (both compared in constant time via `subtle::ConstantTimeEq`, the two results
   `&`-combined before one boolean conversion), `direction == B→A`, `counter == 0`, `content_type ==
   handshake`. Any mismatch is `Corrupt`.
5. Only now: `state.account` (one-time key gone), `state.session`, `peer_curve25519`, `peer_ed25519`,
   `send_counter = 0`, `recv_highest = 0`, `recv_seen_bitmap = 1` (counter 0 is the handshake, already seen).

Because the mutated account is written back only after step 4, and the state file only after step 5, **a
rejected acceptance never consumes the one-time key** (regression-tested with eleven dishonest headers over
an honest session: `api::pairing::tests::wrong_inner_header_is_corrupt_and_keeps_the_otk`).

### 4.5 The "already used" cases

| Situation | What A sees | Why |
|---|---|---|
| The same acceptance pasted twice | `InvitationAlreadyUsed` | step 1: a session exists. State file byte-identical. |
| Two people accept the same invitation; A pastes the second one | `InvitationAlreadyUsed` | step 1 (a session exists from the first). |
| A regenerated the invitation; B accepted the old one | `InvitationAlreadyUsed` | step 3: the new account never held that one-time key (`MissingOneTimeKey`). |
| An acceptance re-signed by a third party under its own identity, keeping B's pre-key message | `InvitationAlreadyUsed` | step 3: the pre-key message names B's identity key, not the signer's (`MismatchedIdentityKey`). The one-time key survives; B's real acceptance still completes. |
| A blob from another chat | `WrongChat` | §4.1 step 4; nothing written. |
| B pastes A's invitation into a chat that already has state | `Internal` | §4.3. |
| An acceptance whose handshake header is dishonest (wrong chat, wrong keys, wrong direction, counter ≠ 0, wrong content type) | `Corrupt` | §4.4 step 4; the one-time key survives. |

### 4.6 What the pairing does not do

- It does not authenticate *who* A and B are; it authenticates that whoever produced each blob controls the
  Ed25519 key inside it. See §5 and §17.
- It has no timeout: a pending chat keeps its account and one-time key until the acceptance arrives, the
  invitation is regenerated or the chat is deleted. The app's deep-link `exp` field is a link-level hint the
  core never sees.
- It never publishes a fallback key or a second one-time key; the account's one-time-key count is 0 after
  completion.

---

## 5. Safety number

After the handshake both devices hold `A_ed25519` and `B_ed25519` — the exact keys that signed the blobs and
that the handshake header bound to the 3DH. The safety number is a fingerprint of those two keys and the
chat id ([`safety.rs#L31`](../../rust/fuzzy_crypto_core/src/safety.rs#L31)):

```
low, high = sort_lexicographic(key_1, key_2)                     // byte-wise on the two [u8; 32]
digest    = SHA-512( "FUZZZYINK_SAFETY_NUMBER_V1" ‖ 0x00 ‖ chat_id_utf8 ‖ 0x00 ‖ low ‖ high )
group[i]  = ( u40 BE of digest[5i .. 5i+5] ) mod 100000            for i in 0..12
text      = zero-padded 5-digit groups joined by single spaces      // 60 digits, 71 characters
```

Constants: domain `FUZZZYINK_SAFETY_NUMBER_V1` ([`safety.rs#L20`](../../rust/fuzzy_crypto_core/src/safety.rs#L20)),
12 groups ([`#L22`](../../rust/fuzzy_crypto_core/src/safety.rs#L22)) of 5 digest bytes each
([`#L24`](../../rust/fuzzy_crypto_core/src/safety.rs#L24)), modulus 100 000
([`#L25`](../../rust/fuzzy_crypto_core/src/safety.rs#L25)); the last 4 bytes of the digest are unused. This
is libsignal's `DisplayableFingerprint` group encoding (5 bytes → `% 100000`), applied to one combined
digest instead of two per-side ones. Vector: `safety_number` (chat id `6f1e9b2c-…`, keys `00 01 … 1f` and
`ff fe … e0` → `77854 71920 59655 43036 43670 32437 81099 92950 15670 73365 44425 64132`).

- **Symmetry.** The sort makes the argument order irrelevant, so A (who calls it with `(our, peer)`) and B (who
  calls it with the same two keys the other way round) get the same string.
- **Strength.** 12 × log₂(100 000) ≈ 199 bits of the digest. An active attacker who substituted identity keys
  on both legs of the pairing (§17) must make both devices display the same 60 digits: A shows
  `f(sort(A_ed, M_B))` and B shows `f(sort(M_A, B_ed))`, and the attacker chooses *both* `M_A` and `M_B`. That is a
  birthday problem over two attacker-chosen key sets — with 2^k candidates for each substituted key a match is
  expected once 2^(2k) ≈ 2^199, i.e. after **about 2^100 key generations plus SHA-512 evaluations** on each side
  (not a 2^199 collision search). Still far beyond reach; the figure is stated as the birthday bound because the
  threat model inherits it. Substituting on one leg only changes the number on that side.
- **Binding.** The number commits to the identity keys only; but the signatures cover `a_curve25519 ‖
  a_one_time_key` and `b_curve25519 ‖ prekey_msg`, and the handshake header ties `b_ed25519` to the session
  — so the number transitively pins the 3DH inputs. It also commits to the chat id, so one chat's number
  cannot be reused as another's.
- **Availability.** B has A's identity key from the moment it accepts; A has B's once the handshake completes.
  Before that `safety_number` is `UnknownChat`.
- **The verified flag** (`mark_verified`, [`safety.rs#L75`](../../rust/fuzzy_crypto_core/src/safety.rs#L75)) is a
  per-device boolean in the sealed state, persisted before the call returns. It is refused (`UnknownChat`)
  while no peer key exists, so a flag can never pre-date the keys it vouches for. The only ways an identity
  key of an existing chat can change — regenerating a pending invitation, or deleting and re-pairing — replace
  the whole state with `verified = false`, so the flag cannot outlive the keys either.
- Nothing secret is hashed; both keys travel in the clear inside the pairing blobs.

---

## 6. Wire formats

### 6.1 Text envelope

Every blob is exchanged as text: the ASCII prefix `Fuzz/` ([`formats.rs#L15`](../../rust/fuzzy_crypto_core/src/formats.rs#L15))
followed by **base64url without padding** (RFC 4648 §5 alphabet `A–Z a–z 0–9 - _`, no `=`) of the binary
blob. Decoding ([`formats.rs#L125`](../../rust/fuzzy_crypto_core/src/formats.rs#L125)):

1. every ASCII whitespace byte (space, `\t`, `\n`, `\x0c`, `\r`) anywhere in the text is dropped — so a blob
   wrapped by an e-mail or SMS client still decodes (vertical tab `\x0b` is *not* whitespace here);
2. the remaining bytes must start with `Fuzz/`, else `UnsupportedFormat`;
3. the rest must be canonical base64url with no padding — `=`, `+`, `/`, any other byte, or non-zero
   trailing bits are `UnsupportedFormat`.

There is no encoding byte in version 1: base64url is the only text encoding, and its alphabet is the
discriminator (see §12).

### 6.2 Outer envelope (every blob and every container)

| Offset | Size | Field | Value |
|---|---|---|---|
| 0..4 | 4 | magic | `46 55 5a 5a` = `FUZZ` ([`formats.rs#L17`](../../rust/fuzzy_crypto_core/src/formats.rs#L17)) |
| 4 | 1 | version | `0x01` ([`formats.rs#L19`](../../rust/fuzzy_crypto_core/src/formats.rs#L19)) |
| 5 | 1 | type | `0x01` invitation · `0x02` acceptance · `0x03` message · `0x04` file container · `0x05` password-sealed blob · `0x10` wrapped key (storage only) · `0x20` local seal (storage only) ([`formats.rs#L37`](../../rust/fuzzy_crypto_core/src/formats.rs#L37)) |
| 6.. | | payload | per type |

Envelope length 6 ([`formats.rs#L21`](../../rust/fuzzy_crypto_core/src/formats.rs#L21)). Any other magic,
version or type byte is `UnsupportedFormat` ([`formats.rs#L152`](../../rust/fuzzy_crypto_core/src/formats.rs#L152));
a blob of the wrong type for the call (an invitation given to the message decoder) is also
`UnsupportedFormat`. Types `0x10` and `0x20` are refused by the paste path (`decode_pasted`) — they are valid
only where the device stores them.

All payload fields are fixed-size or carry a big-endian length prefix (`u8` for chat ids, `u16` for Olm bodies
and names, `u32` for inner-header bodies). No JSON, no serde, no varints on the wire. Every decoder reads
through a bounds-checked cursor: a short input is `Corrupt`, trailing bytes after a fixed layout are
`Corrupt`, and no input can cause a panic or a length-driven allocation.

### 6.3 Invitation `0x01`

Vector: `invitation` (A's Ed25519 seed `01×32`, Curve25519 secret `02×32`, one-time secret `03×32`). Offsets
assume the 36-byte uuid.

| Offset | Size | Field | Rule |
|---|---|---|---|
| 0..6 | 6 | envelope | `FUZZ 01 01` |
| 6 | 1 | `chat_id_len` | 1..=255 (`0x24` = 36 for a uuid) |
| 7..43 | 36 | `chat_id` | UTF-8; non-empty; not validated for uuid shape by the codec (§2) |
| 43..75 | 32 | `a_curve25519` | A's Curve25519 identity public key |
| 75..107 | 32 | `a_ed25519` | A's Ed25519 identity public key — the signing key of this blob |
| 107..139 | 32 | `a_one_time_key` | the published Curve25519 one-time key |
| 139..203 | 64 | `sig` | Ed25519(`a_ed25519`) over bytes `0..139` (§4.1) |

203 bytes → 271 base64url characters after `Fuzz/`. The decoder rejects trailing bytes.

### 6.4 Acceptance `0x02`

Vector: `acceptance` — B's Ed25519 seed `04×32`, Curve25519 secret `05×32`, a **5-byte placeholder** in
place of the pre-key message (vodozemac's pre-key message is randomised and cannot be pinned; the vector pins
the layout, the length prefix and the signed range with a real signature). A real acceptance carries a 282-byte
pre-key message and is 455 bytes.

| Offset | Size | Field | Rule |
|---|---|---|---|
| 0..6 | 6 | envelope | `FUZZ 01 02` |
| 6 | 1 | `chat_id_len` | 1..=255 |
| 7..43 | 36 | `chat_id` | UTF-8, non-empty |
| 43..75 | 32 | `b_curve25519` | B's Curve25519 identity public key (the pre-key message names it too; §4.4 step 3) |
| 75..107 | 32 | `b_ed25519` | B's Ed25519 identity public key — the signing key of this blob |
| 107..109 | 2 | `prekey_len` | `u16 BE`, 1..=65535 (0 is `Corrupt`) |
| 109..109+n | n | `prekey_msg` | vodozemac `PreKeyMessage::to_bytes()` — Olm's own encoding, containing B's identity key, B's base key, A's one-time key and the encrypted handshake header |
| 109+n..173+n | 64 | `sig` | Ed25519(`b_ed25519`) over bytes `0..109+n` |

### 6.5 Message `0x03`

Vector: `message` (a 4-byte placeholder body; a real body is vodozemac's `Message::to_bytes()` or
`PreKeyMessage::to_bytes()`).

| Offset | Size | Field | Rule |
|---|---|---|---|
| 0..6 | 6 | envelope | `FUZZ 01 03` |
| 6 | 1 | `olm_type` | `0x00` pre-key message · `0x01` normal message ([`formats.rs#L72`](../../rust/fuzzy_crypto_core/src/formats.rs#L72)); anything else `Corrupt` |
| 7.. | ≥ 1 | `olm_body` | the Olm message bytes; empty is `Corrupt` |

Nothing else is in the clear — **no chat id, no counter, no sender**: a chat id on every message would be a
cross-blob tracking identifier. The paste target is the open chat, and the inner header (§7) enforces the
binding after decryption. The Olm plaintext of every message is an inner header.

### 6.6 File container `0x04`

See §9 for the chunks; this is the header. Two key modes. `header_len` is not stored: the decoder recomputes
it from the fields it read ([`formats.rs#L476`](../../rust/fuzzy_crypto_core/src/formats.rs#L476)).

**Chat mode** (`key_mode 0x01`) — vector: `file_header_chat` (3-byte placeholder Olm body; a real one is a
pre-key or normal message whose plaintext is an inner header with content type `0x02`, vector
`inner_header_file_key`).

| Offset | Size | Field | Rule |
|---|---|---|---|
| 0..6 | 6 | envelope | `FUZZ 01 04` |
| 6 | 1 | `key_mode` | `0x01` |
| 7..11 | 4 | `chunk_size` | `u32 BE`; encoder writes 1 048 576 ([`formats.rs#L25`](../../rust/fuzzy_crypto_core/src/formats.rs#L25)); decoder accepts 65 536 ≤ n ≤ 16 777 216 ([`#L27`](../../rust/fuzzy_crypto_core/src/formats.rs#L27), [`#L29`](../../rust/fuzzy_crypto_core/src/formats.rs#L29)), else `Corrupt` |
| 11..30 | 19 | `nonce_prefix` | random per file; the STREAM nonce prefix (§9.1) |
| 30 | 1 | `olm_type` | as §6.5 |
| 31..33 | 2 | `olm_len` | `u16 BE`, 1..=65535 |
| 33..33+n | n | `olm_body` | the Olm message carrying the file key (§9.4) |

`header_len = 33 + n`.

**Password mode** (`key_mode 0x02`) — vector: `file_header_password` (55 bytes).

| Offset | Size | Field | Rule |
|---|---|---|---|
| 0..6 | 6 | envelope | `FUZZ 01 04` |
| 6 | 1 | `key_mode` | `0x02` |
| 7..11 | 4 | `chunk_size` | as above |
| 11..30 | 19 | `nonce_prefix` | random per file |
| 30..46 | 16 | `salt` | random per file; Argon2id salt |
| 46..50 | 4 | `m_cost` | `u32 BE`, KiB; encoder writes 65 536 |
| 50..54 | 4 | `t_cost` | `u32 BE`; encoder writes 4 |
| 54 | 1 | `p_cost` | encoder writes 1 |

`header_len = 55`. An unknown `key_mode` byte is `Corrupt`. The file key is `Argon2id(password, salt, m, t, p)`
(§11).

### 6.7 Password-sealed blob `0x05`

Vector: `password_sealed_text` (password `pw`, salt `11×16`, nonce `22×24`, plaintext `hello`; text form in
`password_sealed_text.txt`).

| Offset | Size | Field | Rule |
|---|---|---|---|
| 0..6 | 6 | envelope | `FUZZ 01 05` |
| 6..22 | 16 | `salt` | random per seal |
| 22..26 | 4 | `m_cost` | `u32 BE`, KiB (encoder: 65 536) |
| 26..30 | 4 | `t_cost` | `u32 BE` (encoder: 4) |
| 30 | 1 | `p_cost` | (encoder: 1) |
| 31..55 | 24 | `nonce` | random per seal |
| 55.. | ≥ 16 | `ct ‖ tag` | AEAD(key = Argon2id(password, salt, m, t, p), nonce, **aad = bytes 0..31 of this blob**, plaintext) |

The AAD is the blob's own first 31 bytes — envelope, salt and the three cost fields
([`passwords.rs#L18`](../../rust/fuzzy_crypto_core/src/passwords.rs#L18)) — read from the received bytes, not
re-encoded. It binds the type byte (so a `0x10` blob re-typed as `0x05` fails its tag even under the same
password and salt) and the recorded cost parameters (so they cannot be swapped). The nonce is not in the AAD:
it is an AEAD input already, and any change to it fails the tag by itself. Fewer than 16 bytes after the nonce
is `Corrupt`. Decryption rules and error mapping: §11.

### 6.8 Wrapped key `0x10` (storage only)

Vectors: `wrapped_store_key` (key `33×32`, password `pw`, salt `11×16`, nonce `22×24`, AAD `store-key`) and
`wrapped_vault_key` (same inputs, AAD `vault-key` — same header and ciphertext, different tag).

| Offset | Size | Field | Rule |
|---|---|---|---|
| 0..6 | 6 | envelope | `FUZZ 01 10` |
| 6..22 | 16 | `salt` | random per wrap |
| 22..26 | 4 | `m_cost` | `u32 BE`, KiB (encoder: 65 536) |
| 26..30 | 4 | `t_cost` | (encoder: 4) |
| 30 | 1 | `p_cost` | (encoder: 1) |
| 31..55 | 24 | `nonce` | random per wrap |
| 55..103 | 48 | `ct ‖ tag` | AEAD(key = Argon2id(password, salt, m, t, p), nonce, aad = role string, the 32-byte key) — exactly 48 bytes ([`formats.rs#L31`](../../rust/fuzzy_crypto_core/src/formats.rs#L31)); anything else `Corrupt` |

103 bytes. The AAD names the key's **role**: `store-key` ([`store.rs#L41`](../../rust/fuzzy_crypto_core/src/store.rs#L41))
for the app-lock store key, `vault-key` ([`vault.rs#L15`](../../rust/fuzzy_crypto_core/src/vault.rs#L15)) for the
vault master key, so a blob wrapped for one role never unwraps as the other. Never valid on the wire.

### 6.9 Local seal `0x20` (storage only)

Vectors: `local_seal_chat` (history key `55×32`, nonce `44×24`, plaintext `hello`, AAD `local-seal` ‖ chat id),
`vault_item` (master key `33×32`, nonce `44×24`, plaintext `item`, AAD `vault-item`), `state_file` (store key
`33×32`, nonce `44×24`, AAD `chat-state` ‖ chat id, plaintext `state_file.body.json`).

| Offset | Size | Field | Rule |
|---|---|---|---|
| 0..6 | 6 | envelope | `FUZZ 01 20` |
| 6..30 | 24 | `nonce` | random per seal |
| 30.. | ≥ 16 | `ct ‖ tag` | AEAD(key, nonce, aad, plaintext); the key and AAD depend on the use (§10) |

Fewer than 16 bytes after the nonce is `Corrupt`. Never valid on the wire.

---

## 7. Inner header and validation rules

The **inner header** is the plaintext of every Olm message the protocol produces — the handshake, every text
message, every chat-mode file key. It is the Matrix "m.olm" construction: the sender's and recipient's
identity keys and the room (chat) id travel *inside* the authenticated plaintext, and the receiver checks
them against its own state after decryption ([`formats.rs#L513`](../../rust/fuzzy_crypto_core/src/formats.rs#L513)).

### 7.1 Layout

Vectors: `inner_header_handshake` (116 bytes), `inner_header_text` (body `hello`, A→B, counter 7),
`inner_header_file_key` (body = `file_key_body`, A→B, counter 8). Offsets assume the 36-byte uuid.

| Offset | Size | Field | Rule |
|---|---|---|---|
| 0 | 1 | `inner_version` | `0x01` ([`formats.rs#L513`](../../rust/fuzzy_crypto_core/src/formats.rs#L513)); anything else `UnsupportedFormat` at the codec, remapped to `Corrupt` by every caller (a foreign inner version inside a message is not a negotiation signal) |
| 1 | 1 | `chat_id_len` | 1..=255 |
| 2..38 | 36 | `chat_id` | UTF-8 |
| 38..70 | 32 | `sender_ed25519` | the sender's identity key |
| 70..102 | 32 | `recipient_ed25519` | the recipient's identity key |
| 102 | 1 | `direction` | `0x00` A→B (inviter to accepter) · `0x01` B→A ([`formats.rs#L519`](../../rust/fuzzy_crypto_core/src/formats.rs#L519)); else `Corrupt` |
| 103..111 | 8 | `counter` | `u64 BE`, per direction, starts at 0 (B→A counter 0 is the handshake) |
| 111 | 1 | `content_type` | `0x00` handshake (empty body) · `0x01` text (UTF-8) · `0x02` file-key envelope (§7.3) ([`formats.rs#L537`](../../rust/fuzzy_crypto_core/src/formats.rs#L537)); else `Corrupt` |
| 112..116 | 4 | `body_len` | `u32 BE`; 0 is allowed |
| 116.. | `body_len` | `body` | per content type |

Trailing bytes are `Corrupt`.

### 7.2 Receiving a message — the ordered check list

`decrypt_text` / `unwrap_file_key` both run `decrypt_payload` ([`messages.rs#L122`](../../rust/fuzzy_crypto_core/src/messages.rs#L122));
there is exactly one implementation of these rules. The checks stop at the first failure. **Nothing in the
chat's state changes unless every check passes**, and the state file is written only on success (§10.3) — so
after any rejection the file on disk is byte-identical and the ratchet has not advanced.

| # | Check | Failure |
|---|---|---|
| 1 | Text envelope, outer envelope, type `0x03` | `UnsupportedFormat` |
| 2 | `olm_type` known, body non-empty, and the body parses as a vodozemac `PreKeyMessage` / `Message` | `Corrupt` |
| 3 | **Olm decrypt** on a *copy* of the session: `MissingMessageKey` (the message key was consumed or evicted) | `Replay` |
| | `TooBigMessageGap` (more than 2000 ahead of the chain) | `TooOld` |
| | any other failure — bad MAC, non-contributory ratchet key, padding; this is where a blob from **another chat** dies, its MAC being under another session | `Corrupt` |
| 4 | The plaintext decodes as an inner header (§7.1, including `inner_version == 1`) | `Corrupt` |
| 5 | `chat_id == state.chat_id` | `WrongChat` |
| 6 | `sender_ed25519 == state.peer_ed25519` **and** `recipient_ed25519 == state.our_ed25519`, both in constant time (`subtle`), the two results combined before one boolean conversion | `WrongChat` |
| 7 | `direction` is the peer's direction (B→A for an inviter, A→B for an accepter) | `Corrupt` |
| 8 | `content_type` is the one this call expects (`0x01` for text, `0x02` for a file key) | `Corrupt` |
| 9 | The body parses for that content type: valid UTF-8 for text; a valid file-key body with a usable file name for `0x02` (§7.3) | `Corrupt` |
| 10 | The per-direction **counter window** accepts `counter` (§8.2) | `Replay` / `TooOld` |
| 11 | Commit: the ratcheted session copy, `recv_highest`, `recv_seen_bitmap` are written into the state and the state file is sealed and written before the plaintext is returned | `Io` (nothing returned) |

Check 3 runs before checks 5–10 by design: Olm is the cryptographic authority; the inner header is the belt,
the counter window the braces. Consequences a reviewer should expect: a cross-chat paste is `Corrupt` (step
3), not `WrongChat`; a genuine replay is `Replay` from step 3 before the window is consulted.

**Sending** (`encrypt_payload`, [`messages.rs#L78`](../../rust/fuzzy_crypto_core/src/messages.rs#L78)): the chat
must have a session (else `Internal`); the header is stamped with our identity key as sender, the peer's as
recipient, our direction, `counter = send_counter`; `session.encrypt`; then `send_counter += 1` (overflow is
`Internal`) and the ratcheted session are committed and the state file written **before** the blob is
returned. A crash after the write loses at most a blob nobody has seen; a counter is never reused.

### 7.3 File-key body (content type `0x02`)

Vector: `file_key_body` (44 bytes: key `42×32`, name `report.pdf`).

| Offset | Size | Field | Rule |
|---|---|---|---|
| 0..32 | 32 | `file_key` | the container's AEAD key |
| 32..34 | 2 | `original_name_len` | `u16 BE`, 1..=65535 |
| 34.. | n | `original_name` | UTF-8; then validated as a **file name** ([`files.rs#L269`](../../rust/fuzzy_crypto_core/src/files.rs#L269)): not empty, not `.` or `..`, at most 255 bytes ([`files.rs#L261`](../../rust/fuzzy_crypto_core/src/files.rs#L261)), no `/`, `\`, NUL or any byte in `0x00..=0x1f`, `0x7f` |

The name check runs on both sides (the sender derives it from a real basename; the receiver checks it inside
step 9, before the counter commit). It is a file *name*, never a path, so a peer cannot steer the receiver's
output outside the directory the receiver chose. It is not display-sanitised (a Unicode direction override is
a valid file name); the UI must treat it as untrusted text.

---

## 8. Ordering, replay and windows

### 8.1 What Olm does (vodozemac 0.10.0)

- Each received message names its ratchet key and chain index. A message on the current chain that is *ahead*
  of the chain index advances the chain and caches the skipped message keys; a message *behind* it is looked
  up in the skipped-key store and its key is **deleted on use**; a message whose key is neither current nor
  stored fails with `MissingMessageKey` (`vodozemac-0.10.0/src/olm/session/receiver_chain.rs`,
  `find_message_key`).
- The skipped-key store holds at most **40** keys per receiving chain (`MAX_MESSAGE_KEYS`, line 50 of that
  file), oldest evicted; only keys within 40 of the delivered index are stored at all (line 202).
- A message more than **2000** ahead of the chain index is refused (`MAX_MESSAGE_GAP`, line 31).
- At most **5** receiving chains are kept (`MAX_RECEIVING_CHAINS`, `session/mod.rs` line 53); older chains —
  and their skipped keys — are dropped when the peer ratchets again.
- An account holds at most 50 one-time keys (irrelevant here: this protocol publishes exactly one).

So a blob is decryptable exactly once, and only while its key is still cached — "generated but never sent"
blobs work up to 40 per chain, after which the oldest are gone. These are vodozemac's constants and are not
tunable without forking it.

### 8.2 The counter window (this protocol)

Defence in depth behind Olm, and the source of the user-facing `Replay` / `TooOld` distinction
([`counters.rs#L28`](../../rust/fuzzy_crypto_core/src/counters.rs#L28)). Per chat, per **direction**, the state
holds `recv_highest: u64` (the highest counter accepted so far) and `recv_seen_bitmap: u64` where bit `i`
marks counter `recv_highest − i` (bit 0 = `recv_highest` itself). Window width 64
([`counters.rs#L22`](../../rust/fuzzy_crypto_core/src/counters.rs#L22)).

```
if counter > highest:          shift = counter − highest
                               bitmap = (shift >= 64) ? 1 : (bitmap << shift) | 1
                               highest = counter                                     → accept
else:                          offset = highest − counter
                               if offset >= 64                                      → TooOld
                               if bitmap bit offset set                              → Replay
                               set bit offset                                        → accept
```

Initial values: an accepter starts at `(0, 0)` — A→B counter 0 is still to come; an inviter starts at
`(0, 1)` — B→A counter 0 was the handshake. The accepted window is therefore `highest − 63 ..= highest`.

**Parity with Olm — a deliberate difference.** This window is per *direction* and forgets anything more than
63 behind the newest accepted counter; Olm's store is per *chain* and keeps a key until it is consumed. So
there are messages Olm could still decrypt that this layer refuses as `TooOld`: (a) a message on an older
ratchet chain once the newer chain has advanced 64 counters past it; (b) on one chain, a counter that fell
more than 63 behind after a run of newer messages was read. The layer can therefore refuse what Olm would
accept, never the reverse — strictly safer, but a product limit users must be told: *a blob more than 63
messages behind the newest one you already read (per direction) can no longer be unfuzzed*, on top of Olm's
40-per-chain rule.

### 8.3 What "generated but never sent" means

A sender's counter and ratchet advance when the blob is *generated*, not when it is delivered. A blob the user
generated and then discarded (or that never arrived) leaves a gap the receiver's Olm store bridges with a
skipped key — up to 40 such gaps per chain, and never more than 63 behind the newest accepted message. Beyond
that the blob is unrecoverable by design: no key is kept for it anywhere.

---

## 9. Files

A file becomes a `0x04` container: the header of §6.6 followed by the plaintext sealed in chunks with the
RustCrypto STREAM construction (`aead-stream` 0.6.0, `EncryptorBE32`/`DecryptorBE32` over
`chacha20poly1305` 0.11.0). One chunk is in flight at a time; a file is never read into memory.

### 9.1 Chunk layout, nonce and AAD

| Item | Definition |
|---|---|
| chunk size | `chunk_size` from the header: encoder 1 MiB, decoder accepts 64 KiB..=16 MiB (§6.6) |
| chunk `i` (`0 ≤ i < n`) | `AEAD(file_key, nonce_i, aad_i, plaintext_i)` = `ct ‖ tag(16)`; every chunk but the last holds exactly `chunk_size` plaintext bytes, the last holds the remainder (0..=`chunk_size`) |
| `nonce_i` (24 bytes) | `nonce_prefix(19) ‖ i as u32 BE ‖ last_flag` where `last_flag = 0x01` for chunk `n−1`, `0x00` otherwise — built by `aead-stream` (`StreamBE32::aead_nonce`, `aead-stream-0.6.0/src/lib.rs` line 440) |
| `aad_i` | the **exact header bytes as they appear in the file** (`header_len` bytes, §6.6) ‖ `i as u32 BE` ([`files.rs#L487`](../../rust/fuzzy_crypto_core/src/files.rs#L487)) |
| `n` (chunks) | encrypt: `max(1, ceil(len / chunk_size))` — an empty file is one 16-byte chunk; decrypt: `ceil(body_len / (chunk_size + 16))` |

Vectors: `file_container_password` (one 43-byte plaintext → one chunk sealed with the last flag; key =
Argon2id(`pw`, salt `a0..af`)); `file_container_fixed_key` (65 541-byte plaintext, 64 KiB chunks → chunk 0
with nonce `prefix ‖ 00000000 ‖ 00` and chunk 1 with `prefix ‖ 00000001 ‖ 01`; key `42×32` supplied directly —
the benchmark path). The fixed-key container carries a **password-mode header** (`key_mode 0x02`, `chunk_size`
65 536, prefix `90..a2`, salt `a0..af`, the production Argon2id parameters) whose KDF output is simply not used
because the key was supplied, so no password opens it. Its plaintext is 65 541 bytes of xorshift64: state
`x = 0x9e3779b97f4a7c15`; per byte `x ^= x << 13; x ^= x >> 7; x ^= x << 17` (wrapping 64-bit) and the low byte
of the *new* `x` is emitted.

### 9.2 Decoding and what the tags detect

`decrypt_chunks` ([`files.rs#L343`](../../rust/fuzzy_crypto_core/src/files.rs#L343)), in order:

1. Read at most `MAX_HEADER_LEN = 65 568` bytes ([`files.rs#L53`](../../rust/fuzzy_crypto_core/src/files.rs#L53)),
   decode the header (§6.6; `UnsupportedFormat` / `Corrupt` as there), keep its exact bytes for the AAD.
2. Derive the key (password mode: Argon2id from the header's salt and parameters, §11; chat mode: §9.4).
3. Structural check ([`files.rs#L418`](../../rust/fuzzy_crypto_core/src/files.rs#L418)): `body_len = file_len −
   header_len ≥ 16`, `n = ceil(body_len / (chunk_size + 16))`, and the last chunk `≥ 16` bytes; else `Corrupt`
   — before any output file exists.
4. For `i in 0..n`: read the chunk, `decrypt_next` for `i < n−1`, `decrypt_last` for `i = n−1`; write the
   plaintext to `<output>.part` **only after the tag verified**. A tag failure on chunk 0 is `WrongPassword` in
   password mode (the AEAD cannot tell a wrong password from a corrupt first chunk, and the password is the
   only input the user controls) and `Corrupt` in chat mode (the key is Olm-authenticated); on any later chunk
   `Corrupt`.
5. `fsync`, close, rename `<output>.part` → `<output>`.

| Tampering | Detected by |
|---|---|
| any modified byte in a chunk | that chunk's tag |
| a chunk moved, swapped or duplicated | nonce counter and AAD index |
| file truncated mid-chunk | tag of the (now short) last chunk |
| file truncated at a chunk boundary | the surviving last chunk was sealed with `last_flag = 0` but is opened with `decrypt_last` (flag 1) — tag failure |
| bytes appended | the true last chunk is now opened with `decrypt_next` (flag 0) — tag failure; or a tail `< 16` bytes fails step 3 |
| header changed (chunk size, nonce prefix, salt, parameters, Olm body) | every chunk's AAD |
| a key message moved onto another container (chat mode) | the AAD carries the whole header incl. the nonce prefix; chunk 0 fails (§9.4) |

### 9.3 The `.part` rule and jobs

- All output goes to `<output>.part` (suffix appended, so `report.pdf.part`), created with mode `0o600` on
  unix ([`store.rs#L319`](../../rust/fuzzy_crypto_core/src/store.rs#L319)), **after** the header parsed and the key
  was derived — so a header-stage rejection creates nothing. On success: `fsync` → close → rename over
  `<output>` (replacing an existing file silently). On *any* other exit — error, cancel, panic — the `.part`
  is unlinked by a drop guard ([`files.rs#L499`](../../rust/fuzzy_crypto_core/src/files.rs#L499)). A process kill
  mid-job can leave a `.part` behind; the next job over the same output truncates it.
- A job's control word ([`files.rs#L41`](../../rust/fuzzy_crypto_core/src/files.rs#L41)) is read before every
  chunk: paused → sleep 50 ms and re-read; cancelled (terminal) → `Cancelled`, `.part` gone. Progress is one
  event per chunk (`chunks_done / n`), then exactly one terminal event; a failure is reported on the stream as
  `is_complete = true` with an `error_message` (a Dart consumer checks the message first).
- Password-mode jobs never touch the store; chat-mode jobs are two steps (§9.4) so that the store lock is
  held only for the Olm step, never for the transfer.

### 9.4 Chat mode — the file key rides in one Olm message

**Send** (`prepare_file_send` → `run_file_job`, [`api/files.rs#L207`](../../rust/fuzzy_crypto_core/src/api/files.rs#L207),
[`files.rs#L190`](../../rust/fuzzy_crypto_core/src/files.rs#L190)): the input must be a readable regular file
(`Io` otherwise — checked before anything is spent); its basename is validated as in §7.3; a random 32-byte
file key is drawn; the file-key body `file_key ‖ name_len ‖ name` is sealed in **one Olm message** on the
chat's session with content type `0x02` and the next send counter — the sending rules of §7.2 exactly; the
ratcheted session and counter are persisted; the ticket (key + header) is returned and the core lock
released. The container header embeds that Olm message; then the chunks are streamed. **Every file consumes
one ratchet step and has the same forward secrecy as a text message.**

**Receive** (`prepare_file_receive` → `run_file_job`, [`api/files.rs#L248`](../../rust/fuzzy_crypto_core/src/api/files.rs#L248),
[`files.rs#L220`](../../rust/fuzzy_crypto_core/src/files.rs#L220)): the input must be a regular file; the header is
read and the structural check of §9.2 step 3 runs **first**, so a header-only or truncated container is
`Corrupt` before the file's message is spent; a password-mode header is `UnsupportedFormat`; then the embedded
Olm message goes through the receiving chain of §7.2 with `content_type = 0x02` and the file-key body as the
body parser — `Replay`, `TooOld`, `WrongChat`, `Corrupt` exactly as for text; the state is persisted; the
ticket carries the key and the original name. The run then opens the chunks with `Corrupt` as the chunk-0
failure, and additionally refuses to release the key unless the header on disk equals the header the ticket
was prepared on ([`api/files.rs#L302`](../../rust/fuzzy_crypto_core/src/api/files.rs#L302)) — redundant with the
AAD, kept as a belt.

**Binding.** The Olm message commits to the inner header only — chat, identities, direction, counter, key,
name — not to `chunk_size`, `nonce_prefix` or the chunks. The binding of the key to *this* container comes
from the chunk AAD, which is the entire header (Olm body included) plus the index, and from the nonce prefix
inside that header. A key message re-bound to different chunks or a different prefix unwraps fine and then
fails at chunk 0.

**Semantics a consumer must know.** A successful prepare consumes the file's message: a run that fails
afterwards (a corrupt chunk) is terminal for that container — a retry is `Replay`; the sender must send the
file again. Preparing is therefore only done on a complete local file. A ticket is one-shot (a second run is
`Internal`); an unrun receive ticket has still consumed the message; the key inside the ticket is wiped on
drop either way.

### 9.5 Chat archive export (per chat)

The app can write one chat's history to a file the user keeps. The archive is an ordinary **password-mode
`0x04` container** (§6.6 `key_mode 0x02`: fresh 16-byte salt, Argon2id m = 65 536 KiB, t = 4, p = 1; chunks
as §9.1) whose plaintext is UTF-8 **JSON lines**, one object per message row in the chat's stored order:
`chatId`, `chatName`, `direction` (`sent` | `received`), `sentAt` (UTC ISO-8601), `type` (`text` | `file`),
then exactly one of `text` (the row's opened local seal, §10.4), `fileName` (the base name of the stored
file — **never file bytes**; the file itself is a plain file on the device, §10.5) or `"unreadable": true`
(a text row whose local seal did not open: absent, malformed, or `Corrupt` / `UnknownChat` / `StoreLocked`
at the core). The crate sees nothing but a password-mode file job: the lines are produced by the app
(`lib/src/fuzzzy_ink/data/repositories/chat_archive_repository/`), so no vector covers them — the container
is the `0x04` of §9.1 and the JSON is application data. The archive opens in Basics → file decryption under
the same password. **No import path exists** and none is planned: it is a human-readable backup, not a
state transfer, and a restored install cannot turn it back into a chat.

What a reader must hold: the archive is **outside forward secrecy by design** — it is plaintext the ratchet
had already released, protected only by the password (the export dialog refuses weak and fair passwords)
against offline, Argon2id-bounded guessing (§11). The export is gated on an open store (a locked store
returns before a byte is written, so a blank-rows archive cannot be produced). During the seal the JSON
lines exist in the clear as `<application support directory>/chat_archive_<chat_id>.jsonl` (default file
mode inside a user-private directory), deleted in a `finally` on every in-process exit; a process **kill**
mid-seal leaves that file until the next export of the same chat overwrites and deletes it — there is no
boot sweep (`THREAT_MODEL.md` §2.5, R35). On Android the sealed container is additionally staged by the
share sheet under `cache/share_plus/` until the next share — sealed bytes only, as for every file the app
shares.

---

## 10. Local state

### 10.1 Layout on disk

```
<application support directory>/fuzzy_crypto_store/<chat_id>.state      one sealed 0x20 file per chat
<application support directory>/fuzzy_crypto_store/<chat_id>.state.tmp  transient, see 10.3
flutter_secure_storage  key "crypto_store_key_v1"                       the wrapped store key (0x10), base64
Isar (app database)     StoredMessageData.sealedPlaintext                one local seal (0x20) per message under the chat's history key, base64
Isar (app database)     StoredVaultMetadata.verificationTokenBase64      the wrapped vault master key (0x10), base64
vault item files        one file per item (VaultFileDataSource)          a 0x20 blob, AAD "vault-item" (optionally wrapped again in a 0x05 under a per-item password)
<application support directory>/chat_archive_<chat_id>.jsonl            transient: plaintext JSON lines during an archive export (§9.5), deleted in finally
<application documents directory>/<chat name>/<name>                     unfuzzed FILES in the clear (§10.5) — plain files, not sealed; fuzzed containers <name>.fuzz sit beside them.
                                                                        Android since T-0366: the finished file is moved to the public Downloads/Fuzzzy Ink/<chat name>/ (MediaStore); iOS exposes Documents to the Files app
```

The store directory is created and canonicalised when the store opens; every path under it is formed only
from a shape-validated chat id (§2) and is asserted to stay inside the directory.

### 10.2 Store key lifecycle

- **Creation** (`create_store_key`, [`api/core.rs#L23`](../../rust/fuzzy_crypto_core/src/api/core.rs#L23)): 32 random
  bytes, wrapped (§6.8, AAD `store-key`) under the app-lock password with a fresh salt and nonce and
  `Argon2id(m = 65 536 KiB, t = 4, p = 1)`. With app lock disabled the password is the empty string — the
  wrapping is the same, the KEK is simply derived from `""`.
- **Open** (`open_store`, [`api/core.rs#L33`](../../rust/fuzzy_crypto_core/src/api/core.rs#L33)): unwrap under the
  password — a tag failure is `WrongPassword` (the AEAD cannot distinguish a wrong password from a tampered
  blob), so **the wrapped key doubles as the password verifier**; there is no separate verification token.
  The plaintext must be exactly 32 bytes. Then the directory is created/canonicalised and an opaque handle is
  returned (§13).
- **Password change / enable / disable** (`rewrap_store_key`, [`api/core.rs#L50`](../../rust/fuzzy_crypto_core/src/api/core.rs#L50)):
  unwrap under the old password, wrap under the new one with a fresh salt and nonce. One blob replaces the
  other in secure storage in a single write; nothing else on disk changes, because nothing else is keyed by
  the password.
- **Lock** (`close`): the handle drops the store key and every cached state; every later call on the handle is
  `StoreLocked`.

### 10.3 Sealed per-chat state files

`<chat_id>.state` is a `0x20` blob (§6.9): `AEAD(store key, random nonce, aad = "chat-state" ‖ chat_id,
body)` ([`store.rs#L42`](../../rust/fuzzy_crypto_core/src/store.rs#L42), no separator — the chat id is fixed-length).
Vector: `state_file` with its decrypted body in `state_file.body.json`.

The body is compact serde JSON of `ChatState` ([`state.rs#L57`](../../rust/fuzzy_crypto_core/src/state.rs#L57)) —
fields in the table order below, no whitespace, no trailing newline; JSON is used *only* here, never on the wire:

| Field | Type | Meaning |
|---|---|---|
| `format_version` | `u8` | `1` ([`state.rs#L16`](../../rust/fuzzy_crypto_core/src/state.rs#L16)); anything else `UnsupportedFormat` |
| `role` | `"Inviter"` / `"Accepter"` | §2 |
| `chat_id` | string | must equal the requested chat id (belt; the AAD already enforces it) — else `Corrupt` |
| `account` | vodozemac `AccountPickle` | the chat's Olm account (private keys included) |
| `session` | vodozemac `SessionPickle` or `null` | the Olm session once connected |
| `our_ed25519` | 32 bytes | our identity key (denormalised from the account) |
| `peer_curve25519`, `peer_ed25519` | 32 bytes or `null` | the peer's keys once known |
| `send_counter` | `u64` | next counter to stamp on a sent message |
| `recv_highest`, `recv_seen_bitmap` | `u64` | the window of §8.2 |
| `verified` | bool | §5 |
| `last_invitation`, `last_acceptance` | bytes or `null` | the blob this side last produced, for re-display |
| `history_key` | 32 bytes | the chat's history key (§3, §10.4) — random, drawn with the account, wiped with the state |

The vodozemac pickles are stored as the plain serde structs vodozemac ships (their JSON shape —
`signing_key.Normal`, `diffie_hellman_key`, `one_time_keys.{next_key_id, public_keys, private_keys}`,
`fallback_keys`, and the session's chains — is vodozemac 0.10.0's serde form, reproduced verbatim in
`state_file.body.json`; a vodozemac upgrade that changes it fails the vector check) — **not** through
`AccountPickle::encrypt`/`SessionPickle::encrypt` (whose scheme uses a deterministic IV and an 8-byte MAC).
One AEAD scheme with random nonces covers all local state. The JSON is produced into an exactly-sized buffer
that is wiped after use ([`state.rs#L27`](../../rust/fuzzy_crypto_core/src/state.rs#L27)), so no partial copy of a
key is left on the heap by buffer growth.

**Atomic write, save-before-return** ([`store.rs#L334`](../../rust/fuzzy_crypto_core/src/store.rs#L334),
[`#L420`](../../rust/fuzzy_crypto_core/src/store.rs#L420)): every mutation (pairing step, message, file key, flag)
runs inside `with_state_mut`: load (lazily cached), mutate, seal, write `<chat_id>.state.tmp` (mode `0o600`),
`fsync`, rename over `<chat_id>.state`, `fsync` the directory (unix). The result of the operation is returned
only after the rename. If the mutation, the seal or the write fails, the cached copy is evicted and the next
call re-reads the disk — the cache never holds a state that is not on disk, and a rejected operation leaves
the file byte-identical. On decrypt this means: a crash *between* Olm decrypt and the write leaves the message
key on disk, so the user re-pastes once; a crash *after* the write has already returned the plaintext.

**Delete** ([`store.rs#L444`](../../rust/fuzzy_crypto_core/src/store.rs#L444)): remove a stale `.tmp`, overwrite the
state file with zeros (best effort on flash), unlink. Idempotent. The history key goes with the state, so the
chat's sealed history (§10.4) is unreadable from then on by design — a chat re-created under the same id draws
a new key and answers `Corrupt` for the old seals.

### 10.4 Local seal of message history

The app keeps received *and* sent **text** plaintext locally (the ratchet makes a blob decryptable once, and a
sender can never decrypt its own output) — owner decision D-1, design (a). File rows carry no seal: a received
file is a plain file on disk (§10.5) and its row holds only the path. Each text plaintext is sealed by
`seal_local(chat_id, plaintext)`: `AEAD(history key of chat_id, random nonce, aad = "local-seal" ‖ chat_id,
plaintext)` in a `0x20` blob, stored base64 in the database row
([`store.rs#L43`](../../rust/fuzzy_crypto_core/src/store.rs#L43), [`#L210`](../../rust/fuzzy_crypto_core/src/store.rs#L210),
[`#L466`](../../rust/fuzzy_crypto_core/src/store.rs#L466)); `open_local(chat_id, blob)` is the inverse. The
history key is the chat's own (§3): it is read from that chat's sealed state — the cached copy when the state is
loaded, else the file — so a chat the store does not know is `UnknownChat`, a tag failure (a tampered blob,
another chat's key, or the right key under another chat's id, which the AAD binds) is `Corrupt`. Vector:
`local_seal_chat`.

What this buys, stated exactly: a leaked **history key** opens one chat's history and no other's, on one device
(A's and B's keys for the same chat are independent). It does **not** limit a leaked **store key** or the app-lock
password: the store key opens every state file, each state file holds its chat's history key, so whoever has the
store key reads every chat's history — the per-chat key is defence in depth below the store key, not a second
gate above it. History is therefore readable only while the store is unlocked; because the store key is wrapped
under the app-lock password, a copy of the database without the password (and without the OS keystore) is
ciphertext. No migration exists: seals written by the pre-F2-12 store-derived key (`HKDF(store key,
"fuzzy-local-seal-v1")`, AAD `local-seal` without a chat id) read as `Corrupt` at the core — an empty row in
the app, which never throws on a seal it cannot open (`THREAT_MODEL.md` §8) — that key was never shipped.

### 10.5 What is *not* sealed

Deliberately, so the reviewer is not misled: the app's Isar database is not encrypted as a whole. Chat names,
the chat id, timestamps, message ordering, file names and sizes, the `encryptedMessage` column (the `Fuzz/`
blob text itself — ciphertext, but a record that a message exists), and every other row are plaintext on disk.
Only the `sealedPlaintext` column and the vault item files are sealed; a vault item's title, tags, group and
type are plaintext columns in the database. The wrapped store key lives in the platform
secure storage (Keychain / Keystore / DPAPI / libsecret) as a `0x10` blob.

**Unfuzzed files are written in the clear.** A received file's plaintext is delivered as an ordinary file at
`<application documents directory>/<chat name>/<original name>` — on desktop that is the user's Documents
folder; on iOS the app's Documents folder, which the Files app shows as "On My iPhone › Fuzzzy Ink"; on
Android the file is written there and then moved to the public `Downloads/Fuzzzy Ink/<chat name>/` through
MediaStore (T-0366, so the user finds it with any file manager) — and the fuzzed containers the user produced
sit beside it as `<name>.fuzz` (ciphertext). The plaintext file is **not sealed, not gated by the app lock, and
not removed when the chat is deleted**; anyone who can read the device's file system reads it, and only text
rows get a `sealedPlaintext` (§10.4). A file row's `encryptedMessage` column holds that file's path, so the
database names the plaintext file but does not contain it; the archive export (§9.5) records the name only.
Basics file decryption likewise writes a plain file into a folder under the same documents directory. The app's own copy (About
encryption; README) says so in as many words. `THREAT_MODEL.md` §2.5, §7.13, R36.

### 10.6 Vault

The vault has its own 32-byte master key, wrapped under the vault password exactly like the store key (§6.8)
but with AAD `vault-key` — a vault blob never unwraps as the app-lock key and vice versa. Items are sealed
under the master key **directly** (no sub-key: the master key has one purpose) as `0x20` blobs with AAD
`vault-item` ([`vault.rs#L16`](../../rust/fuzzy_crypto_core/src/vault.rs#L16)); a tag failure is `Corrupt`. A vault
password change re-wraps the master key ([`vault.rs#L52`](../../rust/fuzzy_crypto_core/src/vault.rs#L52)); items are
never re-encrypted. The master key is held in an opaque handle (`VaultKey`) that behaves like the store handle
(`close` → later calls `StoreLocked`). Vectors: `wrapped_vault_key`, `vault_item`.

---

## 11. Password formats

**Argon2id everywhere.** One implementation, `derive_kek` ([`store.rs#L94`](../../rust/fuzzy_crypto_core/src/store.rs#L94)),
is the crate's only Argon2 entry: the store key, the vault key, password-sealed blobs and password-mode files
all go through it.

| Parameter | Value written by this build | Where |
|---|---|---|
| algorithm | Argon2id, version 0x13 | `argon2` 0.6.0 |
| `m_cost` | 65 536 KiB (64 MiB) | [`store.rs#L27`](../../rust/fuzzy_crypto_core/src/store.rs#L27) |
| `t_cost` | 4 | same |
| `p_cost` | 1 | same |
| output | 32 bytes | same |
| salt | 16 random bytes per wrap/seal/file | §6.6–6.8 |

**Why the parameters are in every header.** They are inputs the *decoder* needs, and they are the knobs a
future build may turn (a slower phone may need `t = 3`; a memory-richer one more): recording them next to
the salt lets any later build open any earlier blob without a format change. They are authenticated — by
the AAD in the `0x05` blob, by the AAD in every file chunk, and (for `0x10`) by the tag itself, since a
changed parameter derives a different KEK.

**Caps on attacker-controlled headers.** Because a pasted `0x05` blob, a received container or a tampered
`0x10` blob dictates the cost, the decoder refuses `m_cost > 262 144 KiB (256 MiB)`
([`store.rs#L36`](../../rust/fuzzy_crypto_core/src/store.rs#L36)) or `t_cost > 16`
([`store.rs#L39`](../../rust/fuzzy_crypto_core/src/store.rs#L39)) — and anything `argon2::Params::new` rejects, e.g.
`p = 0` or `m < 8·p` — as `Corrupt` **before allocating a single block**. The worst header a peer can make the
device compute is therefore 256 MiB × 16 passes (≈ 2 s on a 2021 laptop in release, more on a phone). All
Argon2 runs in the process are serialised by one lock, taken *before* the block buffer is allocated
([`store.rs#L48`](../../rust/fuzzy_crypto_core/src/store.rs#L48)), so peak memory is one buffer, and that buffer
is owned by the crate and wiped after the run (the `argon2` crate does not wipe its own).

**Password-sealed blob `0x05`** (§6.7; vector `password_sealed_text`): `open_bytes`
([`passwords.rs#L62`](../../rust/fuzzy_crypto_core/src/passwords.rs#L62)) decodes the layout (`UnsupportedFormat` /
`Corrupt`), takes the AAD from the received bytes, derives the key with the header's parameters (caps as
above), opens. **A tag failure is `WrongPassword`** — wrong password and tampered blob are indistinguishable,
and the UI says so. `open_text` additionally requires UTF-8 plaintext (`Corrupt`). Whitespace inside the
pasted text is ignored (§6.1).

Passwords arrive over the FFI as strings and are moved into wiped buffers on the first line of every
function; the KEK is a wiped 32-byte buffer; the AEAD object wipes its key on drop.

---

## 12. Versioning policy

- **Magic, version, type** (§6.2) are the whole negotiation. A decoder that does not recognise all three
  refuses the input with `UnsupportedFormat` and never guesses.
- **A version bump (`0x01` → `0x02`) means an incompatible layout** of the envelope or of any payload it
  carries. Nothing in this document survives a version bump unless the next document says so explicitly.
  This build carries no compatibility shims and no legacy readers (the project's rule for the hardening);
  whether a version-2 build would read version-1 blobs is a decision that version's document must make —
  the version-1 layout is not designed to coexist with another version in one decoder.
- **Adding a type byte is not a bump.** New types can appear under version 1; an old build reports them as
  `UnsupportedFormat`, which is the intended behaviour for "this build cannot read that".
- **Removing or changing the meaning of a type byte, a field, an AAD string, a domain string, a KDF
  parameter's semantics, a nonce layout or a check in §7.2** is a bump.
- **Inner header version** (`inner_version`, §7.1) and **state body version** (`format_version`, §10.3) are
  independent counters with the same rule each: an unknown value is refused. They are bumped only when their
  own layout changes.
- **Argon2 parameters are data, not format** (§11): changing the values a build *writes* is not a bump.
- **Text encoding.** Version 1 has exactly one text encoding, base64url without padding, and no encoding byte
  after `Fuzz/`. The design note that a base91 encoding could later be added as "encoding `0x02`" of the
  same binary blob has *not* been implemented: the shipped envelope carries no such byte. A second encoding
  would have to be introduced with an explicit discriminator (a new prefix or a byte after the prefix) and
  documented here; a version-1 decoder fed base91 text refuses it at §6.1 step 3, because base91 uses
  characters outside the base64url alphabet — it can never be misread as base64url.
- **Crate pins** (§15): the four cryptographic crates and the FFI crate are `=`-pinned in `Cargo.toml`; the
  other eight dependencies are caret ranges. The effective pin for *every* crate is `Cargo.lock`, which CI builds
  `--locked`, so no resolution can change without a lock-file commit. A dependency upgrade that changes bytes
  additionally fails the vector check in `cargo test` (§Appendix A) and is therefore a deliberate act, not an
  accident.

---

## 13. Trust boundaries

Fuzzzy Ink is a Flutter app; the crate is reached through `flutter_rust_bridge` 2.13.0 (frb). The boundary
is drawn so that **no key material ever crosses it**.

**Crosses the FFI, Dart → Rust:** passwords (as strings; moved into wiped buffers immediately), the wrapped
`0x10` blobs (ciphertext), `Fuzz/` blob texts and container paths (attacker-controlled input), chat ids
(validated by shape on entry), plaintext the user typed (to be encrypted), file paths, the verified flag.

**Crosses the FFI, Rust → Dart:** `Fuzz/` blob texts and `0x10`/`0x20`/`0x05` blobs (ciphertext), the
plaintext the user asked to see (a decrypted message, an opened local seal, a decrypted vault item), the
safety-number string, status enums, progress events, file names, and the 13 `CoreError` variants
(payload-free — no OS error text, no path, no key or digit ever appears in an error).

**Never crosses:** the store key, the KEK, the history keys, the vault master key, file keys, Olm accounts and
sessions, message keys, state-file bodies. They live inside four opaque handles the Dart side holds by
reference only — `CryptoCore` (the unlocked store), `VaultKey`, `FileTicket` (a prepared file job with its
key), `FileJob` (a pause/cancel word, no secret) — and every function that touches a key is asynchronous
(runs on frb's thread pool). The only synchronous functions in the crate are `blob_type_of`, `peek_chat_id`
([`api/formats.rs#L22`](../../rust/fuzzy_crypto_core/src/api/formats.rs#L22), [`#L40`](../../rust/fuzzy_crypto_core/src/api/formats.rs#L40))
and the three `FileJob` controls ([`api/files.rs#L85`](../../rust/fuzzy_crypto_core/src/api/files.rs#L85)) — none
touches a key. `peek_chat_id` reads the chat id out of an `0x01`/`0x02` blob **without** verifying its
signature and **without** the uuid shape check — Dart receives whatever 1..=255 bytes of UTF-8 the blob
carries. It is a routing hint only: the Dart side validates the uuid shape before using the string as a key,
path or query, and every crate operation that acts on that id re-validates it and re-verifies the blob (§4.1).

**What the Dart side is trusted with** (and the threat model must account for): the clipboard (a blob on it
is readable by any app that can read the clipboard), the database (§10.5), the platform secure storage for
the wrapped store key, the file system paths it passes in, and the screen. On macOS in the *development*
flavour the wrapped store key is placed in the login keychain rather than the data-protection keychain, so
unsigned developer builds can run; staging and production builds use the data-protection keychain.

**Inside the crate:** every secret is a `Zeroizing` buffer or a `ZeroizeOnDrop` struct, wiped on drop; the
crate's own key-holding structs (`ChatState`, `FileKeyBody`, `OpenStore`, the opaque handles) derive neither
`Debug` nor `Clone` — note that the `Zeroizing<[u8; 32]>` / `Zeroizing<Vec<u8>>` buffers themselves do carry
`zeroize`'s `Debug`/`Clone` impls, so the guarantee against a key ever being printed rests on the fact that
there is no logging anywhere in the crate and no `format!` of a secret, not on the type system. Comparisons of secret-derived bytes against
state use `subtle::ConstantTimeEq` (§4.4, §7.2). Public-data comparisons (magic bytes, chat-id strings) are
ordinary comparisons on purpose. The crate never reads environment variables, files outside the store
directory or the paths it is given, or the network (it has no network code at all).

---

## 14. The forward-secrecy argument

**Claim.** A message blob (text or file) can be decrypted once, on the device it was addressed to, and never
again by anyone — including that device after it has done so, and including the sender. This is **forward
secrecy** (past messages stay closed). The complementary property, **post-compromise security** (a copy of the
state stops working), holds only after a DH ratchet round trip — point 3 below states exactly what a copy of
the state file can read.

1. **Per-message keys.** Every blob is an Olm message; Olm derives a fresh message key from the receiving
   chain for every chain index and, on a ratchet step, a fresh chain from a fresh Diffie-Hellman. This is
   vodozemac's double ratchet, unmodified (§8.1).
2. **The receiver deletes the key on use.** A message key that was consumed is removed from the skipped-key
   store; a current-chain key is advanced past. A second decrypt of the same blob yields `MissingMessageKey`
   from vodozemac — asserted at the Olm layer, not merely at the API, by `api::messages::tests::forward_secrecy`
   and `api::files::tests::forward_secrecy_for_files`.
3. **The deletion is persisted before the plaintext is returned** (§10.3). A snapshot of the sealed state file
   taken *after* message N−1 was read cannot decrypt N−1 or anything earlier (their keys are already gone from
   that snapshot) — forward secrecy holds for everything already read. **But the snapshot holds the receiving
   chain key**, so, together with the store key (or the app-lock password that unwraps it), it decrypts N *and
   every later message the peer generates on that same receiving chain* — reading it on the live device does not
   close a *copy*. The copy stops working only at the next DH ratchet step, which needs a round trip: this device
   sends, the peer receives that message (advancing its ratchet), and the peer's next message arrives on a new
   chain the copy never had. Verified against the crate: a copy of B's state taken after reading one message
   opened three messages A generated afterwards; after B replied and A had read the reply, the copy got
   `Corrupt` on the next one. Post-compromise security is therefore "after a round trip", not "immediately".
4. **The sender cannot decrypt its own output.** An Olm sender holds the sending chain only; feeding its own
   blob to its own session fails the MAC (`InvalidMAC`, mapped to `Corrupt`). This is why sent plaintext must
   be kept locally (§10.4).
5. **Files inherit the property.** The file key is a random 32-byte key that exists only inside one Olm
   message (§9.4). Once that message is consumed the key is unrecoverable from the protocol; the container's
   chunks are useless without it.
6. **The window limits how long a key waits** (§8): at most 40 skipped keys per chain, 5 chains, and never
   further than 63 counters behind the newest accepted message. A key that is evicted is gone; the blob it
   protected is undecryptable forever. This bounds the exposure of a seized device to the *unread* blobs still
   inside those windows — plus, per point 3, whatever the peer keeps sending on the current chain until a round
   trip ratchets past the seized chain key.
7. **What the argument does not cover.** The plaintext the app keeps locally (§10.4) is protected by the app
   lock, not by the ratchet; a device attacker who has the unlocked store, or the password, reads history — and,
   with a copy of the state, reads *forward* on the current receiving chain until the peer ratchets (point 3),
   so the incremental exposure of a state copy over the history it already reveals is future messages, not
   past ones. The identity keys of a chat are long-lived and their compromise lets an attacker impersonate that
   party in *that* chat going forward (not read past messages). All of this is the threat model's subject, not
   this document's.

---

## 15. Reference crates and versions

In `rust/fuzzy_crypto_core/Cargo.toml` the cryptographic crates `vodozemac`, `chacha20poly1305`, `aead-stream`,
`argon2` and the FFI crate `flutter_rust_bridge` are exact (`=`) pins; `sha2`, `zeroize`, `getrandom`,
`subtle`, `base64`, `serde`, `serde_json` and `thiserror` are caret ranges. **The real pin is `Cargo.lock`**,
which resolves every crate to the version below, and CI builds `--locked`, so a different resolution cannot
build without a lock-file change. Toolchain: Rust 1.98.1 (`rust-toolchain.toml`), Flutter 3.41.7 / Dart 3.11.5
(`.fvmrc`).

| Crate | Version | Role here | Audit / provenance |
|---|---|---|---|
| `vodozemac` | 0.10.0 (`default-features = false`) | Olm v1: accounts, one-time keys, 3DH, double ratchet, message encoding, Ed25519 verify (`verify_strict`) | Least Authority, "Matrix vodozemac Final Audit Report", March 2022 — no significant findings; https://matrix.org/media/Least%20Authority%20-%20Matrix%20vodozemac%20Final%20Audit%20Report.pdf. Olm spec: https://gitlab.matrix.org/matrix-org/olm/blob/master/docs/olm.md |
| `chacha20poly1305` | 0.11.0 (`zeroize`) | XChaCha20-Poly1305 for every AEAD use (§6.7–6.9, §9) | RustCrypto AEADs; NCC Group audit of the `chacha20poly1305` crate, 2020, no significant findings (report linked from the crate README: https://github.com/RustCrypto/AEADs/tree/master/chacha20poly1305). Also present at 0.10.1 as vodozemac's dependency |
| `aead-stream` | 0.6.0 (`alloc`) | the STREAM construction (BE32 nonce layout) of §9.1 | RustCrypto AEADs (same repository); implements the STREAM construction of Hoang, Reyhanitabar, Rogaway, Vizár (2015) |
| `argon2` | 0.6.0 (`zeroize`) | Argon2id of §11 | RustCrypto password-hashes; RFC 9106; parameters per OWASP Password Storage Cheat Sheet |
| `sha2` | 0.11.0 | SHA-512 for the safety number (§5) — the crate's only direct hash use. The crate calls no HKDF of its own: the `hkdf` dependency became callerless when the store-derived local key was replaced by per-chat history keys (§3, §10.4) and was removed from `Cargo.toml`, the lock and the SBOM; the only HKDF in the core is inside vodozemac's ratchet | RustCrypto hashes (`sha2` 0.10.9 and `hkdf` 0.12.4 are also present as vodozemac's transitive dependencies) |
| `subtle` | 2.6.1 | constant-time comparisons (§4.4, §7.2) | dalek-cryptography |
| `zeroize` | 1.9.0 (`zeroize_derive`) | wiped buffers and structs (§13) | RustCrypto utils |
| `getrandom` | 0.4.3 (`sys_rng`) | the only randomness source: nonces, salts, keys, one-time-key seeds (through vodozemac's own `rand`/`getrandom` 0.2.17 for its keys) | rust-random |
| `base64` | 0.22.1 | base64url-no-pad text envelope (§6.1) | marshallpierce/rust-base64 |
| `ed25519-dalek` / `x25519-dalek` / `curve25519-dalek` | 2.2.0 / 2.0.1 / 4.1.3 | vodozemac's curves (transitive) | dalek-cryptography (transitive through vodozemac; not separately audited for this project) |
| `serde` / `serde_json` | 1.0.229 / 1.0.151 | state-file body only (§10.3) | — |
| `flutter_rust_bridge` | 2.13.0 (Rust, Dart and codegen in lockstep) | the FFI (§13) | — |
| `thiserror` | 2.0.20 | `CoreError` | — |

Nothing else in the crate is cryptographic: there is no hand-written primitive, no custom KDF, no custom MAC,
no custom encoding of Olm messages. `vodozemac`'s `libolm-compat` feature is disabled — libolm pickles are
never read. The crate must never be built with `--cfg fuzzing`: under it vodozemac's `Ed25519PublicKey::verify`
is a no-op (a standing comment at the top of `lib.rs` records this).

---

## 16. Threat model

This document describes the mechanism; the threat model — assets, trust boundaries, the adversaries (passive
channel observer, active attacker on the pairing channel, device thief with and without the app lock,
malicious peer, harvest-now-decrypt-later), what is and is not defended, and residual risks — is
`THREAT_MODEL.md` (F5-2). Read §13 and §17 here as its inputs.

---

## 17. Known limitations

Stated so a reviewer does not have to discover them.

1. **Man-in-the-middle until the safety number is compared.** The pairing authenticates blobs to the keys
   inside them, not to people. An attacker who replaces *both* blobs in transit (the invitation on the way
   to B and the acceptance on the way to A) holds two sessions and relays. The safety number (§5) detects this
   — on both sides the 60 digits differ — but only when the users compare it out of band. Until then the chat
   works and is not authenticated. There is no third blob and no commitment round, so an emoji/SAS scheme
   would not add strength here (a two-message SAS without commitment is grindable by an active attacker).
2. **The counter window is stricter than Olm** (§8.2): a message more than 63 behind the newest accepted one in
   its direction is refused even though Olm could still decrypt it (and Olm itself keeps only 40 per chain,
   5 chains). Whether to widen the window or make it per-chain is an open product decision; the core ships the
   stricter rule.
3. **Plaintext at rest — owner decision D-1, answered 2026-09-13: design (a) with a per-chat key.** This build
   stores sent and received plaintext locally because a ratcheted blob cannot be re-read; each chat's history
   is sealed under that chat's own history key, which lives in the chat's state file under the store key
   (§10.4). The per-chat key bounds a *history-key* leak to one chat; it does not bound a *store-key* leak,
   which opens every state and therefore every history key. The sealed copy is exactly as strong as the app
   lock: no app-lock password (the empty-string wrap) means the OS keystore alone protects the store key.
4. **Metadata is not sealed** (§10.5): chat names, timestamps, message counts and the blob texts themselves are
   readable in the database.
5. **A corrupt chat-mode file consumes its message** (§9.4): the key message is opened — and the ratchet
   advanced — before the chunks are verified, because doing it the other way round would keep the message key
   alive while the file key sits outside the store. A damaged file must be re-sent; the app says so.
6. **Olm's 8-byte MAC** (Olm v1 truncates HMAC-SHA256 to 8 bytes per message). There is no online oracle in a
   paste-only protocol — every trial is a user pasting a blob, every failed paste leaves the state file
   byte-identical, and a forgery that passed the MAC would additionally have to decrypt to a valid inner header
   carrying the right chat id and both 32-byte identity keys (§7.2) — but the reviewer should know the tag length.
7. **Olm encoding malleability.** vodozemac re-encodes the protobuf-style Olm message it MACs, so a handful of
   non-canonical encodings (an unknown protobuf field, the high bit of an X25519 key, which curve25519-dalek
   masks) of the *same* message are accepted as that message. Same plaintext, same key consumption; not a
   forgery. Inherent to Olm, documented here so nobody mistakes a fuzzer's "accepted mutant" for a bypass.
8. **macOS development flavour uses the login keychain** for the wrapped store key so that unsigned developer
   builds run; it is a development-only setting, not shipped in staging or production.
9. **Hostile Argon2 headers cost up to 256 MiB × 16 passes** (§11) before being refused by the tag. A phone may
   take ten seconds on the worst accepted header; it will not crash.
10. **Two processes on one store are unsupported.** In-process access is serialised; a second process opening
    the same directory would race the atomic writes.
11. **`.part` after a process kill** (§9.3) stays on disk until the next job over the same output.
12. **No post-quantum component, no deniability claim, no multi-device, no key rotation** of a chat's identity
    keys (delete and re-pair instead).
13. **An Ed25519 identity key is per chat for the life of that chat.** Its compromise allows impersonation in
    that chat from then on; it does not reveal past message keys (§14).
14. **A copy of the sealed state plus the store key reads forward until the peer ratchets** (§14.3). Whoever
    holds a `<chat_id>.state` file and the store key (or the app-lock password, which unwraps it) can decrypt every
    message the peer sends on the current receiving chain after the copy was taken — not messages already read
    (forward secrecy), but future ones, until this device sends and the peer's next message arrives on a fresh
    chain. Post-compromise security needs that round trip; nothing in the protocol forces one.
15. **Unfuzzed files and exported archives are outside every guarantee above.** A received file lands as a
    plain file under the app's documents directory (§10.5) and an archive export is the chat's plaintext under
    a user-chosen password (§9.5); neither is sealed by the store, gated by the app lock, or covered by forward
    secrecy. Only text history is sealed at rest.

---

## Appendix A — Test vectors

`documents/security/vectors/` holds 19 vectors (43 files) as `.hex` (bytes, 32 per line — `xxd -r -p name.hex | xxd`),
`.txt` (the `Fuzz/` form of wire blobs) and `.json` (inputs), plus `state_file.body.json`. They are
generated by `rust/fuzzy_crypto_core/src/vectors.rs` from fixed inputs through the production code paths
(randomness injected through the crate's `*_with` hooks) and **checked on every `cargo test`**: the test
`vectors::committed_vectors_match` fails if any byte of any vector differs from what the build produces, or
if a file the generator does not own appears in the directory. Regeneration after a deliberate format change
is `FUZZY_WRITE_VECTORS=1 cargo test --locked vectors::write_vectors`, which also asserts that a second
generation is byte-identical.

Every vector was also re-derived from this document's tables with an independent implementation (Python:
`argon2-cffi`, `pycryptodome`, `cryptography`/`pynacl`, `hashlib`) — first by the reviewers of the features
that introduced each layout, then again for this document. `vectors/README.md` lists each vector, its inputs
and the independent derivation it was checked against.

| Vector | Section | Bytes | Deterministic through |
|---|---|---|---|
| `invitation` | §6.3 | 203 | fixed A account (seeds `01`/`02`/`03`), real Ed25519 signature |
| `acceptance` | §6.4 | 178 | fixed B account (seeds `04`/`05`), placeholder pre-key body, real signature |
| `message` | §6.5 | 11 | placeholder Olm body |
| `inner_header_handshake` | §7.1 | 116 | A's and B's fixed identity keys |
| `inner_header_text` | §7.1 | 121 | same, body `hello`, counter 7 |
| `file_key_body` | §7.3 | 44 | key `42×32`, name `report.pdf` |
| `inner_header_file_key` | §7.1/7.3 | 160 | same, counter 8 |
| `argon2id_kek` | §11 | 32 | `pw`, salt `11×16` |
| `wrapped_store_key` | §6.8 | 103 | key `33×32`, `pw`, salt `11×16`, nonce `22×24`, AAD `store-key` |
| `wrapped_vault_key` | §6.8 | 103 | same, AAD `vault-key` |
| `local_seal_chat` | §6.9/10.4 | 51 | history key `55×32`, chat id, `hello`, nonce `44×24` |
| `vault_item` | §6.9/10.6 | 50 | `item`, nonce `44×24` |
| `password_sealed_text` | §6.7 | 76 | `pw`, salt `11×16`, nonce `22×24`, `hello` |
| `state_file` (+ `.body.json`) | §10.3 | 1662 | A's fixed account, freshly invited, history key `55×32`, nonce `44×24` |
| `file_header_password` | §6.6 | 55 | prefix `90..a2`, salt `a0..af` |
| `file_header_chat` | §6.6 | 36 | prefix `90..a2`, placeholder Olm body |
| `file_container_password` | §9 | 114 | one chunk, `pw`, salt `a0..af` |
| `file_container_fixed_key` | §9 | 65 628 | two chunks, key `42×32`, 64 KiB chunks |
| `safety_number` | §5 | 71 chars | keys `00..1f`, `ff..e0` |

What cannot be pinned: vodozemac's outbound-session creation and message encryption draw randomness (base
key, ratchet key) with no injection point, so no vector contains a real Olm message body; the Olm message
format is vodozemac's own, audited, and outside this specification.

## Appendix B — Error codes

`CoreError` ([`error.rs#L11`](../../rust/fuzzy_crypto_core/src/error.rs#L11)), payload-free; the display text is what
a file job's terminal event carries.

| Variant | Text | Meaning |
|---|---|---|
| `UnsupportedFormat` | `unsupported format` | unknown magic, version, type byte or text encoding; a blob of the wrong type for the call; storage-only type pasted |
| `InvalidSignature` | `invalid signature` | an invitation/acceptance signature did not verify (or the key/signature bytes do not parse) |
| `InvitationAlreadyUsed` | `invitation already used` | §4.5 |
| `WrongChat` | `wrong chat` | the blob names another chat, or its identity keys are not this chat's peer/ours |
| `Replay` | `replay` | the message key was already consumed, or the counter was already seen |
| `TooOld` | `too old` | the counter fell out of the window, or Olm's gap limit was exceeded |
| `Corrupt` | `corrupt` | structurally invalid bytes, a failed authentication tag on a keyed blob, an unusable header parameter, or a dishonest inner header |
| `WrongPassword` | `wrong password` | the password does not open the store, the vault, a `0x05` blob or chunk 0 of a password-mode file (indistinguishable from tampering) |
| `StoreLocked` | `store locked` | the handle was closed or never opened |
| `UnknownChat` | `unknown chat` | no state for that chat id; or (safety number) no peer key yet |
| `Io` | `io` | a file-system failure; the OS text stays inside the crate |
| `Cancelled` | `cancelled` | a file job was cancelled (surfaces as `is_cancelled`, never as a message) |
| `Internal` | `internal` | an invariant the core relies on did not hold, or a call the UI must not make (encrypt on an unconnected chat, re-accept, a second run of a ticket) |

## Appendix C — Constants index

| Constant | Value | Defined at |
|---|---|---|
| text prefix | `Fuzz/` | [`formats.rs#L15`](../../rust/fuzzy_crypto_core/src/formats.rs#L15) |
| magic | `FUZZ` | [`formats.rs#L17`](../../rust/fuzzy_crypto_core/src/formats.rs#L17) |
| envelope version | `0x01` | [`formats.rs#L19`](../../rust/fuzzy_crypto_core/src/formats.rs#L19) |
| envelope length | 6 | [`formats.rs#L21`](../../rust/fuzzy_crypto_core/src/formats.rs#L21) |
| signature length | 64 | [`formats.rs#L23`](../../rust/fuzzy_crypto_core/src/formats.rs#L23) |
| type bytes | `01 02 03 04 05 10 20` | [`formats.rs#L37`](../../rust/fuzzy_crypto_core/src/formats.rs#L37) |
| key modes | chat `0x01`, password `0x02` | [`formats.rs#L439`](../../rust/fuzzy_crypto_core/src/formats.rs#L439) |
| chunk size written / accepted | 1 048 576 / 65 536..=16 777 216 | [`formats.rs#L25`](../../rust/fuzzy_crypto_core/src/formats.rs#L25) |
| wrapped-key ciphertext length | 48 | [`formats.rs#L31`](../../rust/fuzzy_crypto_core/src/formats.rs#L31) |
| Poly1305 tag length | 16 | [`formats.rs#L644`](../../rust/fuzzy_crypto_core/src/formats.rs#L644) |
| inner header version | `0x01` | [`formats.rs#L513`](../../rust/fuzzy_crypto_core/src/formats.rs#L513) |
| direction bytes | A→B `0x00`, B→A `0x01` | [`formats.rs#L519`](../../rust/fuzzy_crypto_core/src/formats.rs#L519) |
| content types | `0x00 0x01 0x02` | [`formats.rs#L537`](../../rust/fuzzy_crypto_core/src/formats.rs#L537) |
| Argon2id parameters written | m 65 536 KiB, t 4, p 1 | [`store.rs#L27`](../../rust/fuzzy_crypto_core/src/store.rs#L27) |
| Argon2id caps read | m ≤ 262 144 KiB, t ≤ 16 | [`store.rs#L36`](../../rust/fuzzy_crypto_core/src/store.rs#L36) |
| AAD `store-key` | | [`store.rs#L41`](../../rust/fuzzy_crypto_core/src/store.rs#L41) |
| AAD `chat-state` ‖ chat id | | [`store.rs#L42`](../../rust/fuzzy_crypto_core/src/store.rs#L42) |
| AAD `local-seal` ‖ chat id | | [`store.rs#L43`](../../rust/fuzzy_crypto_core/src/store.rs#L43) |
| AAD `vault-key` / `vault-item` | | [`vault.rs#L15`](../../rust/fuzzy_crypto_core/src/vault.rs#L15) |
| `0x05` AAD length | 31 | [`passwords.rs#L18`](../../rust/fuzzy_crypto_core/src/passwords.rs#L18) |
| store directory | `fuzzy_crypto_store` | [`store.rs#L25`](../../rust/fuzzy_crypto_core/src/store.rs#L25) |
| state file extensions | `.state`, `.state.tmp` | [`store.rs#L44`](../../rust/fuzzy_crypto_core/src/store.rs#L44) |
| state body version | 1 | [`state.rs#L16`](../../rust/fuzzy_crypto_core/src/state.rs#L16) |
| counter window | 64 | [`counters.rs#L22`](../../rust/fuzzy_crypto_core/src/counters.rs#L22) |
| safety-number domain / groups / bytes / modulus | `FUZZZYINK_SAFETY_NUMBER_V1` / 12 / 5 / 100 000 | [`safety.rs#L20`](../../rust/fuzzy_crypto_core/src/safety.rs#L20) |
| original name limit | 255 bytes | [`files.rs#L261`](../../rust/fuzzy_crypto_core/src/files.rs#L261) |
| longest header read | 65 568 | [`files.rs#L53`](../../rust/fuzzy_crypto_core/src/files.rs#L53) |
| pause poll | 50 ms | [`files.rs#L50`](../../rust/fuzzy_crypto_core/src/files.rs#L50) |
| Olm skipped keys / gap / chains | 40 / 2000 / 5 | `vodozemac-0.10.0/src/olm/session/receiver_chain.rs` lines 50, 31; `session/mod.rs` line 53 |
