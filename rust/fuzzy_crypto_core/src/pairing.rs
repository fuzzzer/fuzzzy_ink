//! Pairing — an Olm session established through the app's two-blob flow
//! (plan §B.2): A's signed Invitation carries one one-time key, B's signed
//! Acceptance carries the pre-key message that consumes it, and A completes
//! the handshake by creating the inbound session.
//!
//! Pure functions over [`ChatState`] and vodozemac; no I/O. Persistence is the
//! API layer's job (`api/pairing.rs`), through `OpenStore::with_state_mut`, so
//! every `Err` here leaves the state exactly as it was.
//!
//! The Ed25519 signatures cover the whole blob before `sig` — envelope included,
//! so the type byte (`0x01` / `0x02`) separates the two signing domains.

use subtle::ConstantTimeEq;
use vodozemac::olm::{Account, OlmMessage, PreKeyMessage, SessionConfig, SessionCreationError};
use vodozemac::{Curve25519PublicKey, Ed25519PublicKey, Ed25519Signature};

use crate::error::CoreError;
use crate::formats::{
    encode_text, Acceptance, ContentType, Direction, InnerHeader, Invitation, SIGNATURE_LEN,
};
use crate::state::{ChatState, Role};
use crate::store;

/// The bytes an invitation or acceptance signature covers: everything but the trailer.
fn signed_part(blob: &[u8]) -> Result<&[u8], CoreError> {
    let end = blob
        .len()
        .checked_sub(SIGNATURE_LEN)
        .ok_or(CoreError::Corrupt)?;
    blob.get(..end).ok_or(CoreError::Corrupt)
}

/// Strict Ed25519 verification of `signature` over `signed` under `key`.
/// A key or signature that does not parse cannot have signed anything.
fn verify(key: &[u8; 32], signed: &[u8], signature: &[u8; SIGNATURE_LEN]) -> Result<(), CoreError> {
    let key = Ed25519PublicKey::from_slice(key).map_err(|_| CoreError::InvalidSignature)?;
    let signature =
        Ed25519Signature::from_slice(signature).map_err(|_| CoreError::InvalidSignature)?;
    key.verify(signed, &signature)
        .map_err(|_| CoreError::InvalidSignature)
}

/// A fresh, marked-as-published account with exactly one one-time key.
fn account_with_one_time_key() -> Result<(Account, Curve25519PublicKey), CoreError> {
    let mut account = Account::new();
    let generated = account.generate_one_time_keys(1);
    let one_time_key = match generated.created.as_slice() {
        [key] => *key,
        _ => return Err(CoreError::Internal),
    };
    account.mark_keys_as_published();
    Ok((account, one_time_key))
}

/// The signed 0x01 blob for `account`'s keys and `one_time_key`.
pub(crate) fn invitation_blob(
    account: &Account,
    chat_id: &str,
    one_time_key: Curve25519PublicKey,
) -> Result<Vec<u8>, CoreError> {
    let mut invitation = Invitation {
        chat_id: chat_id.to_string(),
        a_curve25519: account.curve25519_key().to_bytes(),
        a_ed25519: *account.ed25519_key().as_bytes(),
        a_one_time_key: one_time_key.to_bytes(),
        signature: [0; SIGNATURE_LEN],
    };
    invitation.signature = account.sign(invitation.to_be_signed()?).to_bytes();
    invitation.encode()
}

/// A (inviter): a brand-new account, one published one-time key, the signed
/// invitation, and the chat's history key drawn alongside (owner decision D-1).
/// Returns the pending state and the `Fuzz/` text.
pub fn create_invitation(chat_id: &str) -> Result<(ChatState, String), CoreError> {
    let (account, one_time_key) = account_with_one_time_key()?;
    let blob = invitation_blob(&account, chat_id, one_time_key)?;
    let text = encode_text(&blob);
    let mut state = ChatState::new(
        Role::Inviter,
        chat_id.to_string(),
        account.pickle(),
        *account.ed25519_key().as_bytes(),
        store::random_array()?,
    );
    state.last_invitation = Some(blob);
    Ok((state, text))
}

