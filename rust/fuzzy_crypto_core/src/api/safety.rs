use crate::api::core::CryptoCore;
use crate::error::CoreError;
use crate::safety;
use crate::store::validate_chat_id;

impl CryptoCore {
    /// The chat's 60-digit safety number (`"12345 67890 …"`, 12 groups), derived
    /// from both Ed25519 identity keys and the chat id (plan §B.3) — identical on
    /// both sides of a pairing. `UnknownChat` for a chat the store does not know
    /// or that is not paired yet. Nothing secret is involved; it stays async
    /// like every other call on the handle.
    pub fn safety_number(&self, chat_id: String) -> Result<String, CoreError> {
        let state = self.opened()?.load_state(&chat_id)?;
        safety::safety_number(&state)
    }

    /// Persists whether the user compared the safety number with the peer. The
    /// flag is on disk before this returns; a chat that is not paired yet is
    /// `UnknownChat`.
    pub fn mark_verified(&mut self, chat_id: String, verified: bool) -> Result<(), CoreError> {
        validate_chat_id(&chat_id)?;
        self.opened_mut()?
            .with_state_mut(&chat_id, |state| safety::mark_verified(state, verified))
    }

    /// The persisted flag; `false` for every chat until [`CryptoCore::mark_verified`].
    pub fn is_verified(&self, chat_id: String) -> Result<bool, CoreError> {
        let state = self.opened()?.load_state(&chat_id)?;
        Ok(state.verified)
    }
}

#[cfg(test)]
mod tests {
    mod safety_number {
        use std::fs;
        use std::path::PathBuf;

        use crate::api::core::{create_store_key, open_store, CryptoCore};
        use crate::error::CoreError;
        use crate::safety::safety_number_for;
        use crate::store::test_support::temp_dir;
        use crate::store::STORE_SUBDIR;

        const CHAT_X: &str = "6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d";

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

            /// Drops the handle and opens the same store again (every later
            /// read comes from disk, as after a restart).
            fn reopen(&mut self) {
                self.core.close();
                self.core = open_store(
                    self.dir.to_string_lossy().into_owned(),
                    self.wrapped.clone(),
                    "".into(),
                )
                .unwrap();
            }

            fn state_bytes(&self, chat_id: &str) -> Vec<u8> {
                fs::read(self.dir.join(STORE_SUBDIR).join(format!("{chat_id}.state"))).unwrap()
            }
        }

        impl Drop for Device {
            fn drop(&mut self) {
                let _ = fs::remove_dir_all(&self.dir);
            }
        }

        /// Pairs `inviter` and `accepter` on `chat_id` (create → accept → complete).
        fn pair(inviter: &mut Device, accepter: &mut Device, chat_id: &str) {
            let invitation = inviter.core.create_invitation(chat_id.into()).unwrap();
            let acceptance = accepter
                .core
                .accept_invitation(chat_id.into(), invitation)
                .unwrap();
            inviter
                .core
                .complete_handshake(chat_id.into(), acceptance)
                .unwrap();
        }

        #[test]
        fn symmetric() {
            let mut a = Device::new();
            let mut b = Device::new();
            pair(&mut a, &mut b, CHAT_X);

            let on_a = a.core.safety_number(CHAT_X.into()).unwrap();
            let on_b = b.core.safety_number(CHAT_X.into()).unwrap();
            assert_eq!(on_a, on_b);
            assert_eq!(on_a.len(), 60 + 11);

            // It is the pure function over the two identity keys the states hold.
            let a_state = a.core.opened().unwrap().load_state(CHAT_X).unwrap();
            let b_state = b.core.opened().unwrap().load_state(CHAT_X).unwrap();
            assert_eq!(
                on_a,
                safety_number_for(CHAT_X, &a_state.our_ed25519, &b_state.our_ed25519)
            );

            // Another pairing of the same chat id has other keys, so other digits.
            let mut a2 = Device::new();
            let mut b2 = Device::new();
            pair(&mut a2, &mut b2, CHAT_X);
            assert_ne!(a2.core.safety_number(CHAT_X.into()).unwrap(), on_a);
        }

