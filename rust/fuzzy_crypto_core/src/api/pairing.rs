use crate::api::core::CryptoCore;
use crate::error::CoreError;
use crate::formats::{decode_pasted, encode_text};
use crate::pairing;
use crate::state::ChatState;
use crate::store::{validate_chat_id, OpenStore};

/// Where a chat stands in the handshake, as the core sees it. The Dart cubits
/// keep their own `ChatSetupStatus`; this is for tests and consistency checks.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ChatStatus {
    /// An inviter waiting for the acceptance.
    Invited,
    /// A session exists on this side.
    Connected,
}

/// `Some(state)` for a chat the store knows, `None` for a new one.
fn existing_state(store: &OpenStore, chat_id: &str) -> Result<Option<ChatState>, CoreError> {
    match store.load_state(chat_id) {
        Ok(state) => Ok(Some(state)),
        Err(CoreError::UnknownChat) => Ok(None),
        Err(error) => Err(error),
    }
}

impl CryptoCore {
    /// A (inviter): creates the chat's Olm account and returns the signed
    /// invitation as `Fuzz/` text. Calling it again for a pending chat
    /// **regenerates** — a brand-new account replaces the old one, so the old
    /// invitation can no longer be completed. A connected chat is `Internal`.
    pub fn create_invitation(&mut self, chat_id: String) -> Result<String, CoreError> {
        validate_chat_id(&chat_id)?;
        let store = self.opened_mut()?;
        if existing_state(store, &chat_id)?.is_some_and(|state| state.session.is_some()) {
            return Err(CoreError::Internal);
        }
        let (state, text) = pairing::create_invitation(&chat_id)?;
        store.put_state(state)?;
        Ok(text)
    }

    /// B (accepter): verifies A's invitation, establishes the outbound session
    /// on its one-time key and returns the signed acceptance as `Fuzz/` text.
    /// `chat_id` must be the one inside the invitation (`WrongChat` otherwise);
    /// a chat that already has state is `Internal`.
    pub fn accept_invitation(
        &mut self,
        chat_id: String,
        invitation: String,
    ) -> Result<String, CoreError> {
        validate_chat_id(&chat_id)?;
        let store = self.opened_mut()?;
        let (_, blob) = decode_pasted(&invitation)?;
        let invitation = pairing::verify_invitation(&chat_id, &blob)?;
        if existing_state(store, &chat_id)?.is_some() {
            return Err(CoreError::Internal);
        }
        let (state, text) = pairing::accept_invitation(&chat_id, &invitation)?;
        store.put_state(state)?;
        Ok(text)
    }

    /// A (inviter): verifies B's acceptance and completes the handshake —
    /// the one-time key is consumed exactly once, so a second acceptance for
    /// the same invitation is `InvitationAlreadyUsed`. The session is on disk
    /// before this returns; any failure leaves the chat untouched.
    pub fn complete_handshake(
        &mut self,
        chat_id: String,
        acceptance: String,
    ) -> Result<(), CoreError> {
        validate_chat_id(&chat_id)?;
        let store = self.opened_mut()?;
        let (_, blob) = decode_pasted(&acceptance)?;
        let acceptance = pairing::verify_acceptance(&chat_id, &blob)?;
        store.with_state_mut(&chat_id, |state| {
            pairing::complete_handshake(state, &acceptance)
        })
    }

    /// The invitation this chat last produced, for re-display.
    pub fn current_invitation(&self, chat_id: String) -> Result<String, CoreError> {
        let state = self.opened()?.load_state(&chat_id)?;
        state
            .last_invitation
            .as_deref()
            .map(encode_text)
            .ok_or(CoreError::UnknownChat)
    }

    /// The acceptance this chat last produced, for re-display.
    pub fn current_acceptance(&self, chat_id: String) -> Result<String, CoreError> {
        let state = self.opened()?.load_state(&chat_id)?;
        state
            .last_acceptance
            .as_deref()
            .map(encode_text)
            .ok_or(CoreError::UnknownChat)
    }

    /// `Connected` once this side holds a session, `Invited` before.
    pub fn chat_status(&self, chat_id: String) -> Result<ChatStatus, CoreError> {
        let state = self.opened()?.load_state(&chat_id)?;
        Ok(if state.session.is_some() {
            ChatStatus::Connected
        } else {
            ChatStatus::Invited
        })
    }
}

