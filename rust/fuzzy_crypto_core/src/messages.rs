//! Text messages on the live Olm session (plan §B.2 step 4, §B.4).
//!
//! Pure functions over [`ChatState`] — no I/O. The API layer (`api/messages.rs`)
//! wraps them in `OpenStore::with_state_mut`, which persists **before** the
//! result leaves Rust and, crucially, saves **only on `Ok`**: every `Err` path
//! here leaves the chat's state file byte-identical, so the validation chain can
//! mutate a cloned session freely and still never advance the on-disk ratchet on
//! a rejection (plan §B.4 "persist before returning", §B.6 crash semantics).
//!
//! The Olm step itself — inner header, ratchet, counter policy — is shared with
//! the chat-mode file key of F3-2 through [`encrypt_payload`] /
//! [`decrypt_payload`]; the text functions are the `content_type 0x01` face of
//! it, the file container's key envelope the `0x02` one. One implementation of
//! the inner-header rules, never two.

use subtle::ConstantTimeEq;
use vodozemac::olm::{Message as OlmNormalMessage, OlmMessage, PreKeyMessage};
use zeroize::{Zeroize, Zeroizing};

use crate::counters;
use crate::error::CoreError;
use crate::formats::{ContentType, Direction, InnerHeader, Message, OlmType};
use crate::state::{ChatState, Role};

/// The direction this device stamps on the messages it sends: the inviter is
/// A→B, the accepter is B→A (F2-3).
fn our_direction(role: Role) -> Direction {
    match role {
        Role::Inviter => Direction::AToB,
        Role::Accepter => Direction::BToA,
    }
}

/// The direction the peer stamps on what we receive — the opposite side.
fn peer_direction(role: Role) -> Direction {
    match role {
        Role::Inviter => Direction::BToA,
        Role::Accepter => Direction::AToB,
    }
}

/// Encrypts `text` as a 0x03 message on the session, stamping the inner header
/// with our next send counter, then returns the `Fuzz/` blob. The counter is
/// incremented and the ratcheted session written into `state`; the caller
/// persists before the blob is returned, so a crash can only lose a blob the
/// user never saw — a counter is never reused (plan §B.4).
pub fn encrypt_text(state: &mut ChatState, text: &str) -> Result<String, CoreError> {
    let message = encrypt_payload(state, ContentType::Text, text.as_bytes())?;
    Ok(crate::formats::encode_text(&message.encode()?))
}

/// Decrypts a pasted 0x03 message blob. The checks run in the fixed order of
/// plan §B.4 and stop at the first failure; nothing is committed to `state`
/// until every one has passed (and the caller only persists on `Ok`):
/// 1. envelope is a message (`UnsupportedFormat`) and its Olm body parses (`Corrupt`);
/// 2. Olm decrypt — `MissingMessageKey` → `Replay`, `TooBigMessageGap` → `TooOld`,
///    any MAC/other failure → `Corrupt` (a blob from another chat fails here, its
///    MAC being under a different session);
/// 3. inner header decode + binding: chat id (`WrongChat`), identity keys
///    (constant-time, `WrongChat`), direction (`Corrupt`), content type text
///    (`Corrupt`), UTF-8 body (`Corrupt`);
/// 4. the per-direction counter window (`Replay` / `TooOld`).
pub fn decrypt_text(state: &mut ChatState, blob: &[u8]) -> Result<String, CoreError> {
    let message = Message::decode(blob)?;
    decrypt_payload(
        state,
        message.olm_type,
        &message.olm_body,
        ContentType::Text,
        |body| String::from_utf8(body).map_err(|_| CoreError::Corrupt),
    )
}

