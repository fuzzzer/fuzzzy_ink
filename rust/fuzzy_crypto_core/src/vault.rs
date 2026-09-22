//! The vault master key (plan §D, F-8): a random 32-byte key that only ever
//! exists inside Rust, wrapped under the vault password as a 0x10 blob — the
//! store key's layout and functions, under the vault's own AAD domain
//! (`vault-key`, so an app-lock blob never unwraps as a vault key and vice
//! versa). Items are sealed under the master key directly (0x20 envelope, AAD
//! `vault-item`), so a password change only re-wraps the key: no item is ever
//! re-encrypted.

use zeroize::Zeroizing;

use crate::error::CoreError;
use crate::formats::LocalSeal;
use crate::store::{self, Key32};

const VAULT_KEY_AAD: &[u8] = b"vault-key";
const VAULT_ITEM_AAD: &[u8] = b"vault-item";

/// Draws a fresh master key and returns it with its wrapping under `password`.
pub fn init(password: &[u8]) -> Result<(Key32, Vec<u8>), CoreError> {
    let mut key = Zeroizing::new([0u8; 32]);
    store::fill_random(key.as_mut())?;
    let wrapped = wrap(&key, password)?;
    Ok((key, wrapped))
}

/// Unwraps the master key; a wrong password (or a tampered blob) is `WrongPassword`.
pub fn unlock(password: &[u8], wrapped: &[u8]) -> Result<Key32, CoreError> {
    store::unwrap_key(wrapped, password, VAULT_KEY_AAD)
}

fn wrap(key: &[u8; 32], password: &[u8]) -> Result<Vec<u8>, CoreError> {
    wrap_with(
        key,
        password,
        store::random_array()?,
        store::random_array()?,
    )
}

/// [`wrap`] with the randomness supplied — the golden test pins its output.
pub(crate) fn wrap_with(
    key: &[u8; 32],
    password: &[u8],
    salt: [u8; 16],
    nonce: [u8; 24],
) -> Result<Vec<u8>, CoreError> {
    store::wrap_key_with(key, password, VAULT_KEY_AAD, salt, nonce)
}

/// Re-wraps the same master key under `new_password` with a fresh salt and
/// nonce. Items sealed before the change keep opening under the new blob.
pub fn rewrap(
    old_password: &[u8],
    new_password: &[u8],
    wrapped: &[u8],
) -> Result<Vec<u8>, CoreError> {
    let key = unlock(old_password, wrapped)?;
    wrap(&key, new_password)
}

/// Seals one item under the master key with a fresh nonce.
pub fn seal_item(key: &[u8; 32], bytes: &[u8]) -> Result<Vec<u8>, CoreError> {
    seal_item_with(key, bytes, store::random_array()?)
}

/// [`seal_item`] with the nonce supplied — the golden test pins its output.
pub(crate) fn seal_item_with(
    key: &[u8; 32],
    bytes: &[u8],
    nonce: [u8; 24],
) -> Result<Vec<u8>, CoreError> {
    let ciphertext = store::seal(key, &nonce, VAULT_ITEM_AAD, bytes)?;
    Ok(LocalSeal { nonce, ciphertext }.encode())
}

