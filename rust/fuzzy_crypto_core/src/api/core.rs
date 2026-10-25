use std::path::PathBuf;

use flutter_rust_bridge::frb;
use zeroize::Zeroizing;

use crate::error::CoreError;
use crate::master::{self, RecoveryKey, STORE_KEY_WRAP_AAD};
use crate::store::{Key32, OpenStore};

/// The opaque handle Dart holds while the store is unlocked (plan §A.2).
///
/// Owns the 32-byte store key and the per-chat state cache; nothing in here
/// ever crosses the FFI. `close` drops it all (zeroised) and every later call
/// answers `StoreLocked` — the handle stays valid, only empty. The master key
/// is never kept: it lives for the length of one call.
#[frb(opaque)]
pub struct CryptoCore {
    store_dir: PathBuf,
    inner: Option<OpenStore>,
}

/// What [`create_master_key`] hands back: the open store and the four blobs
/// the app keeps in secure storage, plus the recovery key to show the user
/// once. `non_opaque` so frb passes the fields once.
#[frb(non_opaque)]
pub struct MasterKeySetup {
    pub core: CryptoCore,
    /// 0x10 — the master key under the master password.
    pub password_wrap: Vec<u8>,
    /// 0x10 — the master key under the recovery key.
    pub recovery_wrap: Vec<u8>,
    /// 0x20 — the store key under the master key.
    pub store_wrap: Vec<u8>,
    /// 0x20 — the recovery lock (public) under the store key: what a vault
    /// with its own password seals its key to, so the recovery key opens it.
    pub recovery_lock: Vec<u8>,
    /// The printable recovery key (`XXXX-XXXX-…`, 32 base32 characters).
    pub recovery_key: String,
}

/// What [`recover_master_password`] hands back: the open store and the
/// master key's new password wrap.
#[frb(non_opaque)]
pub struct RecoveredStore {
    pub core: CryptoCore,
    pub password_wrap: Vec<u8>,
}

/// A new recovery key, the master key's wrap under it and its lock (under
/// the store key); the old recovery wrap stops working the moment the app
/// replaces it with this one.
#[frb(non_opaque)]
pub struct NewRecoveryKey {
    pub recovery_key: String,
    pub recovery_wrap: Vec<u8>,
    pub recovery_lock: Vec<u8>,
}

/// First run: draws the master key, the store key and a recovery key, wraps
/// the master key under `password` and under the recovery key, wraps the
/// store key under the master key, opens the store at
/// `<store_dir>/fuzzy_crypto_store/` and seals the recovery lock under the
/// store key. Two Argon2id runs. An empty password is refused
/// (`WrongPassword`); strength is the app's judgement.
pub fn create_master_key(store_dir: String, password: String) -> Result<MasterKeySetup, CoreError> {
    let password = Zeroizing::new(password.into_bytes());
    master::refuse_empty(&password)?;
    let master_key = master::new_key()?;
    let store_key = master::new_key()?;
    let recovery = RecoveryKey::generate()?;
    let password_wrap = master::wrap_with_password(&master_key, &password)?;
    let recovery_wrap = master::wrap_with_recovery(&master_key, &recovery)?;
    let store_wrap = master::wrap_key(&master_key, &store_key, STORE_KEY_WRAP_AAD)?;
    drop(master_key);
    let core = CryptoCore::open_with(store_dir, store_key)?;
    let recovery_lock = core.opened()?.seal_recovery_lock(&recovery.lock())?;
    Ok(MasterKeySetup {
        core,
        password_wrap,
        recovery_wrap,
        store_wrap,
        recovery_lock,
        recovery_key: recovery.text().to_string(),
    })
}

/// Unwraps the master key from `password_wrap` under `password` (one Argon2id
/// run), the store key from `store_wrap` under the master key, and opens the
/// store. A wrong password — or a tampered password wrap — is `WrongPassword`;
/// a store wrap that does not open under the master key is `Corrupt`.
pub fn open_store(
    store_dir: String,
    password_wrap: Vec<u8>,
    store_wrap: Vec<u8>,
    password: String,
) -> Result<CryptoCore, CoreError> {
    let password = Zeroizing::new(password.into_bytes());
    let master_key = master::unwrap_with_password(&password_wrap, &password)?;
    let store_key = master::unwrap_key(&master_key, &store_wrap, STORE_KEY_WRAP_AAD)?;
    drop(master_key);
    CryptoCore::open_with(store_dir, store_key)
}

