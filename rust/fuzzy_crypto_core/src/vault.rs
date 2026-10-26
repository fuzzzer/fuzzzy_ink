//! The vault key (plan §D, F-8): a random 32-byte key that only ever exists
//! inside Rust. By default it is wrapped under the master key (a 0x20 blob,
//! AAD `vault-key-wrap`), so the master password opens the vault; the user may
//! instead give the vault its own password (a 0x10 blob, AAD `vault-key` — the
//! master key's construction in its own domain), and switch back. Either way
//! it stays a separate key: it opens no chat, and the store key opens no vault
//! item.
//!
//! A vault with its own password is also sealed to the recovery lock (a 0x11
//! blob, AAD `vault-key-recovery`, [`crate::master::seal_to_lock`]), so the
//! recovery key opens it while the master password does not: the master
//! password reaches the lock's public half only (owner, 2026-10-26).
//!
//! Items are sealed under the vault key directly (0x20 envelope, AAD
//! `vault-item` ‖ version ‖ item id), so a password change only re-wraps the
//! key: no item is ever re-encrypted.
//!
//! Each password and file item also has a small **list label** (its username
//! or file name) sealed on its own under the vault key in a separate domain
//! (AAD `vault-label` ‖ version ‖ item id) and padded to one fixed size, so
//! My safe's list opens no item and the file's size says nothing about the
//! label's length (security review 2026-10-26).

use zeroize::Zeroizing;

use crate::error::CoreError;
use crate::formats::{self, BlobKind, LocalSeal};
use crate::master::{self, RecoveryKey, VAULT_KEY_WRAP_AAD};
use crate::store::{self, Key32};

const VAULT_KEY_AAD: &[u8] = b"vault-key";
/// AAD of the vault key sealed to the recovery lock (0x11).
pub(crate) const VAULT_KEY_RECOVERY_AAD: &[u8] = b"vault-key-recovery";
const VAULT_ITEM_AAD: &[u8] = b"vault-item";
const VAULT_LABEL_AAD: &[u8] = b"vault-label";

/// Every label is sealed as exactly this many bytes: one length byte, the
/// label's UTF-8 text, zeros to the end. Every label file has the same size.
pub const LABEL_PADDED_LEN: usize = 256;
/// The longest label kept, in UTF-8 bytes; a longer one is cut at a character
/// boundary (the list shows one line of it anyway).
pub const LABEL_MAX_LEN: usize = LABEL_PADDED_LEN - 1;

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

/// Seals the vault key to the recovery `lock` (a 0x11 blob): the recovery key
/// that made the lock opens it, nothing else does.
pub fn seal_for_recovery(lock: &[u8; 32], key: &[u8; 32]) -> Result<Vec<u8>, CoreError> {
    master::seal_to_lock(lock, key, VAULT_KEY_RECOVERY_AAD)
}

/// Inverse of [`seal_for_recovery`]; another device's recovery key or a
/// tampered blob is `WrongPassword`.
pub fn unlock_with_recovery(blob: &[u8], recovery: &RecoveryKey) -> Result<Key32, CoreError> {
    master::open_with_recovery(blob, recovery, VAULT_KEY_RECOVERY_AAD)
}

/// `vault-item ‖ u32 BE version ‖ item id`: an item is bound to its own id and
/// to the content version the vault's index records for it, so a file copied
/// over another item, or an older copy of the same item, does not open
/// (security review 2026-10-22). The version is fixed-length, so the id needs
/// no separator.
fn item_aad(item_id: &str, version: u32) -> Result<Vec<u8>, CoreError> {
    bound_aad(VAULT_ITEM_AAD, item_id, version)
}

/// `vault-label ‖ u32 BE version ‖ item id`: a label is bound like its item,
/// in its own domain, so a label never opens as an item and an item never as
/// a label, whatever the ids.
fn label_aad(item_id: &str, version: u32) -> Result<Vec<u8>, CoreError> {
    bound_aad(VAULT_LABEL_AAD, item_id, version)
}

