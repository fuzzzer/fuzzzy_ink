# TASK: Message shrinker — denser character sets for shared ciphertext

**Status:** PENDING_PLAN
**Needed before production:** yes (see `before_production.md`)
**Agreed with the owner:** 2026-09-22

## What the owner wants (in their words, tidied)
The shrinker must **not touch the contents of the message, the encryption, or the encoding the
core produces**. It only re-spells the same bytes in a different character set so the text that
gets pasted into a messenger is shorter. It has to be flexible — used as needed, when needed,
configurable from Settings — and it must **never break an old message**: everything ever shared
or stored still pastes and decrypts.

## Fixed contract (do not change)
- The Rust core emits and reads `Fuzz/` + URL-safe base64 (no padding) of the sealed bytes
  (`rust/fuzzy_crypto_core/src/formats.rs`, `TEXT_PREFIX`, `decode_text`).
- `StoredMessageData.encryptedMessage` keeps that base64 string. Storage is untouched.
- Invitations, pairing, files, the ratchet — untouched.

## Design (agreed)
1. **Pure transcoder at the share/paste edge, Dart side only.**
   - Outgoing: copy/share on a sent text bubble (`sent_message_area.dart`,
     `_prepareEncrypredMessage`) → `shrink(text, profile)`. File bubbles are never shrunk.
   - Incoming: `ConnectedChatCubit.receiveMessage` and the deep-link prefill
     (`connected_chat_page.dart`) → `unshrink(text)` → the core always receives `Fuzz/<base64>`.
   - The paste detector (`text.startsWith(fuzzIdentificator)`) must accept `Fuzz<tag>/` too.
2. **Self-describing prefix.** Shrunk text is `Fuzz<tag>/<payload>`; plain `Fuzz/` is base64
   forever. Unknown tag → clean "cannot read this" failure, never a wrong decrypt.
3. **Profiles, pluggable alphabets (ASCII or Unicode):**
   - *Standard* — base64url, what the core makes. **Default.**
   - *Compact ASCII* — base91 (~8 % fewer characters than base64).
   - *Compact Unicode* — **base2048** (11 bits/char, ~45 % fewer characters; designed to survive
     character-counted transports like Telegram/WhatsApp/Twitter) and **base32768**
     (15 bits/char, ~60 % fewer). These are the schemes made for exactly this job.
   - Strip whitespace on decode, as the core already does.
4. **Configurable.** Default profile + "auto: only shrink above N characters" live in
   `ChatPreferences` and are edited on the Settings page. Each sent bubble gets a per-message
   override (next to the existing show-encrypted toggle).
5. **Zero changes** in `rust/`, `lib/rust_bridge/`, storage models, or the core adapter.

## Salvage from branch `worktree-fuzzy-codec-service` (2026-09-08)
Reuse: the codec engine (`base91_codec`, `power_of_two_codec`, `radix_codec`, `FuzzyAlphabet`,
tests, `tool/codec_benchmark.dart`). `FuzzyAlphabet` caps radix at 128 and works on code
units — it must be widened to Unicode code points for base2048/base32768.
Drop: the `-<tag>` envelope, the `aes_service.dart` hook (that service no longer exists),
standard-base64 legacy handling (the core uses base64url no-pad).

## Done when
- Copy/share of a text message in each profile produces `Fuzz<tag>/…`; pasting it back on the
  same or another device decrypts identically to the base64 form.
- Every existing message (stored, and old `Fuzz/…` shares) still decrypts. Test with a fixture
  captured before the change.
- Profile and auto-threshold are chosen in Settings and persist across restart; the per-message
  override works.
- No diff under `rust/`, `lib/rust_bridge/`, `lib/src/fuzzzy_ink/storage/`.
- `fvm flutter analyze` clean, tests pass, character-count table for a 100/500/2000-byte
  message per profile recorded in the review log.

---
### PLAN (by [PLANNER])
*To be populated.*

---
### IMPLEMENTATION (by [DOER])

---
### REVIEW LOG (by [REVIEWER])

---
### DOCUMENTATION (by [DOCUMENTER])