/// Re-wraps the master key under `new_password` with a fresh salt and nonce
/// (two Argon2id runs). Everything below the master key stays as it is, so
/// this one blob is the whole change. The old blob keeps opening with the old
/// password until the caller replaces it.
pub fn change_master_password(
    password_wrap: Vec<u8>,
    old_password: String,
    new_password: String,
) -> Result<Vec<u8>, CoreError> {
    let old_password = Zeroizing::new(old_password.into_bytes());
    let new_password = Zeroizing::new(new_password.into_bytes());
    master::refuse_empty(&new_password)?;
    let master_key = master::unwrap_with_password(&password_wrap, &old_password)?;
    master::wrap_with_password(&master_key, &new_password)
}

/// The forgotten-password path: reads the typed `recovery_key` (a typo is
/// `Corrupt`, before any Argon2 run), unwraps the master key from
/// `recovery_wrap` (a key of another device is `WrongPassword`), wraps it
/// under `new_password` and opens the store. The recovery key, its lock and a
/// vault key sealed to it stay valid.
pub fn recover_master_password(
    store_dir: String,
    recovery_wrap: Vec<u8>,
    store_wrap: Vec<u8>,
    recovery_key: String,
    new_password: String,
) -> Result<RecoveredStore, CoreError> {
    let recovery_key = Zeroizing::new(recovery_key);
    let new_password = Zeroizing::new(new_password.into_bytes());
    master::refuse_empty(&new_password)?;
    let recovery = RecoveryKey::parse(&recovery_key)?;
    let master_key = master::unwrap_with_recovery(&recovery_wrap, &recovery)?;
    let store_key = master::unwrap_key(&master_key, &store_wrap, STORE_KEY_WRAP_AAD)?;
    let password_wrap = master::wrap_with_password(&master_key, &new_password)?;
    drop(master_key);
    let core = CryptoCore::open_with(store_dir, store_key)?;
    Ok(RecoveredStore {
        core,
        password_wrap,
    })
}

/// Draws a new recovery key and wraps the master key under it, after
/// `password` has opened `password_wrap` (two Argon2id runs), and seals its
/// lock under the store key of the open `core`. The app replaces the stored
/// recovery wrap and lock with the new ones, which ends the old key; a vault
/// with its own password is sealed to the new lock with
/// [`crate::api::vault::vault_seal_for_recovery`] (its password is needed —
/// the master password alone never reaches that vault).
pub fn new_recovery_key(
    core: &CryptoCore,
    password_wrap: Vec<u8>,
    password: String,
) -> Result<NewRecoveryKey, CoreError> {
    let password = Zeroizing::new(password.into_bytes());
    let store = core.opened()?;
    let master_key = master::unwrap_with_password(&password_wrap, &password)?;
    let recovery = RecoveryKey::generate()?;
    let recovery_wrap = master::wrap_with_recovery(&master_key, &recovery)?;
    drop(master_key);
    let recovery_lock = store.seal_recovery_lock(&recovery.lock())?;
    Ok(NewRecoveryKey {
        recovery_key: recovery.text().to_string(),
        recovery_wrap,
        recovery_lock,
    })
}

impl CryptoCore {
    fn open_with(store_dir: String, store_key: Key32) -> Result<Self, CoreError> {
        let store_dir = PathBuf::from(store_dir);
        let inner = OpenStore::open(&store_dir, store_key)?;
        Ok(Self {
            store_dir,
            inner: Some(inner),
        })
    }

    pub(crate) fn opened(&self) -> Result<&OpenStore, CoreError> {
        self.inner.as_ref().ok_or(CoreError::StoreLocked)
    }

    pub(crate) fn opened_mut(&mut self) -> Result<&mut OpenStore, CoreError> {
        self.inner.as_mut().ok_or(CoreError::StoreLocked)
    }

    /// Drops the store key and every cached state (all zeroised on drop).
    pub fn close(&mut self) {
        self.inner = None;
    }

    /// Overwrites the chat's state file with zeros (best effort), unlinks it
    /// and forgets the cached state.
    pub fn delete_chat(&mut self, chat_id: String) -> Result<(), CoreError> {
        self.opened_mut()?.delete_chat(&chat_id)
    }