/// Decodes and authenticates a pasted invitation, then checks it is for `chat_id`.
/// Signature first: nothing in the blob is trusted before it verifies.
pub fn verify_invitation(chat_id: &str, blob: &[u8]) -> Result<Invitation, CoreError> {
    let invitation = Invitation::decode(blob)?;
    verify(
        &invitation.a_ed25519,
        signed_part(blob)?,
        &invitation.signature,
    )?;
    if invitation.chat_id != chat_id {
        return Err(CoreError::WrongChat);
    }
    Ok(invitation)
}

/// B (accepter): a brand-new account, the outbound session on A's one-time
/// key, the handshake pre-key message inside the signed acceptance, and the
/// chat's history key drawn alongside (owner decision D-1). Returns the
/// connected state and the `Fuzz/` text.
pub fn accept_invitation(
    chat_id: &str,
    invitation: &Invitation,
) -> Result<(ChatState, String), CoreError> {
    let account = Account::new();
    let mut session = account
        .create_outbound_session(
            SessionConfig::version_1(),
            Curve25519PublicKey::from_bytes(invitation.a_curve25519),
            Curve25519PublicKey::from_bytes(invitation.a_one_time_key),
        )
        .map_err(|_| CoreError::Corrupt)?;
    let handshake = InnerHeader {
        chat_id: chat_id.to_string(),
        sender_ed25519: *account.ed25519_key().as_bytes(),
        recipient_ed25519: invitation.a_ed25519,
        direction: Direction::BToA,
        counter: 0,
        content_type: ContentType::Handshake,
        body: Vec::new(),
    }
    .encode()?;
    let prekey_msg = match session.encrypt(handshake) {
        Ok(OlmMessage::PreKey(message)) => message.to_bytes(),
        _ => return Err(CoreError::Internal),
    };
    let mut acceptance = Acceptance {
        chat_id: chat_id.to_string(),
        b_curve25519: account.curve25519_key().to_bytes(),
        b_ed25519: *account.ed25519_key().as_bytes(),
        prekey_msg,
        signature: [0; SIGNATURE_LEN],
    };
    acceptance.signature = account.sign(acceptance.to_be_signed()?).to_bytes();
    let blob = acceptance.encode()?;
    let text = encode_text(&blob);

    let mut state = ChatState::new(
        Role::Accepter,
        chat_id.to_string(),
        account.pickle(),
        *account.ed25519_key().as_bytes(),
        store::random_array()?,
    );
    state.session = Some(session.pickle());
    state.peer_curve25519 = Some(invitation.a_curve25519);
    state.peer_ed25519 = Some(invitation.a_ed25519);
    state.send_counter = 1;
    state.last_acceptance = Some(blob);
    Ok((state, text))
}

/// Decodes and authenticates a pasted acceptance, then checks it is for `chat_id`.
pub fn verify_acceptance(chat_id: &str, blob: &[u8]) -> Result<Acceptance, CoreError> {
    let acceptance = Acceptance::decode(blob)?;
    verify(
        &acceptance.b_ed25519,
        signed_part(blob)?,
        &acceptance.signature,
    )?;
    if acceptance.chat_id != chat_id {
        return Err(CoreError::WrongChat);
    }
    Ok(acceptance)
}

