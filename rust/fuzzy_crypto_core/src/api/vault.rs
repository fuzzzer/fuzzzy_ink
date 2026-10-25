use flutter_rust_bridge::frb;
use zeroize::Zeroizing;

use crate::error::CoreError;
use crate::master;
use crate::store::Key32;
use crate::vault;

/// The opaque handle Dart holds while the vault is unlocked (plan §D, F-8).
///
/// Owns the 32-byte vault key; it never crosses the FFI — there is no getter,
/// no serde derive, no `Debug`. `close` drops it (zeroised) and every later item
/// call answers `StoreLocked` — the handle stays valid, only empty.
#[frb(opaque)]
pub struct VaultKey {
    inner: Option<Key32>,
}

/// What [`vault_init`] and [`vault_init_with_master`] hand back: the unlocked
/// key and its wrapping, which the app stores in the vault metadata and feeds
/// to the unlock call later. `non_opaque` so frb passes the two fields once
/// instead of wrapping the struct in a second handle with a cloning accessor
/// for the key.
#[frb(non_opaque)]
pub struct VaultInitResult {
    pub key: VaultKey,
    /// The vault key wrapped: a 0x20 under the master key, or a 0x10 under
    /// the vault's own password.
    pub wrapped: Vec<u8>,
}

/// Draws a fresh vault key and wraps it under the master key (the default:
/// the master password opens the vault). `password_wrap` is the master key's
/// 0x10 blob; one Argon2id run. Wrong master password is `WrongPassword`.
pub fn vault_init_with_master(
    password_wrap: Vec<u8>,
    master_password: String,
) -> Result<VaultInitResult, CoreError> {
    let master_password = Zeroizing::new(master_password.into_bytes());
    let master_key = master::unwrap_with_password(&password_wrap, &master_password)?;
    let (key, wrapped) = vault::init_under_master(&master_key)?;
    Ok(VaultInitResult {
        key: VaultKey { inner: Some(key) },
        wrapped,
    })
}

/// Draws a fresh vault key and wraps it under the vault's own `password`.
/// Password strength is the app's judgement, not this function's; an empty
/// password is refused (`WrongPassword`).
pub fn vault_init(password: String) -> Result<VaultInitResult, CoreError> {
    let password = Zeroizing::new(password.into_bytes());
    let (key, wrapped) = vault::init(&password)?;
    Ok(VaultInitResult {
        key: VaultKey { inner: Some(key) },
        wrapped,
    })
}

/// Which password opens the vault whose key is `wrapped`: `true` for its own
/// password (0x10), `false` for the master password (0x20). Reads the type
/// byte only — no key is touched, so it may be synchronous.
#[frb(sync)]
pub fn vault_uses_own_password(wrapped: Vec<u8>) -> Result<bool, CoreError> {
    Ok(vault::wrapping_of(&wrapped)? == vault::Wrapping::OwnPassword)
}

/// Unwraps a vault key wrapped under its own password; a wrong password (or a
/// tampered blob) is `WrongPassword`.
pub fn vault_unlock(password: String, wrapped: Vec<u8>) -> Result<VaultKey, CoreError> {
    let password = Zeroizing::new(password.into_bytes());
    let key = vault::unlock(&password, &wrapped)?;
    Ok(VaultKey { inner: Some(key) })
}

/// Unwraps a vault key wrapped under the master key: the master password
/// opens `password_wrap` (one Argon2id run; wrong is `WrongPassword`), the
/// master key opens `wrapped` (foreign or tampered is `Corrupt`).
pub fn vault_unlock_with_master(
    password_wrap: Vec<u8>,
    master_password: String,
    wrapped: Vec<u8>,
) -> Result<VaultKey, CoreError> {
    let master_password = Zeroizing::new(master_password.into_bytes());
    let master_key = master::unwrap_with_password(&password_wrap, &master_password)?;
    let key = vault::unlock_under_master(&master_key, &wrapped)?;
    Ok(VaultKey { inner: Some(key) })
}

/// Re-wraps a vault key under its own password from `old_password` to
/// `new_password` (fresh salt and nonce). Because the key does not change, no
/// vault item needs re-encryption; the caller replaces the stored blob.
pub fn vault_rewrap(
    old_password: String,
    new_password: String,
    wrapped: Vec<u8>,
) -> Result<Vec<u8>, CoreError> {
    let old_password = Zeroizing::new(old_password.into_bytes());
    let new_password = Zeroizing::new(new_password.into_bytes());
    vault::rewrap(&old_password, &new_password, &wrapped)
}

