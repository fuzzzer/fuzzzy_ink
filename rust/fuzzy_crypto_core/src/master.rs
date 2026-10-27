//! The master key: one random 32-byte key above every other key on the device
//! (owner, 2026-10-25: "user password locks all keys. keys lock messages").
//!
//! It is never stored in the clear and never used to seal data. It exists
//! wrapped twice — under the master password and under the printable recovery
//! key (two 0x10 blobs, two AAD domains) — and only wraps the keys below it
//! (0x20 blobs under the master key itself): the store key, which opens the
//! chats, and, by default, the vault key, which opens the vault. Neither of
//! those opens the other's data, and neither opens the master key.
//!
//! A master-password change re-wraps the master key only, so it is one blob
//! and one write; nothing below it changes.
//!
//! The recovery key also gives a **recovery lock**: an X25519 key pair whose
//! secret half is derived from the recovery key alone. The app keeps only the
//! public half (sealed under the store key, so it cannot be swapped). A vault
//! with its own password has its key sealed to that lock as well (a 0x11
//! blob): anyone can seal to the lock, only the recovery key opens it. The
//! master password reaches the public half only, so it still does not open
//! such a vault; the recovery key does (owner, 2026-10-26).

use sha2::{Digest, Sha256};
use vodozemac::{Curve25519PublicKey, Curve25519SecretKey};
use zeroize::Zeroizing;

use crate::error::CoreError;
use crate::formats::{LocalSeal, RecoveryBox};
use crate::store::{self, Key32};

/// AAD of the master key wrapped under the master password (0x10).
const MASTER_KEY_AAD: &[u8] = b"master-key";
/// AAD of the master key wrapped under the recovery key (0x10).
const MASTER_KEY_RECOVERY_AAD: &[u8] = b"master-key-recovery";
/// AAD of the store key wrapped under the master key (0x20).
pub(crate) const STORE_KEY_WRAP_AAD: &[u8] = b"store-key-wrap";
/// AAD of the vault key wrapped under the master key (0x20).
pub(crate) const VAULT_KEY_WRAP_AAD: &[u8] = b"vault-key-wrap";
/// AAD of the recovery lock sealed under the store key (0x20).
pub(crate) const RECOVERY_LOCK_AAD: &[u8] = b"recovery-lock";
/// Domain of the recovery lock's X25519 secret, derived from the recovery key.
const RECOVERY_LOCK_DOMAIN: &[u8] = b"fuzzy-recovery-lock-v1";
/// Domain of a recovery box's AEAD key, derived from the X25519 shared secret.
const RECOVERY_BOX_DOMAIN: &[u8] = b"fuzzy-recovery-box-v1";

/// Random bytes in a recovery key: 152 bits.
const RECOVERY_RANDOM_LEN: usize = 19;
/// The random bytes plus one check byte — what the KDF reads.
const RECOVERY_KEY_LEN: usize = RECOVERY_RANDOM_LEN + 1;
/// 20 bytes = 160 bits = 32 base32 characters, no padding.
const RECOVERY_TEXT_LEN: usize = 32;
const RECOVERY_GROUP_LEN: usize = 4;
/// RFC 4648 base32: upper-case letters and 2–7 (no 0, 1, 8 or 9 to misread).
const BASE32_ALPHABET: &[u8; 32] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
/// Domain of the check byte, so it is not a bare hash of the key.
const RECOVERY_CHECK_DOMAIN: &[u8] = b"fuzzy-recovery-check-v1";

/// A fresh random 32-byte key (master, store or vault key).
pub fn new_key() -> Result<Key32, CoreError> {
    let mut key = Zeroizing::new([0u8; 32]);
    store::fill_random(key.as_mut())?;
    Ok(key)
}

// ---------------------------------------------------------------------------
// The master key under the master password (0x10)
// ---------------------------------------------------------------------------

/// Wraps `master` under `password` with a fresh salt and nonce. The master
/// password cannot be empty: there is no "lock off" wrapping any more.
pub fn wrap_with_password(master: &[u8; 32], password: &[u8]) -> Result<Vec<u8>, CoreError> {
    wrap_with_password_with(
        master,
        password,
        store::random_array()?,
        store::random_array()?,
    )
}

/// [`wrap_with_password`] with the randomness supplied — the golden test pins its output.
pub(crate) fn wrap_with_password_with(
    master: &[u8; 32],
    password: &[u8],
    salt: [u8; 16],
    nonce: [u8; 24],
) -> Result<Vec<u8>, CoreError> {
    refuse_empty(password)?;
    store::wrap_key_with(master, password, MASTER_KEY_AAD, salt, nonce)
}