    /// Seals the app setting `name` (1..=64 bytes) under the store key — a
    /// 0x20 blob with AAD `app-setting` ‖ name — so the app's lock settings
    /// cannot be loosened by editing a file.
    pub fn seal_setting(&self, name: String, bytes: Vec<u8>) -> Result<Vec<u8>, CoreError> {
        self.opened()?.seal_setting(&name, &bytes)
    }

    /// Inverse of [`CryptoCore::seal_setting`]; another name, another store
    /// or a tampered blob is `Corrupt`.
    pub fn open_setting(&self, name: String, blob: Vec<u8>) -> Result<Vec<u8>, CoreError> {
        self.opened()?.open_setting(&name, &blob)
    }

    /// The directory the store was opened with (for tests).
    pub fn store_dir(&self) -> String {
        self.store_dir.to_string_lossy().into_owned()
    }
}

#[cfg(test)]
impl CryptoCore {
    /// Test harness: a store opened straight under `store_key` — no master
    /// key, no Argon2 run.
    pub(crate) fn open_for_tests(store_dir: &std::path::Path, store_key: [u8; 32]) -> Self {
        Self::open_with(
            store_dir.to_string_lossy().into_owned(),
            Zeroizing::new(store_key),
        )
        .expect("test store opens")
    }
}

#[cfg(test)]
mod tests {
    use std::fs;
    use std::time::Instant;

    use super::*;
    use crate::store::test_support::{err_of, fresh_state, temp_dir};
    use crate::store::STORE_SUBDIR;

    const CHAT_ID: &str = "6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d";
    const ROW: &[u8] = b"\x01Fuzz/row";

    fn dir_text(dir: &std::path::Path) -> String {
        dir.to_string_lossy().into_owned()
    }

    fn created(dir: &std::path::Path) -> MasterKeySetup {
        create_master_key(dir_text(dir), "pw".into()).unwrap()
    }

