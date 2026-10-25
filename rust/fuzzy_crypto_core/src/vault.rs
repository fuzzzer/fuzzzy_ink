//! The vault key (plan §D, F-8): a random 32-byte key that only ever exists
//! inside Rust. By default it is wrapped under the master key (a 0x20 blob,
//! AAD `vault-key-wrap`), so the master password opens the vault; the user may
//! instead give the vault its own password (a 0x10 blob, AAD `vault-key` — the
//! master key's construction in its own domain), and switch back. Either way
//! it stays a separate key: it opens no chat, and the store key opens no vault
//! item.
//!
//! Items are sealed under the vault key directly (0x20 envelope, AAD
//! `vault-item` ‖ version ‖ item id), so a password change only re-wraps the
//! key: no item is ever re-encrypted.

use crate::error::CoreError;
use crate::formats::{self, BlobKind, LocalSeal};
use crate::master::{self, VAULT_KEY_WRAP_AAD};
use crate::store::{self, Key32};

const VAULT_KEY_AAD: &[u8] = b"vault-key";
const VAULT_ITEM_AAD: &[u8] = b"vault-item";

/// How the vault key is wrapped, read from the blob's type byte.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Wrapping {
    /// 0x20 under the master key — the master password opens the vault.
    MasterKey,
    /// 0x10 under the vault's own password.
    OwnPassword,
}

/// Which password opens the vault whose key is `wrapped`. Touches no key.
pub fn wrapping_of(wrapped: &[u8]) -> Result<Wrapping, CoreError> {
    match formats::decode_envelope(wrapped)?.0 {
        BlobKind::LocalSeal => Ok(Wrapping::MasterKey),
        BlobKind::WrappedStoreKey => Ok(Wrapping::OwnPassword),
        _ => Err(CoreError::UnsupportedFormat),
    }
}

/// Draws a fresh vault key and wraps it under the vault's own `password`.
pub fn init(password: &[u8]) -> Result<(Key32, Vec<u8>), CoreError> {
    let key = master::new_key()?;
    let wrapped = wrap(&key, password)?;
    Ok((key, wrapped))
}

/// Draws a fresh vault key and wraps it under the master key.
pub fn init_under_master(master_key: &[u8; 32]) -> Result<(Key32, Vec<u8>), CoreError> {
    let key = master::new_key()?;
    let wrapped = master::wrap_key(master_key, &key, VAULT_KEY_WRAP_AAD)?;
    Ok((key, wrapped))
}

/// Unwraps a vault key wrapped under its own password; a wrong password (or
/// a tampered blob) is `WrongPassword`.
pub fn unlock(password: &[u8], wrapped: &[u8]) -> Result<Key32, CoreError> {
    store::unwrap_key(wrapped, password, VAULT_KEY_AAD)
}

/// Unwraps a vault key wrapped under the master key; a foreign or tampered
/// blob is `Corrupt`.
pub fn unlock_under_master(master_key: &[u8; 32], wrapped: &[u8]) -> Result<Key32, CoreError> {
    master::unwrap_key(master_key, wrapped, VAULT_KEY_WRAP_AAD)
}

/// Wraps the vault key under the master key (switching back to the master
/// password).
pub fn wrap_under_master(master_key: &[u8; 32], key: &[u8; 32]) -> Result<Vec<u8>, CoreError> {
    master::wrap_key(master_key, key, VAULT_KEY_WRAP_AAD)
}

/// Wraps the vault key under its own `password` (fresh salt and nonce); an
/// empty password is refused.
pub fn wrap(key: &[u8; 32], password: &[u8]) -> Result<Vec<u8>, CoreError> {
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
    master::refuse_empty(password)?;
    store::wrap_key_with(key, password, VAULT_KEY_AAD, salt, nonce)
}

/// Re-wraps the same vault key under `new_password` with a fresh salt and
/// nonce. Items sealed before the change keep opening under the new blob.
pub fn rewrap(
    old_password: &[u8],
    new_password: &[u8],
    wrapped: &[u8],
) -> Result<Vec<u8>, CoreError> {
    master::refuse_empty(new_password)?;
    let key = unlock(old_password, wrapped)?;
    wrap(&key, new_password)
}

