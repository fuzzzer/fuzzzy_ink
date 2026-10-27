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

/// What [`vault_init_with_master`] hands back: the unlocked key and its
/// wrapping (a 0x20 under the master key), which the app stores in the vault
/// metadata and feeds to the unlock call later. `non_opaque` so frb passes the
/// two fields once instead of wrapping the struct in a second handle with a
/// cloning accessor for the key.
///
/// There is no call that makes a vault with its own password from scratch:
/// every vault starts under the master key and gets its own password only
/// through [`vault_use_own_password`], which also draws a new recovery key —
/// so a vault key is never sealed to a recovery lock the user was not just
/// shown (security review 2026-10-26).
#[frb(non_opaque)]
pub struct VaultInitResult {
    pub key: VaultKey,
    /// The vault key wrapped: a 0x20 under the master key.
    pub wrapped: Vec<u8>,
}

/// What [`vault_use_own_password`] hands back. The vault gets a **new** key
/// and a **new** recovery key in the same step (security review 2026-10-26):
/// the old key, which anyone who knew the master password could have taken
/// from an old copy of `vault.meta`, opens nothing written after the switch,
/// and the box is sealed to a recovery key the user is shown now, never to
/// one somebody else may have made earlier with the master password.
#[frb(non_opaque)]
pub struct VaultOwnPassword {
    /// The key before the switch: every item is re-sealed from it to `key`
    /// ([`vault_reseal`]), then it is closed.
    pub previous: VaultKey,
    /// The new vault key, drawn fresh.
    pub key: VaultKey,
    /// 0x10 — `key` under the vault's own password.
    pub wrapped: Vec<u8>,
    /// The new printable recovery key, shown once.
    pub recovery_key: String,
    /// 0x10 — the master key under the new recovery key.
    pub recovery_wrap: Vec<u8>,
    /// 0x20 — the new recovery lock under the store key.
    pub recovery_lock: Vec<u8>,
    /// 0x11 — `key` sealed to the new recovery lock.
    pub recovery: Vec<u8>,
}

