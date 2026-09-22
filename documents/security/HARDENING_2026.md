# Fuzzzy Ink — the 2026 cryptographic hardening: what changed and why

**Written:** 2026-09-13 · **State of the code:** branch `agent/chat-harden-rust-crypto-core`, release candidate
tag `v1.0.0-rc.1` (commit `64615a7`) plus the fixes listed in §7 · **Companion documents:**
[`PROTOCOL.md`](PROTOCOL.md) (the specification), [`THREAT_MODEL.md`](THREAT_MODEL.md) (what is and is not
defended), [`RELEASE.md`](RELEASE.md) (build provenance and reproducibility), [`../../SECURITY.md`](../../SECURITY.md)
(disclosure policy), [`sbom/`](sbom/) (CycloneDX bills of materials), [`vectors/`](vectors/) (byte-exact test vectors).

This document is the supporting material for an independent security audit of Fuzzzy Ink. It is written to be
read by someone who has not seen the code: it says what the app's cryptography looked like before September 2026,
what the nine diagnosed weaknesses were, what replaced them, what was measured, which product decisions are
still the owner's to make, and what was deliberately left out. Where a number is given, the artifact that
produced it is named; the CI runs are public.

---

## 1. Why this work exists

Fuzzzy Ink is an **offline** encryption app, not a messenger. Two people pair once by exchanging an invitation
code and an acceptance code by hand; after that either side "fuzzes" (encrypts) text or files into a blob and
sends it over any channel — e-mail, a chat app, a USB stick — and the other side pastes it back to "unfuzz" it.
There are no servers, no accounts and no transport. Two consequences drove every decision below:

1. **Ciphertext is long-lived and public.** Users are told blobs are safe to post anywhere, and they do. A blob
   sits in an inbox for years. This is a harvest-now-decrypt-later target by construction.
2. **There is no online channel to negotiate over.** Every scheme has to work with one-shot, out-of-order,
   possibly never-delivered blobs.

The app had not launched when this work started: **no users, no deployed ciphertext**. That was the one moment
when breaking every format cost nothing, so every format was broken on purpose. There is no migration path,
no compatibility shim and no legacy reader anywhere in the code — the old stack was deleted, not wrapped.

The plan the work serves: harden → obtain an independent audit → publish the report, including whatever it
finds → then apply for the App Defense Alliance MASA assessment. Everything here assumes a professional
cryptographer will read the diff line by line.

---

## 2. What was replaced

Before: a pure-Dart stack built on a vendored copy of PointyCastle 4.0.0. RSA-4096 (OAEP) wrapped one
long-lived AES-256 key per chat at pairing time; every message and file was AES-256-GCM under a per-message
HKDF-SHA256 subkey (random 24-byte salt), with **empty** associated data, no sequence numbers, no
authentication of the pairing, and files streamed to disk as a single GCM blob whose tag was checked only after
the last chunk had already been written. Measured on an Apple-silicon Mac, AOT-compiled: **16 MB in 13.3 s =
1.2 MB/s** (owner brief, "CURRENT STATE", F-9).

After: **one Rust crate, `rust/fuzzy_crypto_core`, behind `flutter_rust_bridge` 2.13.0.** Dart is a thin caller
that never sees a key. The primitives are all audited third-party crates, `=`-pinned and lock-file-locked
(`PROTOCOL.md` §15):

| Concern | Crate | Provenance |
|---|---|---|
| Pairing, ratchet, per-message keys | `vodozemac` 0.10.0 — Olm double ratchet, unmodified (`SessionConfig::version_1()`) | Least Authority audit, March 2022, no significant findings; powers Matrix/Element; Apache-2.0 |
| Every AEAD use (files, local state, password blobs, vault) | `chacha20poly1305` 0.11.0 (XChaCha20-Poly1305) + `aead-stream` 0.6.0 (STREAM, BE32) | RustCrypto; NCC Group audit 2020, no significant findings |
| Password → key | `argon2` 0.6.0 (Argon2id, m = 64 MiB, t = 4, p = 1) | RustCrypto; RFC 9106 |
| Fingerprints (safety number) | `sha2` 0.11.0 — the crate's only hash use. No `hkdf` dependency remains: it lost its last caller when the per-chat history key of D-1 replaced the store-derived local key and was dropped from `Cargo.toml`, the lock and the SBOM in the closing pass; the only HKDF in the core is vodozemac's own (transitive) | RustCrypto |
| Constant-time comparison, wiping, randomness | `subtle`, `zeroize`, `getrandom` | dalek / RustCrypto / rust-random |

