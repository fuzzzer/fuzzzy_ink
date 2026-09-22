use crate::api::core::CryptoCore;
use crate::error::CoreError;

impl CryptoCore {
    /// Seals `bytes` of `chat_id`'s message history (F2-8) under that chat's
    /// own history key (owner decision D-1, F2-12): a 0x20 blob with a fresh
    /// random nonce and AAD `local-seal` ‖ chat id. A chat the store does not
    /// know is `UnknownChat`.
    pub fn seal_local(&self, chat_id: String, bytes: Vec<u8>) -> Result<Vec<u8>, CoreError> {
        self.opened()?.seal_local(&chat_id, &bytes)
    }

    /// Inverse of [`CryptoCore::seal_local`] for the same chat; a tampered
    /// blob or another chat's is `Corrupt`, a deleted chat's is `UnknownChat`.
    pub fn open_local(&self, chat_id: String, blob: Vec<u8>) -> Result<Vec<u8>, CoreError> {
        self.opened()?.open_local(&chat_id, &blob)
    }
}

#[cfg(test)]
mod tests {
    use std::fs;
    use std::path::PathBuf;

    use super::*;
    use crate::api::core::{create_store_key, open_store};
    use crate::store::test_support::temp_dir;

    const CHAT_X: &str = "6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d";
    const CHAT_Y: &str = "0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d";

    /// One device: its own store directory and store key.
    struct Device {
        dir: PathBuf,
        wrapped: Vec<u8>,
        core: CryptoCore,
    }

    impl Device {
        fn new() -> Self {
            let dir = temp_dir();
            let wrapped = create_store_key("".into()).unwrap();
            let core = open_store(
                dir.to_string_lossy().into_owned(),
                wrapped.clone(),
                "".into(),
            )
            .unwrap();
            Self { dir, wrapped, core }
        }

        /// Drops the handle and opens the same store again (clears the cache).
        fn reopen(&mut self) {
            self.core.close();
            self.core = open_store(
                self.dir.to_string_lossy().into_owned(),
                self.wrapped.clone(),
                "".into(),
            )
            .unwrap();
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
            .seal_local(CHAT_X.into(), b"history".to_vec())
            .unwrap();
        assert_eq!(&blob[..6], b"FUZZ\x01\x20");
        assert_eq!(
            device.core.open_local(CHAT_X.into(), blob.clone()).unwrap(),
            b"history"
        );

        let mut tampered = blob;
        tampered[40] ^= 1;
        assert_eq!(
            device.core.open_local(CHAT_X.into(), tampered).unwrap_err(),
            CoreError::Corrupt
        );
        // A chat the store does not know cannot seal or open anything.
        assert_eq!(
            device
                .core
                .seal_local(CHAT_Y.into(), b"x".to_vec())
                .unwrap_err(),
            CoreError::UnknownChat
        );
        assert_eq!(
            device
                .core
                .open_local(CHAT_Y.into(), vec![0; 60])
                .unwrap_err(),
            CoreError::UnknownChat
        );
        assert_eq!(
            device
                .core
                .seal_local("../x".into(), b"x".to_vec())
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
            .seal_local(CHAT_X.into(), b"for X only".to_vec())
            .unwrap();
        assert_eq!(
            a.core.open_local(CHAT_X.into(), sealed_x.clone()).unwrap(),
            b"for X only"
        );
        // Another chat on the same device: another key (and another AAD).
        assert_eq!(
            a.core
                .open_local(CHAT_Y.into(), sealed_x.clone())
                .unwrap_err(),
            CoreError::Corrupt
        );
        // The same chat id on another device: another key.
        assert_eq!(
            other.core.open_local(CHAT_X.into(), sealed_x).unwrap_err(),
            CoreError::Corrupt
        );
    }

    #[test]
    fn history_key_survives_reload() {
        let mut a = invited(CHAT_X);
        let key = a.history_key(CHAT_X);
        let sealed = a
            .core
            .seal_local(CHAT_X.into(), b"before the restart".to_vec())
            .unwrap();

        a.reopen();
        assert_eq!(a.history_key(CHAT_X), key);
        assert_eq!(
            a.core.open_local(CHAT_X.into(), sealed.clone()).unwrap(),
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
            a.core.open_local(CHAT_X.into(), sealed).unwrap(),
            b"before the restart"
        );
    }

    #[test]
    fn delete_chat_makes_history_unreadable() {
        let mut a = invited(CHAT_X);
        let sealed = a
            .core
            .seal_local(CHAT_X.into(), b"gone with the chat".to_vec())
            .unwrap();

        a.core.delete_chat(CHAT_X.into()).unwrap();
        assert_eq!(
            a.core
                .open_local(CHAT_X.into(), sealed.clone())
                .unwrap_err(),
            CoreError::UnknownChat
        );
        // Re-creating the chat under the same id draws a new key: the old
        // seals stay unreadable by design.
        a.core.create_invitation(CHAT_X.into()).unwrap();
        assert_eq!(
            a.core.open_local(CHAT_X.into(), sealed).unwrap_err(),
            CoreError::Corrupt
        );
    }
}
