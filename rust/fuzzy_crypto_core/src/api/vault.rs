use flutter_rust_bridge::frb;
use zeroize::Zeroizing;

use crate::api::core::CryptoCore;
use crate::error::CoreError;
use crate::master::{self, RecoveryKey};
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
    /// 0x11 — the vault key sealed to the recovery lock, so the recovery key
    /// opens a vault with its own password. `None` under the master key
    /// (the recovery key reaches it through the master key) and without a
    /// recovery key.
    pub recovery: Option<Vec<u8>>,
}

/// What [`vault_use_own_password`] hands back: the vault key under its new
/// password, and sealed to the recovery lock when a recovery key is kept.
#[frb(non_opaque)]
pub struct VaultOwnPassword {
    pub wrapped: Vec<u8>,
    pub recovery: Option<Vec<u8>>,
}

/// What the recovery key opens a vault into: the unlocked key and the vault
/// key's new wrapping, which replaces the stored one.
#[frb(non_opaque)]
pub struct VaultRecovered {
    pub key: VaultKey,
    pub wrapped: Vec<u8>,
}

/// The recovery copy of `key`: sealed to the lock that `recovery_lock` (a
/// 0x20 under the store key of `core`) carries; `None` without a lock.
fn recovery_copy(
    core: &CryptoCore,
    recovery_lock: Option<&[u8]>,
    key: &[u8; 32],
) -> Result<Option<Vec<u8>>, CoreError> {
    match recovery_lock {
        None => Ok(None),
        Some(blob) => {
            let lock = core.opened()?.open_recovery_lock(blob)?;
            Ok(Some(vault::seal_for_recovery(&lock, key)?))
        }
    }
}

/// Opens the recovery lock early, so a bad lock costs no Argon2id run.
fn check_lock(core: &CryptoCore, recovery_lock: Option<&[u8]>) -> Result<(), CoreError> {
    if let Some(blob) = recovery_lock {
        core.opened()?.open_recovery_lock(blob)?;
    }
    Ok(())
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
        recovery: None,
    })
}