/// `vault-item ‖ u32 BE version ‖ item id`: an item is bound to its own id and
/// to the content version the vault's index records for it, so a file copied
/// over another item, or an older copy of the same item, does not open
/// (security review 2026-10-22). The version is fixed-length, so the id needs
/// no separator.
fn item_aad(item_id: &str, version: u32) -> Result<Vec<u8>, CoreError> {
    if item_id.is_empty() {
        return Err(CoreError::Corrupt);
    }
    let mut aad = Vec::with_capacity(VAULT_ITEM_AAD.len() + 4 + item_id.len());
    aad.extend_from_slice(VAULT_ITEM_AAD);
    aad.extend_from_slice(&version.to_be_bytes());
    aad.extend_from_slice(item_id.as_bytes());
    Ok(aad)
}

/// Seals one version of one item under the vault key with a fresh nonce.
pub fn seal_item(
    key: &[u8; 32],
    item_id: &str,
    version: u32,
    bytes: &[u8],
) -> Result<Vec<u8>, CoreError> {
    seal_item_with(key, item_id, version, bytes, store::random_array()?)
}

/// [`seal_item`] with the nonce supplied — the golden test pins its output.
pub(crate) fn seal_item_with(
    key: &[u8; 32],
    item_id: &str,
    version: u32,
    bytes: &[u8],
    nonce: [u8; 24],
) -> Result<Vec<u8>, CoreError> {
    let ciphertext = store::seal(key, &nonce, &item_aad(item_id, version)?, bytes)?;
    Ok(LocalSeal { nonce, ciphertext }.encode())
}

