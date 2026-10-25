use crate::api::core::CryptoCore;
use crate::error::CoreError;

impl CryptoCore {
    /// Seals `bytes` of one row of `chat_id`'s message history (F2-8) under
    /// that chat's own history key (owner decision D-1, F2-12): a 0x20 blob
    /// with a fresh random nonce and AAD `local-seal` ‖ chat id ‖ `row`. The
    /// app passes the row's direction byte and `Fuzz/` blob text as `row`, so
    /// a seal opens only on the row it was made for. A chat the store does
    /// not know is `UnknownChat`.
    pub fn seal_local(
        &self,
        chat_id: String,
        row: Vec<u8>,
        bytes: Vec<u8>,
    ) -> Result<Vec<u8>, CoreError> {
        self.opened()?.seal_local(&chat_id, &row, &bytes)
    }

    /// Inverse of [`CryptoCore::seal_local`] for the same chat and row; a
    /// tampered blob, another chat's or another row's is `Corrupt`, a deleted
    /// chat's is `UnknownChat`.
    pub fn open_local(
        &self,
        chat_id: String,
        row: Vec<u8>,
        blob: Vec<u8>,
    ) -> Result<Vec<u8>, CoreError> {
        self.opened()?.open_local(&chat_id, &row, &blob)
    }
}

#[cfg(test)]
mod tests {
    use std::fs;
    use std::path::PathBuf;

    use super::*;
    use crate::store::random_array;
    use crate::store::test_support::temp_dir;

    const CHAT_X: &str = "6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d";
    const CHAT_Y: &str = "0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d";
    const ROW: &[u8] = b"\x01Fuzz/row";

    /// One device: its own store directory and store key.
    struct Device {
        dir: PathBuf,
        store_key: [u8; 32],
        core: CryptoCore,
    }

    impl Device {
        fn new() -> Self {
            let dir = temp_dir();
            let store_key = random_array().unwrap();
            let core = CryptoCore::open_for_tests(&dir, store_key);
            Self {
                dir,
                store_key,
                core,
            }
        }

        /// Drops the handle and opens the same store again (clears the cache).
        fn reopen(&mut self) {
            self.core.close();
            self.core = CryptoCore::open_for_tests(&self.dir, self.store_key);
        }

        fn history_key(&self, chat_id: &str) -> [u8; 32] {
            self.core
                .opened()
                .unwrap()
                .load_state(chat_id)
                .unwrap()
                .history_key
        }
    }

