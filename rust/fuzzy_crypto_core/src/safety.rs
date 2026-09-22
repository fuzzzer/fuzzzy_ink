//! Safety number and the verified flag (plan §B.3, finding F-2).
//!
//! After the handshake both sides hold the same two Ed25519 identity keys — the
//! exact keys that authenticate the 3DH — so a fingerprint over them (and the
//! chat id) is identical on both sides and comparable at any time, by voice or
//! in person. Signal's `DisplayableFingerprint` encoding: 5-byte big-endian
//! chunks of the digest, each `mod 100000`, zero-padded to 5 digits. Nothing
//! here is secret and no ephemeral state is involved; the only decision this
//! module records is the user's "I compared them" (`ChatState::verified`).
//!
//! Pure functions over [`ChatState`] — no I/O. The API layer (`api/safety.rs`)
//! persists the flag through `OpenStore::with_state_mut`.

use sha2::{Digest, Sha512};

use crate::error::CoreError;
use crate::state::ChatState;

/// Domain separator of the digest; the version suffix is the format version.
const DOMAIN: &[u8] = b"FUZZZYINK_SAFETY_NUMBER_V1";
/// 12 groups × 5 digits = 60 digits (~199 bits of the 512-bit digest).
const GROUPS: usize = 12;
/// Each group is read from 5 digest bytes (< 2^40, so the `u64` never overflows).
const GROUP_BYTES: usize = 5;
const GROUP_MODULUS: u64 = 100_000;

/// The 60-digit safety number for `chat_id` over two identity keys, as
/// `"12345 67890 …"` (12 groups, single spaces). The keys are sorted into
/// lexicographic byte order first, so both parties compute the same digits
/// regardless of which side they are on.
pub fn safety_number_for(chat_id: &str, key_1: &[u8; 32], key_2: &[u8; 32]) -> String {
    let (low, high) = if key_1 <= key_2 {
        (key_1, key_2)
    } else {
        (key_2, key_1)
    };
    let mut hasher = Sha512::new();
    hasher.update(DOMAIN);
    hasher.update([0u8]);
    hasher.update(chat_id.as_bytes());
    hasher.update([0u8]);
    hasher.update(low);
    hasher.update(high);
    let digest = hasher.finalize();

    let (chunks, _unused_tail) = digest.as_chunks::<GROUP_BYTES>();
    chunks
        .iter()
        .take(GROUPS)
        .map(|chunk| {
            let value = chunk
                .iter()
                .fold(0u64, |acc, byte| (acc << 8) | u64::from(*byte));
            format!("{:05}", value % GROUP_MODULUS)
        })
        .collect::<Vec<_>>()
        .join(" ")
}

/// The chat's safety number; `UnknownChat` until the peer's identity key is
/// known (an inviter still waiting for the acceptance has nothing to compare).
pub fn safety_number(state: &ChatState) -> Result<String, CoreError> {
    let peer_ed25519 = state.peer_ed25519.ok_or(CoreError::UnknownChat)?;
    Ok(safety_number_for(
        &state.chat_id,
        &state.our_ed25519,
        &peer_ed25519,
    ))
}

/// Records whether the user compared the digits. Refused (`UnknownChat`) while
/// there is no peer key: a flag set before the pairing would otherwise survive
/// `complete_handshake`, which fills the peer key into the same state in place,
/// and vouch for a peer nobody has seen yet.
pub fn mark_verified(state: &mut ChatState, verified: bool) -> Result<(), CoreError> {
    if state.peer_ed25519.is_none() {
        return Err(CoreError::UnknownChat);
    }
    state.verified = verified;
    Ok(())
}

#[cfg(test)]
mod tests {
    mod safety_number {
        use crate::safety::safety_number_for;

        const CHAT_X: &str = "6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d";
        const CHAT_Y: &str = "0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d";

        /// `00 01 … 1f` — sorts first.
        fn key_a() -> [u8; 32] {
            let mut key = [0u8; 32];
            for (index, byte) in key.iter_mut().enumerate() {
                *byte = index as u8;
            }
            key
        }

        /// `ff fe … e0` — sorts last.
        fn key_b() -> [u8; 32] {
            let mut key = [0u8; 32];
            for (index, byte) in key.iter_mut().enumerate() {
                *byte = 0xff - index as u8;
            }
            key
        }

        /// `^\d{5}( \d{5}){11}$` without a regex crate.
        fn is_well_formed(number: &str) -> bool {
            let groups: Vec<&str> = number.split(' ').collect();
            groups.len() == 12
                && groups
                    .iter()
                    .all(|group| group.len() == 5 && group.bytes().all(|b| b.is_ascii_digit()))
        }

        /// Pinned from PROTOCOL.md §5 by an independent implementation (python
        /// `hashlib`, scratchpad `golden_ink.py` — never from this crate) for
        /// `CHAT_X` and the two fixed keys above.
        const GOLDEN: &str =
            "77854 71920 59655 43036 43670 32437 81099 92950 15670 73365 44425 64132";

        #[test]
        fn golden() {
            assert_eq!(safety_number_for(CHAT_X, &key_a(), &key_b()), GOLDEN);
            // The sort makes the order of the arguments irrelevant.
            assert_eq!(safety_number_for(CHAT_X, &key_b(), &key_a()), GOLDEN);
        }

        #[test]
        fn format() {
            let number = safety_number_for(CHAT_X, &key_a(), &key_b());
            assert_eq!(number.len(), 60 + 11);
            assert!(is_well_formed(&number), "{number}");
            // Zero-padding is pinned by the `05772` group in `changes_with_either_key`.
        }

        #[test]
        fn changes_with_either_key() {
            let mut a_flipped = key_a();
            a_flipped[0] ^= 0x01;
            let mut b_flipped = key_b();
            b_flipped[31] = 0x00;
            assert_eq!(
                safety_number_for(CHAT_X, &a_flipped, &key_b()),
                "13690 27442 64231 84405 12670 18278 89890 97745 53804 71814 57421 09264"
            );
            assert_eq!(
                safety_number_for(CHAT_X, &key_a(), &b_flipped),
                "60953 62734 80082 05772 31738 09599 75752 10469 95036 61569 13865 34898"
            );
        }

        #[test]
        fn changes_with_chat_id() {
            assert_eq!(
                safety_number_for(CHAT_Y, &key_a(), &key_b()),
                "25991 71854 84013 76256 64546 75321 84213 77751 07033 33610 09869 10002"
            );
        }
    }
}