/// Inverse of [`seal_item`] for the same item and version; a tampered blob,
/// another key, another item or another version is `Corrupt`.
pub fn open_item(
    key: &[u8; 32],
    item_id: &str,
    version: u32,
    blob: &[u8],
) -> Result<Vec<u8>, CoreError> {
    let sealed = LocalSeal::decode(blob)?;
    store::open(
        key,
        &sealed.nonce,
        &item_aad(item_id, version)?,
        &sealed.ciphertext,
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::formats::WrappedStoreKey;
    use crate::store::ARGON2_PARAMS;

    const PASSWORD: &[u8] = b"pw";
    const KEY: [u8; 32] = [0x33; 32];
    const MASTER: [u8; 32] = [0x77; 32];
    const ITEM: &str = "6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d";

    /// XChaCha20-Poly1305(vault key 0x33×32, nonce 0x44×24, AAD `vault-item` ‖
    /// u32 BE 3 ‖ item id, "item"), computed with pycryptodome from the spec —
    /// the `vault_item` vector.
    const GOLDEN_ITEM_HEX: &str = concat!(
        "46555a5a0120",
        "444444444444444444444444444444444444444444444444",
        "71d215b9",
        "9673c691e4219abe98369a29305d578e",
    );
    /// The 0x10 wrapping of `KEY` under `pw`, salt `0x11×16`, nonce `0x22×24`,
    /// AAD `vault-key`: derived independently in Python (scratchpad
    /// `f41/golden_f41.py`); the same header and ciphertext as the master-key
    /// golden (same KEK, same keystream), a different tag — the AAD domain is
    /// the only difference (reviewer's `review_golden_f41.py` agrees).
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
        assert_eq!(wrapping_of(&wrapped).unwrap(), Wrapping::OwnPassword);

        let unlocked = unlock(PASSWORD, &wrapped).unwrap();
        assert_eq!(*unlocked, *key);
        // A second init draws a different key and a different wrapping.
        let (other, other_wrapped) = init(PASSWORD).unwrap();
        assert_ne!(*other, *key);
        assert_ne!(other_wrapped, wrapped);
    }

    #[test]
    fn init_under_master_round_trip() {
        let (key, wrapped) = init_under_master(&MASTER).unwrap();
        assert_eq!(wrapped.len(), 6 + 24 + 32 + 16);
        assert_eq!(wrapping_of(&wrapped).unwrap(), Wrapping::MasterKey);
        assert_eq!(*unlock_under_master(&MASTER, &wrapped).unwrap(), *key);
        assert_eq!(
            unlock_under_master(&[0x78; 32], &wrapped).unwrap_err(),
            CoreError::Corrupt
        );
        // The vault key's wrap under the master key is not the store key's.
        assert_eq!(
            master::unwrap_key(&MASTER, &wrapped, master::STORE_KEY_WRAP_AAD).unwrap_err(),
            CoreError::Corrupt
        );
        // A master-key wrap is not a vault password wrap, and the reverse.
        assert_eq!(
            unlock(PASSWORD, &wrapped).unwrap_err(),
            CoreError::UnsupportedFormat
        );
        let (_, own) = init(PASSWORD).unwrap();
        assert_eq!(
            unlock_under_master(&MASTER, &own).unwrap_err(),
            CoreError::UnsupportedFormat
        );
    }

    #[test]
    fn switching_between_master_and_own_password_keeps_the_key() {
        let (key, under_master) = init_under_master(&MASTER).unwrap();
        let item = seal_item(&key, ITEM, 1, b"passport scan").unwrap();

        let unlocked = unlock_under_master(&MASTER, &under_master).unwrap();
        let own = wrap(&unlocked, b"vault only").unwrap();
        assert_eq!(wrapping_of(&own).unwrap(), Wrapping::OwnPassword);
        let reopened = unlock(b"vault only", &own).unwrap();
        assert_eq!(
            open_item(&reopened, ITEM, 1, &item).unwrap(),
            b"passport scan"
        );

        let back = wrap_under_master(&MASTER, &reopened).unwrap();
        assert_eq!(wrapping_of(&back).unwrap(), Wrapping::MasterKey);
        let again = unlock_under_master(&MASTER, &back).unwrap();
        assert_eq!(open_item(&again, ITEM, 1, &item).unwrap(), b"passport scan");
    }

    #[test]
    fn wrapping_of_refuses_other_blobs() {
        assert_eq!(wrapping_of(&[]).unwrap_err(), CoreError::UnsupportedFormat);
        let sealed_text = crate::passwords::seal_bytes(PASSWORD, b"x").unwrap();
        assert_eq!(
            wrapping_of(&sealed_text).unwrap_err(),
            CoreError::UnsupportedFormat
        );
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
        assert_eq!(*unlock(PASSWORD, &hex(GOLDEN_WRAPPED_HEX)).unwrap(), KEY);
    }

    #[test]
    fn golden_wrapping() {
        let blob = wrap_with(&KEY, PASSWORD, [0x11; 16], [0x22; 24]).unwrap();
        assert_eq!(blob, hex(GOLDEN_WRAPPED_HEX));
    }

    /// A master-key blob and a vault-key blob under the same password are not
    /// interchangeable: each role's unwrap rejects the other's blob.
    #[test]
    fn master_key_and_vault_key_domains_are_separate() {
        let (key, vault_blob) = init(PASSWORD).unwrap();
        let master_blob = master::wrap_with_password(&key, PASSWORD).unwrap();
        assert_eq!(
            master::unwrap_with_password(&vault_blob, PASSWORD).unwrap_err(),
            CoreError::WrongPassword
        );
        assert_eq!(
            unlock(PASSWORD, &master_blob).unwrap_err(),
            CoreError::WrongPassword
        );
        assert_eq!(*unlock(PASSWORD, &vault_blob).unwrap(), *key);
        assert_eq!(
            *master::unwrap_with_password(&master_blob, PASSWORD).unwrap(),
            *key
        );
        // Same salt/nonce/key/password: header and ciphertext agree, only the tag differs.
        let master_golden =
            master::wrap_with_password_with(&KEY, PASSWORD, [0x11; 16], [0x22; 24]).unwrap();
        let vault_golden = hex(GOLDEN_WRAPPED_HEX);
        assert_eq!(master_golden[..87], vault_golden[..87]);
        assert_ne!(master_golden[87..], vault_golden[87..]);
    }

    #[test]
    fn rewrap_keeps_key() {
        let (key, wrapped) = init(PASSWORD).unwrap();
        let item = seal_item(&key, ITEM, 1, b"passport scan").unwrap();

        let rewrapped = rewrap(PASSWORD, b"new", &wrapped).unwrap();
        assert_ne!(rewrapped, wrapped);
        let key_after = unlock(b"new", &rewrapped).unwrap();
        assert_eq!(*key_after, *key);
        assert_eq!(
            open_item(&key_after, ITEM, 1, &item).unwrap(),
            b"passport scan"
        );
        // The old password no longer opens the new blob; the old blob still opens with it.
        assert_eq!(
            unlock(PASSWORD, &rewrapped).unwrap_err(),
            CoreError::WrongPassword
        );
        assert!(unlock(PASSWORD, &wrapped).is_ok());
        // An empty password is refused: a vault password is never "off".
        assert_eq!(
            rewrap(b"new", b"", &rewrapped).unwrap_err(),
            CoreError::WrongPassword
        );
        assert_eq!(init(b"").unwrap_err(), CoreError::WrongPassword);
    }

    #[test]
    fn seal_open_tamper_detected() {
        let blob = seal_item(&KEY, ITEM, 3, b"item").unwrap();
        assert_eq!(&blob[..6], &[0x46, 0x55, 0x5A, 0x5A, 0x01, 0x20]);
        assert_eq!(open_item(&KEY, ITEM, 3, &blob).unwrap(), b"item");
        assert_ne!(
            seal_item(&KEY, ITEM, 3, b"item").unwrap(),
            blob,
            "fresh nonce"
        );

        for index in 6..blob.len() {
            let mut flipped = blob.clone();
            flipped[index] ^= 0x01;
            assert_eq!(
                open_item(&KEY, ITEM, 3, &flipped).unwrap_err(),
                CoreError::Corrupt,
                "byte {index}"
            );
        }
        for len in 6..blob.len() {
            assert_eq!(
                open_item(&KEY, ITEM, 3, &blob[..len]).unwrap_err(),
                CoreError::Corrupt,
                "length {len}"
            );
        }
        assert_eq!(
            open_item(&[0x34; 32], ITEM, 3, &blob).unwrap_err(),
            CoreError::Corrupt,
            "another key"
        );
        // A history seal (same 0x20 envelope, AAD `local-seal` ‖ chat id ‖ row) is not a vault item.
        let local = store::seal_local(&KEY, ITEM, b"", b"item").unwrap();
        assert_eq!(
            open_item(&KEY, ITEM, 3, &local).unwrap_err(),
            CoreError::Corrupt
        );
        // A 0x10 blob is the wrong kind for this call.
        let (_, wrapped) = init(PASSWORD).unwrap();
        assert_eq!(
            open_item(&KEY, ITEM, 3, &wrapped).unwrap_err(),
            CoreError::UnsupportedFormat
        );
        // Empty items are valid; an empty item id is not.
        let empty = seal_item(&KEY, ITEM, 3, b"").unwrap();
        assert_eq!(open_item(&KEY, ITEM, 3, &empty).unwrap(), b"");
        assert_eq!(
            seal_item(&KEY, "", 3, b"x").unwrap_err(),
            CoreError::Corrupt
        );
    }

    /// Security review 2026-10-22: an item file copied over another item, or an
    /// older copy of the same item put back, no longer opens.
    #[test]
    fn item_is_bound_to_its_id_and_version() {
        let blob = seal_item(&KEY, ITEM, 3, b"current").unwrap();
        assert_eq!(
            open_item(&KEY, "0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d", 3, &blob).unwrap_err(),
            CoreError::Corrupt,
            "swapped onto another item"
        );
        assert_eq!(
            open_item(&KEY, ITEM, 4, &blob).unwrap_err(),
            CoreError::Corrupt,
            "an older copy where a newer version is recorded"
        );
        assert_eq!(
            open_item(&KEY, ITEM, 2, &blob).unwrap_err(),
            CoreError::Corrupt
        );
    }

    #[test]
    fn golden_item() {
        let blob = seal_item_with(&KEY, ITEM, 3, b"item", [0x44; 24]).unwrap();
        assert_eq!(blob, hex(GOLDEN_ITEM_HEX));
        assert_eq!(
            open_item(&KEY, ITEM, 3, &hex(GOLDEN_ITEM_HEX)).unwrap(),
            b"item"
        );
    }
}