/// Inverse of [`wrap_with_password`]; a wrong password or a tampered blob is
/// `WrongPassword` — the wrapped key is the password's only verifier.
pub fn unwrap_with_password(blob: &[u8], password: &[u8]) -> Result<Key32, CoreError> {
    store::unwrap_key(blob, password, MASTER_KEY_AAD)
}

/// An empty password is never the right one for a key: it is refused before
/// any Argon2 run.
pub(crate) fn refuse_empty(password: &[u8]) -> Result<(), CoreError> {
    if password.is_empty() {
        Err(CoreError::WrongPassword)
    } else {
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// The recovery key and the master key under it (0x10)
// ---------------------------------------------------------------------------

/// The printable recovery key: 19 random bytes and one check byte, shown as
/// 32 base32 characters in eight groups of four (`ABCD-EFGH-…`). It is a
/// second password for the master key, drawn by the crate, so its strength
/// does not depend on the user.
pub struct RecoveryKey(Zeroizing<[u8; RECOVERY_KEY_LEN]>);

impl RecoveryKey {
    /// Draws a new recovery key from the OS CSPRNG.
    pub fn generate() -> Result<Self, CoreError> {
        let mut bytes = Zeroizing::new([0u8; RECOVERY_KEY_LEN]);
        store::fill_random(&mut bytes[..RECOVERY_RANDOM_LEN])?;
        Ok(Self::from_random(bytes))
    }

    /// Fills the check byte of `bytes` (its first 19 bytes are the key).
    fn from_random(mut bytes: Zeroizing<[u8; RECOVERY_KEY_LEN]>) -> Self {
        bytes[RECOVERY_RANDOM_LEN] = check_byte(&bytes[..RECOVERY_RANDOM_LEN]);
        Self(bytes)
    }

    /// The text the user writes down: `XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX`.
    pub fn text(&self) -> Zeroizing<String> {
        let mut text = Zeroizing::new(String::with_capacity(
            RECOVERY_TEXT_LEN + RECOVERY_TEXT_LEN / RECOVERY_GROUP_LEN,
        ));
        let mut buffer: u64 = 0;
        let mut bits = 0;
        let mut written = 0;
        for byte in self.0.iter() {
            buffer = (buffer << 8) | u64::from(*byte);
            bits += 8;
            while bits >= 5 {
                bits -= 5;
                if written > 0 && written % RECOVERY_GROUP_LEN == 0 {
                    text.push('-');
                }
                text.push(char::from(
                    BASE32_ALPHABET[((buffer >> bits) & 0x1f) as usize],
                ));
                written += 1;
            }
        }
        text
    }

    /// Reads a recovery key the user typed. Case, spaces, dashes and line
    /// breaks are ignored, and the look-alikes `0`, `1` and `8` read as `O`,
    /// `I` and `B`. Anything that is not 32 base32 characters with a matching
    /// check byte is `Corrupt` — a typo, told apart from a key that does not
    /// open this device (`WrongPassword` at unwrap).
    pub fn parse(text: &str) -> Result<Self, CoreError> {
        let mut bytes = Zeroizing::new([0u8; RECOVERY_KEY_LEN]);
        let mut buffer: u64 = 0;
        let mut bits = 0;
        let mut read = 0;
        let mut written = 0;
        for character in text.chars() {
            if character.is_whitespace() || character == '-' {
                continue;
            }
            let character = match character.to_ascii_uppercase() {
                '0' => 'O',
                '1' => 'I',
                '8' => 'B',
                other => other,
            };
            let value = BASE32_ALPHABET
                .iter()
                .position(|&symbol| char::from(symbol) == character)
                .ok_or(CoreError::Corrupt)?;
            read += 1;
            if read > RECOVERY_TEXT_LEN {
                return Err(CoreError::Corrupt);
            }
            buffer = (buffer << 5) | value as u64;
            bits += 5;
            if bits >= 8 {
                bits -= 8;
                bytes[written] = ((buffer >> bits) & 0xff) as u8;
                written += 1;
            }
        }
        if read != RECOVERY_TEXT_LEN {
            return Err(CoreError::Corrupt);
        }
        if bytes[RECOVERY_RANDOM_LEN] != check_byte(&bytes[..RECOVERY_RANDOM_LEN]) {
            return Err(CoreError::Corrupt);
        }
        Ok(Self(bytes))
    }

    fn as_password(&self) -> &[u8] {
        self.0.as_slice()
    }

    /// The recovery lock's secret half: `X9.63-KDF(the 20 bytes,
    /// "fuzzy-recovery-lock-v1")` as an X25519 scalar. The recovery key is 152
    /// random bits drawn by the crate, so a hash KDF is enough here (no
    /// Argon2: there is nothing to stretch).
    fn lock_secret(&self) -> Curve25519SecretKey {
        let seed = kdf_x963(self.0.as_slice(), &[RECOVERY_LOCK_DOMAIN]);
        Curve25519SecretKey::from_slice(&seed)
    }

    /// The recovery lock: the public half, which the app keeps so a key can be
    /// sealed for recovery without the recovery key at hand.
    pub fn lock(&self) -> [u8; 32] {
        Curve25519PublicKey::from(&self.lock_secret()).to_bytes()
    }
}

/// ANSI X9.63 / SEC 1 §3.6.1 key derivation with SHA-256, one output block:
/// `SHA-256(z ‖ 00 00 00 01 ‖ shared_info)`, the parts of `shared_info`
/// concatenated.
fn kdf_x963(z: &[u8], shared_info: &[&[u8]]) -> Key32 {
    let mut hasher = Sha256::new();
    hasher.update(z);
    hasher.update(1u32.to_be_bytes());
    for part in shared_info {
        hasher.update(part);
    }
    let mut key = Zeroizing::new([0u8; 32]);
    key.copy_from_slice(&hasher.finalize());
    key
}

fn check_byte(random: &[u8]) -> u8 {
    let mut hasher = Sha256::new();
    hasher.update(RECOVERY_CHECK_DOMAIN);
    hasher.update(random);
    hasher.finalize()[0]
}

/// Wraps `master` under the recovery key (Argon2id over its 20 bytes — the
/// same 0x10 construction as the password wrap, its own AAD).
pub fn wrap_with_recovery(master: &[u8; 32], recovery: &RecoveryKey) -> Result<Vec<u8>, CoreError> {
    wrap_with_recovery_with(
        master,
        recovery,
        store::random_array()?,
        store::random_array()?,
    )
}

/// [`wrap_with_recovery`] with the randomness supplied — the tests pin its output.
pub(crate) fn wrap_with_recovery_with(
    master: &[u8; 32],
    recovery: &RecoveryKey,
    salt: [u8; 16],
    nonce: [u8; 24],
) -> Result<Vec<u8>, CoreError> {
    store::wrap_key_with(
        master,
        recovery.as_password(),
        MASTER_KEY_RECOVERY_AAD,
        salt,
        nonce,
    )
}

/// Inverse of [`wrap_with_recovery`]; a recovery key of another device (or a
/// tampered blob) is `WrongPassword`.
pub fn unwrap_with_recovery(blob: &[u8], recovery: &RecoveryKey) -> Result<Key32, CoreError> {
    store::unwrap_key(blob, recovery.as_password(), MASTER_KEY_RECOVERY_AAD)
}

// ---------------------------------------------------------------------------
// Keys sealed to the recovery lock (0x11)
// ---------------------------------------------------------------------------

/// The box key: `X9.63-KDF(X25519(ephemeral, lock), "fuzzy-recovery-box-v1" ‖
/// ephemeral public ‖ lock)`. Both public keys are bound, so a box opens only
/// for the lock it was made for.
fn box_key(shared: &[u8; 32], ephemeral: &[u8; 32], lock: &[u8; 32]) -> Key32 {
    kdf_x963(shared, &[RECOVERY_BOX_DOMAIN, ephemeral, lock])
}

/// Seals a 32-byte `key` to the recovery `lock` (a 0x11 blob) with a fresh
/// ephemeral key and nonce; `aad` names the key's role. Needs no secret: the
/// lock is public.
pub fn seal_to_lock(lock: &[u8; 32], key: &[u8; 32], aad: &[u8]) -> Result<Vec<u8>, CoreError> {
    let mut ephemeral = Zeroizing::new([0u8; 32]);
    store::fill_random(ephemeral.as_mut())?;
    seal_to_lock_with(lock, key, aad, &ephemeral, store::random_array()?)
}

/// [`seal_to_lock`] with the randomness supplied — the test vectors pin its output.
pub(crate) fn seal_to_lock_with(
    lock: &[u8; 32],
    key: &[u8; 32],
    aad: &[u8],
    ephemeral_secret: &[u8; 32],
    nonce: [u8; 24],
) -> Result<Vec<u8>, CoreError> {
    let secret = Curve25519SecretKey::from_slice(ephemeral_secret);
    let ephemeral = Curve25519PublicKey::from(&secret).to_bytes();
    // A low-order lock gives no shared secret: `Corrupt`, never a box under zeros.
    let shared = secret
        .diffie_hellman(&Curve25519PublicKey::from_bytes(*lock))
        .ok_or(CoreError::Corrupt)?;
    let box_key = box_key(shared.as_bytes(), &ephemeral, lock);
    let ciphertext = store::seal(&box_key, &nonce, aad, key)?
        .try_into()
        .map_err(|_| CoreError::Internal)?;
    Ok(RecoveryBox {
        ephemeral,
        nonce,
        ciphertext,
    }
    .encode())
}

/// Inverse of [`seal_to_lock`] with the recovery key that made the lock. A
/// recovery key of another device, another role or a tampered blob is
/// `WrongPassword` — like the recovery wrap, a failed tag cannot tell them
/// apart.
pub fn open_with_recovery(
    blob: &[u8],
    recovery: &RecoveryKey,
    aad: &[u8],
) -> Result<Key32, CoreError> {
    let sealed = RecoveryBox::decode(blob)?;
    let secret = recovery.lock_secret();
    let lock = Curve25519PublicKey::from(&secret).to_bytes();
    let shared = secret
        .diffie_hellman(&Curve25519PublicKey::from_bytes(sealed.ephemeral))
        .ok_or(CoreError::WrongPassword)?;
    let box_key = box_key(shared.as_bytes(), &sealed.ephemeral, &lock);
    let plain = Zeroizing::new(
        store::open(&box_key, &sealed.nonce, aad, &sealed.ciphertext)
            .map_err(|_| CoreError::WrongPassword)?,
    );
    let mut key = Zeroizing::new([0u8; 32]);
    if plain.len() != key.len() {
        return Err(CoreError::Corrupt);
    }
    key.copy_from_slice(&plain);
    Ok(key)
}

// ---------------------------------------------------------------------------
// Keys under the master key (0x20)
// ---------------------------------------------------------------------------

/// Wraps a 32-byte `key` under `master` with a fresh nonce; `aad` names the
/// key's role (`store-key-wrap`, `vault-key-wrap`).
pub fn wrap_key(master: &[u8; 32], key: &[u8; 32], aad: &[u8]) -> Result<Vec<u8>, CoreError> {
    wrap_key_with(master, key, aad, store::random_array()?)
}

/// [`wrap_key`] with the nonce supplied — the test vectors pin its output.
pub(crate) fn wrap_key_with(
    master: &[u8; 32],
    key: &[u8; 32],
    aad: &[u8],
    nonce: [u8; 24],
) -> Result<Vec<u8>, CoreError> {
    let ciphertext = store::seal(master, &nonce, aad, key)?;
    Ok(LocalSeal { nonce, ciphertext }.encode())
}

/// Inverse of [`wrap_key`] under the same role. A tag failure — another
/// master key, another role, a tampered blob — or a plaintext that is not 32
/// bytes is `Corrupt`.
pub fn unwrap_key(master: &[u8; 32], blob: &[u8], aad: &[u8]) -> Result<Key32, CoreError> {
    let sealed = LocalSeal::decode(blob)?;
    let plain = Zeroizing::new(store::open(master, &sealed.nonce, aad, &sealed.ciphertext)?);
    let mut key = Zeroizing::new([0u8; 32]);
    if plain.len() != key.len() {
        return Err(CoreError::Corrupt);
    }
    key.copy_from_slice(&plain);
    Ok(key)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::formats::{Argon2Params, WrappedStoreKey, WRAPPED_STORE_KEY_CT_LEN};

    const PASSWORD: &[u8] = b"pw";
    const MASTER: [u8; 32] = [0x33; 32];
    const STORE_KEY: [u8; 32] = [0x66; 32];

    /// XChaCha20-Poly1305 under `Argon2id(pw, salt 0x11×16, m 65536, t 4, p 1)`
    /// (the `argon2id_kek` vector), nonce 0x22×24, AAD `master-key`, plaintext
    /// the master key 0x33×32 — computed with pycryptodome from the spec, not
    /// with this crate (`wrapped_master_key` vector).
    const GOLDEN_MASTER_WRAP_HEX: &str = concat!(
        "46555a5a0110",
        "11111111111111111111111111111111",
        "000100000000000401",
        "222222222222222222222222222222222222222222222222",
        "ca92d2caa5a5120ca9b162dab36620db05f2829d86e6df4fefe299cbb96637a4",
        "bfdf3e494aedeac363025f68c9189653",
    );
    /// XChaCha20-Poly1305(master 0x33×32, nonce 0x44×24, AAD `store-key-wrap`,
    /// store key 0x66×32) — pycryptodome (`store_key_wrap` vector).
    const GOLDEN_STORE_WRAP_HEX: &str = concat!(
        "46555a5a0120",
        "444444444444444444444444444444444444444444444444",
        "7ec016b2568451e5f4162d7876b1a4c15864845e46b4212763d6b135d4612065",
        "e2b380c30b92469981d71705ff383157",
    );

    /// The recovery lock of [`fixed_recovery`]: X25519 base-point multiple of
    /// `SHA-256(the 20 bytes ‖ 00000001 ‖ "fuzzy-recovery-lock-v1")` — pure-Python
    /// RFC 7748 ladder, not this crate (`recovery_lock` vector).
    const GOLDEN_LOCK_HEX: &str =
        "e6aa01cec0ac127010f47c597affce66b8c419f862f40f6674a35dc16f5ada77";
    /// The vault key 0x33×32 sealed to [`GOLDEN_LOCK_HEX`] with the ephemeral
    /// secret 0x55×32, nonce 0x22×24, AAD `vault-key-recovery` — pure-Python
    /// X25519, hashlib and pycryptodome XChaCha20-Poly1305 (`vault_key_recovery`
    /// vector).
    const GOLDEN_BOX_HEX: &str = concat!(
        "46555a5a0111",
        "38ab664bd86f77d7e66bdd9ae0792913a94fd8b33a1260027e4b46c1f4884c67",
        "222222222222222222222222222222222222222222222222",
        "ac77d0cda55e9b7273d7809ab066b80ed64df03144316b591f20ac10299cc041",
        "37372c3bd0205eb8126b61e49624cbba",
    );
    const BOX_AAD: &[u8] = b"vault-key-recovery";

    fn hex(text: &str) -> Vec<u8> {
        (0..text.len())
            .step_by(2)
            .map(|index| u8::from_str_radix(&text[index..index + 2], 16).unwrap())
            .collect()
    }

    fn fixed_recovery() -> RecoveryKey {
        let mut bytes = Zeroizing::new([0u8; RECOVERY_KEY_LEN]);
        for (index, byte) in bytes[..RECOVERY_RANDOM_LEN].iter_mut().enumerate() {
            *byte = index as u8;
        }
        RecoveryKey::from_random(bytes)
    }

    mod password {
        use super::*;

        #[test]
        fn wrong_password_rejected() {
            let blob = wrap_with_password(&MASTER, PASSWORD).unwrap();

            assert_eq!(
                unwrap_with_password(&blob, b"px").unwrap_err(),
                CoreError::WrongPassword
            );
            assert_eq!(
                unwrap_with_password(&blob, b"").unwrap_err(),
                CoreError::WrongPassword
            );
            assert_eq!(*unwrap_with_password(&blob, PASSWORD).unwrap(), MASTER);
        }

        #[test]
        fn empty_password_is_refused() {
            assert_eq!(
                wrap_with_password(&MASTER, b"").unwrap_err(),
                CoreError::WrongPassword
            );
        }

        #[test]
        fn tampered_blob_is_wrong_password_not_a_panic() {
            let blob = wrap_with_password(&MASTER, PASSWORD).unwrap();

            // One byte of the salt, the nonce, the ciphertext and the tag (the Argon2
            // parameter bytes are a different KDF, not a tag failure — covered below).
            for index in [6, 31, 55, 102] {
                let mut tampered = blob.clone();
                tampered[index] ^= 0x01;
                assert_eq!(
                    unwrap_with_password(&tampered, PASSWORD).unwrap_err(),
                    CoreError::WrongPassword,
                    "byte {index}"
                );
            }
        }

        #[test]
        fn rewrap_round_trip() {
            let old_blob = wrap_with_password(&MASTER, PASSWORD).unwrap();
            let key = unwrap_with_password(&old_blob, PASSWORD).unwrap();
            let new_blob = wrap_with_password(&key, b"new").unwrap();

            assert_ne!(old_blob, new_blob, "fresh salt and nonce every time");
            assert_eq!(
                unwrap_with_password(&old_blob, b"new").unwrap_err(),
                CoreError::WrongPassword
            );
            assert_eq!(*unwrap_with_password(&new_blob, b"new").unwrap(), MASTER);
            assert_eq!(
                unwrap_with_password(&new_blob, PASSWORD).unwrap_err(),
                CoreError::WrongPassword
            );
        }

        #[test]
        fn wrapped_blob_format_exact_bytes() {
            let golden = hex(GOLDEN_MASTER_WRAP_HEX);

            let blob = wrap_with_password_with(&MASTER, PASSWORD, [0x11; 16], [0x22; 24]).unwrap();

            assert_eq!(blob.len(), 103);
            assert_eq!(blob, golden);
            assert_eq!(*unwrap_with_password(&golden, PASSWORD).unwrap(), MASTER);
        }

        #[test]
        fn foreign_or_broken_blobs_are_errors_not_panics() {
            let blob = wrap_with_password(&MASTER, PASSWORD).unwrap();

            let sealed = wrap_key(&MASTER, &STORE_KEY, STORE_KEY_WRAP_AAD).unwrap();
            assert_eq!(
                unwrap_with_password(&sealed, PASSWORD).unwrap_err(),
                CoreError::UnsupportedFormat
            );
            assert_eq!(
                unwrap_with_password(&blob[..blob.len() - 1], PASSWORD).unwrap_err(),
                CoreError::Corrupt
            );
            assert_eq!(
                unwrap_with_password(&[], PASSWORD).unwrap_err(),
                CoreError::UnsupportedFormat
            );
            // An absurd memory cost in the header is refused before any allocation.
            let mut huge = blob.clone();
            huge[22..26].copy_from_slice(&u32::MAX.to_be_bytes());
            assert_eq!(
                unwrap_with_password(&huge, PASSWORD).unwrap_err(),
                CoreError::Corrupt
            );
            let mut zero_lanes = blob.clone();
            zero_lanes[30] = 0;
            assert_eq!(
                unwrap_with_password(&zero_lanes, PASSWORD).unwrap_err(),
                CoreError::Corrupt
            );
        }

        #[test]
        fn tightened_header_caps_reject_oversized_argon2_params() {
            let make = |m_cost: u32, t_cost: u32| {
                WrappedStoreKey {
                    salt: [0x11; 16],
                    params: Argon2Params {
                        m_cost,
                        t_cost,
                        p_cost: 1,
                    },
                    nonce: [0x22; 24],
                    ciphertext: [0; WRAPPED_STORE_KEY_CT_LEN],
                }
                .encode()
            };

            // 256 MiB and 16 passes are the ceilings for an attacker-controlled
            // header (F2-2 review R2); one past either is `Corrupt`, refused
            // before a single Argon2 block is allocated.
            assert_eq!(
                unwrap_with_password(&make((256 * 1024) + 1, 1), PASSWORD).unwrap_err(),
                CoreError::Corrupt
            );
            assert_eq!(
                unwrap_with_password(&make(1024, 17), PASSWORD).unwrap_err(),
                CoreError::Corrupt
            );
        }
    }

    mod recovery {
        use super::*;

        #[test]
        fn text_is_eight_groups_of_four_base32_characters() {
            let text = fixed_recovery().text();
            // 0x00 0x01 … 0x12 ‖ check byte, RFC 4648 base32, grouped by four.
            assert_eq!(text.as_str(), "AAAQ-EAYE-AUDA-OCAJ-BIFQ-YDIO-B4IB-CEQZ");
            for _ in 0..32 {
                let key = RecoveryKey::generate().unwrap();
                let text = key.text();
                assert_eq!(text.len(), 39);
                assert!(text
                    .chars()
                    .all(|character| character == '-'
                        || BASE32_ALPHABET.contains(&(character as u8))));
                assert_eq!(*RecoveryKey::parse(&text).unwrap().0, *key.0);
            }
        }

        #[test]
        fn parse_forgives_case_spacing_and_look_alikes() {
            let key = fixed_recovery();
            for typed in [
                "AAAQ-EAYE-AUDA-OCAJ-BIFQ-YDIO-B4IB-CEQZ",
                "aaaq eaye auda ocaj bifq ydio b4ib ceqz",
                "AAAQEAYEAUDAOCAJBIFQYDIOB4IBCEQZ",
                "aaaq-eaye-auda-ocaj-8ifq-ydio-84ib-ceqz\n",
                "AAAQ-EAYE-AUDA-0CAJ-BIFQ-YDI0-B4IB-CEQZ",
            ] {
                assert_eq!(*RecoveryKey::parse(typed).unwrap().0, *key.0, "{typed:?}");
            }
        }

        #[test]
        fn typos_and_wrong_lengths_are_corrupt() {
            for typed in [
                "",
                "AAAQ-EAYE-AUDA-OCAJ-BIFQ-YDIO-B4IB-CEQ",
                "AAAQ-EAYE-AUDA-OCAJ-BIFQ-YDIO-B4IB-CEQZA",
                "AAAQ-EAYE-AUDA-OCAJ-BIFQ-YDIO-B4IB-CEQY",
                "BAAQ-EAYE-AUDA-OCAJ-BIFQ-YDIO-B4IB-CEQZ",
                "AAAQ-EAYE-AUDA-OCAJ-BIFQ-YDIO-B4IB-CEQ9",
                "AAAQ_EAYE-AUDA-OCAJ-BIFQ-YDIO-B4IB-CEQZ",
            ] {
                assert_eq!(
                    RecoveryKey::parse(typed).err(),
                    Some(CoreError::Corrupt),
                    "{typed:?}"
                );
            }
        }

        #[test]
        fn recovery_wrap_opens_only_with_its_key_and_role() {
            let key = RecoveryKey::generate().unwrap();
            let blob = wrap_with_recovery(&MASTER, &key).unwrap();
            assert_eq!(blob.len(), 103);
            assert_eq!(*unwrap_with_recovery(&blob, &key).unwrap(), MASTER);

            let other = RecoveryKey::generate().unwrap();
            assert_eq!(
                unwrap_with_recovery(&blob, &other).unwrap_err(),
                CoreError::WrongPassword
            );
            // The same bytes as a password under the password role do not open it.
            assert_eq!(
                unwrap_with_password(&blob, key.as_password()).unwrap_err(),
                CoreError::WrongPassword
            );
            let password_blob = wrap_with_password(&MASTER, key.as_password()).unwrap();
            assert_eq!(
                unwrap_with_recovery(&password_blob, &key).unwrap_err(),
                CoreError::WrongPassword
            );
        }

        #[test]
        fn recovery_wrap_differs_from_password_wrap_only_in_the_tag() {
            let key = fixed_recovery();
            let recovery = wrap_with_recovery_with(&MASTER, &key, [0x11; 16], [0x22; 24]).unwrap();
            let password =
                wrap_with_password_with(&MASTER, key.as_password(), [0x11; 16], [0x22; 24])
                    .unwrap();
            assert_eq!(recovery[..87], password[..87]);
            assert_ne!(recovery[87..], password[87..]);
        }
    }

    mod recovery_lock {
        use super::*;

        #[test]
        fn lock_is_the_keys_own_and_matches_the_golden() {
            let key = fixed_recovery();
            assert_eq!(key.lock().to_vec(), hex(GOLDEN_LOCK_HEX));
            assert_eq!(key.lock(), key.lock(), "derived, not drawn");
            let parsed = RecoveryKey::parse(&key.text()).unwrap();
            assert_eq!(parsed.lock(), key.lock());
            assert_ne!(RecoveryKey::generate().unwrap().lock(), key.lock());
        }

        #[test]
        fn box_round_trip_and_golden() {
            let lock: [u8; 32] = hex(GOLDEN_LOCK_HEX).try_into().unwrap();
            let golden = hex(GOLDEN_BOX_HEX);
            let blob = seal_to_lock_with(&lock, &MASTER, BOX_AAD, &[0x55; 32], [0x22; 24]).unwrap();
            assert_eq!(blob, golden);
            assert_eq!(blob.len(), 6 + 32 + 24 + 48);
            let key = fixed_recovery();
            assert_eq!(*open_with_recovery(&golden, &key, BOX_AAD).unwrap(), MASTER);
            let fresh = seal_to_lock(&key.lock(), &MASTER, BOX_AAD).unwrap();
            assert_ne!(fresh[6..38], golden[6..38], "fresh ephemeral key");
            assert_eq!(*open_with_recovery(&fresh, &key, BOX_AAD).unwrap(), MASTER);
        }

        #[test]
        fn only_the_recovery_key_of_the_lock_opens_a_box() {
            let key = RecoveryKey::generate().unwrap();
            let blob = seal_to_lock(&key.lock(), &STORE_KEY, BOX_AAD).unwrap();

            let other = RecoveryKey::generate().unwrap();
            assert_eq!(
                open_with_recovery(&blob, &other, BOX_AAD).unwrap_err(),
                CoreError::WrongPassword
            );
            // Another role does not open it.
            assert_eq!(
                open_with_recovery(&blob, &key, b"master-key-recovery").unwrap_err(),
                CoreError::WrongPassword
            );
            // Every byte after the envelope is covered: the ephemeral key through
            // the shared secret and the box key, nonce and ciphertext through the tag.
            for index in 6..blob.len() {
                let mut flipped = blob.clone();
                flipped[index] ^= 0x01;
                assert!(
                    open_with_recovery(&flipped, &key, BOX_AAD).is_err(),
                    "byte {index}"
                );
            }
            // Other kinds and lengths are format errors, not panics.
            assert_eq!(
                open_with_recovery(&blob[..blob.len() - 1], &key, BOX_AAD).unwrap_err(),
                CoreError::Corrupt
            );
            let wrapped = wrap_with_recovery(&STORE_KEY, &key).unwrap();
            assert_eq!(
                open_with_recovery(&wrapped, &key, BOX_AAD).unwrap_err(),
                CoreError::UnsupportedFormat
            );
        }

        #[test]
        fn a_low_order_lock_or_ephemeral_is_refused() {
            // The all-zero point (and other small-order points) give no shared secret.
            assert_eq!(
                seal_to_lock(&[0u8; 32], &STORE_KEY, BOX_AAD).unwrap_err(),
                CoreError::Corrupt
            );
            let key = RecoveryKey::generate().unwrap();
            let mut blob = seal_to_lock(&key.lock(), &STORE_KEY, BOX_AAD).unwrap();
            blob[6..38].copy_from_slice(&[0u8; 32]);
            assert_eq!(
                open_with_recovery(&blob, &key, BOX_AAD).unwrap_err(),
                CoreError::WrongPassword
            );
        }

        #[test]
        fn the_master_key_does_not_open_a_box() {
            // The box is sealed to the lock, not under any key the master key
            // reaches: neither a 0x20 unwrap nor a password unwrap reads it.
            let key = RecoveryKey::generate().unwrap();
            let blob = seal_to_lock(&key.lock(), &STORE_KEY, BOX_AAD).unwrap();
            assert_eq!(
                unwrap_key(&MASTER, &blob, BOX_AAD).unwrap_err(),
                CoreError::UnsupportedFormat
            );
            assert_eq!(
                unwrap_with_password(&blob, PASSWORD).unwrap_err(),
                CoreError::UnsupportedFormat
            );
        }
    }

    mod under_master {
        use super::*;

        #[test]
        fn round_trip_and_golden() {
            let golden = hex(GOLDEN_STORE_WRAP_HEX);
            let blob = wrap_key_with(&MASTER, &STORE_KEY, STORE_KEY_WRAP_AAD, [0x44; 24]).unwrap();
            assert_eq!(blob, golden);
            assert_eq!(blob.len(), 6 + 24 + 32 + 16);
            assert_eq!(
                *unwrap_key(&MASTER, &golden, STORE_KEY_WRAP_AAD).unwrap(),
                STORE_KEY
            );
            let fresh = wrap_key(&MASTER, &STORE_KEY, STORE_KEY_WRAP_AAD).unwrap();
            assert_ne!(fresh, golden, "fresh nonce");
            assert_eq!(
                *unwrap_key(&MASTER, &fresh, STORE_KEY_WRAP_AAD).unwrap(),
                STORE_KEY
            );
        }

        #[test]
        fn roles_keys_and_tampering_are_corrupt() {
            let blob = wrap_key(&MASTER, &STORE_KEY, STORE_KEY_WRAP_AAD).unwrap();

            // The store key's wrap is not the vault key's, and the reverse.
            assert_eq!(
                unwrap_key(&MASTER, &blob, VAULT_KEY_WRAP_AAD).unwrap_err(),
                CoreError::Corrupt
            );
            let vault_blob = wrap_key(&MASTER, &STORE_KEY, VAULT_KEY_WRAP_AAD).unwrap();
            assert_eq!(
                unwrap_key(&MASTER, &vault_blob, STORE_KEY_WRAP_AAD).unwrap_err(),
                CoreError::Corrupt
            );
            assert_eq!(
                unwrap_key(&[0x34; 32], &blob, STORE_KEY_WRAP_AAD).unwrap_err(),
                CoreError::Corrupt
            );
            for index in 6..blob.len() {
                let mut flipped = blob.clone();
                flipped[index] ^= 0x01;
                assert_eq!(
                    unwrap_key(&MASTER, &flipped, STORE_KEY_WRAP_AAD).unwrap_err(),
                    CoreError::Corrupt,
                    "byte {index}"
                );
            }
            // A 0x20 of the wrong length (an ordinary seal) is not a key.
            let short = wrap_key_with(&MASTER, &STORE_KEY, STORE_KEY_WRAP_AAD, [0x44; 24])
                .map(|mut sealed| {
                    sealed.truncate(sealed.len() - 1);
                    sealed
                })
                .unwrap();
            assert_eq!(
                unwrap_key(&MASTER, &short, STORE_KEY_WRAP_AAD).unwrap_err(),
                CoreError::Corrupt
            );
            let not_a_key = LocalSeal {
                nonce: [0x44; 24],
                ciphertext: store::seal(&MASTER, &[0x44; 24], STORE_KEY_WRAP_AAD, b"short")
                    .unwrap(),
            }
            .encode();
            assert_eq!(
                unwrap_key(&MASTER, &not_a_key, STORE_KEY_WRAP_AAD).unwrap_err(),
                CoreError::Corrupt
            );
            // A 0x10 is the wrong kind.
            let password_blob = wrap_with_password(&MASTER, PASSWORD).unwrap();
            assert_eq!(
                unwrap_key(&MASTER, &password_blob, STORE_KEY_WRAP_AAD).unwrap_err(),
                CoreError::UnsupportedFormat
            );
        }
    }
}