/// Gives a vault that the master password opens its own password: the master
/// password opens the vault key's 0x20 `wrapped`, the key is wrapped again as
/// a 0x10 under `new_password`. Two Argon2id runs; the caller replaces the
/// stored blob, after which the master password no longer opens the vault.
pub fn vault_use_own_password(
    password_wrap: Vec<u8>,
    master_password: String,
    wrapped: Vec<u8>,
    new_password: String,
) -> Result<Vec<u8>, CoreError> {
    let master_password = Zeroizing::new(master_password.into_bytes());
    let new_password = Zeroizing::new(new_password.into_bytes());
    master::refuse_empty(&new_password)?;
    let master_key = master::unwrap_with_password(&password_wrap, &master_password)?;
    let key = vault::unlock_under_master(&master_key, &wrapped)?;
    drop(master_key);
    vault::wrap(&key, &new_password)
}

/// The way back: the vault's own password opens its 0x10 `wrapped`, the
/// master password opens the master key, and the vault key is wrapped under
/// it as a 0x20. Two Argon2id runs; the caller replaces the stored blob.
pub fn vault_use_master_password(
    wrapped: Vec<u8>,
    vault_password: String,
    password_wrap: Vec<u8>,
    master_password: String,
) -> Result<Vec<u8>, CoreError> {
    let vault_password = Zeroizing::new(vault_password.into_bytes());
    let master_password = Zeroizing::new(master_password.into_bytes());
    let key = vault::unlock(&vault_password, &wrapped)?;
    let master_key = master::unwrap_with_password(&password_wrap, &master_password)?;
    vault::wrap_under_master(&master_key, &key)
}

/// Seals version `version` of the item `item_id` under the vault key: a 0x20
/// blob with a fresh nonce and AAD `vault-item` ‖ u32 BE version ‖ item id.
pub fn vault_seal(
    key: &VaultKey,
    item_id: String,
    version: u32,
    bytes: Vec<u8>,
) -> Result<Vec<u8>, CoreError> {
    vault::seal_item(key.unlocked()?, &item_id, version, &bytes)
}

/// Inverse of [`vault_seal`] for the same item and version; a tampered or
/// foreign blob — another item's, or another version's — is `Corrupt`.
pub fn vault_open(
    key: &VaultKey,
    item_id: String,
    version: u32,
    blob: Vec<u8>,
) -> Result<Vec<u8>, CoreError> {
    vault::open_item(key.unlocked()?, &item_id, version, &blob)
}

impl VaultKey {
    fn unlocked(&self) -> Result<&[u8; 32], CoreError> {
        self.inner.as_deref().ok_or(CoreError::StoreLocked)
    }