fn bound_aad(domain: &[u8], item_id: &str, version: u32) -> Result<Vec<u8>, CoreError> {
    if item_id.is_empty() {
        return Err(CoreError::Corrupt);
    }
    let mut aad = Vec::with_capacity(domain.len() + 4 + item_id.len());
    aad.extend_from_slice(domain);
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

/// `len ‖ label ‖ zeros`, [`LABEL_PADDED_LEN`] bytes; the label cut to
/// [`LABEL_MAX_LEN`] bytes at a character boundary.
fn pad_label(label: &str) -> Zeroizing<Vec<u8>> {
    let mut len = label.len().min(LABEL_MAX_LEN);
    while !label.is_char_boundary(len) {
        len -= 1;
    }
    let mut padded = Zeroizing::new(vec![0u8; LABEL_PADDED_LEN]);
    // `len` ≤ 255: it fits the length byte.
    padded[0] = len as u8;
    padded[1..=len].copy_from_slice(&label.as_bytes()[..len]);
    padded
}

/// Inverse of [`pad_label`]; any other shape (length, padding, UTF-8) is
/// `Corrupt`.
fn unpad_label(padded: &[u8]) -> Result<String, CoreError> {
    if padded.len() != LABEL_PADDED_LEN {
        return Err(CoreError::Corrupt);
    }
    let (text, padding) = padded[1..].split_at(usize::from(padded[0]));
    if padding.iter().any(|&byte| byte != 0) {
        return Err(CoreError::Corrupt);
    }
    String::from_utf8(text.to_vec()).map_err(|_| CoreError::Corrupt)
}

/// Seals an item's list label (padded, [`pad_label`]) at the item's content
/// version under the vault key with a fresh nonce. An empty label is sealed
/// too, so a label file's presence does not say whether a username exists.
pub fn seal_label(
    key: &[u8; 32],
    item_id: &str,
    version: u32,
    label: &str,
) -> Result<Vec<u8>, CoreError> {
    seal_label_with(key, item_id, version, label, store::random_array()?)
}

/// [`seal_label`] with the nonce supplied — the golden test pins its output.
pub(crate) fn seal_label_with(
    key: &[u8; 32],
    item_id: &str,
    version: u32,
    label: &str,
    nonce: [u8; 24],
) -> Result<Vec<u8>, CoreError> {
    let padded = pad_label(label);
    let ciphertext = store::seal(key, &nonce, &label_aad(item_id, version)?, &padded)?;
    Ok(LocalSeal { nonce, ciphertext }.encode())
}

/// The padded plaintext of a label blob, checked to be a label's shape.
fn open_label_padded(
    key: &[u8; 32],
    item_id: &str,
    version: u32,
    blob: &[u8],
) -> Result<Zeroizing<Vec<u8>>, CoreError> {
    let sealed = LocalSeal::decode(blob)?;
    let padded = Zeroizing::new(store::open(
        key,
        &sealed.nonce,
        &label_aad(item_id, version)?,
        &sealed.ciphertext,
    )?);
    unpad_label(&padded)?;
    Ok(padded)
}

/// Inverse of [`seal_label`] for the same item and version; a tampered blob,
/// another key, item, version, an item blob or a malformed padding is
/// `Corrupt`.
pub fn open_label(
    key: &[u8; 32],
    item_id: &str,
    version: u32,
    blob: &[u8],
) -> Result<String, CoreError> {
    unpad_label(&open_label_padded(key, item_id, version, blob)?)
}

/// Moves a label from the vault key `from` to `to` (same item, same version,
/// fresh nonce); the label stays in Rust and is wiped.
pub fn reseal_label(
    from: &[u8; 32],
    to: &[u8; 32],
    item_id: &str,
    version: u32,
    blob: &[u8],
) -> Result<Vec<u8>, CoreError> {
    let padded = open_label_padded(from, item_id, version, blob)?;
    let nonce = store::random_array()?;
    let ciphertext = store::seal(to, &nonce, &label_aad(item_id, version)?, &padded)?;
    Ok(LocalSeal { nonce, ciphertext }.encode())
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

    /// XChaCha20-Poly1305(vault key 0x33×32, nonce 0x44×24, AAD `vault-label`
    /// ‖ u32 BE 3 ‖ item id, `04` ‖ "user" ‖ 251 zero bytes), computed with
    /// pycryptodome from the spec — the `vault_label` vector.
    const GOLDEN_LABEL_HEX: &str = concat!(
        "46555a5a0120",
        "444444444444444444444444444444444444444444444444",
        "1cd303b142e2378392704b1e10d7c2a73e02e23820d2474105b0d753b2074603",
        "d4b14bdc99655c9c9bdc0ddfd3a8ef2ed11878e3e25d7b6298e55c5c888e4281",
        "6a92e0c72cf58531ce113e0ff08ee04c671f3aef25c4a4a3d00485d44a1f55ac",
        "29ea5a9789cc9a6c4445b094ea7bf946755ff30aa5d7048508f4a3847895c26d",
        "5f4125c13d04df95ebff7382750180fef0f59e2014f1cef3160e7b58019484c5",
        "e21e495538fb2758724a3633580c902afde0c0d60e1b5b1d06a7be62c8046479",
        "eb705964c7cc7bc92cb50ae70a89f1fbbba53202d9fb0b1d5288d73e3e3f4d8b",
        "c2a640cc902ab6418148396b39a6e9a34b63779e146a750319235a3760733fff",
        "fffda726278314b87272786675075d1c",
    );

    #[test]
    fn golden_label() {
        let blob = seal_label_with(&KEY, ITEM, 3, "user", [0x44; 24]).unwrap();
        assert_eq!(blob, hex(GOLDEN_LABEL_HEX));
        assert_eq!(
            open_label(&KEY, ITEM, 3, &hex(GOLDEN_LABEL_HEX)).unwrap(),
            "user"
        );
    }

    /// Security review 2026-10-26: a label file's size says nothing about the
    /// label's length, nor whether there is one.
    #[test]
    fn every_label_has_one_size() {
        let size = 6 + 24 + LABEL_PADDED_LEN + 16;
        for label in ["", "a", "tamar@mail.ge", &"x".repeat(LABEL_MAX_LEN)] {
            let blob = seal_label(&KEY, ITEM, 1, label).unwrap();
            assert_eq!(blob.len(), size, "{label:?}");
            assert_eq!(open_label(&KEY, ITEM, 1, &blob).unwrap(), label);
        }
        // Longer labels are cut to the limit, never mid-character.
        let long = seal_label(&KEY, ITEM, 1, &"y".repeat(400)).unwrap();
        assert_eq!(long.len(), size);
        assert_eq!(open_label(&KEY, ITEM, 1, &long).unwrap(), "y".repeat(255));
        let georgian = "ა".repeat(100); // 3 bytes each: 300 bytes
        let cut = open_label(
            &KEY,
            ITEM,
            1,
            &seal_label(&KEY, ITEM, 1, &georgian).unwrap(),
        )
        .unwrap();
        assert_eq!(cut, "ა".repeat(85), "255 bytes is 85 whole letters");
    }

    /// A label is sealed in its own domain: it never opens as an item, an item
    /// never opens as a label, and a label is bound to its item and version.
    #[test]
    fn label_and_item_domains_are_separate() {
        let label = seal_label(&KEY, ITEM, 3, "user").unwrap();
        let item = seal_item(&KEY, ITEM, 3, b"item").unwrap();
        assert_eq!(
            open_item(&KEY, ITEM, 3, &label).unwrap_err(),
            CoreError::Corrupt
        );
        assert_eq!(
            open_label(&KEY, ITEM, 3, &item).unwrap_err(),
            CoreError::Corrupt
        );
        assert_eq!(
            open_label(&KEY, "0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d", 3, &label).unwrap_err(),
            CoreError::Corrupt,
            "another item's label"
        );
        assert_eq!(
            open_label(&KEY, ITEM, 4, &label).unwrap_err(),
            CoreError::Corrupt,
            "an older label"
        );
        assert_eq!(
            open_label(&[0x34; 32], ITEM, 3, &label).unwrap_err(),
            CoreError::Corrupt
        );
        let mut tampered = label.clone();
        tampered[40] ^= 1;
        assert_eq!(
            open_label(&KEY, ITEM, 3, &tampered).unwrap_err(),
            CoreError::Corrupt
        );
        assert_eq!(
            seal_label(&KEY, "", 3, "user").unwrap_err(),
            CoreError::Corrupt
        );
    }

    /// Anything sealed in the label domain that is not a padded label is
    /// refused: wrong length, a stray byte in the padding, broken UTF-8.
    #[test]
    fn a_label_of_another_shape_does_not_open() {
        let sealed = |plain: &[u8]| {
            let nonce = [0x44; 24];
            let ciphertext =
                store::seal(&KEY, &nonce, &label_aad(ITEM, 1).unwrap(), plain).unwrap();
            LocalSeal { nonce, ciphertext }.encode()
        };
        let mut stray = vec![0u8; LABEL_PADDED_LEN];
        stray[0] = 1;
        stray[1] = b'a';
        stray[200] = 1;
        let mut broken = vec![0u8; LABEL_PADDED_LEN];
        broken[0] = 1;
        broken[1] = 0xff;
        for plain in [
            b"user".to_vec(),
            vec![0u8; 255],
            vec![0u8; 257],
            stray,
            broken,
        ] {
            assert_eq!(
                open_label(&KEY, ITEM, 1, &sealed(&plain)).unwrap_err(),
                CoreError::Corrupt
            );
        }
        assert_eq!(
            open_label(&KEY, ITEM, 1, &sealed(&[0u8; LABEL_PADDED_LEN])).unwrap(),
            ""
        );
    }

    #[test]
    fn reseal_label_moves_it_to_the_new_key() {
        let next = [0x35; 32];
        let before = seal_label(&KEY, ITEM, 2, "tamar@mail.ge").unwrap();
        let after = reseal_label(&KEY, &next, ITEM, 2, &before).unwrap();
        assert_eq!(after.len(), before.len());
        assert_eq!(open_label(&next, ITEM, 2, &after).unwrap(), "tamar@mail.ge");
        assert_eq!(
            open_label(&KEY, ITEM, 2, &after).unwrap_err(),
            CoreError::Corrupt,
            "the old key opens no moved label"
        );
        // An item blob is not a label: it does not move as one.
        let item = seal_item(&KEY, ITEM, 2, b"item").unwrap();
        assert_eq!(
            reseal_label(&KEY, &next, ITEM, 2, &item).unwrap_err(),
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