/// Inverse of [`seal_item`]; a tampered blob or another key is `Corrupt`.
pub fn open_item(key: &[u8; 32], blob: &[u8]) -> Result<Vec<u8>, CoreError> {
    let sealed = LocalSeal::decode(blob)?;
    store::open(key, &sealed.nonce, VAULT_ITEM_AAD, &sealed.ciphertext)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::formats::WrappedStoreKey;
    use crate::store::ARGON2_PARAMS;

    const PASSWORD: &[u8] = b"pw";
    const MASTER: [u8; 32] = [0x33; 32];

    /// Derived independently in Python (scratchpad `f41/golden_f41.py`): master
    /// key `0x33×32`, nonce `0x44×24`, AAD `vault-item`, item `item`.
    const GOLDEN_ITEM_HEX: &str = concat!(
        "46555a5a0120",
        "444444444444444444444444444444444444444444444444",
        "71d215b9975d3e21421abeb467d33deef3cb8a14",
    );
    /// The same script's 0x10 wrapping of `MASTER` under `pw`, salt `0x11×16`,
    /// nonce `0x22×24`, AAD `vault-key`: the same header and ciphertext as F2-2's
    /// store-key golden (same KEK, same keystream), a different tag — the AAD
    /// domain is the only difference (reviewer's `review_golden_f41.py` agrees).
    const GOLDEN_WRAPPED_HEX: &str = concat!(
        "46555a5a0110",
        "11111111111111111111111111111111",
        "000100000000000401",
        "222222222222222222222222222222222222222222222222",
        "ca92d2caa5a5120ca9b162dab36620db05f2829d86e6df4fefe299cbb96637a4",
        "47a1848d1fb05c95e5db70a94677dfd0",
    );

    fn hex(text: &str) -> Vec<u8> {
        (0..text.len())
            .step_by(2)
            .map(|i| u8::from_str_radix(&text[i..i + 2], 16).unwrap())
            .collect()
    }

    #[test]
    fn init_unlock_round_trip() {
        let (key, wrapped) = init(PASSWORD).unwrap();
        let decoded = WrappedStoreKey::decode(&wrapped).unwrap();
        assert_eq!(decoded.params, ARGON2_PARAMS);
        assert_eq!(wrapped.len(), 103);

        let unlocked = unlock(PASSWORD, &wrapped).unwrap();
        assert_eq!(*unlocked, *key);
        // A second init draws a different key and a different wrapping.
        let (other, other_wrapped) = init(PASSWORD).unwrap();
        assert_ne!(*other, *key);
        assert_ne!(other_wrapped, wrapped);
    }

    #[test]
    fn wrong_password() {
        let (_, wrapped) = init(PASSWORD).unwrap();
        assert_eq!(
            unlock(b"px", &wrapped).unwrap_err(),
            CoreError::WrongPassword
        );
        assert_eq!(unlock(b"", &wrapped).unwrap_err(), CoreError::WrongPassword);
        assert_eq!(
            rewrap(b"px", b"new", &wrapped).unwrap_err(),
            CoreError::WrongPassword
        );
        let mut tampered = wrapped.clone();
        tampered[60] ^= 1;
        assert_eq!(
            unlock(PASSWORD, &tampered).unwrap_err(),
            CoreError::WrongPassword
        );
        // The golden wrapping (made in Python) unlocks to the known key.
        assert_eq!(*unlock(PASSWORD, &hex(GOLDEN_WRAPPED_HEX)).unwrap(), MASTER);
    }

    #[test]
    fn golden_wrapping() {
        let blob = wrap_with(&MASTER, PASSWORD, [0x11; 16], [0x22; 24]).unwrap();
        assert_eq!(blob, hex(GOLDEN_WRAPPED_HEX));
    }

    /// A store-key blob and a vault-key blob under the same password are not
    /// interchangeable: each role's unwrap rejects the other's blob.
    #[test]
    fn store_key_and_vault_key_domains_are_separate() {
        let (key, vault_blob) = init(PASSWORD).unwrap();
        let store_blob = store::wrap_store_key(&key, PASSWORD).unwrap();
        assert_eq!(
            store::unwrap_store_key(&vault_blob, PASSWORD).unwrap_err(),
            CoreError::WrongPassword
        );
        assert_eq!(
            unlock(PASSWORD, &store_blob).unwrap_err(),
            CoreError::WrongPassword
        );
        assert_eq!(*unlock(PASSWORD, &vault_blob).unwrap(), *key);
        assert_eq!(
            *store::unwrap_store_key(&store_blob, PASSWORD).unwrap(),
            *key
        );
        // Same salt/nonce/key/password: header and ciphertext agree, only the tag differs.
        let store_golden =
            store::wrap_store_key_with(&MASTER, PASSWORD, [0x11; 16], [0x22; 24]).unwrap();
        let vault_golden = hex(GOLDEN_WRAPPED_HEX);
        assert_eq!(store_golden[..87], vault_golden[..87]);
        assert_ne!(store_golden[87..], vault_golden[87..]);
    }

    #[test]
    fn rewrap_keeps_key() {
        let (key, wrapped) = init(PASSWORD).unwrap();
        let item = seal_item(&key, b"passport scan").unwrap();

        let rewrapped = rewrap(PASSWORD, b"new", &wrapped).unwrap();
        assert_ne!(rewrapped, wrapped);
        let key_after = unlock(b"new", &rewrapped).unwrap();
        assert_eq!(*key_after, *key);
        assert_eq!(open_item(&key_after, &item).unwrap(), b"passport scan");
        // The old password no longer opens the new blob; the old blob still opens with it.
        assert_eq!(
            unlock(PASSWORD, &rewrapped).unwrap_err(),
            CoreError::WrongPassword
        );
        assert!(unlock(PASSWORD, &wrapped).is_ok());
        // An empty new password is valid (the "no password" case).
        let no_password = rewrap(b"new", b"", &rewrapped).unwrap();
        assert_eq!(*unlock(b"", &no_password).unwrap(), *key);
    }

    #[test]
    fn seal_open_tamper_detected() {
        let blob = seal_item(&MASTER, b"item").unwrap();
        assert_eq!(&blob[..6], &[0x46, 0x55, 0x5A, 0x5A, 0x01, 0x20]);
        assert_eq!(open_item(&MASTER, &blob).unwrap(), b"item");
        assert_ne!(seal_item(&MASTER, b"item").unwrap(), blob, "fresh nonce");

        for index in 6..blob.len() {
            let mut flipped = blob.clone();
            flipped[index] ^= 0x01;
            assert_eq!(
                open_item(&MASTER, &flipped).unwrap_err(),
                CoreError::Corrupt,
                "byte {index}"
            );
        }
        for len in 6..blob.len() {
            assert_eq!(
                open_item(&MASTER, &blob[..len]).unwrap_err(),
                CoreError::Corrupt,
                "length {len}"
            );
        }
        assert_eq!(
            open_item(&[0x34; 32], &blob).unwrap_err(),
            CoreError::Corrupt,
            "another key"
        );
        // A history seal (same 0x20 envelope, AAD `local-seal` ‖ chat id) is not a vault item.
        let local =
            store::seal_local(&MASTER, "6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d", b"item").unwrap();
        assert_eq!(open_item(&MASTER, &local).unwrap_err(), CoreError::Corrupt);
        // A 0x10 blob is the wrong kind for this call.
        let (_, wrapped) = init(b"").unwrap();
        assert_eq!(
            open_item(&MASTER, &wrapped).unwrap_err(),
            CoreError::UnsupportedFormat
        );
        // Empty items are valid.
        let empty = seal_item(&MASTER, b"").unwrap();
        assert_eq!(open_item(&MASTER, &empty).unwrap(), b"");
    }

    #[test]
    fn golden_item() {
        let blob = seal_item_with(&MASTER, b"item", [0x44; 24]).unwrap();
        assert_eq!(blob, hex(GOLDEN_ITEM_HEX));
        assert_eq!(open_item(&MASTER, &hex(GOLDEN_ITEM_HEX)).unwrap(), b"item");
    }
}