    #[test]
    fn create_opens_the_store_and_the_password_reopens_it() {
        let dir = temp_dir();
        let started = Instant::now();
        let mut setup = created(&dir);
        println!(
            "create_master_key (two Argon2id runs): {:?}",
            started.elapsed()
        );

        assert!(dir.join(STORE_SUBDIR).is_dir());
        assert_eq!(setup.core.store_dir(), dir.to_string_lossy());
        assert_eq!(setup.password_wrap.len(), 103);
        assert_eq!(setup.recovery_wrap.len(), 103);
        assert_eq!(setup.store_wrap.len(), 78);
        assert_eq!(setup.recovery_lock.len(), 78);
        assert_eq!(setup.recovery_key.len(), 39);
        // The lock under the store key is the recovery key's public half.
        assert_eq!(
            setup
                .core
                .opened()
                .unwrap()
                .open_recovery_lock(&setup.recovery_lock)
                .unwrap(),
            RecoveryKey::parse(&setup.recovery_key).unwrap().lock()
        );
        setup.core.create_invitation(CHAT_ID.into()).unwrap();
        let sealed = setup
            .core
            .seal_local(CHAT_ID.into(), ROW.to_vec(), b"before".to_vec())
            .unwrap();
        setup.core.close();

        let reopened = open_store(
            dir_text(&dir),
            setup.password_wrap.clone(),
            setup.store_wrap.clone(),
            "pw".into(),
        )
        .unwrap();
        assert_eq!(
            reopened
                .open_local(CHAT_ID.into(), ROW.to_vec(), sealed)
                .unwrap(),
            b"before"
        );
        assert_eq!(
            err_of(open_store(
                dir_text(&dir),
                setup.password_wrap.clone(),
                setup.store_wrap.clone(),
                "wrong".into()
            )),
            CoreError::WrongPassword
        );
        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn the_empty_password_is_gone() {
        let dir = temp_dir();
        assert_eq!(
            err_of(create_master_key(dir_text(&dir), "".into())),
            CoreError::WrongPassword
        );
        let setup = created(&dir);
        assert_eq!(
            err_of(open_store(
                dir_text(&dir),
                setup.password_wrap.clone(),
                setup.store_wrap.clone(),
                "".into()
            )),
            CoreError::WrongPassword
        );
        assert_eq!(
            change_master_password(setup.password_wrap.clone(), "pw".into(), "".into())
                .unwrap_err(),
            CoreError::WrongPassword
        );
        assert_eq!(
            err_of(recover_master_password(
                dir_text(&dir),
                setup.recovery_wrap.clone(),
                setup.store_wrap.clone(),
                setup.recovery_key.clone(),
                "".into()
            )),
            CoreError::WrongPassword
        );
        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn a_store_wrap_from_another_device_does_not_open() {
        let dir = temp_dir();
        let mine = created(&dir);
        let other = created(&dir);
        assert_eq!(
            err_of(open_store(
                dir_text(&dir),
                mine.password_wrap.clone(),
                other.store_wrap.clone(),
                "pw".into()
            )),
            CoreError::Corrupt
        );
        let mut tampered = mine.store_wrap.clone();
        tampered[40] ^= 1;
        assert_eq!(
            err_of(open_store(
                dir_text(&dir),
                mine.password_wrap.clone(),
                tampered,
                "pw".into()
            )),
            CoreError::Corrupt
        );
        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn change_master_password_rewraps_only_the_master_key() {
        let dir = temp_dir();
        let mut setup = created(&dir);
        setup.core.create_invitation(CHAT_ID.into()).unwrap();
        let sealed = setup
            .core
            .seal_local(CHAT_ID.into(), ROW.to_vec(), b"before".to_vec())
            .unwrap();
        setup.core.close();

        let new_wrap =
            change_master_password(setup.password_wrap.clone(), "pw".into(), "new".into()).unwrap();
        assert_eq!(
            change_master_password(setup.password_wrap.clone(), "nope".into(), "new".into())
                .unwrap_err(),
            CoreError::WrongPassword
        );

        // The same store wrap opens under the new password; the old seal still opens.
        let reopened = open_store(
            dir_text(&dir),
            new_wrap.clone(),
            setup.store_wrap.clone(),
            "new".into(),
        )
        .unwrap();
        assert_eq!(
            reopened
                .open_local(CHAT_ID.into(), ROW.to_vec(), sealed)
                .unwrap(),
            b"before"
        );
        assert_eq!(
            err_of(open_store(
                dir_text(&dir),
                new_wrap,
                setup.store_wrap.clone(),
                "pw".into()
            )),
            CoreError::WrongPassword
        );
        // The recovery key still opens the same master key.
        assert!(recover_master_password(
            dir_text(&dir),
            setup.recovery_wrap.clone(),
            setup.store_wrap.clone(),
            setup.recovery_key.clone(),
            "third".into()
        )
        .is_ok());
        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn recovery_sets_a_new_password_and_keeps_every_chat() {
        let dir = temp_dir();
        let mut setup = created(&dir);
        setup.core.create_invitation(CHAT_ID.into()).unwrap();
        let sealed = setup
            .core
            .seal_local(CHAT_ID.into(), ROW.to_vec(), b"kept".to_vec())
            .unwrap();
        setup.core.close();

        let typed = setup.recovery_key.to_lowercase().replace('-', " ");
        let recovered = recover_master_password(
            dir_text(&dir),
            setup.recovery_wrap.clone(),
            setup.store_wrap.clone(),
            typed,
            "fresh".into(),
        )
        .unwrap();
        assert_eq!(
            recovered
                .core
                .open_local(CHAT_ID.into(), ROW.to_vec(), sealed)
                .unwrap(),
            b"kept"
        );
        assert!(open_store(
            dir_text(&dir),
            recovered.password_wrap.clone(),
            setup.store_wrap.clone(),
            "fresh".into()
        )
        .is_ok());

        // A typo is Corrupt (no Argon2 run); another device's key is WrongPassword.
        assert_eq!(
            err_of(recover_master_password(
                dir_text(&dir),
                setup.recovery_wrap.clone(),
                setup.store_wrap.clone(),
                "AAAA-AAAA".into(),
                "fresh".into()
            )),
            CoreError::Corrupt
        );
        let other = created(&dir);
        assert_eq!(
            err_of(recover_master_password(
                dir_text(&dir),
                setup.recovery_wrap.clone(),
                setup.store_wrap.clone(),
                other.recovery_key.clone(),
                "fresh".into()
            )),
            CoreError::WrongPassword
        );
        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn a_new_recovery_key_replaces_the_old_one() {
        let dir = temp_dir();
        let mut setup = created(&dir);
        assert_eq!(
            err_of(new_recovery_key(
                &setup.core,
                setup.password_wrap.clone(),
                "nope".into()
            )),
            CoreError::WrongPassword
        );
        let fresh =
            new_recovery_key(&setup.core, setup.password_wrap.clone(), "pw".into()).unwrap();
        assert_ne!(fresh.recovery_key, setup.recovery_key);
        // A new lock, under the same store key, for the new key only.
        let store = setup.core.opened().unwrap();
        let new_lock = store.open_recovery_lock(&fresh.recovery_lock).unwrap();
        assert_eq!(
            new_lock,
            RecoveryKey::parse(&fresh.recovery_key).unwrap().lock()
        );
        assert_ne!(
            new_lock,
            store.open_recovery_lock(&setup.recovery_lock).unwrap()
        );
        // A closed store makes no new key (nothing to seal the lock under).
        setup.core.close();
        assert_eq!(
            err_of(new_recovery_key(
                &setup.core,
                setup.password_wrap.clone(),
                "pw".into()
            )),
            CoreError::StoreLocked
        );

        // Under the new wrap only the new key opens; the old key is dead once
        // the app has replaced the wrap.
        assert!(recover_master_password(
            dir_text(&dir),
            fresh.recovery_wrap.clone(),
            setup.store_wrap.clone(),
            fresh.recovery_key.clone(),
            "x".into()
        )
        .is_ok());
        assert_eq!(
            err_of(recover_master_password(
                dir_text(&dir),
                fresh.recovery_wrap.clone(),
                setup.store_wrap.clone(),
                setup.recovery_key.clone(),
                "x".into()
            )),
            CoreError::WrongPassword
        );
        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn delete_chat_removes_file_and_cache() {
        let dir = temp_dir();
        let mut core = CryptoCore::open_for_tests(&dir, [0x33; 32]);
        core.opened_mut()
            .unwrap()
            .put_state(fresh_state(CHAT_ID))
            .unwrap();
        let path = dir.join(STORE_SUBDIR).join(format!("{CHAT_ID}.state"));
        assert!(path.is_file());

        core.delete_chat(CHAT_ID.into()).unwrap();

        assert!(!path.exists());
        assert_eq!(
            core.opened_mut()
                .unwrap()
                .with_state_mut(CHAT_ID, |_| Ok(()))
                .unwrap_err(),
            CoreError::UnknownChat
        );
        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn settings_round_trip_through_the_handle() {
        let dir = temp_dir();
        let core = CryptoCore::open_for_tests(&dir, [0x33; 32]);
        let sealed = core
            .seal_setting("auto-lock".into(), b"{\"idle\":5}".to_vec())
            .unwrap();
        assert_eq!(
            core.open_setting("auto-lock".into(), sealed.clone())
                .unwrap(),
            b"{\"idle\":5}"
        );
        let other = CryptoCore::open_for_tests(&dir, [0x34; 32]);
        assert_eq!(
            other.open_setting("auto-lock".into(), sealed).unwrap_err(),
            CoreError::Corrupt
        );
        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn close_zeroises_and_later_calls_fail_cleanly() {
        let dir = temp_dir();
        let mut core = CryptoCore::open_for_tests(&dir, [0x33; 32]);
        core.opened_mut()
            .unwrap()
            .put_state(fresh_state(CHAT_ID))
            .unwrap();

        core.close();

        assert_eq!(err_of(core.opened()), CoreError::StoreLocked);
        assert_eq!(
            core.seal_local(CHAT_ID.into(), ROW.to_vec(), b"x".to_vec())
                .unwrap_err(),
            CoreError::StoreLocked
        );
        assert_eq!(
            core.open_local(CHAT_ID.into(), ROW.to_vec(), vec![0; 60])
                .unwrap_err(),
            CoreError::StoreLocked
        );
        assert_eq!(
            core.delete_chat(CHAT_ID.into()).unwrap_err(),
            CoreError::StoreLocked
        );
        assert_eq!(
            core.seal_setting("auto-lock".into(), vec![]).unwrap_err(),
            CoreError::StoreLocked
        );
        assert_eq!(core.store_dir(), dir.to_string_lossy());
        core.close();
        let _ = fs::remove_dir_all(dir);
    }
}
