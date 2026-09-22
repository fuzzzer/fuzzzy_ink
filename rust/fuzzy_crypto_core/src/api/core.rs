use std::path::PathBuf;

use flutter_rust_bridge::frb;
use zeroize::Zeroizing;

use crate::error::CoreError;
use crate::store::{self, OpenStore};

/// The opaque handle Dart holds while the store is unlocked (plan §A.2).
///
/// Owns the 32-byte store key and the per-chat state cache; nothing in here
/// ever crosses the FFI. `close` drops it all (zeroised) and every later call
/// answers `StoreLocked` — the handle stays valid, only empty.
#[frb(opaque)]
pub struct CryptoCore {
    store_dir: PathBuf,
    inner: Option<OpenStore>,
}

/// Draws a fresh 32-byte store key and returns it wrapped under `password`
/// (0x10 blob — the only form the key ever takes outside Rust). Call
/// [`open_store`] with the blob to use it.
pub fn create_store_key(password: String) -> Result<Vec<u8>, CoreError> {
    let password = Zeroizing::new(password.into_bytes());
    let mut store_key = Zeroizing::new([0u8; 32]);
    store::fill_random(store_key.as_mut())?;
    store::wrap_store_key(&store_key, &password)
}

/// Unwraps `wrapped` under `password` and opens the store at
/// `<store_dir>/fuzzy_crypto_store/` (created if missing). A wrong password —
/// or a tampered blob — is `WrongPassword`.
pub fn open_store(
    store_dir: String,
    wrapped: Vec<u8>,
    password: String,
) -> Result<CryptoCore, CoreError> {
    let password = Zeroizing::new(password.into_bytes());
    let store_key = store::unwrap_store_key(&wrapped, &password)?;
    let store_dir = PathBuf::from(store_dir);
    let inner = OpenStore::open(&store_dir, store_key)?;
    Ok(CryptoCore {
        store_dir,
        inner: Some(inner),
    })
}

/// Re-wraps the store key under `new_password` with a fresh salt and nonce.
/// The old blob keeps opening with the old password until the caller replaces it.
pub fn rewrap_store_key(
    wrapped: Vec<u8>,
    old_password: String,
    new_password: String,
) -> Result<Vec<u8>, CoreError> {
    let old_password = Zeroizing::new(old_password.into_bytes());
    let new_password = Zeroizing::new(new_password.into_bytes());
    let store_key = store::unwrap_store_key(&wrapped, &old_password)?;
    store::wrap_store_key(&store_key, &new_password)
}

impl CryptoCore {
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

    /// The directory the store was opened with (for tests).
    pub fn store_dir(&self) -> String {
        self.store_dir.to_string_lossy().into_owned()
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

    fn opened(dir: &std::path::Path) -> (CryptoCore, Vec<u8>) {
        let wrapped = create_store_key("pw".into()).unwrap();
        let core = open_store(
            dir.to_string_lossy().into_owned(),
            wrapped.clone(),
            "pw".into(),
        )
        .unwrap();
        (core, wrapped)
    }

    #[test]
    fn open_store_creates_the_store_dir_and_rejects_a_wrong_password() {
        let dir = temp_dir();
        let started = Instant::now();
        let (core, wrapped) = opened(&dir);
        let elapsed = started.elapsed();
        println!("create_store_key + open_store (two Argon2id runs): {elapsed:?}");

        assert!(dir.join(STORE_SUBDIR).is_dir());
        assert_eq!(core.store_dir(), dir.to_string_lossy());
        assert_eq!(
            err_of(open_store(
                dir.to_string_lossy().into_owned(),
                wrapped,
                "wrong".into()
            )),
            CoreError::WrongPassword
        );
        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn rewrap_round_trip_at_the_api() {
        let dir = temp_dir();
        let (mut core, old_blob) = opened(&dir);
        core.create_invitation(CHAT_ID.into()).unwrap();
        let sealed = core.seal_local(CHAT_ID.into(), b"before".to_vec()).unwrap();
        core.close();

        let new_blob = rewrap_store_key(old_blob.clone(), "pw".into(), "new".into()).unwrap();
        assert_eq!(
            rewrap_store_key(old_blob.clone(), "nope".into(), "new".into()).unwrap_err(),
            CoreError::WrongPassword
        );

        // The same store key comes back under the new password: the old seal still opens.
        let dir_text = dir.to_string_lossy().into_owned();
        let reopened = open_store(dir_text.clone(), new_blob.clone(), "new".into()).unwrap();
        assert_eq!(
            reopened.open_local(CHAT_ID.into(), sealed).unwrap(),
            b"before"
        );
        assert_eq!(
            err_of(open_store(dir_text.clone(), new_blob, "pw".into())),
            CoreError::WrongPassword
        );
        assert!(open_store(dir_text, old_blob, "pw".into()).is_ok());
        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn delete_chat_removes_file_and_cache() {
        let dir = temp_dir();
        let (mut core, _) = opened(&dir);
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
    fn close_zeroises_and_later_calls_fail_cleanly() {
        let dir = temp_dir();
        let (mut core, _) = opened(&dir);
        core.opened_mut()
            .unwrap()
            .put_state(fresh_state(CHAT_ID))
            .unwrap();

        core.close();

        assert_eq!(err_of(core.opened()), CoreError::StoreLocked);
        assert_eq!(
            core.seal_local(CHAT_ID.into(), b"x".to_vec()).unwrap_err(),
            CoreError::StoreLocked
        );
        assert_eq!(
            core.open_local(CHAT_ID.into(), vec![0; 60]).unwrap_err(),
            CoreError::StoreLocked
        );
        assert_eq!(
            core.delete_chat(CHAT_ID.into()).unwrap_err(),
            CoreError::StoreLocked
        );
        assert_eq!(core.store_dir(), dir.to_string_lossy());
        core.close();
        let _ = fs::remove_dir_all(dir);
    }
}