Nothing cryptographic was written by hand: no primitive, no KDF, no MAC, no protocol. The Olm session is used
as vodozemac ships it; the file container is the STREAM construction as RustCrypto documents it; the safety
number is Signal's encoding. Every blob and file starts with a magic prefix, a version byte and a type byte
(`FUZZ 01 xx`), so a future format change is a new version, never a silent reinterpretation.

`libsignal` was considered and rejected before a line was written: it is AGPL-3.0-only (the whole app would
become AGPL), its App Store status is an open legal question, and Signal states that use outside Signal is
unsupported. `vodozemac` gives the same audited double ratchet under a permissive licence. The one thing it
does not give is post-quantum key agreement — deferred, §8.

---

## 3. The nine findings and how each was closed

The findings were diagnosed by reading the old `lib/src/core/encryption_services/` before the work began and are
numbered as in the owner brief. "Where" points at the specification section and the code that closes it.

| # | Finding (before) | Fix (after) | Where | Status |
|---|---|---|---|---|
| **F-1** | **No forward secrecy.** One long-lived symmetric key per chat, RSA-wrapped in the acceptance blob: one device compromise decrypts the whole history and every future message. | Olm double ratchet: a fresh message key per blob, derived from a chain that ratchets on every direction change; the receiver deletes a key on use and persists the deletion **before** returning plaintext. A blob decrypts once, on one device, never again — not even by the sender. Proved at the Olm layer, not just at the API: `api::messages::tests::forward_secrecy`, `api::files::tests::forward_secrecy_for_files` (a state snapshot taken after message N−1 yields `MissingMessageKey` for N−1 and earlier). | `PROTOCOL.md` §8.1, §14; `rust/fuzzy_crypto_core/src/api/messages.rs` | **Closed.** Product consequence (single-use blobs, local history) is owner decision D-1 — §5: text history is kept readable on the device, sealed under a random per-chat history key that lives inside the chat's state file (F2-12); unfuzzed files are plain files, not sealed |
| **F-2** | **Unauthenticated handshake.** No fingerprint or safety number anywhere; the README asked users to verify out of band in prose. | Both pairing blobs carry a 64-byte Ed25519 signature by their author over every preceding byte (envelope included, `verify_strict`); the handshake header binds both identity keys into the 3DH; a **60-digit safety number** (SHA-512 over both Ed25519 keys and the chat id, Signal's 5-digit-group encoding) is shown on a verification page with a persisted "verified" flag and a shield indicator in the chat header. | `PROTOCOL.md` §4.1, §5; `pairing.rs`, `safety.rs`; `lib/src/fuzzzy_ink/ui/pages/safety_number_page` | **Closed.** The brief named vodozemac's emoji SAS; a safety number ships instead — owner decision D-2, §5 |
| **F-3** | **Empty AAD.** `Uint8List(0)` as associated data: ciphertext bound to nothing. | Every message carries an inner header *inside* the Olm plaintext — version, chat id, sender and recipient identity keys, direction, 64-bit counter, content type — checked field by field on receipt (a blob from chat A dies in chat B at the MAC, and again at the header). Every local and password-sealed format has AAD: file chunks bind the 55-byte header and the chunk index; wrapped keys use role-separated AAD (`store-key` / `vault-key`); state files bind `chat-state ‖ chat_id`. | `PROTOCOL.md` §7.1–7.2, §6.6–6.9, §9.1 | **Closed** |
| **F-4** | **No replay or ordering protection.** No sequence numbers; a captured blob re-decrypts forever. | Two layers: Olm's consumed-key store (a used key is gone) and, per chat and per direction, a 64-bit counter window (`recv_highest` + a 64-bit seen bitmap): a seen counter → `Replay`, more than 63 behind the newest accepted → `TooOld`, both surfaced as distinct user copy. Out-of-order arrival is served by Olm's 40 skipped keys per chain. | `PROTOCOL.md` §8.2–8.3; `counters.rs` | **Closed.** The 63-behind rule is stricter than Olm's own store (a documented product limit, `THREAT_MODEL.md` §7.7) |
| **F-5** | **File decryption released unverified plaintext.** One GCM blob streamed to disk; the tag was checked after the last chunk had been written. | STREAM container: 1 MiB chunks, each XChaCha20-Poly1305 with its own tag, nonce = `prefix ‖ chunk index ‖ last flag`, AAD = header ‖ index; the last chunk carries an explicit last-flag so truncation, appended bytes, reordering and duplication are all detected; **a chunk is written only after its tag verifies**, into `<out>.part` (mode 0600), renamed on success and deleted on any failure. Tests flip every chunk's first byte, byte 17 and tag byte, truncate mid-chunk and at a boundary, append and reorder — no output path exists after any of them. | `PROTOCOL.md` §9.1–9.3; `files.rs` (`tamper_leaves_no_partial_output`, `truncated_*`, `appended_bytes_detected`, `reordered_or_duplicated_chunks_detected`) | **Closed** |
| **F-6** | **Non-standard OAEP.** PointyCastle's `OAEPEncoding` is RSAES-OAEP v2.0 with SHA-1 MGF1 — interoperable with nothing. | The RSA handshake is **deleted**, not fixed: pairing is Olm's X25519 3DH with Ed25519-signed blobs; no RSA remains in the repository. | `PROTOCOL.md` §4 | **Closed by removal** |
| **F-7** | **Vendored, unsynced PointyCastle fork** (`packages/pointycastle`, 441 files, no upstream tracking). | Deleted together with the entire pure-Dart crypto stack (commit `d4f7ce4`); `pointycastle` is absent from `pubspec.yaml` and `pubspec.lock`; `rg -i pointycastle lib test pubspec.*` is empty. | F4-4 deletion commit; independent reviewer re-ran the greps | **Closed** |
| **F-8** | **Unwipeable key material.** RSA private keys serialised as decimal `String`s (`BigInt.toString()`, primes included) — immutable, GC-copied, never zeroised. | All key material lives in Rust: `Zeroizing`/`ZeroizeOnDrop` on every secret, no `Debug`/`Clone` on key types, exact-size serialisation of the Olm pickles (no reallocation residue), the Argon2 block wiped and at most one allocated at a time. Keys are `#[frb(opaque)]` handles; nothing but user-requested plaintext crosses the bridge; passwords become `Zeroizing<Vec<u8>>` on entry. | `PROTOCOL.md` §13; `THREAT_MODEL.md` §2.2, T11 | **Closed for keys.** Residual: a password typed into a Dart `String` cannot be wiped on the Dart side (R19) — Dart structurally cannot fix that part |
| **F-9** | **Pure-Dart bulk crypto: 1.2 MB/s.** No AES-NI/ARMv8 crypto extensions, no PMULL — a 1 GB file took ~14 minutes. | Native STREAM path in Rust, one reused chunk buffer, 3.9 MB peak RSS over a 1 GiB file. Measured numbers in §4. | `files.rs`; `examples/bench_file.rs`; the development-flavour benchmark tile | **Closed** (≈ 480× on the Mac, ≥ 17× on a memory-starved emulator) |

**Nothing among F-1 … F-9 is deferred.** What *is* deferred is in §8.

---

## 4. File throughput — before and after

MB = 10⁶ bytes throughout; every figure is one full encrypt or decrypt of the file including reading the
input, writing `<out>.part`, `fsync` and the rename, with a SHA-256 round-trip check outside the timed region.

| Platform / build | Size | Encrypt | Decrypt | Source |
|---|---|---|---|---|
| **Before:** pure Dart, AOT, Apple-silicon Mac | 16 MB | **1.2 MB/s** (13.3 s) | — | owner brief, "CURRENT STATE" F-9 |
| Mac M1 Max, Rust release, `bench_file` (first run after build) | 16 MiB | 392 MB/s | 448 MB/s | hardening log F3-1 §5 |
| same, binary run directly, page cache warm | 16 MiB | 511 MB/s (three more runs: 483 / 498 / 495) | 496 MB/s (477 / 493 / 510) | F3-1 §5 |
| same | 1 GiB | **583 MB/s** (588 on the first run) | **587 MB/s** (571) | F3-1 §5; `/usr/bin/time -l`: 3.9 MB peak RSS |
| Mac, through the Dart bridge (`benchmarkFiles`), release dylib, 3 runs | 64 MiB | 576 / 584 / 573 MB/s | 597 / 584 / 584 MB/s | F3-4 §4 |
| Android emulator API 35 arm64 (4 vCPU, 2.5 GB), `--profile` build = release core, 6 cold runs after `am kill-all` | 64 MiB | **min 20 · median 60 · max 438 MB/s** | **min 108 · median 424 · max 509 MB/s** | F3-4 §4 (per-run table) |
| same emulator restarted with 4 GB, `--profile`, consolidated QA sweep, 3 runs | 64 MiB | 441.7 / 451.2 / 455.4 MB/s | 463.2 / 461.2 / 458.7 MB/s | sweep `qa-reports/fuzzy-chat-hardening_SWEEP_2026-09-13/logs/bench_profile_runs.txt` |

Two honest notes on the table. The emulator spread in the 2.5 GB row is the emulator, not the core: the slow
encrypt runs are the ones whose pre-first-chunk phase (the 64 MiB Argon2id block being page-faulted while the
kernel reclaimed the just-written input) took 2–4 s; the same VM with 4 GB streams at 440–460 MB/s both ways.
And the Mac ceiling is ≈ 580 MB/s, not the > 1 GB/s an AEAD could reach: `chacha20` 0.10 uses its NEON backend
on aarch64 but `poly1305` 0.9 has only a portable backend there, and the brief forbids substituting or
hand-rolling primitives, so the tag is the ceiling. **No real-device Android number exists** — no hardware was
available; the emulator establishes ≥ 400 MB/s when unobstructed.

Other timings that matter to a user (all on release/profile builds, since a debug Flutter build ships the
crate's *dev* profile, whose Argon2id is many times slower): app-lock unlock (one Argon2id) 0.13 s on the Mac,
0.97–1.05 s on the emulator; **password change 260 ms on the Mac, 6.68 s on the emulator** — it is two Argon2id
runs by design (unwrap under the old password, wrap under the new), the acceptance for it is stated against a
real device or the Mac (owner decision D-9), and the overlay says "Re-securing your keys…" while it runs.

---

## 5. The product decisions — what the owner has and has not signed

The brief reserved one decision for the owner and the build surfaced a few more. They are quoted here as they
stand on 2026-09-13; the build never waited silently on any of them.

**D-1 · Plaintext at rest (the forward-secrecy trade-off) — decided 2026-09-13: (a) + per-chat key.** The ratchet makes every blob single-use:
decrypt once, on one device, never again. That is F-1 closed, and it collides with how people use this app —
they keep blobs in their inbox and paste an old one to read it again. Sent messages *must* be stored locally
regardless (an Olm sender cannot decrypt its own output). Two options were put to the owner: **(a)** store
received plaintext too, sealed with XChaCha20-Poly1305 under a per-install key protected by the app-lock
password (Isar 3 is not encrypted on its own — verified), plus the skipped-key window, a password-protected
archive export and plain UI copy that a new device cannot re-read old blobs; **(b)** received messages stay
ciphertext-only and history shows "unfuzzed once" placeholders. **The owner's answer (2026-09-13): GO on (a),
with each chat's history sealed under a key that belongs to that chat** — "derived from that chat's initial key
material, not the app-wide local key", as defence in depth, the app-lock password staying the outer gate.
Implemented as F2-12: a 32-byte history key is drawn from the CSPRNG together with the chat's Olm account
(`create_invitation` / `accept_invitation`), stored only inside that chat's sealed state file, and seals that
chat's rows with AAD `local-seal` ‖ chat id (`PROTOCOL.md` §3, §10.4). It is random-with-the-account rather
than HKDF-derived from the identity secret because vodozemac 0.10.0 exposes no accessor for that secret; the
effect the owner asked for — one chat's key opens no other chat's history, and A's and B's keys for one chat are
unrelated — holds. Stated plainly in `THREAT_MODEL.md` §4.3/§8/T13/R33: the per-chat key bounds a *history-key*
leak to one chat; a captured *store key* (or the app-lock password) still opens every state file and therefore
every history key, so the app lock remains the gate that matters. **Scope of the seal: text only.** An unfuzzed
*file* is delivered as an ordinary file at `<documents>/<chat name>/<original name>` (on desktop the user's
Documents folder) — not sealed, not gated by the app lock, not removed with the chat — because a file is
decrypted in order to be used outside the app; the database row holds its path. The About-encryption page and
the README say so (`THREAT_MODEL.md` §7.13, R36; `PROTOCOL.md` §10.5). **Built on this answer, both on
2026-09-13:** the password-protected **archive export** (F2-10 — "Export chat archive" in a chat's settings, a
password-mode `0x04` container of JSON lines that opens in Basics → file decryption, no import path, outside
forward secrecy by design; `PROTOCOL.md` §9.5, `THREAT_MODEL.md` R35) and the **trade-off copy** (F2-11 — an
onboarding slide, the chat-creation success notice, an About-encryption page and the README bullet, in English
and Georgian). D-1 is closed.

**D-2 · Safety number instead of vodozemac's emoji SAS — accepted by the owner 2026-09-13.**
vodozemac's `Sas` holds an in-memory ephemeral secret with no serialisation, so an inviter cannot keep it across
the days between invitation and acceptance; and in a two-blob flow with no commitment round a 7-emoji SAS is
grindable by an active MITM (≈ 2^42). The build ships a Signal-style 60-digit safety number over both
Ed25519 identity keys and the chat id, verifiable at any time, with a verification page and a shield indicator.
F-2 is closed either way. If the owner insists on emoji SAS: one extra blob plus a commitment step, an add-on.
Recorded as reversible. The owner's answer (2026-09-13): **safety number accepted**.

**Decisions applied without an owner answer being required** (recorded in the hardening flow's decision log):
D-4 (build fully, then one consolidated live QA sweep — applied), D-8 (opt out of OS backups — implemented,
§7), D-9 (password-change duration is by design — acceptance restated, progress copy added, §4).

**Owner/ops items that block nothing in the code but do block a store release** — §9.

---

## 6. Statements an auditor should hold us to

**No pure-Dart cryptography remains.** From the independent review of the deletion commit (`d4f7ce4`),
signed by the reviewer for inclusion here:

> As of commit `d4f7ce4` no cryptographic code is written in Dart anywhere in `lib/` or `test/`. Every
> primitive — Olm (vodozemac), ChaCha20-Poly1305 and STREAM, Argon2id, HKDF/SHA-2, constant-time comparison
> and the CSPRNG — executes in the Rust crate `fuzzy_crypto_core` and is reached only through the
> `flutter_rust_bridge` adapter `lib/src/core/encryption_services/crypto_core_service/*`; key material lives in
> opaque Rust handles and never crosses the bridge. The vendored PointyCastle fork (441 files), the
> AES/RSA/handshake/password-based services, the RSA key store (`KeysRepository`, `KeyStorageRepository`,
> `StoredChatSecurityData`), the HKDF constant `fuzzVersionInfo`, the `Random.secure()` helper and the 27 old
> tests were deleted, not wrapped, and an independent reviewer re-ran the greps: no crypto identifier,
> primitive name or `Random.secure` remains in code (the only hits are doc comments), `pointycastle` is absent
> from `pubspec.yaml` and `pubspec.lock`, and the `crypto` package is present only as a transitive dependency
> of the analyzer and `web_socket_channel`. What remains that touches secrets is not cryptography:
> `flutter_secure_storage` and `biometric_storage` are OS keystore wrappers holding Rust-wrapped blobs, `uuid`
> v4 produces identifiers, and `base64` encodes Rust output for transport. Nothing prevents signing this.

(The HKDF named in that statement was the store-derived local key of `d4f7ce4`. Since F2-12 the crate
derives no key with HKDF itself — the only HKDF in the core is inside vodozemac's ratchet — and the callerless
`hkdf` crate was removed from `Cargo.toml`, `Cargo.lock` and the SBOM in the closing pass; §2's crate table is
the current list.)

**A password change re-wraps; it never rotates a key.** Changing the app-lock password, enabling or disabling
the lock, or changing the vault password re-wraps the *same* 32-byte store key or vault master key under a new
Argon2id-derived key. Nothing is re-sealed and no re-key path exists in the crate or the app. A key that has
already left the device — a copy of the `0x10` blob wrapped under the empty string while the lock was off, or
the key read out of an unlocked process — stays valid after every later password change
(`THREAT_MODEL.md` R33). The only remedy for a suspected leak is to delete the chats and pair again.

**Post-compromise security needs a round trip.** Forward secrecy holds for everything already read: a
snapshot of a chat's sealed state taken after message N−1 cannot open N−1 or anything earlier. But the
snapshot holds the *receiving chain key*, so — together with the store key or the app-lock password — it opens
message N and every later message the peer generates on that chain. The copy stops working at the next
Diffie-Hellman ratchet step, which is a round trip: this device sends, the peer receives that message, and the
peer's next message is on a chain the copy never derived — **PCS heals on the peer's first message after it
has received our send.** Asserted in `api::messages::tests::forward_secrecy` (a restored snapshot opens a later
message on the same chain and gets `InvalidMAC` on the first one sent after the round trip);
`PROTOCOL.md` §14 point 3, `THREAT_MODEL.md` R32.

**The Rust core is reproducible; the Flutter app around it is not.** `rust-repro` builds the crate twice on two
independent GitHub runners (no shared cache) for `x86_64-unknown-linux-gnu` and `aarch64-linux-android` and
`rust-repro-compare` fails the workflow if any hash differs or a runner path survives in a binary
(`RELEASE.md` §4). Result as of run
[34722501385](https://github.com/fuzzzy-bot/fuzzy_chat/actions/runs/34722501385): **the Linux core
(`b13462d8…02f6`) and the Android core (`ad625a3a…2dd3`, after the Android Gradle plugin's
`llvm-strip --strip-debug`) are byte-identical on both runners and byte-identical to the cores shipped inside
the attested Linux bundle and the APK.** Two caveats, stated in full in `RELEASE.md` §5: at the `v1.0.0-rc.1`
tag itself the plain `cargo-ndk` rebuild of the Android core differed from the APK's by a SysV `.hash` section
(cargokit links with `--hash-style=both`) and the section-name table (the packaging strip) — the fix was to
build the rebuild the way cargokit and AGP do, established on the commits after the tag; and on the rc.1 tag run
the compare step's `diff` was `&&`-chained to an `echo` and could not have failed, so the rc.1 hashes rest on
the two runners' identical artifacts re-verified by an independent reviewer, not on the gate — the gate is
fixed on the next commit and a new `attest` step now extracts the shipped Linux and APK cores and fails a tag
run unless their hashes are in the rebuild's `SHA256SUMS`. The Flutter AOT output (`libapp.so`, the desktop
executables, the bundles) embeds build paths and ids and is not bit-for-bit reproducible today
(dart-lang/sdk#52506). Rebuilding the Android core from a macOS host gives a different binary — 17,159 bytes
spread over `.text`/`.rodata`/`.eh_frame`/`.gcc_except_table` at identical section sizes, plus an extra
`.comment` line from the darwin-hosted NDK clang (`RELEASE.md` §5); reproduce on Linux x86_64, which is what
CI uses.

**Every release artifact is hashed and attested; none is signed by us.** A `v*` tag run produces `SHA256SUMS`
over the APK, the Linux and Windows executables and crate libraries and the macOS zip, and
`actions/attest-build-provenance` signs a SLSA provenance statement for those six digests (Sigstore, keyless;
rc.1: [attestation 47099408](https://github.com/fuzzzy-bot/fuzzy_chat/attestations/47099408)). What that does
*not* prove: the **macOS app is unsigned and not notarized** (the Xcode project is signed for a team whose
certificate CI does not hold — owner decision D-3); the **Android APK is signed with a throwaway key generated
per run** (`CN=fuzzzy_ink CI throwaway`, validity 1 day) because the release build type refuses to build
without one — it installs and runs and is a faithful attested build of the commit, but it is **not a store
build** and cannot update an installation signed with the real key (owner decision D-6); **iOS is not built**;
Windows and Linux have no signing at all. Provenance says who built the bytes, not that the code is correct.

**Backups.** Since `6ecd9f1` the app opts out of OS and cloud backups on Android (`allowBackup="false"`,
`fullBackupContent`, `dataExtractionRules` for both cloud backup and device-to-device transfer, every domain
excluded) and on iOS/macOS (`NSURLIsExcludedFromBackupKey` on the Application Support directory that holds the
crypto store and the database, set at launch), and its keychain items are `ThisDeviceOnly`. Before that commit
an iOS backup was a usable, permanent copy of the store key (`THREAT_MODEL.md` §2.8, R34).

**What is pinned and checked.** `Cargo.lock` and `pubspec.lock` are committed and built `--locked`; Rust 1.98.1
and Flutter 3.41.7 are pinned; 19 byte-exact test vectors under `vectors/` (invitation, acceptance, message,
file container, password blob, wrapped keys, state file, safety number, …) are regenerated from fixed inputs
through the production code paths and compared in `cargo test`, so any dependency change that alters a byte
fails CI (`PROTOCOL.md` Appendix A); the two SBOMs (`sbom/rust.cdx.json`, 173 components; `sbom/flutter.cdx.json`,
203 components) are regenerated on every CI run and the run fails if they drift from the lock files; Dependabot
watches the cargo, pub and GitHub Actions ecosystems weekly — **except `flutter_rust_bridge`**, which is pinned
three ways (Rust crate, Dart package, the codegen that wrote `lib/rust_bridge/**`) and must move as one, so it is
excluded from Dependabot in both ecosystems and bumped by hand in lockstep with the codegen re-run; there is no
CI gate for codegen drift — a stale generated bridge is caught by the per-feature reviewer re-running the
generator, not by a job (`THREAT_MODEL.md` §9.3, R24). Test counts at the closing pass:
`cargo test --locked` 165, `flutter test` 256 (161 / 240 when this write-up was first drafted), both green on every push (CI matrix: rust, flutter-test,
android with a 16 KB page-size gate, linux, windows, macos, rust-repro ×2 + compare; `attest` on tags).

---

## 7. What was verified, and by whom

- **Per-feature review.** Every feature was built by one worker and reviewed on the diff by a different one
  (goldens, fuzz-style tamper tests, pattern conformance); the protocol specification
  and the threat model were additionally read cold by a security-auditor persona (20 attack vectors against the
  specification, every one answered in `PROTOCOL.md` or `THREAT_MODEL.md`).
- **Consolidated live QA sweep, 2026-09-13** (`qa-reports/fuzzy-chat-hardening_SWEEP_2026-09-13/` in the
  operating repository — 47 test cases, screenshots and logs, Android emulator + macOS): pairing on two
  devices, three-message exchange and history after relaunch, replay / own-blob / garbage / 64-behind window
  copy, safety number identical on both devices and the shield surviving relaunch, file round trip
  (md5-identical) with wrong-password, byte-flipped and truncated containers rejected leaving no output and no
  `.part`, a 40 MiB chat-mode container with atomic rename, vault create/lock/unlock/wrong-password/relaunch,
  Basics text and file paths, every route on both devices, 0 panics/unhandled exceptions across all logs,
  `flutter test` 233/233 and `cargo test` 161/161 at that tip. **Verdict: green with three non-blocking
  tickets**, all three fixed in commit `439357b` (a header overflow on a 55-character chat name, a vault
  snackbar that showed a raw enum name, and the password-change progress copy) and awaiting the sweep's
  re-verification.
- **Independent golden containers.** The STREAM container was cross-checked against a second implementation
  written from the specification (pycryptodome), pinning the nonce/counter/flag order, the AAD composition and
  the last-flag semantics.
- **CI on every push**, all platforms; the release candidate tag run
  [34720257592](https://github.com/fuzzzy-bot/fuzzy_chat/actions/runs/34720257592) was green on all ten jobs.

Not verified, stated plainly: no real Android hardware was available (all Android figures are emulator
figures); the macOS-recipient chat-file round trip and the macOS benchmark dialog were not walked (native
file picker undrivable headlessly); the biometric prompt was not exercised live (no enrolment on the
emulator; covered by a router test).

---

## 8. Deferred — with the reason each time

| Item | Why not now | Where it is tracked |
|---|---|---|
| **Post-quantum key agreement** | Olm is X25519-based; adding a hybrid ML-KEM step over the pairing exchange is a distinct protocol migration and should not be stacked on top of the Olm migration before that has been audited. The product's long-lived public ciphertext makes this matter *more* than for a transport messenger, which is exactly why it gets its own project. | `THREAT_MODEL.md` §7.9, R22; the next-milestone plan (internal `fuzzzy_ink_future_plans.md` §3) |
| **Formal verification of the handshake** (Tamarin) | An academic-collaboration-sized project; worth doing after the audit, not before. | future plans §4 |
| **iOS / App Store** | `ios/` builds but there is no store presence and no signing; ordinary store-readiness work, unrelated to the crypto (the chosen stack is Apache-2.0/MIT, so the AGPL/App Store question that libsignal would have raised does not arise). | future plans §5; `RELEASE.md` §2 |
| **Web build** | Unsupported: the core is native code and the trust boundary is the FFI; a web build would need a WASM port and a different key-storage story. | `THREAT_MODEL.md` §7.12 |
| **Sealing Isar metadata** (chat names, vault item titles, timestamps, file names) | The same `seal_local` call on more columns; a follow-up, not this build. Until then a device thief without the password learns *who* (as named), *when* and *how much* — never *what*. | `THREAT_MODEL.md` §7.4, R11 |
| **Olm's 8-byte MAC** | vodozemac's `SessionConfig::version_2()` (32-byte MAC) is behind its `experimental-session-config` feature and off by default; no forgery oracle exists here (every decrypt is a human paste). Listed as an audit question. | `THREAT_MODEL.md` §7.5, R6, R23 |
| **Olm-parity replay window** | The 63-behind counter rule is stricter than Olm's 40-skipped-keys-per-chain store; whether to widen it is a product decision, and the stricter rule is the safer default. | `THREAT_MODEL.md` §7.7; `PROTOCOL.md` §8.2 |
| **Multi-device, groups, key rotation, transport** | Out of the product's shape: one chat is one pair of devices, blobs move by hand. | `THREAT_MODEL.md` §7.12 |
| **The store key re-key path** | Would let a password change actually rotate keys; deliberately not built for this version — the honest statement is in §6. | `THREAT_MODEL.md` R33 |

---

## 9. Open items for the owner (none blocks the code; some block a store release)

| Id | What is needed | Blocks |
|---|---|---|
| **D-1** | **Answered 2026-09-13** — (a) with a per-chat history key, implemented (F2-12, §5); archive export (F2-10) and trade-off copy (F2-11) built on it. Closed. | — |
| **D-2** | **Answered 2026-09-13** — safety number accepted (§5). Closed. | — |
| **D-3** | **Answered 2026-09-13** — macOS signing moves to the owner's **Codemagic** pipeline; nothing on the build Mac. One item for that pipeline: add `com.apple.security.files.user-selected.read-write` to both macOS entitlements files (they carry `app-sandbox` without it), or a signed build cannot open the file picker or the archive save panel. | a signed, notarized macOS artifact (owner's pipeline) |
| **D-5** | **Answered yes 2026-09-13.** Private vulnerability reporting **enabled** (`365e8bd`). Still open: the `security@fuzzzycore.com` route (owner-only Cloudflare account — add the route or hand ops a scoped token; `contact@` stays advertised meanwhile) and the website's `security.txt` (written, `fuzzzy_core_website` PR #1, not yet deployed). | the mail route named in the policy |
| **D-6** | **Answered 2026-09-13** — the store build is signed by the owner at publish time (Codemagic); the GitHub release stays a throwaway-signed, attested side-load build. Closed for this build. | the store build (owner's pipeline) |
| **D-7** | **Answered 2026-09-13** — keep the chat id in message links; all three facts (chat id in links, biometric unlock keeps the password in the OS keystore, the chat store never auto-locks) are stated on the About-encryption page (F2-11). Closed. | — |
| **D-10** | **Answered 2026-09-13** — the hardened build ships as **`v1.1.0`** (`v1.0.0` is a 2025 tag of the old stack); `WHAT_CHANGED.md` is the before/after glossary the owner asked for alongside it. | the release name at merge |
| **ka review** | The Georgian copy added by F2-11 (19 strings; the About-encryption body was reworded again after review) has not had a native read — listed in the hardening flow's `HANDOFF.md`. | nothing in the code |

---

## 10. Where to look

| Question | Document |
|---|---|
| What exactly does the protocol do, byte for byte? | [`PROTOCOL.md`](PROTOCOL.md) — pairing, safety number, wire formats, inner header, windows, files, local state, password formats, versioning, trust boundaries, the forward-secrecy argument, crates, test vectors, error codes |
| What is and is not defended, against whom? | [`THREAT_MODEL.md`](THREAT_MODEL.md) — assets, trust boundaries per platform, adversaries, the threat table, the nine findings, explicit non-goals, the D-1 trade-off, supply chain, residual risks, what an audit should focus on |
| How is a release built, what is attested, how do I verify a download or reproduce the core? | [`RELEASE.md`](RELEASE.md) |
| How do I report a vulnerability? | [`../../SECURITY.md`](../../SECURITY.md), [`security.txt`](security.txt) |
| What is in the binaries? | [`sbom/rust.cdx.json`](sbom/rust.cdx.json), [`sbom/flutter.cdx.json`](sbom/flutter.cdx.json) |
| Can I check a layout independently? | [`vectors/README.md`](vectors/README.md) |