/// Draws a fresh vault key and wraps it under the vault's own `password`,
/// and — with a `recovery_lock` (the 0x20 the first run or a new recovery key
/// left, opened with the store key of `core`) — seals it to the recovery
/// lock too. Password strength is the app's judgement, not this function's;
/// an empty password is refused (`WrongPassword`).
pub fn vault_init(
    core: &CryptoCore,
    password: String,
    recovery_lock: Option<Vec<u8>>,
) -> Result<VaultInitResult, CoreError> {
    let password = Zeroizing::new(password.into_bytes());
    check_lock(core, recovery_lock.as_deref())?;
    let (key, wrapped) = vault::init(&password)?;
    let recovery = recovery_copy(core, recovery_lock.as_deref(), &key)?;
    Ok(VaultInitResult {
        key: VaultKey { inner: Some(key) },
        wrapped,
        recovery,
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
/// a 0x10 under `new_password` and, with a `recovery_lock`, sealed to the
/// recovery lock. Two Argon2id runs; the caller replaces the stored blobs,
/// after which the master password no longer opens the vault — the recovery
/// key still does.
pub fn vault_use_own_password(
    core: &CryptoCore,
    password_wrap: Vec<u8>,
    master_password: String,
    wrapped: Vec<u8>,
    new_password: String,
    recovery_lock: Option<Vec<u8>>,
) -> Result<VaultOwnPassword, CoreError> {
    let master_password = Zeroizing::new(master_password.into_bytes());
    let new_password = Zeroizing::new(new_password.into_bytes());
    master::refuse_empty(&new_password)?;
    check_lock(core, recovery_lock.as_deref())?;
    let master_key = master::unwrap_with_password(&password_wrap, &master_password)?;
    let key = vault::unlock_under_master(&master_key, &wrapped)?;
    drop(master_key);
    Ok(VaultOwnPassword {
        wrapped: vault::wrap(&key, &new_password)?,
        recovery: recovery_copy(core, recovery_lock.as_deref(), &key)?,
    })
}

/// Seals the key of a vault with its own password to a (new) recovery lock:
/// the vault password opens `wrapped` (one Argon2id run), the lock comes from
/// `recovery_lock` under the store key of `core`. Used after a new recovery
/// key, so the new key opens the vault too. A vault under the master key
/// needs no copy (`UnsupportedFormat`).
pub fn vault_seal_for_recovery(
    core: &CryptoCore,
    recovery_lock: Vec<u8>,
    wrapped: Vec<u8>,
    vault_password: String,
) -> Result<Vec<u8>, CoreError> {
    let vault_password = Zeroizing::new(vault_password.into_bytes());
    let lock = core.opened()?.open_recovery_lock(&recovery_lock)?;
    let key = vault::unlock(&vault_password, &wrapped)?;
    vault::seal_for_recovery(&lock, &key)
}

/// The recovery key opens a vault with its own password and gives it
/// `new_password`: the typed `recovery_key` (a typo is `Corrupt`) opens the
/// 0x11 `recovery` (another device's key is `WrongPassword`), and the vault
/// key is wrapped under `new_password` (one Argon2id run). The key does not
/// change, so `recovery` stays valid and no item is re-encrypted; the caller
/// replaces the stored wrapping.
pub fn vault_recover(
    recovery: Vec<u8>,
    recovery_key: String,
    new_password: String,
) -> Result<VaultRecovered, CoreError> {
    let recovery_key = Zeroizing::new(recovery_key);
    let new_password = Zeroizing::new(new_password.into_bytes());
    master::refuse_empty(&new_password)?;
    let recovery_key = RecoveryKey::parse(&recovery_key)?;
    let key = vault::unlock_with_recovery(&recovery, &recovery_key)?;
    let wrapped = vault::wrap(&key, &new_password)?;
    Ok(VaultRecovered {
        key: VaultKey { inner: Some(key) },
        wrapped,
    })
}

/// The recovery key opens a vault with its own password and puts it back
/// under the master key: the typed `recovery_key` opens the 0x11 `recovery`
/// and the master key's `recovery_wrap` (one Argon2id run), and the vault key
/// is wrapped under the master key (a 0x20). The caller replaces the stored
/// wrapping; the master password opens the vault from then on.
pub fn vault_recover_to_master(
    recovery_wrap: Vec<u8>,
    recovery: Vec<u8>,
    recovery_key: String,
) -> Result<VaultRecovered, CoreError> {
    let recovery_key = Zeroizing::new(recovery_key);
    let recovery_key = RecoveryKey::parse(&recovery_key)?;
    let key = vault::unlock_with_recovery(&recovery, &recovery_key)?;
    let master_key = master::unwrap_with_recovery(&recovery_wrap, &recovery_key)?;
    let wrapped = vault::wrap_under_master(&master_key, &key)?;
    Ok(VaultRecovered {
        key: VaultKey { inner: Some(key) },
        wrapped,
    })
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
    use std::fs;
    use std::path::PathBuf;

    use super::*;
    use crate::api::core::{create_master_key, new_recovery_key, MasterKeySetup};
    use crate::store::test_support::{err_of, temp_dir};

    const ITEM: &str = "6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d";

    fn master_wrap(password: &str) -> Vec<u8> {
        let master_key = master::new_key().unwrap();
        master::wrap_with_password(&master_key, password.as_bytes()).unwrap()
    }

    /// A first run with the master password `master`: an open store, the
    /// master key's wraps, the recovery lock and the recovery key.
    fn device() -> (PathBuf, MasterKeySetup) {
        let dir = temp_dir();
        let setup = create_master_key(dir.to_string_lossy().into_owned(), "master".into()).unwrap();
        (dir, setup)
    }

    #[test]
    fn init_seal_rewrap_unlock_open_through_the_api() {
        let (dir, setup) = device();
        let VaultInitResult {
            key,
            wrapped,
            recovery,
        } = vault_init(&setup.core, "pw".into(), None).unwrap();
        assert!(recovery.is_none(), "no lock given, no recovery copy");
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
        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn the_master_password_opens_the_vault_by_default() {
        let password_wrap = master_wrap("master");
        let VaultInitResult {
            key,
            wrapped,
            recovery,
        } = vault_init_with_master(password_wrap.clone(), "master".into()).unwrap();
        assert!(
            recovery.is_none(),
            "the master key carries the recovery path"
        );
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
        let (dir, setup) = device();
        let password_wrap = setup.password_wrap.clone();
        let VaultInitResult { key, wrapped, .. } =
            vault_init_with_master(password_wrap.clone(), "master".into()).unwrap();
        let item = vault_seal(&key, ITEM.into(), 2, b"kept".to_vec()).unwrap();

        assert_eq!(
            err_of(vault_use_own_password(
                &setup.core,
                password_wrap.clone(),
                "wrong".into(),
                wrapped.clone(),
                "vault".into(),
                None
            )),
            CoreError::WrongPassword
        );
        assert_eq!(
            err_of(vault_use_own_password(
                &setup.core,
                password_wrap.clone(),
                "master".into(),
                wrapped.clone(),
                "".into(),
                None
            )),
            CoreError::WrongPassword
        );
        let VaultOwnPassword {
            wrapped: own,
            recovery,
        } = vault_use_own_password(
            &setup.core,
            password_wrap.clone(),
            "master".into(),
            wrapped,
            "vault".into(),
            None,
        )
        .unwrap();
        assert!(recovery.is_none());
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
        let _ = fs::remove_dir_all(dir);
    }

    /// The owner's rule (2026-10-26): the recovery key also opens a vault with
    /// its own password; the master password alone still does not.
    #[test]
    fn the_recovery_key_opens_a_vault_with_its_own_password() {
        let (dir, setup) = device();
        let VaultInitResult { key, wrapped, .. } =
            vault_init_with_master(setup.password_wrap.clone(), "master".into()).unwrap();
        let item = vault_seal(&key, ITEM.into(), 1, b"passport".to_vec()).unwrap();
        let VaultOwnPassword {
            wrapped: own,
            recovery,
        } = vault_use_own_password(
            &setup.core,
            setup.password_wrap.clone(),
            "master".into(),
            wrapped,
            "vault".into(),
            Some(setup.recovery_lock.clone()),
        )
        .unwrap();
        let recovery = recovery.expect("a recovery copy when a lock is kept");
        assert_eq!(recovery.len(), 110);

        // The master password alone: no way in.
        assert_eq!(
            err_of(vault_unlock_with_master(
                setup.password_wrap.clone(),
                "master".into(),
                own.clone()
            )),
            CoreError::UnsupportedFormat
        );
        assert_eq!(
            err_of(vault_unlock("master".into(), own.clone())),
            CoreError::WrongPassword
        );

        // The recovery key, with a new vault password: same key, every item opens.
        let typed = setup.recovery_key.to_lowercase();
        let VaultRecovered {
            key: reopened,
            wrapped: renewed,
        } = vault_recover(recovery.clone(), typed.clone(), "fresh".into()).unwrap();
        assert_eq!(
            vault_open(&reopened, ITEM.into(), 1, item.clone()).unwrap(),
            b"passport"
        );
        assert!(vault_uses_own_password(renewed.clone()).unwrap());
        assert!(vault_unlock("fresh".into(), renewed.clone()).is_ok());
        assert_eq!(
            err_of(vault_unlock("vault".into(), renewed)),
            CoreError::WrongPassword
        );
        // The copy keeps working after that (the vault key did not change).
        assert!(vault_recover(recovery.clone(), typed.clone(), "again".into()).is_ok());

        // Or back to the master password.
        let VaultRecovered {
            key: by_recovery,
            wrapped: under_master,
        } = vault_recover_to_master(setup.recovery_wrap.clone(), recovery.clone(), typed).unwrap();
        assert!(!vault_uses_own_password(under_master.clone()).unwrap());
        assert_eq!(
            vault_open(&by_recovery, ITEM.into(), 1, item.clone()).unwrap(),
            b"passport"
        );
        let by_master =
            vault_unlock_with_master(setup.password_wrap.clone(), "master".into(), under_master)
                .unwrap();
        assert_eq!(
            vault_open(&by_master, ITEM.into(), 1, item).unwrap(),
            b"passport"
        );

        // A typo, another device's key, an empty new password.
        assert_eq!(
            err_of(vault_recover(
                recovery.clone(),
                "AAAA-AAAA".into(),
                "x".into()
            )),
            CoreError::Corrupt
        );
        let (other_dir, other) = device();
        assert_eq!(
            err_of(vault_recover(
                recovery.clone(),
                other.recovery_key.clone(),
                "x".into()
            )),
            CoreError::WrongPassword
        );
        assert_eq!(
            err_of(vault_recover_to_master(
                other.recovery_wrap.clone(),
                recovery.clone(),
                setup.recovery_key.clone()
            )),
            CoreError::WrongPassword
        );
        assert_eq!(
            err_of(vault_recover(
                recovery,
                setup.recovery_key.clone(),
                "".into()
            )),
            CoreError::WrongPassword
        );
        let _ = fs::remove_dir_all(dir);
        let _ = fs::remove_dir_all(other_dir);
    }

    #[test]
    fn a_vault_made_with_its_own_password_gets_a_recovery_copy() {
        let (dir, setup) = device();
        let VaultInitResult {
            key,
            wrapped,
            recovery,
        } = vault_init(
            &setup.core,
            "vault".into(),
            Some(setup.recovery_lock.clone()),
        )
        .unwrap();
        let item = vault_seal(&key, ITEM.into(), 1, b"note".to_vec()).unwrap();
        let VaultRecovered { key: reopened, .. } = vault_recover(
            recovery.expect("copy"),
            setup.recovery_key.clone(),
            "new".into(),
        )
        .unwrap();
        assert_eq!(
            vault_open(&reopened, ITEM.into(), 1, item).unwrap(),
            b"note"
        );

        // A lock from another store (or a tampered one) is refused before any
        // Argon2 run, and nothing is sealed to it.
        let (other_dir, other) = device();
        assert_eq!(
            err_of(vault_init(
                &setup.core,
                "vault".into(),
                Some(other.recovery_lock.clone())
            )),
            CoreError::Corrupt
        );
        let mut tampered = setup.recovery_lock.clone();
        tampered[40] ^= 1;
        assert_eq!(
            err_of(vault_seal_for_recovery(
                &setup.core,
                tampered,
                wrapped.clone(),
                "vault".into()
            )),
            CoreError::Corrupt
        );
        let _ = fs::remove_dir_all(dir);
        let _ = fs::remove_dir_all(other_dir);
    }

    /// A new recovery key keeps the vault recoverable once the vault is sealed
    /// to its lock; the old key opens neither the master key nor the vault.
    #[test]
    fn a_new_recovery_key_is_sealed_in_and_the_old_one_is_out() {
        let (dir, mut setup) = device();
        let VaultInitResult {
            key,
            wrapped,
            recovery: old_copy,
        } = vault_init(
            &setup.core,
            "vault".into(),
            Some(setup.recovery_lock.clone()),
        )
        .unwrap();
        let item = vault_seal(&key, ITEM.into(), 1, b"kept".to_vec()).unwrap();

        let fresh =
            new_recovery_key(&setup.core, setup.password_wrap.clone(), "master".into()).unwrap();
        assert_eq!(
            err_of(vault_seal_for_recovery(
                &setup.core,
                fresh.recovery_lock.clone(),
                wrapped.clone(),
                "wrong".into()
            )),
            CoreError::WrongPassword
        );
        let new_copy = vault_seal_for_recovery(
            &setup.core,
            fresh.recovery_lock.clone(),
            wrapped.clone(),
            "vault".into(),
        )
        .unwrap();

        let VaultRecovered { key: reopened, .. } =
            vault_recover(new_copy.clone(), fresh.recovery_key.clone(), "n".into()).unwrap();
        assert_eq!(
            vault_open(&reopened, ITEM.into(), 1, item).unwrap(),
            b"kept"
        );
        // The old key does not open the new copy (the app replaces the old one).
        assert_eq!(
            err_of(vault_recover(
                new_copy,
                setup.recovery_key.clone(),
                "n".into()
            )),
            CoreError::WrongPassword
        );
        // The new key does not open the old copy either.
        assert_eq!(
            err_of(vault_recover(
                old_copy.expect("copy"),
                fresh.recovery_key.clone(),
                "n".into()
            )),
            CoreError::WrongPassword
        );
        // A vault under the master key needs no copy.
        let VaultInitResult {
            wrapped: under_master,
            ..
        } = vault_init_with_master(setup.password_wrap.clone(), "master".into()).unwrap();
        assert_eq!(
            err_of(vault_seal_for_recovery(
                &setup.core,
                fresh.recovery_lock.clone(),
                under_master,
                "master".into()
            )),
            CoreError::UnsupportedFormat
        );
        // A locked store seals nothing.
        setup.core.close();
        assert_eq!(
            err_of(vault_seal_for_recovery(
                &setup.core,
                fresh.recovery_lock,
                wrapped,
                "vault".into()
            )),
            CoreError::StoreLocked
        );
        let _ = fs::remove_dir_all(dir);
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
        let (dir, setup) = device();
        let VaultInitResult { mut key, .. } = vault_init(&setup.core, "pw".into(), None).unwrap();
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
        let _ = fs::remove_dir_all(dir);
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