#[cfg(test)]
mod tests {
    use std::fs;
    use std::path::{Path, PathBuf};

    use vodozemac::olm::{OlmMessage, Session};

    use super::*;
    use crate::api::core::{create_store_key, open_store};
    use crate::formats::{decode_text, encode_text, InnerHeader};
    use crate::state::Role;
    use crate::store::test_support::temp_dir;
    use crate::store::STORE_SUBDIR;

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

        /// Drops the handle and opens the same store again.
        fn reopen(&mut self) {
            self.core.close();
            self.core = open_store(
                self.dir.to_string_lossy().into_owned(),
                self.wrapped.clone(),
                "".into(),
            )
            .unwrap();
        }

        fn state_file(&self, chat_id: &str) -> PathBuf {
            self.dir.join(STORE_SUBDIR).join(format!("{chat_id}.state"))
        }

        fn state_bytes(&self, chat_id: &str) -> Vec<u8> {
            fs::read(self.state_file(chat_id)).unwrap()
        }

        fn state(&self, chat_id: &str) -> ChatState {
            self.core.opened().unwrap().load_state(chat_id).unwrap()
        }

        fn session(&self, chat_id: &str) -> Session {
            let mut state = self.state(chat_id);
            Session::from_pickle(state.session.take().unwrap())
        }
    }

    impl Drop for Device {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.dir);
        }
    }

    /// A invites, B accepts, A completes — the happy path every test builds on.
    fn paired() -> (Device, Device, String, String) {
        let mut a = Device::new();
        let mut b = Device::new();
        let invitation = a.core.create_invitation(CHAT_X.into()).unwrap();
        let acceptance = b
            .core
            .accept_invitation(CHAT_X.into(), invitation.clone())
            .unwrap();
        a.core
            .complete_handshake(CHAT_X.into(), acceptance.clone())
            .unwrap();
        (a, b, invitation, acceptance)
    }

    fn flipped(text: &str, offset: usize) -> String {
        let mut blob = decode_text(text).unwrap();
        blob[offset] ^= 0x01;
        encode_text(&blob)
    }

    fn assert_no_state(path: &Path) {
        assert!(!path.exists(), "no state may be written on a rejection");
    }

    #[test]
    fn two_parties_round_trip() {
        let (a, b, invitation, acceptance) = paired();

        assert_eq!(
            a.core.chat_status(CHAT_X.into()).unwrap(),
            ChatStatus::Connected
        );
        assert_eq!(
            b.core.chat_status(CHAT_X.into()).unwrap(),
            ChatStatus::Connected
        );
        println!(
            "invitation {} B, acceptance {} B (binary)",
            decode_text(&invitation).unwrap().len(),
            decode_text(&acceptance).unwrap().len()
        );

        // The handshake header was verified inside complete_handshake; the
        // resulting states mirror each other.
        let a_state = a.state(CHAT_X);
        let b_state = b.state(CHAT_X);
        assert_eq!(a_state.role, Role::Inviter);
        assert_eq!(b_state.role, Role::Accepter);
        assert_eq!(a_state.peer_ed25519, Some(b_state.our_ed25519));
        assert_eq!(b_state.peer_ed25519, Some(a_state.our_ed25519));
        assert_eq!(
            a_state.peer_curve25519,
            Some(b_state.account().unwrap().curve25519_key().to_bytes())
        );
        assert_eq!(
            (
                a_state.send_counter,
                a_state.recv_highest,
                a_state.recv_seen_bitmap
            ),
            (0, 0, 1)
        );
        assert_eq!(
            (
                b_state.send_counter,
                b_state.recv_highest,
                b_state.recv_seen_bitmap
            ),
            (1, 0, 0)
        );
        assert_eq!(
            a_state.account().unwrap().stored_one_time_key_count(),
            0,
            "the one-time key was consumed"
        );

        // The sessions are live: one message each way (the message API is F2-4).
        let mut a_session = a.session(CHAT_X);
        let mut b_session = b.session(CHAT_X);
        let to_b = a_session.encrypt(b"from A").unwrap();
        assert!(matches!(to_b, OlmMessage::Normal(_)));
        assert_eq!(b_session.decrypt(&to_b).unwrap(), b"from A");
        let to_a = b_session.encrypt(b"from B").unwrap();
        assert_eq!(a_session.decrypt(&to_a).unwrap(), b"from B");
    }

    #[test]
    fn handshake_inner_header_is_what_complete_checks() {
        let mut a = Device::new();
        let mut b = Device::new();
        let invitation = a.core.create_invitation(CHAT_X.into()).unwrap();
        let acceptance = b.core.accept_invitation(CHAT_X.into(), invitation).unwrap();

        // Decrypt the handshake on a scratch copy of A's account to look at it.
        let blob = decode_text(&acceptance).unwrap();
        let acceptance = pairing::verify_acceptance(CHAT_X, &blob).unwrap();
        let mut account = a.state(CHAT_X).account().unwrap();
        let inbound = account
            .create_inbound_session(
                vodozemac::olm::SessionConfig::version_1(),
                vodozemac::Curve25519PublicKey::from_bytes(acceptance.b_curve25519),
                &vodozemac::olm::PreKeyMessage::from_bytes(&acceptance.prekey_msg).unwrap(),
            )
            .unwrap();
        let header = InnerHeader::decode(&inbound.plaintext).unwrap();
        assert_eq!(header.chat_id, CHAT_X);
        assert_eq!(header.sender_ed25519, acceptance.b_ed25519);
        assert_eq!(header.recipient_ed25519, a.state(CHAT_X).our_ed25519);
        assert_eq!(header.direction, crate::formats::Direction::BToA);
        assert_eq!(header.counter, 0);
        assert_eq!(header.content_type, crate::formats::ContentType::Handshake);
        assert!(header.body.is_empty());
        assert_eq!(inbound.plaintext.len(), 116);
    }

    #[test]
    fn second_acceptance_rejected() {
        let (mut a, _b, invitation, acceptance) = paired();
        let before = a.state_bytes(CHAT_X);

        // The same acceptance pasted twice.
        assert_eq!(
            a.core
                .complete_handshake(CHAT_X.into(), acceptance)
                .unwrap_err(),
            CoreError::InvitationAlreadyUsed
        );
        assert_eq!(a.state_bytes(CHAT_X), before);

        // A second accepter of the same invitation.
        let mut c = Device::new();
        let second = c.core.accept_invitation(CHAT_X.into(), invitation).unwrap();
        assert_eq!(
            a.core
                .complete_handshake(CHAT_X.into(), second)
                .unwrap_err(),
            CoreError::InvitationAlreadyUsed
        );
        assert_eq!(a.state_bytes(CHAT_X), before);
        assert_eq!(
            a.core.chat_status(CHAT_X.into()).unwrap(),
            ChatStatus::Connected
        );
    }

    #[test]
    fn two_accepters_race_only_the_first_completes() {
        let mut a = Device::new();
        let mut b = Device::new();
        let mut c = Device::new();
        let invitation = a.core.create_invitation(CHAT_X.into()).unwrap();
        let from_b = b
            .core
            .accept_invitation(CHAT_X.into(), invitation.clone())
            .unwrap();
        let from_c = c.core.accept_invitation(CHAT_X.into(), invitation).unwrap();

        a.core.complete_handshake(CHAT_X.into(), from_c).unwrap();
        let before = a.state_bytes(CHAT_X);
        assert_eq!(
            a.core
                .complete_handshake(CHAT_X.into(), from_b)
                .unwrap_err(),
            CoreError::InvitationAlreadyUsed
        );
        assert_eq!(a.state_bytes(CHAT_X), before);
        assert_eq!(
            a.state(CHAT_X).peer_ed25519,
            Some(c.state(CHAT_X).our_ed25519)
        );
    }

    #[test]
    fn tampered_invitation_rejected() {
        let mut a = Device::new();
        let mut b = Device::new();
        let invitation = a.core.create_invitation(CHAT_X.into()).unwrap();
        let b_file = b.state_file(CHAT_X);

        // One byte in each field: chat_id (7..43), curve (43..75), ed (75..107),
        // otk (107..139), sig (139..203).
        for offset in [7, 20, 42, 43, 74, 75, 106, 107, 138, 139, 170, 202] {
            assert_eq!(
                b.core
                    .accept_invitation(CHAT_X.into(), flipped(&invitation, offset))
                    .unwrap_err(),
                CoreError::InvalidSignature,
                "offset {offset}"
            );
            assert_no_state(&b_file);
        }
        // Header bytes: magic, version, type.
        for offset in [0, 3, 4, 5] {
            assert_eq!(
                b.core
                    .accept_invitation(CHAT_X.into(), flipped(&invitation, offset))
                    .unwrap_err(),
                CoreError::UnsupportedFormat,
                "offset {offset}"
            );
            assert_no_state(&b_file);
        }
        // Length byte → the layout no longer parses.
        assert_eq!(
            b.core
                .accept_invitation(CHAT_X.into(), flipped(&invitation, 6))
                .unwrap_err(),
            CoreError::Corrupt
        );
        // Truncated / extended.
        let blob = decode_text(&invitation).unwrap();
        assert_eq!(
            b.core
                .accept_invitation(CHAT_X.into(), encode_text(&blob[..202]))
                .unwrap_err(),
            CoreError::Corrupt
        );
        let mut extended = blob.clone();
        extended.push(0);
        assert_eq!(
            b.core
                .accept_invitation(CHAT_X.into(), encode_text(&extended))
                .unwrap_err(),
            CoreError::Corrupt
        );
        // Not an invitation at all.
        assert_eq!(
            b.core
                .accept_invitation(CHAT_X.into(), "Fuzz/RlVaWgEDAd6tvu8".into())
                .unwrap_err(),
            CoreError::UnsupportedFormat
        );
        assert_eq!(
            b.core
                .accept_invitation(CHAT_X.into(), "not a blob".into())
                .unwrap_err(),
            CoreError::UnsupportedFormat
        );
        assert_no_state(&b_file);

        // The untouched invitation still works.
        b.core.accept_invitation(CHAT_X.into(), invitation).unwrap();
    }

    #[test]
    fn tampered_acceptance_rejected() {
        let mut a = Device::new();
        let mut b = Device::new();
        let invitation = a.core.create_invitation(CHAT_X.into()).unwrap();
        let acceptance = b.core.accept_invitation(CHAT_X.into(), invitation).unwrap();
        let before = a.state_bytes(CHAT_X);
        let len = decode_text(&acceptance).unwrap().len();

        // chat_id, curve, ed, prekey (first and last byte), sig (first and last).
        for offset in [7, 42, 43, 74, 75, 106, 109, len - 65, len - 64, len - 1] {
            assert_eq!(
                a.core
                    .complete_handshake(CHAT_X.into(), flipped(&acceptance, offset))
                    .unwrap_err(),
                CoreError::InvalidSignature,
                "offset {offset}"
            );
            assert_eq!(a.state_bytes(CHAT_X), before, "offset {offset}");
        }
        for offset in [0, 4, 5] {
            assert_eq!(
                a.core
                    .complete_handshake(CHAT_X.into(), flipped(&acceptance, offset))
                    .unwrap_err(),
                CoreError::UnsupportedFormat
            );
        }
        // Length prefixes are layout, not content: chat_id_len, prekey_len (both bytes).
        for offset in [6, 107, 108] {
            assert_eq!(
                a.core
                    .complete_handshake(CHAT_X.into(), flipped(&acceptance, offset))
                    .unwrap_err(),
                CoreError::Corrupt,
                "offset {offset}"
            );
        }
        assert_eq!(
            a.core
                .complete_handshake(CHAT_X.into(), "Fuzz/RlVaWgEDAd6tvu8".into())
                .unwrap_err(),
            CoreError::UnsupportedFormat
        );
        assert_eq!(a.state_bytes(CHAT_X), before);
        assert_eq!(
            a.core.chat_status(CHAT_X.into()).unwrap(),
            ChatStatus::Invited
        );

        a.core
            .complete_handshake(CHAT_X.into(), acceptance)
            .unwrap();
    }

    #[test]
    fn resigned_acceptance_under_another_identity_rejected() {
        // C re-signs B's pre-key message under C's own keys — the signature
        // verifies, but the pre-key message still names B's identity key.
        let mut a = Device::new();
        let mut b = Device::new();
        let mut c = Device::new();
        let invitation = a.core.create_invitation(CHAT_X.into()).unwrap();
        let from_b = b
            .core
            .accept_invitation(CHAT_X.into(), invitation.clone())
            .unwrap();
        let _from_c = c.core.accept_invitation(CHAT_X.into(), invitation).unwrap();
        let before = a.state_bytes(CHAT_X);

        // Re-sign B's acceptance under C's key with C's curve key swapped in.
        let mut forged =
            pairing::verify_acceptance(CHAT_X, &decode_text(&from_b).unwrap()).unwrap();
        let c_account = c.state(CHAT_X).account().unwrap();
        forged.b_curve25519 = c_account.curve25519_key().to_bytes();
        forged.b_ed25519 = *c_account.ed25519_key().as_bytes();
        forged.signature = c_account.sign(forged.to_be_signed().unwrap()).to_bytes();
        let forged_text = encode_text(&forged.encode().unwrap());

        // MismatchedIdentityKey → InvitationAlreadyUsed by the spec's mapping.
        assert_eq!(
            a.core
                .complete_handshake(CHAT_X.into(), forged_text)
                .unwrap_err(),
            CoreError::InvitationAlreadyUsed
        );
        assert_eq!(a.state_bytes(CHAT_X), before);
        a.core.complete_handshake(CHAT_X.into(), from_b).unwrap();
    }

    /// A dishonest inner header inside an otherwise honest, honestly-signed Olm
    /// acceptance must be rejected `Corrupt` **after** the Olm decrypt but
    /// **before** the save — so the one-time key is never consumed and A's state
    /// file is untouched. The committed acceptance tests all carry an honest
    /// header, so without this a dropped header check would still pass
    /// `cargo test` (F2-3 review nit 1 — the reviewer's 11-variant harness).
    #[test]
    fn wrong_inner_header_is_corrupt_and_keeps_the_otk() {
        use vodozemac::olm::{Account, SessionConfig};
        use vodozemac::Curve25519PublicKey;

        use crate::formats::{Acceptance, ContentType, Direction, SIGNATURE_LEN};

        let mut a = Device::new();
        let invitation_text = a.core.create_invitation(CHAT_X.into()).unwrap();
        let invitation =
            pairing::verify_invitation(CHAT_X, &decode_text(&invitation_text).unwrap()).unwrap();

        // Build an acceptance whose Olm session is honest (A's real one-time key)
        // but whose inner-header plaintext is produced by `corrupt`, signed under
        // the B account that produced it.
        let forge = |corrupt: &dyn Fn(InnerHeader) -> Vec<u8>| -> String {
            let b = Account::new();
            let honest = InnerHeader {
                chat_id: CHAT_X.to_string(),
                sender_ed25519: *b.ed25519_key().as_bytes(),
                recipient_ed25519: invitation.a_ed25519,
                direction: Direction::BToA,
                counter: 0,
                content_type: ContentType::Handshake,
                body: Vec::new(),
            };
            let plaintext = corrupt(honest);
            let mut session = b
                .create_outbound_session(
                    SessionConfig::version_1(),
                    Curve25519PublicKey::from_bytes(invitation.a_curve25519),
                    Curve25519PublicKey::from_bytes(invitation.a_one_time_key),
                )
                .unwrap();
            let prekey_msg = match session.encrypt(plaintext).unwrap() {
                OlmMessage::PreKey(message) => message.to_bytes(),
                OlmMessage::Normal(_) => panic!("the first message is always a pre-key"),
            };
            let mut acceptance = Acceptance {
                chat_id: CHAT_X.to_string(),
                b_curve25519: b.curve25519_key().to_bytes(),
                b_ed25519: *b.ed25519_key().as_bytes(),
                prekey_msg,
                signature: [0; SIGNATURE_LEN],
            };
            acceptance.signature = b.sign(acceptance.to_be_signed().unwrap()).to_bytes();
            encode_text(&acceptance.encode().unwrap())
        };

        type Corrupt = Box<dyn Fn(InnerHeader) -> Vec<u8>>;
        let variants: Vec<(&str, Corrupt)> = vec![
            (
                "wrong chat id",
                Box::new(|mut h: InnerHeader| {
                    h.chat_id = CHAT_Y.to_string();
                    h.encode().unwrap()
                }),
            ),
            (
                "wrong sender key",
                Box::new(|mut h: InnerHeader| {
                    h.sender_ed25519 = [0xEE; 32];
                    h.encode().unwrap()
                }),
            ),
            (
                "wrong recipient key",
                Box::new(|mut h: InnerHeader| {
                    h.recipient_ed25519 = [0xEE; 32];
                    h.encode().unwrap()
                }),
            ),
            (
                "direction A->B",
                Box::new(|mut h: InnerHeader| {
                    h.direction = Direction::AToB;
                    h.encode().unwrap()
                }),
            ),
            (
                "counter 1",
                Box::new(|mut h: InnerHeader| {
                    h.counter = 1;
                    h.encode().unwrap()
                }),
            ),
            (
                "content type text",
                Box::new(|mut h: InnerHeader| {
                    h.content_type = ContentType::Text;
                    h.encode().unwrap()
                }),
            ),
            (
                "inner version 2",
                Box::new(|h: InnerHeader| {
                    let mut bytes = h.encode().unwrap();
                    bytes[0] = 2;
                    bytes
                }),
            ),
            ("empty", Box::new(|_h: InnerHeader| Vec::new())),
            (
                "garbage",
                Box::new(|_h: InnerHeader| b"not an inner header".to_vec()),
            ),
            (
                "truncated",
                Box::new(|h: InnerHeader| {
                    let mut bytes = h.encode().unwrap();
                    bytes.pop();
                    bytes
                }),
            ),
            (
                "trailing byte",
                Box::new(|h: InnerHeader| {
                    let mut bytes = h.encode().unwrap();
                    bytes.push(0);
                    bytes
                }),
            ),
        ];

        for (name, corrupt) in &variants {
            let acceptance = forge(corrupt);
            let before = a.state_bytes(CHAT_X);
            assert_eq!(
                a.core
                    .complete_handshake(CHAT_X.into(), acceptance)
                    .unwrap_err(),
                CoreError::Corrupt,
                "{name}"
            );
            assert_eq!(a.state_bytes(CHAT_X), before, "{name}: state untouched");
            assert_eq!(
                a.state(CHAT_X)
                    .account()
                    .unwrap()
                    .stored_one_time_key_count(),
                1,
                "{name}: one-time key not consumed"
            );
        }

        // An honest acceptance still completes afterwards.
        let mut b = Device::new();
        let honest = b
            .core
            .accept_invitation(CHAT_X.into(), invitation_text)
            .unwrap();
        a.core.complete_handshake(CHAT_X.into(), honest).unwrap();
        assert_eq!(
            a.core.chat_status(CHAT_X.into()).unwrap(),
            ChatStatus::Connected
        );
    }

    #[test]
    fn regenerate_invalidates_old() {
        let mut a = Device::new();
        let mut b = Device::new();
        let old = a.core.create_invitation(CHAT_X.into()).unwrap();
        let old_state = a.state_bytes(CHAT_X);
        let new = a.core.create_invitation(CHAT_X.into()).unwrap();

        assert_ne!(old, new);
        assert_ne!(a.state_bytes(CHAT_X), old_state);
        assert_eq!(a.core.current_invitation(CHAT_X.into()).unwrap(), new);
        assert_eq!(
            a.core.chat_status(CHAT_X.into()).unwrap(),
            ChatStatus::Invited
        );

        // B accepts the old one: B cannot know, A rejects it.
        let stale = b.core.accept_invitation(CHAT_X.into(), old).unwrap();
        let pending = a.state_bytes(CHAT_X);
        assert_eq!(
            a.core.complete_handshake(CHAT_X.into(), stale).unwrap_err(),
            CoreError::InvitationAlreadyUsed
        );
        assert_eq!(a.state_bytes(CHAT_X), pending);

        // B starts over with the new one.
        b.core.delete_chat(CHAT_X.into()).unwrap();
        let fresh = b.core.accept_invitation(CHAT_X.into(), new).unwrap();
        a.core.complete_handshake(CHAT_X.into(), fresh).unwrap();
        assert_eq!(
            a.core.chat_status(CHAT_X.into()).unwrap(),
            ChatStatus::Connected
        );

        // Connected: no more invitations for this chat.
        assert_eq!(
            a.core.create_invitation(CHAT_X.into()).unwrap_err(),
            CoreError::Internal
        );
    }

    #[test]
    fn redisplay_after_reload() {
        let (mut a, mut b, invitation, acceptance) = paired();

        a.reopen();
        b.reopen();
        assert_eq!(
            a.core.current_invitation(CHAT_X.into()).unwrap(),
            invitation
        );
        assert_eq!(
            b.core.current_acceptance(CHAT_X.into()).unwrap(),
            acceptance
        );
        assert_eq!(
            a.core.chat_status(CHAT_X.into()).unwrap(),
            ChatStatus::Connected
        );
        assert_eq!(
            b.core.chat_status(CHAT_X.into()).unwrap(),
            ChatStatus::Connected
        );
        // Each side only has the blob it produced.
        assert_eq!(
            a.core.current_acceptance(CHAT_X.into()).unwrap_err(),
            CoreError::UnknownChat
        );
        assert_eq!(
            b.core.current_invitation(CHAT_X.into()).unwrap_err(),
            CoreError::UnknownChat
        );
        assert_eq!(
            a.core.current_invitation(CHAT_Y.into()).unwrap_err(),
            CoreError::UnknownChat
        );
        assert_eq!(
            a.core.chat_status(CHAT_Y.into()).unwrap_err(),
            CoreError::UnknownChat
        );
    }

    #[test]
    fn wrong_chat_rejected() {
        let mut a = Device::new();
        let mut b = Device::new();
        let invitation_x = a.core.create_invitation(CHAT_X.into()).unwrap();
        let _invitation_y = a.core.create_invitation(CHAT_Y.into()).unwrap();
        let y_before = a.state_bytes(CHAT_Y);

        // X's invitation pasted into B's chat Y.
        assert_eq!(
            b.core
                .accept_invitation(CHAT_Y.into(), invitation_x.clone())
                .unwrap_err(),
            CoreError::WrongChat
        );
        assert_no_state(&b.state_file(CHAT_Y));

        // X's acceptance pasted into A's chat Y.
        let acceptance_x = b
            .core
            .accept_invitation(CHAT_X.into(), invitation_x)
            .unwrap();
        assert_eq!(
            a.core
                .complete_handshake(CHAT_Y.into(), acceptance_x.clone())
                .unwrap_err(),
            CoreError::WrongChat
        );
        assert_eq!(a.state_bytes(CHAT_Y), y_before);
        assert_eq!(
            a.core.chat_status(CHAT_Y.into()).unwrap(),
            ChatStatus::Invited
        );
        a.core
            .complete_handshake(CHAT_X.into(), acceptance_x)
            .unwrap();
    }

    #[test]
    fn chat_id_is_validated_before_anything_else() {
        let mut a = Device::new();
        let (_a2, _b, invitation, acceptance) = paired();
        for bad in ["", "../../x", "6F1E9B2C-3D4A-4F5B-8C6D-7E8F9A0B1C2D"] {
            assert_eq!(
                a.core.create_invitation(bad.into()).unwrap_err(),
                CoreError::Corrupt
            );
            assert_eq!(
                a.core
                    .accept_invitation(bad.into(), invitation.clone())
                    .unwrap_err(),
                CoreError::Corrupt
            );
            assert_eq!(
                a.core
                    .complete_handshake(bad.into(), acceptance.clone())
                    .unwrap_err(),
                CoreError::Corrupt
            );
            assert_eq!(
                a.core.current_invitation(bad.into()).unwrap_err(),
                CoreError::Corrupt
            );
            assert_eq!(
                a.core.chat_status(bad.into()).unwrap_err(),
                CoreError::Corrupt
            );
        }
        assert!(fs::read_dir(a.dir.join(STORE_SUBDIR))
            .unwrap()
            .next()
            .is_none());
    }

    #[test]
    fn accept_on_an_existing_chat_and_locked_store_fail_cleanly() {
        let (mut a, mut b, invitation, _) = paired();
        let b_before = b.state_bytes(CHAT_X);

        assert_eq!(
            b.core
                .accept_invitation(CHAT_X.into(), invitation.clone())
                .unwrap_err(),
            CoreError::Internal
        );
        assert_eq!(b.state_bytes(CHAT_X), b_before);
        // A's own pending chat cannot accept its own invitation either.
        let mut c = Device::new();
        let own = c.core.create_invitation(CHAT_Y.into()).unwrap();
        assert_eq!(
            c.core.accept_invitation(CHAT_Y.into(), own).unwrap_err(),
            CoreError::Internal
        );

        a.core.close();
        assert_eq!(
            a.core.create_invitation(CHAT_Y.into()).unwrap_err(),
            CoreError::StoreLocked
        );
        assert_eq!(
            a.core
                .accept_invitation(CHAT_Y.into(), invitation)
                .unwrap_err(),
            CoreError::StoreLocked
        );
        assert_eq!(
            a.core.chat_status(CHAT_X.into()).unwrap_err(),
            CoreError::StoreLocked
        );
    }
}
