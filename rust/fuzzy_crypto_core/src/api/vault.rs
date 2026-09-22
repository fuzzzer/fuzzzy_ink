use flutter_rust_bridge::frb;
use zeroize::Zeroizing;

use crate::error::CoreError;
use crate::store::Key32;
use crate::vault;

/// The opaque handle Dart holds while the vault is unlocked (plan §D, F-8).
///
/// Owns the 32-byte master key; it never crosses the FFI — there is no getter,
/// no serde derive, no `Debug`. `close` drops it (zeroised) and every later item
/// call answers `StoreLocked` — the handle stays valid, only empty.
#[frb(opaque)]
pub struct VaultKey {
    inner: Option<Key32>,
}

/// What [`vault_init`] hands back: the unlocked key and its wrapping, which
/// the app stores in the vault metadata and feeds to [`vault_unlock`] later.
/// `non_opaque` so frb passes the two fields once instead of wrapping the
/// struct in a second handle with a cloning accessor for the key.
#[frb(non_opaque)]
pub struct VaultInitResult {
    pub key: VaultKey,
    /// A 0x10 blob — the master key wrapped under the vault password.
    pub wrapped: Vec<u8>,
}

/// Draws a fresh master key and wraps it under `password`. Password strength
/// is the app's judgement, not this function's.
pub fn vault_init(password: String) -> Result<VaultInitResult, CoreError> {
    let password = Zeroizing::new(password.into_bytes());
    let (key, wrapped) = vault::init(&password)?;
    Ok(VaultInitResult {
        key: VaultKey { inner: Some(key) },
        wrapped,
    })
}

/// Unwraps the master key; a wrong password (or a tampered blob) is `WrongPassword`.
pub fn vault_unlock(password: String, wrapped: Vec<u8>) -> Result<VaultKey, CoreError> {
    let password = Zeroizing::new(password.into_bytes());
    let key = vault::unlock(&password, &wrapped)?;
    Ok(VaultKey { inner: Some(key) })
}

/// Re-wraps the same master key under `new_password` (fresh salt and nonce).
/// Because the key does not change, no vault item needs re-encryption; the
/// caller replaces the stored blob and keeps every item as it is.
pub fn vault_rewrap(
    old_password: String,
    new_password: String,
    wrapped: Vec<u8>,
) -> Result<Vec<u8>, CoreError> {
    let old_password = Zeroizing::new(old_password.into_bytes());
    let new_password = Zeroizing::new(new_password.into_bytes());
    vault::rewrap(&old_password, &new_password, &wrapped)
}

/// Seals one item under the master key: a 0x20 blob with a fresh nonce and
/// AAD `vault-item`.
pub fn vault_seal(key: &VaultKey, bytes: Vec<u8>) -> Result<Vec<u8>, CoreError> {
    vault::seal_item(key.unlocked()?, &bytes)
}

/// Inverse of [`vault_seal`]; a tampered or foreign blob is `Corrupt`.
pub fn vault_open(key: &VaultKey, blob: Vec<u8>) -> Result<Vec<u8>, CoreError> {
    vault::open_item(key.unlocked()?, &blob)
}

impl VaultKey {
    fn unlocked(&self) -> Result<&[u8; 32], CoreError> {
        self.inner.as_deref().ok_or(CoreError::StoreLocked)
    }

    /// Drops the master key (zeroised). Later `vault_seal`/`vault_open` calls
    /// on this handle answer `StoreLocked`; a second `close` is a no-op.
    pub fn close(&mut self) {
        self.inner = None;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::store::test_support::err_of;

    #[test]
    fn init_seal_rewrap_unlock_open_through_the_api() {
        let VaultInitResult { key, wrapped } = vault_init("pw".into()).unwrap();
        let item = vault_seal(&key, b"item".to_vec()).unwrap();
        assert_eq!(vault_open(&key, item.clone()).unwrap(), b"item");

        let rewrapped = vault_rewrap("pw".into(), "new".into(), wrapped.clone()).unwrap();
        assert_eq!(
            err_of(vault_unlock("pw".into(), rewrapped.clone())),
            CoreError::WrongPassword
        );
        let reopened = vault_unlock("new".into(), rewrapped).unwrap();
        assert_eq!(vault_open(&reopened, item.clone()).unwrap(), b"item");

        let mut tampered = item;
        tampered[35] ^= 1;
        assert_eq!(
            vault_open(&reopened, tampered).unwrap_err(),
            CoreError::Corrupt
        );
        assert_eq!(
            err_of(vault_unlock("nope".into(), wrapped)),
            CoreError::WrongPassword
        );
    }

    #[test]
    fn close_zeroises_and_later_calls_fail_cleanly() {
        let VaultInitResult { mut key, .. } = vault_init("".into()).unwrap();
        let item = vault_seal(&key, b"x".to_vec()).unwrap();

        key.close();

        assert_eq!(
            vault_seal(&key, b"x".to_vec()).unwrap_err(),
            CoreError::StoreLocked
        );
        assert_eq!(vault_open(&key, item).unwrap_err(), CoreError::StoreLocked);
        key.close();
        assert!(key.inner.is_none());
    }

    /// The review item made checkable: nothing in the vault or password API
    /// hands raw key bytes to Dart, and `VaultKey` exposes no field.
    #[test]
    fn key_never_serialises() {
        let library_part =
            |source: &'static str| source.split("#[cfg(test)]").next().unwrap_or_default();
        let vault_api = library_part(include_str!("vault.rs"));
        let passwords_api = library_part(include_str!("passwords.rs"));
        for line in vault_api.lines().filter(|line| line.contains("pub fn")) {
            assert!(!line.contains("[u8; 32]"), "{line}");
            assert!(!line.contains("Key32"), "{line}");
        }
        assert!(!vault_api.contains("pub inner"));
        assert!(!vault_api.contains("derive("));
        for source in [vault_api, passwords_api] {
            assert!(!source.contains("frb(sync)"));
            assert!(!source.contains("Serialize"));
        }
    }
}