/// One Olm message carrying `body` under `content_type`, stamped with our next
/// send counter (steps of [`encrypt_text`] minus the text envelope). Commits
/// the incremented counter and the ratcheted session to `state` — all or
/// nothing, and only once the message exists.
pub(crate) fn encrypt_payload(
    state: &mut ChatState,
    content_type: ContentType,
    body: &[u8],
) -> Result<Message, CoreError> {
    // The chat must be connected; a pending invite has no session.
    let mut session = state.session()?.ok_or(CoreError::Internal)?;
    let peer_ed25519 = state.peer_ed25519.ok_or(CoreError::Internal)?;

    let counter = state.send_counter;
    let mut header = InnerHeader {
        chat_id: state.chat_id.clone(),
        sender_ed25519: state.our_ed25519,
        recipient_ed25519: peer_ed25519,
        direction: our_direction(state.role),
        counter,
        content_type,
        body: body.to_vec(),
    };
    // The body may be a file key: both copies of it are wiped once encrypted.
    let plaintext = Zeroizing::new(header.encode()?);
    header.body.zeroize();

    let (olm_type, olm_body) = match session
        .encrypt(&*plaintext)
        .map_err(|_| CoreError::Internal)?
    {
        OlmMessage::PreKey(message) => (OlmType::PreKey, message.to_bytes()),
        OlmMessage::Normal(message) => (OlmType::Normal, message.to_bytes()),
    };
    let message = Message { olm_type, olm_body };

    // Commit only after the message is built, and all-or-nothing: the counter
    // step is the only fallible part, so it goes first.
    state.send_counter = counter.checked_add(1).ok_or(CoreError::Internal)?;
    state.session = Some(session.pickle());
    Ok(message)
}

/// Steps 2–5 of [`decrypt_text`] for any content type: Olm decrypt on a cloned
/// session, the inner-header binding, `content_type` must match, `parse_body`
/// must accept the body, then the counter window — and only then the commit.
/// `parse_body` runs *before* the commit, so a malformed body is as harmless
/// as a bad header: nothing in `state` changes.
pub(crate) fn decrypt_payload<T>(
    state: &mut ChatState,
    olm_type: OlmType,
    olm_body: &[u8],
    content_type: ContentType,
    parse_body: impl FnOnce(Vec<u8>) -> Result<T, CoreError>,
) -> Result<T, CoreError> {
    // 1. Olm body → Olm message.
    let olm = match olm_type {
        OlmType::PreKey => {
            OlmMessage::PreKey(PreKeyMessage::from_bytes(olm_body).map_err(|_| CoreError::Corrupt)?)
        }
        OlmType::Normal => OlmMessage::Normal(
            OlmNormalMessage::from_bytes(olm_body).map_err(|_| CoreError::Corrupt)?,
        ),
    };

    // 2. Olm decrypt on a cloned session (the clone ratchets; state is untouched
    //    until the commit at the end, so a later failure leaves the chain intact).
    let mut session = state.session()?.ok_or(CoreError::Internal)?;
    let plaintext = Zeroizing::new(session.decrypt(&olm).map_err(|error| {
        use vodozemac::olm::DecryptionError::{MissingMessageKey, TooBigMessageGap};
        match error {
            MissingMessageKey(_) => CoreError::Replay,
            TooBigMessageGap(..) => CoreError::TooOld,
            _ => CoreError::Corrupt,
        }
    })?);

    // 3. Inner header binding.
    let header = InnerHeader::decode(&plaintext).map_err(|_| CoreError::Corrupt)?;
    if header.chat_id != state.chat_id {
        return Err(CoreError::WrongChat);
    }
    let peer_ed25519 = state.peer_ed25519.ok_or(CoreError::Internal)?;
    let keys_match = header.sender_ed25519.ct_eq(&peer_ed25519)
        & header.recipient_ed25519.ct_eq(&state.our_ed25519);
    if !bool::from(keys_match) {
        return Err(CoreError::WrongChat);
    }
    if header.direction != peer_direction(state.role) {
        return Err(CoreError::Corrupt);
    }
    if header.content_type != content_type {
        return Err(CoreError::Corrupt);
    }
    let counter = header.counter;
    let value = parse_body(header.body)?;

    // 4. Counter window.
    let (recv_highest, recv_seen_bitmap) =
        counters::accept(state.recv_highest, state.recv_seen_bitmap, counter)?;

    // 5. Commit (the caller persists before returning).
    state.session = Some(session.pickle());
    state.recv_highest = recv_highest;
    state.recv_seen_bitmap = recv_seen_bitmap;
    Ok(value)
}