/// A (inviter): consumes the one-time key by creating the inbound session from
/// B's pre-key message, checks the handshake's inner header, and only then
/// writes the session and B's keys into `state`.
pub fn complete_handshake(state: &mut ChatState, acceptance: &Acceptance) -> Result<(), CoreError> {
    if state.role != Role::Inviter || state.session.is_some() {
        return Err(CoreError::InvitationAlreadyUsed);
    }
    let prekey =
        PreKeyMessage::from_bytes(&acceptance.prekey_msg).map_err(|_| CoreError::Corrupt)?;
    let mut account = state.account()?;
    let inbound = account
        .create_inbound_session(
            SessionConfig::version_1(),
            Curve25519PublicKey::from_bytes(acceptance.b_curve25519),
            &prekey,
        )
        .map_err(|error| match error {
            SessionCreationError::MissingOneTimeKey(_)
            | SessionCreationError::MismatchedIdentityKey(..) => CoreError::InvitationAlreadyUsed,
            _ => CoreError::Corrupt,
        })?;
    let header = InnerHeader::decode(&inbound.plaintext).map_err(|_| CoreError::Corrupt)?;
    let keys_match = header.sender_ed25519.ct_eq(&acceptance.b_ed25519)
        & header.recipient_ed25519.ct_eq(&state.our_ed25519);
    if header.chat_id != state.chat_id
        || !bool::from(keys_match)
        || header.direction != Direction::BToA
        || header.counter != 0
        || header.content_type != ContentType::Handshake
    {
        return Err(CoreError::Corrupt);
    }

    state.account = account.pickle();
    state.session = Some(inbound.session.pickle());
    state.peer_curve25519 = Some(acceptance.b_curve25519);
    state.peer_ed25519 = Some(acceptance.b_ed25519);
    state.send_counter = 0;
    state.recv_highest = 0;
    state.recv_seen_bitmap = 1;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::formats::{decode_text, BlobKind};

    const CHAT_ID: &str = "6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d";
    // Invitation layout: envelope 6 · len 1 · chat_id 36 · curve 32 · ed 32 · otk 32 · sig 64.
    const INVITATION_LEN: usize = 203;
    // Acceptance layout: envelope 6 · len 1 · chat_id 36 · curve 32 · ed 32 · prekey_len 2 · prekey · sig 64.
    const ACCEPTANCE_FIXED_LEN: usize = 173;
    // Olm plaintext of the handshake: the 116-byte inner header with an empty body.
    const HANDSHAKE_PLAINTEXT_LEN: usize = 116;
    // Olm v1 pre-key message carrying that plaintext (one 128-byte AES-CBC block).
    const HANDSHAKE_PREKEY_LEN: usize = 282;

    /// A's account rebuilt from fixed secrets through the pickle's serde form —
    /// vodozemac has no public "from seed" constructor, but its pickle is plain
    /// serde (`Ed25519KeypairPickle` = `SecretKeys::Normal(32 B)`,
    /// `Curve25519KeypairPickle` = 32 B, one-time keys keyed by id).
    fn fixed_account() -> (Account, Curve25519PublicKey) {
        let json = serde_json::json!({
            "signing_key": { "Normal": vec![0x01u8; 32] },
            "diffie_hellman_key": vec![0x02u8; 32],
            "one_time_keys": {
                "next_key_id": 1,
                "public_keys": {},
                "private_keys": { "0": vec![0x03u8; 32] }
            },
            "fallback_keys": { "key_id": 0, "fallback_key": null, "previous_fallback_key": null }
        });
        let account = Account::from_pickle(serde_json::from_value(json).unwrap());
        let one_time_key =
            Curve25519PublicKey::from(&vodozemac::Curve25519SecretKey::from_slice(&[0x03; 32]));
        assert_eq!(account.stored_one_time_key_count(), 1);
        (account, one_time_key)
    }

    #[test]
    fn fixed_key_invitation_is_byte_exact() {
        // Expected bytes from an independent implementation (scratchpad
        // `golden_f23.py`: python `cryptography` Ed25519 / X25519 from the same
        // three 32-byte secrets), one field per line.
        let expected = concat!(
            "46555a5a0101", // FUZZ 01 01
            "24",           // chat_id_len 36
            "36663165396232632d336434612d346635622d386336642d376538663961306231633264", // chat_id
            "ce8d3ad1ccb633ec7b70c17814a5c76ecd029685050d344745ba05870e587d59", // a_curve25519
            "8a88e3dd7409f195fd52db2d3cba5d72ca6709bf1d94121bf3748801b40f6f5c", // a_ed25519
            "5dfedd3b6bd47f6fa28ee15d969d5bb0ea53774d488bdaf9df1c6e0124b3ef22", // a_one_time_key
            "6e3fc7600ffedaca8991d4a8bbeaeb40f8c7a8ba0ce1572e3b95cbf6c7226a65", // sig[..32]
            "23c9c0396df09a792ffe3f19aba38406e3053e41c76f8496c4cc0cbef4fe660a", // sig[32..]
        );
        let (account, one_time_key) = fixed_account();
        let blob = invitation_blob(&account, CHAT_ID, one_time_key).unwrap();

        assert_eq!(blob.len(), INVITATION_LEN);
        assert_eq!(hex(&blob), expected);
    }

    #[test]
    fn invitation_structure_and_signature() {
        let (state, text) = create_invitation(CHAT_ID).unwrap();
        let blob = decode_text(&text).unwrap();

        assert_eq!(blob.len(), INVITATION_LEN);
        assert_eq!(&blob[..6], &[0x46, 0x55, 0x5A, 0x5A, 0x01, 0x01]);
        assert_eq!(state.last_invitation.as_deref(), Some(blob.as_slice()));
        assert_eq!(state.role, Role::Inviter);
        assert!(state.session.is_none());
        let invitation = verify_invitation(CHAT_ID, &blob).unwrap();
        assert_eq!(invitation.a_ed25519, state.our_ed25519);
        // Exactly one one-time key, held privately and already marked published.
        let account = state.account().unwrap();
        assert_eq!(account.stored_one_time_key_count(), 1);
        assert!(account.one_time_keys().is_empty());
    }

    #[test]
    fn acceptance_structure_and_signature() {
        let (_, invitation_text) = create_invitation(CHAT_ID).unwrap();
        let invitation =
            verify_invitation(CHAT_ID, &decode_text(&invitation_text).unwrap()).unwrap();
        let (state, text) = accept_invitation(CHAT_ID, &invitation).unwrap();
        let blob = decode_text(&text).unwrap();

        assert_eq!(&blob[..6], &[0x46, 0x55, 0x5A, 0x5A, 0x01, 0x02]);
        let acceptance = verify_acceptance(CHAT_ID, &blob).unwrap();
        assert_eq!(acceptance.prekey_msg.len(), HANDSHAKE_PREKEY_LEN);
        assert_eq!(blob.len(), ACCEPTANCE_FIXED_LEN + HANDSHAKE_PREKEY_LEN);
        let prekey = PreKeyMessage::from_bytes(&acceptance.prekey_msg).unwrap();
        assert_eq!(
            prekey.identity_key().to_bytes(),
            acceptance.b_curve25519,
            "the pre-key message names B's own identity key"
        );
        assert_eq!(prekey.one_time_key().to_bytes(), invitation.a_one_time_key);
        println!(
            "acceptance: {} B total, prekey {} B (handshake plaintext {} B)",
            blob.len(),
            acceptance.prekey_msg.len(),
            HANDSHAKE_PLAINTEXT_LEN
        );
        assert_eq!(state.role, Role::Accepter);
        assert!(state.session.is_some());
        assert_eq!(state.peer_curve25519, Some(invitation.a_curve25519));
        assert_eq!(state.peer_ed25519, Some(invitation.a_ed25519));
        assert_eq!(state.send_counter, 1);
        assert_eq!(state.last_acceptance.as_deref(), Some(blob.as_slice()));
    }

    #[test]
    fn signature_covers_the_envelope() {
        let (_, text) = create_invitation(CHAT_ID).unwrap();
        let blob = decode_text(&text).unwrap();
        assert_eq!(
            signed_part(&blob).unwrap(),
            &blob[..INVITATION_LEN - SIGNATURE_LEN]
        );
        assert_eq!(&signed_part(&blob).unwrap()[..6], &blob[..6]);
        assert_eq!(signed_part(&[0; 63]).unwrap_err(), CoreError::Corrupt);
        // Same body signed under the other type byte would be a different domain.
        let mut relabelled = blob.clone();
        relabelled[5] = BlobKind::Acceptance as u8;
        assert_eq!(
            Invitation::decode(&relabelled).unwrap_err(),
            CoreError::UnsupportedFormat
        );
    }

    fn hex(bytes: &[u8]) -> String {
        bytes.iter().map(|byte| format!("{byte:02x}")).collect()
    }
}