    impl Drop for Device {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.dir);
        }
    }

    /// A invites on `chat_id` (the moment the chat's key material — and with
    /// it the history key — exists); nothing else is needed to seal history.
    fn invited(chat_id: &str) -> Device {
        let mut device = Device::new();
        device.core.create_invitation(chat_id.into()).unwrap();
        device
    }

    #[test]
    fn seal_open_round_trip_and_tamper_through_the_handle() {
        let device = invited(CHAT_X);

        let blob = device
            .core
            .seal_local(CHAT_X.into(), ROW.to_vec(), b"history".to_vec())
            .unwrap();
        assert_eq!(&blob[..6], b"FUZZ\x01\x20");
        assert_eq!(
            device
                .core
                .open_local(CHAT_X.into(), ROW.to_vec(), blob.clone())
                .unwrap(),
            b"history"
        );

        let mut tampered = blob;
        tampered[40] ^= 1;
        assert_eq!(
            device
                .core
                .open_local(CHAT_X.into(), ROW.to_vec(), tampered)
                .unwrap_err(),
            CoreError::Corrupt
        );
        // A chat the store does not know cannot seal or open anything.
        assert_eq!(
            device
                .core
                .seal_local(CHAT_Y.into(), ROW.to_vec(), b"x".to_vec())
                .unwrap_err(),
            CoreError::UnknownChat
        );
        assert_eq!(
            device
                .core
                .open_local(CHAT_Y.into(), ROW.to_vec(), vec![0; 60])
                .unwrap_err(),
            CoreError::UnknownChat
        );
        assert_eq!(
            device
                .core
                .seal_local("../x".into(), ROW.to_vec(), b"x".to_vec())
                .unwrap_err(),
            CoreError::Corrupt
        );
    }

    #[test]
    fn history_key_differs_per_chat() {
        let mut a = Device::new();
        let invitation = a.core.create_invitation(CHAT_X.into()).unwrap();
        a.core.create_invitation(CHAT_Y.into()).unwrap();
        let mut b = Device::new();
        b.core.accept_invitation(CHAT_X.into(), invitation).unwrap();

        let x = a.history_key(CHAT_X);
        let y = a.history_key(CHAT_Y);
        let b_x = b.history_key(CHAT_X);
        assert_ne!(x, y, "two chats on one device");
        assert_ne!(
            x, b_x,
            "the same chat on the two devices — nothing crosses the wire"
        );
        assert_ne!(x, [0; 32]);
        assert_ne!(y, [0; 32]);
        assert_ne!(b_x, [0; 32]);
    }

    #[test]
    fn cross_chat_seal_rejected() {
        let mut a = invited(CHAT_X);
        a.core.create_invitation(CHAT_Y.into()).unwrap();
        let other = invited(CHAT_X);

        let sealed_x = a
            .core
            .seal_local(CHAT_X.into(), ROW.to_vec(), b"for X only".to_vec())
            .unwrap();
        assert_eq!(
            a.core
                .open_local(CHAT_X.into(), ROW.to_vec(), sealed_x.clone())
                .unwrap(),
            b"for X only"
        );
        // Another chat on the same device: another key (and another AAD).
        assert_eq!(
            a.core
                .open_local(CHAT_Y.into(), ROW.to_vec(), sealed_x.clone())
                .unwrap_err(),
            CoreError::Corrupt
        );
        // The same chat id on another device: another key.
        assert_eq!(
            other
                .core
                .open_local(CHAT_X.into(), ROW.to_vec(), sealed_x)
                .unwrap_err(),
            CoreError::Corrupt
        );
    }

    /// Security review 2026-10-22: a seal copied onto another row of the same
    /// chat does not open there.
    #[test]
    fn cross_row_seal_rejected() {
        let a = invited(CHAT_X);
        let sealed = a
            .core
            .seal_local(CHAT_X.into(), ROW.to_vec(), b"row one".to_vec())
            .unwrap();
        assert_eq!(
            a.core
                .open_local(CHAT_X.into(), b"\x00Fuzz/row".to_vec(), sealed.clone())
                .unwrap_err(),
            CoreError::Corrupt
        );
        assert_eq!(
            a.core
                .open_local(CHAT_X.into(), b"\x01Fuzz/other".to_vec(), sealed)
                .unwrap_err(),
            CoreError::Corrupt
        );
    }

    #[test]
    fn history_key_survives_reload() {
        let mut a = invited(CHAT_X);
        let key = a.history_key(CHAT_X);
        let sealed = a
            .core
            .seal_local(CHAT_X.into(), ROW.to_vec(), b"before the restart".to_vec())
            .unwrap();

        a.reopen();
        assert_eq!(a.history_key(CHAT_X), key);
        assert_eq!(
            a.core
                .open_local(CHAT_X.into(), ROW.to_vec(), sealed.clone())
                .unwrap(),
            b"before the restart"
        );

        // Completing the handshake mutates the state; the key is untouched.
        let mut b = Device::new();
        let acceptance = b
            .core
            .accept_invitation(
                CHAT_X.into(),
                a.core.current_invitation(CHAT_X.into()).unwrap(),
            )
            .unwrap();
        a.core
            .complete_handshake(CHAT_X.into(), acceptance)
            .unwrap();
        a.reopen();
        assert_eq!(a.history_key(CHAT_X), key);
        assert_eq!(
            a.core
                .open_local(CHAT_X.into(), ROW.to_vec(), sealed)
                .unwrap(),
            b"before the restart"
        );
    }

    #[test]
    fn delete_chat_makes_history_unreadable() {
        let mut a = invited(CHAT_X);
        let sealed = a
            .core
            .seal_local(CHAT_X.into(), ROW.to_vec(), b"gone with the chat".to_vec())
            .unwrap();

        a.core.delete_chat(CHAT_X.into()).unwrap();
        assert_eq!(
            a.core
                .open_local(CHAT_X.into(), ROW.to_vec(), sealed.clone())
                .unwrap_err(),
            CoreError::UnknownChat
        );
        // Re-creating the chat under the same id draws a new key: the old
        // seals stay unreadable by design.
        a.core.create_invitation(CHAT_X.into()).unwrap();
        assert_eq!(
            a.core
                .open_local(CHAT_X.into(), ROW.to_vec(), sealed)
                .unwrap_err(),
            CoreError::Corrupt
        );
    }
}