    /// Drops the vault key (zeroised). Later `vault_seal`/`vault_open` calls
    /// on this handle answer `StoreLocked`; a second `close` is a no-op.
    pub fn close(&mut self) {
        self.inner = None;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::store::test_support::err_of;

    const ITEM: &str = "6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d";

    fn master_wrap(password: &str) -> Vec<u8> {
        let master_key = master::new_key().unwrap();
        master::wrap_with_password(&master_key, password.as_bytes()).unwrap()
    }

    #[test]
    fn init_seal_rewrap_unlock_open_through_the_api() {
        let VaultInitResult { key, wrapped } = vault_init("pw".into()).unwrap();
        assert!(vault_uses_own_password(wrapped.clone()).unwrap());
        let item = vault_seal(&key, ITEM.into(), 1, b"item".to_vec()).unwrap();
        assert_eq!(
            vault_open(&key, ITEM.into(), 1, item.clone()).unwrap(),
            b"item"
        );

        let rewrapped = vault_rewrap("pw".into(), "new".into(), wrapped.clone()).unwrap();
        assert_eq!(
            err_of(vault_unlock("pw".into(), rewrapped.clone())),
            CoreError::WrongPassword
        );
        let reopened = vault_unlock("new".into(), rewrapped).unwrap();
        assert_eq!(
            vault_open(&reopened, ITEM.into(), 1, item.clone()).unwrap(),
            b"item"
        );

        let mut tampered = item;
        tampered[35] ^= 1;
        assert_eq!(
            vault_open(&reopened, ITEM.into(), 1, tampered).unwrap_err(),
            CoreError::Corrupt
        );
        assert_eq!(
            err_of(vault_unlock("nope".into(), wrapped)),
            CoreError::WrongPassword
        );
    }

    #[test]
    fn the_master_password_opens_the_vault_by_default() {
        let password_wrap = master_wrap("master");
        let VaultInitResult { key, wrapped } =
            vault_init_with_master(password_wrap.clone(), "master".into()).unwrap();
        assert!(!vault_uses_own_password(wrapped.clone()).unwrap());
        let item = vault_seal(&key, ITEM.into(), 1, b"secret".to_vec()).unwrap();

        let reopened =
            vault_unlock_with_master(password_wrap.clone(), "master".into(), wrapped.clone())
                .unwrap();
        assert_eq!(
            vault_open(&reopened, ITEM.into(), 1, item).unwrap(),
            b"secret"
        );
        assert_eq!(
            err_of(vault_unlock_with_master(
                password_wrap.clone(),
                "wrong".into(),
                wrapped.clone()
            )),
            CoreError::WrongPassword
        );
        assert_eq!(
            err_of(vault_init_with_master(password_wrap, "wrong".into())),
            CoreError::WrongPassword
        );
        // Another device's master key does not open this vault key.
        let other = master_wrap("master");
        assert_eq!(
            err_of(vault_unlock_with_master(other, "master".into(), wrapped)),
            CoreError::Corrupt
        );
    }

    #[test]
    fn own_password_and_back_keep_every_item() {
        let password_wrap = master_wrap("master");
        let VaultInitResult { key, wrapped } =
            vault_init_with_master(password_wrap.clone(), "master".into()).unwrap();
        let item = vault_seal(&key, ITEM.into(), 2, b"kept".to_vec()).unwrap();

        assert_eq!(
            vault_use_own_password(
                password_wrap.clone(),
                "wrong".into(),
                wrapped.clone(),
                "vault".into()
            )
            .unwrap_err(),
            CoreError::WrongPassword
        );
        assert_eq!(
            vault_use_own_password(
                password_wrap.clone(),
                "master".into(),
                wrapped.clone(),
                "".into()
            )
            .unwrap_err(),
            CoreError::WrongPassword
        );
        let own = vault_use_own_password(
            password_wrap.clone(),
            "master".into(),
            wrapped,
            "vault".into(),
        )
        .unwrap();
        assert!(vault_uses_own_password(own.clone()).unwrap());
        // The master password no longer opens it; its own password does.
        assert_eq!(
            err_of(vault_unlock_with_master(
                password_wrap.clone(),
                "master".into(),
                own.clone()
            )),
            CoreError::UnsupportedFormat
        );
        assert_eq!(
            err_of(vault_unlock("master".into(), own.clone())),
            CoreError::WrongPassword
        );
        let by_own = vault_unlock("vault".into(), own.clone()).unwrap();
        assert_eq!(
            vault_open(&by_own, ITEM.into(), 2, item.clone()).unwrap(),
            b"kept"
        );

        assert_eq!(
            vault_use_master_password(
                own.clone(),
                "wrong".into(),
                password_wrap.clone(),
                "master".into()
            )
            .unwrap_err(),
            CoreError::WrongPassword
        );
        assert_eq!(
            vault_use_master_password(
                own.clone(),
                "vault".into(),
                password_wrap.clone(),
                "wrong".into()
            )
            .unwrap_err(),
            CoreError::WrongPassword
        );
        let back =
            vault_use_master_password(own, "vault".into(), password_wrap.clone(), "master".into())
                .unwrap();
        assert!(!vault_uses_own_password(back.clone()).unwrap());
        let by_master = vault_unlock_with_master(password_wrap, "master".into(), back).unwrap();
        assert_eq!(
            vault_open(&by_master, ITEM.into(), 2, item).unwrap(),
            b"kept"
        );
    }

    #[test]
    fn vault_uses_own_password_refuses_other_blobs() {
        assert_eq!(
            vault_uses_own_password(vec![]).unwrap_err(),
            CoreError::UnsupportedFormat
        );
        assert_eq!(
            vault_uses_own_password(b"FUZZ\x01\x05".to_vec()).unwrap_err(),
            CoreError::UnsupportedFormat
        );
    }

    #[test]
    fn close_zeroises_and_later_calls_fail_cleanly() {
        let VaultInitResult { mut key, .. } = vault_init("pw".into()).unwrap();
        let item = vault_seal(&key, ITEM.into(), 1, b"x".to_vec()).unwrap();

        key.close();

        assert_eq!(
            vault_seal(&key, ITEM.into(), 1, b"x".to_vec()).unwrap_err(),
            CoreError::StoreLocked
        );
        assert_eq!(
            vault_open(&key, ITEM.into(), 1, item).unwrap_err(),
            CoreError::StoreLocked
        );
        key.close();
        assert!(key.inner.is_none());
    }

    /// The review item made checkable: nothing in the vault, master-key or
    /// password API hands raw key bytes to Dart, and `VaultKey` exposes no field.
    #[test]
    fn key_never_serialises() {
        let library_part =
            |source: &'static str| source.split("#[cfg(test)]").next().unwrap_or_default();
        let vault_api = library_part(include_str!("vault.rs"));
        let core_api = library_part(include_str!("core.rs"));
        let passwords_api = library_part(include_str!("passwords.rs"));
        for api in [vault_api, core_api] {
            for line in api.lines().filter(|line| line.contains("pub fn")) {
                assert!(!line.contains("[u8; 32]"), "{line}");
                assert!(!line.contains("Key32"), "{line}");
            }
        }
        assert!(!vault_api.contains("pub inner"));
        assert!(!vault_api.contains("derive("));
        assert!(!core_api.contains("derive("));
        for source in [vault_api, core_api, passwords_api] {
            assert!(!source.contains("Serialize"));
        }
        // The one synchronous vault function reads a type byte, never a key.
        assert_eq!(vault_api.matches("frb(sync)").count(), 1);
        assert!(!core_api.contains("frb(sync)"));
        assert!(!passwords_api.contains("frb(sync)"));
    }
}