        #[test]
        fn unpaired_chat_is_unknown() {
            let mut a = Device::new();
            let mut b = Device::new();
            assert_eq!(
                a.core.safety_number(CHAT_X.into()).unwrap_err(),
                CoreError::UnknownChat
            );
            assert_eq!(
                a.core.is_verified(CHAT_X.into()).unwrap_err(),
                CoreError::UnknownChat
            );
            assert_eq!(
                a.core.mark_verified(CHAT_X.into(), true).unwrap_err(),
                CoreError::UnknownChat
            );

            // An inviter waiting for the acceptance has no peer key yet: the
            // number does not exist and the flag cannot be set ahead of it.
            let invitation = a.core.create_invitation(CHAT_X.into()).unwrap();
            let before = a.state_bytes(CHAT_X);
            assert_eq!(
                a.core.safety_number(CHAT_X.into()).unwrap_err(),
                CoreError::UnknownChat
            );
            assert_eq!(
                a.core.mark_verified(CHAT_X.into(), true).unwrap_err(),
                CoreError::UnknownChat
            );
            assert_eq!(
                a.state_bytes(CHAT_X),
                before,
                "a refused mark never rewrites"
            );
            assert!(!a.core.is_verified(CHAT_X.into()).unwrap());

            // The accepter holds A's key from the invitation, so it can compare
            // right away — and A can once the handshake completes.
            let acceptance = b.core.accept_invitation(CHAT_X.into(), invitation).unwrap();
            let on_b = b.core.safety_number(CHAT_X.into()).unwrap();
            a.core
                .complete_handshake(CHAT_X.into(), acceptance)
                .unwrap();
            assert_eq!(a.core.safety_number(CHAT_X.into()).unwrap(), on_b);
            assert!(!a.core.is_verified(CHAT_X.into()).unwrap());
        }

        #[test]
        fn verified_flag_survives_reload() {
            let mut a = Device::new();
            let mut b = Device::new();
            pair(&mut a, &mut b, CHAT_X);
            assert!(!a.core.is_verified(CHAT_X.into()).unwrap());
            assert!(!b.core.is_verified(CHAT_X.into()).unwrap());

            let before = a.state_bytes(CHAT_X);
            a.core.mark_verified(CHAT_X.into(), true).unwrap();
            assert_ne!(
                a.state_bytes(CHAT_X),
                before,
                "the flag is on disk before the call returns"
            );
            assert!(a.core.is_verified(CHAT_X.into()).unwrap());

            a.reopen();
            assert!(a.core.is_verified(CHAT_X.into()).unwrap());
            assert!(
                !b.core.is_verified(CHAT_X.into()).unwrap(),
                "the flag is per device"
            );

            // Unmark round-trips too, and the number itself never changes.
            let number = a.core.safety_number(CHAT_X.into()).unwrap();
            a.core.mark_verified(CHAT_X.into(), false).unwrap();
            a.reopen();
            assert!(!a.core.is_verified(CHAT_X.into()).unwrap());
            assert_eq!(a.core.safety_number(CHAT_X.into()).unwrap(), number);

            // The flag never outlives the pairing: a deleted and re-paired chat
            // starts unverified with new keys.
            a.core.mark_verified(CHAT_X.into(), true).unwrap();
            a.core.delete_chat(CHAT_X.into()).unwrap();
            b.core.delete_chat(CHAT_X.into()).unwrap();
            pair(&mut a, &mut b, CHAT_X);
            assert!(!a.core.is_verified(CHAT_X.into()).unwrap());
            assert_ne!(a.core.safety_number(CHAT_X.into()).unwrap(), number);
        }

        #[test]
        fn locked_store_and_bad_chat_id_fail_cleanly() {
            let mut a = Device::new();
            let mut b = Device::new();
            pair(&mut a, &mut b, CHAT_X);

            for bad in ["", "../../x", "6F1E9B2C-3D4A-4F5B-8C6D-7E8F9A0B1C2D"] {
                assert_eq!(
                    a.core.safety_number(bad.into()).unwrap_err(),
                    CoreError::Corrupt
                );
                assert_eq!(
                    a.core.mark_verified(bad.into(), true).unwrap_err(),
                    CoreError::Corrupt
                );
                assert_eq!(
                    a.core.is_verified(bad.into()).unwrap_err(),
                    CoreError::Corrupt
                );
            }

            a.core.close();
            assert_eq!(
                a.core.safety_number(CHAT_X.into()).unwrap_err(),
                CoreError::StoreLocked
            );
            assert_eq!(
                a.core.mark_verified(CHAT_X.into(), true).unwrap_err(),
                CoreError::StoreLocked
            );
            assert_eq!(
                a.core.is_verified(CHAT_X.into()).unwrap_err(),
                CoreError::StoreLocked
            );
        }
    }
}