/// What the recovery key opens a vault into: the unlocked key and the vault
/// key's new wrapping, which replaces the stored one.
#[frb(non_opaque)]
pub struct VaultRecovered {
    pub key: VaultKey,
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

/// Gives a vault that the master password opens its own password. The master
/// password opens the master key and, with it, the current vault key (the
/// 0x20 `wrapped`); then a **new** vault key is drawn and wrapped as a 0x10
/// under `new_password`, a **new** recovery key is drawn, the master key is
/// wrapped under it and its lock sealed under the store key of `core`, and
/// the new vault key is sealed to that lock (0x11). Three Argon2id runs.
///
/// The caller re-seals every item from `previous` to `key`
/// ([`vault_reseal`]), replaces the stored wrapping in one atomic step,
/// replaces the recovery blobs, and shows the recovery key. After that the
/// master password no longer opens the vault — not even with a copy of the
/// old `vault.meta` — and only the recovery key just shown does.
pub fn vault_use_own_password(
    core: &CryptoCore,
    password_wrap: Vec<u8>,
    master_password: String,
    wrapped: Vec<u8>,
    new_password: String,
) -> Result<VaultOwnPassword, CoreError> {
    let master_password = Zeroizing::new(master_password.into_bytes());
    let new_password = Zeroizing::new(new_password.into_bytes());
    master::refuse_empty(&new_password)?;
    let store = core.opened()?;
    let master_key = master::unwrap_with_password(&password_wrap, &master_password)?;
    let previous = vault::unlock_under_master(&master_key, &wrapped)?;
    let recovery = RecoveryKey::generate()?;
    let recovery_wrap = master::wrap_with_recovery(&master_key, &recovery)?;
    drop(master_key);
    let lock = recovery.lock();
    let recovery_lock = store.seal_recovery_lock(&lock)?;
    let (key, wrapped) = vault::init(&new_password)?;
    let recovery_box = vault::seal_for_recovery(&lock, &key)?;
    Ok(VaultOwnPassword {
        previous: VaultKey {
            inner: Some(previous),
        },
        key: VaultKey { inner: Some(key) },
        wrapped,
        recovery_key: recovery.text().to_string(),
        recovery_wrap,
        recovery_lock,
        recovery: recovery_box,
    })
}

/// Moves version `version` of the item `item_id` from the vault key `from`
/// to the vault key `to`: opens `blob` under `from` and seals it under `to`
/// with a fresh nonce, same item, same version. The plaintext stays in Rust
/// and is wiped. A blob that does not open (another item, version or key) is
/// `Corrupt`; a closed handle is `StoreLocked`.
pub fn vault_reseal(
    from: &VaultKey,
    to: &VaultKey,
    item_id: String,
    version: u32,
    blob: Vec<u8>,
) -> Result<Vec<u8>, CoreError> {
    let plain = Zeroizing::new(vault::open_item(
        from.unlocked()?,
        &item_id,
        version,
        &blob,
    )?);
    vault::seal_item(to.unlocked()?, &item_id, version, &plain)
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

/// Seals the list label (a username or file name) of version `version` of the
/// item `item_id` under the vault key: a 0x20 blob with a fresh nonce, AAD
/// `vault-label` ‖ u32 BE version ‖ item id, the label padded to one fixed
/// size (cut to 255 UTF-8 bytes). An empty label is sealed too.
pub fn vault_seal_label(
    key: &VaultKey,
    item_id: String,
    version: u32,
    label: String,
) -> Result<Vec<u8>, CoreError> {
    let label = Zeroizing::new(label);
    vault::seal_label(key.unlocked()?, &item_id, version, &label)
}

/// Inverse of [`vault_seal_label`] for the same item and version; an item
/// blob, another item's or version's label, or a tampered blob is `Corrupt`.
pub fn vault_open_label(
    key: &VaultKey,
    item_id: String,
    version: u32,
    blob: Vec<u8>,
) -> Result<String, CoreError> {
    vault::open_label(key.unlocked()?, &item_id, version, &blob)
}

/// [`vault_reseal`] for a list label: moves it from `from` to `to`, same item
/// and version; the label stays in Rust and is wiped. A blob that is not this
/// item's label at this version is `Corrupt`.
pub fn vault_reseal_label(
    from: &VaultKey,
    to: &VaultKey,
    item_id: String,
    version: u32,
    blob: Vec<u8>,
) -> Result<Vec<u8>, CoreError> {
    vault::reseal_label(from.unlocked()?, to.unlocked()?, &item_id, version, &blob)
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

    /// A vault key under its own `password`, made directly (the API has no
    /// such call: a vault gets its own password only through the switch).
    fn own_vault(password: &str) -> (VaultKey, Vec<u8>) {
        let (key, wrapped) = vault::init(password.as_bytes()).unwrap();
        (VaultKey { inner: Some(key) }, wrapped)
    }

    /// A vault under the master key of `setup`, switched to the own password
    /// `vault`, with one item re-sealed: the item before and after.
    fn switched(setup: &MasterKeySetup) -> (Vec<u8>, VaultOwnPassword, Vec<u8>, Vec<u8>) {
        let VaultInitResult { key, wrapped } =
            vault_init_with_master(setup.password_wrap.clone(), "master".into()).unwrap();
        let before = vault_seal(&key, ITEM.into(), 1, b"passport".to_vec()).unwrap();
        let own = vault_use_own_password(
            &setup.core,
            setup.password_wrap.clone(),
            "master".into(),
            wrapped.clone(),
            "vault".into(),
        )
        .unwrap();
        let after = vault_reseal(&own.previous, &own.key, ITEM.into(), 1, before.clone()).unwrap();
        (wrapped, own, before, after)
    }

    #[test]
    fn seal_rewrap_unlock_open_through_the_api() {
        let (key, wrapped) = own_vault("pw");
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

    /// Security review 2026-10-26 (M1): someone who knew the master password
    /// and kept a copy of the old `vault.meta` gets the old key back from it —
    /// and that key opens nothing the vault holds after the switch.
    #[test]
    fn its_own_password_draws_a_new_key_the_old_wrapping_cannot_reach() {
        let (dir, setup) = device();
        let (old_wrapped, own, before, after) = switched(&setup);

        assert!(vault_uses_own_password(own.wrapped.clone()).unwrap());
        assert_eq!(
            vault_open(&own.key, ITEM.into(), 1, after.clone()).unwrap(),
            b"passport"
        );
        // The old key and the new key are different keys.
        assert_eq!(
            vault_open(&own.key, ITEM.into(), 1, before.clone()).unwrap_err(),
            CoreError::Corrupt
        );
        assert_eq!(
            vault_open(&own.previous, ITEM.into(), 1, after.clone()).unwrap_err(),
            CoreError::Corrupt
        );
        // The old copy of vault.meta plus the master password: the old key,
        // which opens no re-sealed item and no item written later.
        let stale =
            vault_unlock_with_master(setup.password_wrap.clone(), "master".into(), old_wrapped)
                .unwrap();
        assert_eq!(
            vault_open(&stale, ITEM.into(), 1, after.clone()).unwrap_err(),
            CoreError::Corrupt
        );
        let later = vault_seal(&own.key, ITEM.into(), 2, b"later".to_vec()).unwrap();
        assert_eq!(
            vault_open(&stale, ITEM.into(), 2, later).unwrap_err(),
            CoreError::Corrupt
        );
        // The master password does not open the new wrapping; its own does.
        assert_eq!(
            err_of(vault_unlock_with_master(
                setup.password_wrap.clone(),
                "master".into(),
                own.wrapped.clone()
            )),
            CoreError::UnsupportedFormat
        );
        assert_eq!(
            err_of(vault_unlock("master".into(), own.wrapped.clone())),
            CoreError::WrongPassword
        );
        let by_own = vault_unlock("vault".into(), own.wrapped.clone()).unwrap();
        assert_eq!(
            vault_open(&by_own, ITEM.into(), 1, after.clone()).unwrap(),
            b"passport"
        );

        // And back to the master password: the new key, every item.
        assert_eq!(
            vault_use_master_password(
                own.wrapped.clone(),
                "wrong".into(),
                setup.password_wrap.clone(),
                "master".into()
            )
            .unwrap_err(),
            CoreError::WrongPassword
        );
        let back = vault_use_master_password(
            own.wrapped.clone(),
            "vault".into(),
            setup.password_wrap.clone(),
            "master".into(),
        )
        .unwrap();
        let by_master =
            vault_unlock_with_master(setup.password_wrap.clone(), "master".into(), back).unwrap();
        assert_eq!(
            vault_open(&by_master, ITEM.into(), 1, after).unwrap(),
            b"passport"
        );
        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn the_switch_refuses_a_wrong_master_password_an_empty_one_and_a_locked_store() {
        let (dir, mut setup) = device();
        let VaultInitResult { wrapped, .. } =
            vault_init_with_master(setup.password_wrap.clone(), "master".into()).unwrap();
        let call = |setup: &MasterKeySetup, master: &str, new: &str| {
            vault_use_own_password(
                &setup.core,
                setup.password_wrap.clone(),
                master.into(),
                wrapped.clone(),
                new.into(),
            )
        };
        assert_eq!(
            err_of(call(&setup, "wrong", "vault")),
            CoreError::WrongPassword
        );
        assert_eq!(err_of(call(&setup, "master", "")), CoreError::WrongPassword);
        // A vault that already has its own password is not a 0x20.
        let (_, own_wrapped) = own_vault("vault");
        assert_eq!(
            err_of(vault_use_own_password(
                &setup.core,
                setup.password_wrap.clone(),
                "master".into(),
                own_wrapped,
                "x".into(),
            )),
            CoreError::UnsupportedFormat
        );
        setup.core.close();
        assert_eq!(
            err_of(call(&setup, "master", "vault")),
            CoreError::StoreLocked
        );
        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn reseal_keeps_the_item_and_version_and_refuses_the_wrong_ones() {
        let (from, _) = own_vault("a");
        let (mut to, _) = own_vault("b");
        let blob = vault_seal(&from, ITEM.into(), 3, b"note".to_vec()).unwrap();
        let moved = vault_reseal(&from, &to, ITEM.into(), 3, blob.clone()).unwrap();
        assert_eq!(
            vault_open(&to, ITEM.into(), 3, moved.clone()).unwrap(),
            b"note"
        );
        assert_eq!(
            vault_open(&to, ITEM.into(), 4, moved).unwrap_err(),
            CoreError::Corrupt
        );
        assert_eq!(
            err_of(vault_reseal(&from, &to, ITEM.into(), 4, blob.clone())),
            CoreError::Corrupt
        );
        assert_eq!(
            err_of(vault_reseal(&to, &from, ITEM.into(), 3, blob.clone())),
            CoreError::Corrupt
        );
        to.close();
        assert_eq!(
            err_of(vault_reseal(&from, &to, ITEM.into(), 3, blob)),
            CoreError::StoreLocked
        );
    }

    /// The owner's rule (2026-10-26): the recovery key also opens a vault with
    /// its own password; the master password alone still does not. The
    /// recovery key that does is the one the switch made and showed.
    #[test]
    fn the_recovery_key_shown_at_the_switch_opens_the_vault() {
        let (dir, setup) = device();
        let (_, own, _, item) = switched(&setup);
        assert_eq!(own.recovery.len(), 110);
        assert_ne!(own.recovery_key, setup.recovery_key);

        // The recovery key, with a new vault password: same key, every item opens.
        let typed = own.recovery_key.to_lowercase();
        let VaultRecovered {
            key: reopened,
            wrapped: renewed,
        } = vault_recover(own.recovery.clone(), typed.clone(), "fresh".into()).unwrap();
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
        assert!(vault_recover(own.recovery.clone(), typed.clone(), "again".into()).is_ok());

        // Or back to the master password, through the new recovery wrap.
        let VaultRecovered {
            key: by_recovery,
            wrapped: under_master,
        } = vault_recover_to_master(own.recovery_wrap.clone(), own.recovery.clone(), typed)
            .unwrap();
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

        // The new recovery wrap opens the master key (forgotten master password).
        let parsed = RecoveryKey::parse(&own.recovery_key).unwrap();
        assert!(master::unwrap_with_recovery(&own.recovery_wrap, &parsed).is_ok());

        // A typo, another device's key, an empty new password.
        assert_eq!(
            err_of(vault_recover(
                own.recovery.clone(),
                "AAAA-AAAA".into(),
                "x".into()
            )),
            CoreError::Corrupt
        );
        let (other_dir, other) = device();
        assert_eq!(
            err_of(vault_recover(
                own.recovery.clone(),
                other.recovery_key.clone(),
                "x".into()
            )),
            CoreError::WrongPassword
        );
        assert_eq!(
            err_of(vault_recover(
                own.recovery,
                own.recovery_key.clone(),
                "".into()
            )),
            CoreError::WrongPassword
        );
        let _ = fs::remove_dir_all(dir);
        let _ = fs::remove_dir_all(other_dir);
    }

    /// Security review 2026-10-26 (M1): someone who knew the master password
    /// makes a recovery key of their own before the vault gets its own
    /// password. The switch draws another one, so theirs opens neither the
    /// vault's box nor (once the app replaces the wrap) the master key.
    #[test]
    fn a_recovery_key_planted_earlier_does_not_open_the_switched_vault() {
        let (dir, setup) = device();
        let planted =
            new_recovery_key(&setup.core, setup.password_wrap.clone(), "master".into()).unwrap();
        let (_, own, _, _) = switched(&setup);
        for earlier in [&planted.recovery_key, &setup.recovery_key] {
            assert_eq!(
                err_of(vault_recover(
                    own.recovery.clone(),
                    earlier.clone(),
                    "mine".into()
                )),
                CoreError::WrongPassword
            );
            assert_eq!(
                err_of(vault_recover_to_master(
                    own.recovery_wrap.clone(),
                    own.recovery.clone(),
                    earlier.clone()
                )),
                CoreError::WrongPassword
            );
        }
        let _ = fs::remove_dir_all(dir);
    }

    /// A new recovery key keeps the vault recoverable once the vault is sealed
    /// to its lock; the old key opens neither the master key nor the vault.
    #[test]
    fn a_new_recovery_key_is_sealed_in_and_the_old_one_is_out() {
        let (dir, mut setup) = device();
        let (_, own, _, item) = switched(&setup);
        let wrapped = own.wrapped.clone();

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
            b"passport"
        );
        // The old key does not open the new copy (the app replaces the old one).
        assert_eq!(
            err_of(vault_recover(
                new_copy,
                own.recovery_key.clone(),
                "n".into()
            )),
            CoreError::WrongPassword
        );
        // The new key does not open the old copy either.
        assert_eq!(
            err_of(vault_recover(
                own.recovery.clone(),
                fresh.recovery_key.clone(),
                "n".into()
            )),
            CoreError::WrongPassword
        );
        // A lock from another store, or a tampered one, is refused.
        let (other_dir, other) = device();
        assert_eq!(
            err_of(vault_seal_for_recovery(
                &setup.core,
                other.recovery_lock.clone(),
                wrapped.clone(),
                "vault".into()
            )),
            CoreError::Corrupt
        );
        let mut tampered = fresh.recovery_lock.clone();
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
        let _ = fs::remove_dir_all(other_dir);
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
        let (mut key, _) = own_vault("pw");
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

    /// Labels through the API: their own seal, open and re-seal, a closed
    /// handle answers `StoreLocked`, and an item never passes as a label.
    #[test]
    fn labels_seal_open_and_move_through_the_api() {
        let (mut key, _) = own_vault("pw");
        let (next, _) = own_vault("pw2");
        let label = vault_seal_label(&key, ITEM.into(), 1, "tamar@mail.ge".into()).unwrap();
        assert_eq!(
            vault_open_label(&key, ITEM.into(), 1, label.clone()).unwrap(),
            "tamar@mail.ge"
        );
        assert_eq!(
            vault_open(&key, ITEM.into(), 1, label.clone()).unwrap_err(),
            CoreError::Corrupt
        );
        let item = vault_seal(&key, ITEM.into(), 1, b"x".to_vec()).unwrap();
        assert_eq!(
            vault_open_label(&key, ITEM.into(), 1, item).unwrap_err(),
            CoreError::Corrupt
        );
        let moved = vault_reseal_label(&key, &next, ITEM.into(), 1, label.clone()).unwrap();
        assert_eq!(
            vault_open_label(&next, ITEM.into(), 1, moved).unwrap(),
            "tamar@mail.ge"
        );

        key.close();
        assert_eq!(
            vault_seal_label(&key, ITEM.into(), 1, "x".into()).unwrap_err(),
            CoreError::StoreLocked
        );
        assert_eq!(
            vault_open_label(&key, ITEM.into(), 1, label.clone()).unwrap_err(),
            CoreError::StoreLocked
        );
        assert_eq!(
            vault_reseal_label(&key, &next, ITEM.into(), 1, label).unwrap_err(),
            CoreError::StoreLocked
        );
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
