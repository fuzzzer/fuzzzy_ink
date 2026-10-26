use std::fs::File;
use std::io::Read;
use std::path::PathBuf;

use flutter_rust_bridge::frb;

use crate::api::core::CryptoCore;
use crate::error::CoreError;
use crate::files;
use crate::formats::{
    self, decode_envelope, decode_text, Acceptance, BlobKind, FileKeyMode, Invitation, Message,
    OlmType, PasswordSealed, ENVELOPE_LEN, MAGIC, TEXT_PREFIX, VERSION,
};
use crate::messages;
use crate::store::validate_chat_id;

/// What a pasted `Fuzz/` string is, judged by its outer envelope alone.
///
/// `unknown` covers everything the paste path must refuse: no `Fuzz/` prefix,
/// bad base64url, unknown magic/version/type, and the storage-only kinds
/// (wrapped store key, local seal).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BlobType {
    Invitation,
    Acceptance,
    Message,
    File,
    PasswordSealed,
    Unknown,
}

/// Classifies a pasted blob without touching any key material.
#[frb(sync)]
pub fn blob_type_of(text: String) -> BlobType {
    match formats::decode_pasted(&text) {
        Ok((BlobKind::Invitation, _)) => BlobType::Invitation,
        Ok((BlobKind::Acceptance, _)) => BlobType::Acceptance,
        Ok((BlobKind::Message, _)) => BlobType::Message,
        Ok((BlobKind::FileContainer, _)) => BlobType::File,
        Ok((BlobKind::PasswordSealed, _)) => BlobType::PasswordSealed,
        Ok((BlobKind::WrappedStoreKey | BlobKind::RecoveryBox | BlobKind::LocalSeal, _))
        | Err(_) => BlobType::Unknown,
    }
}

/// The clear chat id of a pasted invitation or acceptance — the only two blobs
/// that carry one. Anything else is `UnsupportedFormat`; a malformed payload is `Corrupt`.
///
/// A routing hint only: nothing is authenticated here. `accept_invitation` /
/// `complete_handshake` verify the signature and re-check the chat id before
/// the blob touches any state.
#[frb(sync)]
pub fn peek_chat_id(text: String) -> Result<String, CoreError> {
    let (kind, blob) = formats::decode_pasted(&text)?;
    match kind {
        BlobKind::Invitation => Ok(Invitation::decode(&blob)?.chat_id),
        BlobKind::Acceptance => Ok(Acceptance::decode(&blob)?.chat_id),
        _ => Err(CoreError::UnsupportedFormat),
    }
}

/// What a pasted text or a chosen file is, as Open needs to know it before it
/// spends anything (see [`CryptoCore::peek_pasted`]).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PeekKind {
    /// A signed invitation; `chat_id` is its clear chat id (a routing hint).
    Invitation,
    /// A signed acceptance; `chat_id` is its clear chat id (a routing hint).
    Acceptance,
    /// A chat message; `chat_id` is the chat whose session it was sent on, or
    /// none when no given chat matches.
    Message,
    /// A chat-mode file container; `chat_id` as for a message.
    ChatFile,
    /// Text sealed with a password (`0x05`).
    PasswordText,
    /// A password-mode file container (Basics, or a saved history archive).
    PasswordFile,
    /// Fuzzzy Ink's envelope with a version or a type this build does not
    /// know: made by a newer app.
    NewerVersion,
    /// Not Fuzzzy Ink's at all (no `Fuzz/` text, no `FUZZ` file).
    NotFuzzzy,
    /// Fuzzzy Ink's envelope, but cut off, malformed or a storage-only kind.
    Damaged,
}

/// The answer of a peek: the kind, and the chat it routes to when there is one.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Peek {
    pub kind: PeekKind,
    pub chat_id: Option<String>,
    /// For a file: it holds sealed **text** (a `Fuzz/` blob saved as a
    /// `.fuzz` file), which opens like a paste of that text.
    pub is_text_file: bool,
}

impl Peek {
    fn of(kind: PeekKind) -> Self {
        Self {
            kind,
            chat_id: None,
            is_text_file: false,
        }
    }
}

/// A `.fuzz` file holding sealed text is never larger than this; anything
/// longer that is not a container is not Fuzzzy Ink's.
const MAX_TEXT_FILE_LEN: u64 = 1 << 20;

/// What the outer envelope says before any payload is read.
enum Envelope {
    Kind(BlobKind),
    Newer,
    Damaged,
}

fn envelope_of(blob: &[u8]) -> Envelope {
    let Some(header) = blob.first_chunk::<ENVELOPE_LEN>() else {
        return Envelope::Damaged;
    };
    if header[..4] != MAGIC {
        return Envelope::Damaged;
    }
    if header[4] > VERSION {
        return Envelope::Newer;
    }
    if header[4] != VERSION {
        return Envelope::Damaged;
    }
    match decode_envelope(blob) {
        Ok((kind, _)) if kind.is_wire() => Envelope::Kind(kind),
        Ok(_) => Envelope::Damaged,
        // A type byte this build does not know: added by a newer version
        // (PROTOCOL.md §12, "adding a type byte is not a bump").
        Err(_) => Envelope::Newer,
    }
}

/// The routing hint of a signed pairing blob, refused unless it has the chat
/// id shape (it becomes a file name on this device later).
fn pairing_chat_id(chat_id: String) -> Option<String> {
    validate_chat_id(&chat_id).ok().map(|()| chat_id)
}

impl CryptoCore {
    /// Recognises a pasted text without spending anything: no message key, no
    /// one-time key, no state write. Invitations and acceptances answer their
    /// clear chat id (a hint: nothing is authenticated until they are
    /// accepted or completed); a password-sealed text needs nothing more. A
    /// message names no chat (PROTOCOL.md §6.5), so it is tried read-only
    /// against each of `chat_ids` ([`messages::is_for_chat`]): the first
    /// whose session sent it is answered. Chat ids that are malformed or
    /// unknown to the store are skipped. Only a message needs the open store
    /// (`StoreLocked` otherwise).
    pub fn peek_pasted(&mut self, text: String, chat_ids: Vec<String>) -> Result<Peek, CoreError> {
        let compact: String = text.split_ascii_whitespace().collect();
        if !compact.starts_with(TEXT_PREFIX) {
            return Ok(Peek::of(PeekKind::NotFuzzzy));
        }
        let Ok(blob) = decode_text(&compact) else {
            return Ok(Peek::of(PeekKind::Damaged));
        };
        let kind = match envelope_of(&blob) {
            Envelope::Newer => return Ok(Peek::of(PeekKind::NewerVersion)),
            Envelope::Damaged => return Ok(Peek::of(PeekKind::Damaged)),
            Envelope::Kind(kind) => kind,
        };
        let peek = match kind {
            BlobKind::Invitation => match Invitation::decode(&blob) {
                Ok(invitation) => Peek {
                    kind: PeekKind::Invitation,
                    chat_id: pairing_chat_id(invitation.chat_id),
                    is_text_file: false,
                },
                Err(_) => Peek::of(PeekKind::Damaged),
            },
            BlobKind::Acceptance => match Acceptance::decode(&blob) {
                Ok(acceptance) => Peek {
                    kind: PeekKind::Acceptance,
                    chat_id: pairing_chat_id(acceptance.chat_id),
                    is_text_file: false,
                },
                Err(_) => Peek::of(PeekKind::Damaged),
            },
            BlobKind::PasswordSealed => match PasswordSealed::decode(&blob) {
                Ok(_) => Peek::of(PeekKind::PasswordText),
                Err(_) => Peek::of(PeekKind::Damaged),
            },
            BlobKind::Message => match Message::decode(&blob) {
                Ok(message) => Peek {
                    kind: PeekKind::Message,
                    chat_id: self.chat_of(message.olm_type, &message.olm_body, &chat_ids)?,
                    is_text_file: false,
                },
                Err(_) => Peek::of(PeekKind::Damaged),
            },
            // Containers are files, never text (§2); the storage kinds were
            // refused above.
            _ => Peek::of(PeekKind::Damaged),
        };
        Ok(peek)
    }

    /// [`CryptoCore::peek_pasted`] for a chosen file: a container is told by
    /// its header (a header-only or truncated one is `Damaged`, as the receive
    /// would refuse it), a chat-mode one is matched to a chat exactly like a
    /// message; a small file of sealed text (`is_text_file`) is peeked as that
    /// text. A missing or unreadable file is `Io`.
    pub fn peek_file(&mut self, input: String, chat_ids: Vec<String>) -> Result<Peek, CoreError> {
        let path = PathBuf::from(&input);
        let mut file = File::open(&path).map_err(|_| CoreError::Io)?;
        let metadata = file.metadata().map_err(|_| CoreError::Io)?;
        if !metadata.is_file() {
            return Err(CoreError::Io);
        }
        let mut head = [0u8; ENVELOPE_LEN];
        let head_len = read_up_to(&mut file, &mut head)?;
        if head_len >= MAGIC.len() && head[..MAGIC.len()] == MAGIC {
            if head_len < ENVELOPE_LEN {
                return Ok(Peek::of(PeekKind::Damaged));
            }
            match envelope_of(&head) {
                Envelope::Newer => return Ok(Peek::of(PeekKind::NewerVersion)),
                Envelope::Kind(BlobKind::FileContainer) => {}
                _ => return Ok(Peek::of(PeekKind::Damaged)),
            }
            let Ok(header) = files::peek_header(&path) else {
                return Ok(Peek::of(PeekKind::Damaged));
            };
            return Ok(match header.key_mode {
                FileKeyMode::Password { .. } => Peek::of(PeekKind::PasswordFile),
                FileKeyMode::Chat { olm_type, olm_body } => Peek {
                    kind: PeekKind::ChatFile,
                    chat_id: self.chat_of(olm_type, &olm_body, &chat_ids)?,
                    is_text_file: false,
                },
            });
        }

        if metadata.len() > MAX_TEXT_FILE_LEN {
            return Ok(Peek::of(PeekKind::NotFuzzzy));
        }
        let bytes = std::fs::read(&path).map_err(|_| CoreError::Io)?;
        let Ok(text) = String::from_utf8(bytes) else {
            return Ok(Peek::of(PeekKind::NotFuzzzy));
        };
        let mut peek = self.peek_pasted(text, chat_ids)?;
        peek.is_text_file = peek.kind != PeekKind::NotFuzzzy;
        Ok(peek)
    }

    /// The first of `chat_ids` whose session sent this Olm message, read-only.
    fn chat_of(
        &mut self,
        olm_type: OlmType,
        olm_body: &[u8],
        chat_ids: &[String],
    ) -> Result<Option<String>, CoreError> {
        let store = self.opened_mut()?;
        for chat_id in chat_ids {
            if validate_chat_id(chat_id).is_err() {
                continue;
            }
            if let Ok(true) = store.with_state(chat_id, |state| {
                messages::is_for_chat(state, olm_type, olm_body)
            }) {
                return Ok(Some(chat_id.clone()));
            }
        }
        Ok(None)
    }
}

/// Reads up to `buffer.len()` bytes (fewer only at the end of the file).
fn read_up_to(file: &mut File, buffer: &mut [u8]) -> Result<usize, CoreError> {
    let mut filled = 0;
    while filled < buffer.len() {
        match file.read(&mut buffer[filled..]) {
            Ok(0) => break,
            Ok(read) => filled += read,
            Err(error) if error.kind() == std::io::ErrorKind::Interrupted => {}
            Err(_) => return Err(CoreError::Io),
        }
    }
    Ok(filled)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::formats::{encode_text, Argon2Params, FileHeader, FileKeyMode, PasswordSealed};

    const CHAT_ID: &str = "6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d";
    // The golden invitation of `formats::tests`, as pasted text.
    const INVITATION_TEXT: &str = "Fuzz/RlVaWgEBJDZmMWU5YjJjLTNkNGEtNGY1Yi04YzZkLTdlOGY5YTBiMWMyZBERERERERERERERERERERERERERERERERERERERERERIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzM0REREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREQ";
    // FUZZ 01 03 · Normal · de ad be ef
    const MESSAGE_TEXT: &str = "Fuzz/RlVaWgEDAd6tvu8";

    fn acceptance_text() -> String {
        encode_text(
            &Acceptance {
                chat_id: CHAT_ID.to_string(),
                b_curve25519: [0x55; 32],
                b_ed25519: [0x66; 32],
                prekey_msg: vec![0xA1; 5],
                signature: [0x77; 64],
            }
            .encode()
            .unwrap(),
        )
    }

    #[test]
    fn blob_type_of_classifies_every_wire_kind() {
        assert_eq!(
            blob_type_of(INVITATION_TEXT.to_string()),
            BlobType::Invitation
        );
        assert_eq!(blob_type_of(acceptance_text()), BlobType::Acceptance);
        assert_eq!(blob_type_of(MESSAGE_TEXT.to_string()), BlobType::Message);
        let file = FileHeader {
            chunk_size: 1 << 20,
            nonce_prefix: [0x90; 19],
            key_mode: FileKeyMode::Password {
                salt: [0xA0; 16],
                params: Argon2Params {
                    m_cost: 65536,
                    t_cost: 4,
                    p_cost: 1,
                },
            },
        };
        assert_eq!(
            blob_type_of(encode_text(&file.encode().unwrap())),
            BlobType::File
        );
        let sealed = PasswordSealed {
            salt: [0xA0; 16],
            params: Argon2Params {
                m_cost: 65536,
                t_cost: 4,
                p_cost: 1,
            },
            nonce: [0xB0; 24],
            ciphertext: vec![0xCC; 20],
        };
        assert_eq!(
            blob_type_of(encode_text(&sealed.encode())),
            BlobType::PasswordSealed
        );
        // whitespace-wrapped paste still classifies
        assert_eq!(
            blob_type_of("Fuzz/RlVa\r\n WgEDAd6tvu8".to_string()),
            BlobType::Message
        );
    }

    #[test]
    fn blob_type_of_is_unknown_for_storage_kinds_and_garbage() {
        for text in [
            "Fuzz/RlVaWgEQoKGio6SlpqeoqaqrrK2urwABAAAAAAAEAbCxsrO0tba3uLm6u7y9vr_AwcLDxMXGx-7u7u7u7u7u7u7u7u7u7u7u7u7u7u7u7u7u7u7u7u7u7u7u7u7u7u7u7u7u7u7u7g", // 0x10
            "Fuzz/RlVaWgEgsLGys7S1tre4ubq7vL2-v8DBwsPExcbH3d3d3d3d3d3d3d3d3d3d3d0", // 0x20
            "Fuzz/RlVaWgIDAA",   // version 0x02
            "Fuzz/RlVaeAEDAA",   // magic FUZx
            "Fuzz/RlVaWgEGAA",   // type 0x06
            "Fuzz/RlVaWgEDAA==", // padding
            "Fuzz/",
            "Fuzz/RlVa",     // 3 bytes, no full envelope
            "RlVaWgEDAd6tvu8", // no prefix
            "hello world",
            "",
        ] {
            assert_eq!(blob_type_of(text.to_string()), BlobType::Unknown, "{text:?}");
        }
    }

    #[test]
    fn peek_chat_id_reads_invitation_and_acceptance() {
        assert_eq!(peek_chat_id(INVITATION_TEXT.to_string()).unwrap(), CHAT_ID);
        assert_eq!(peek_chat_id(acceptance_text()).unwrap(), CHAT_ID);
    }

    #[test]
    fn peek_chat_id_rejects_other_kinds_and_broken_payloads() {
        assert_eq!(
            peek_chat_id(MESSAGE_TEXT.to_string()),
            Err(CoreError::UnsupportedFormat)
        );
        assert_eq!(
            peek_chat_id("garbage".to_string()),
            Err(CoreError::UnsupportedFormat)
        );
        assert_eq!(
            peek_chat_id("Fuzz/RlVaWgEQ".to_string()),
            Err(CoreError::UnsupportedFormat)
        );
        // 264 chars = 198 whole bytes: valid base64url, five bytes short of an invitation
        let truncated = &INVITATION_TEXT[..INVITATION_TEXT.len() - 7];
        assert_eq!(peek_chat_id(truncated.to_string()), Err(CoreError::Corrupt));
    }
}

#[cfg(test)]
mod peek_tests {
    use std::fs;
    use std::path::{Path, PathBuf};
    use std::sync::atomic::AtomicU8;

    use super::*;
    use crate::api::files::run_ticket;
    use crate::files::JOB_RUNNING;
    use crate::formats::{encode_text, Argon2Params, FileHeader};
    use crate::store::test_support::temp_dir;
    use crate::store::STORE_SUBDIR;

    const CHAT_X: &str = "6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d";
    const CHAT_Y: &str = "0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d";

    struct Device {
        dir: PathBuf,
        core: CryptoCore,
    }

    impl Device {
        fn new() -> Self {
            let dir = temp_dir();
            let core = CryptoCore::open_for_tests(&dir, crate::store::random_array().unwrap());
            Self { dir, core }
        }

        fn state_bytes(&self, chat_id: &str) -> Vec<u8> {
            fs::read(self.dir.join(STORE_SUBDIR).join(format!("{chat_id}.state"))).unwrap()
        }

        fn write(&self, name: &str, bytes: &[u8]) -> String {
            let path = self.dir.join(name);
            fs::write(&path, bytes).unwrap();
            path.to_string_lossy().into_owned()
        }

        fn peek(&mut self, text: &str, chats: &[&str]) -> Peek {
            self.core
                .peek_pasted(text.into(), chats.iter().map(|c| c.to_string()).collect())
                .unwrap()
        }

        fn peek_file(&mut self, path: &str, chats: &[&str]) -> Peek {
            self.core
                .peek_file(path.into(), chats.iter().map(|c| c.to_string()).collect())
                .unwrap()
        }
    }

    impl Drop for Device {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.dir);
        }
    }

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

    fn routed(kind: PeekKind, chat_id: Option<&str>) -> Peek {
        Peek {
            kind,
            chat_id: chat_id.map(str::to_string),
            is_text_file: false,
        }
    }

    /// A on two chats: X with B, Y with C.
    fn three() -> (Device, Device, Device) {
        let mut a = Device::new();
        let mut b = Device::new();
        let mut c = Device::new();
        pair(&mut a, &mut b, CHAT_X);
        pair(&mut a, &mut c, CHAT_Y);
        (a, b, c)
    }

    #[test]
    fn a_message_routes_to_its_chat_and_spends_nothing() {
        let (mut a, mut b, mut c) = three();
        // B's first message is a pre-key message, C's second a normal one
        // after A replied: both shapes route.
        let from_b = b
            .core
            .encrypt_text(CHAT_X.into(), "hi from b".into())
            .unwrap();
        let first_c = c.core.encrypt_text(CHAT_Y.into(), "c0".into()).unwrap();
        a.core.decrypt_text(CHAT_Y.into(), first_c).unwrap();
        let reply = a.core.encrypt_text(CHAT_Y.into(), "a0".into()).unwrap();
        c.core.decrypt_text(CHAT_Y.into(), reply).unwrap();
        let from_c = c.core.encrypt_text(CHAT_Y.into(), "c1".into()).unwrap();

        let x_before = a.state_bytes(CHAT_X);
        let y_before = a.state_bytes(CHAT_Y);
        for order in [[CHAT_X, CHAT_Y], [CHAT_Y, CHAT_X]] {
            assert_eq!(
                a.peek(&from_b, &order),
                routed(PeekKind::Message, Some(CHAT_X))
            );
            assert_eq!(
                a.peek(&from_c, &order),
                routed(PeekKind::Message, Some(CHAT_Y))
            );
        }
        // Read-only: both state files byte-identical, both still open once.
        assert_eq!(a.state_bytes(CHAT_X), x_before);
        assert_eq!(a.state_bytes(CHAT_Y), y_before);
        assert_eq!(
            a.core.decrypt_text(CHAT_X.into(), from_b.clone()).unwrap(),
            "hi from b"
        );
        assert_eq!(a.core.decrypt_text(CHAT_Y.into(), from_c).unwrap(), "c1");

        // Already opened: still routed to its chat, so Open can say where it is.
        assert_eq!(
            a.peek(&from_b, &[CHAT_Y, CHAT_X]),
            routed(PeekKind::Message, Some(CHAT_X))
        );
        assert_eq!(
            a.core.decrypt_text(CHAT_X.into(), from_b),
            Err(CoreError::Replay)
        );
    }

    #[test]
    fn a_message_for_no_given_chat_routes_nowhere() {
        let (mut a, mut b, _c) = three();
        let from_b = b.core.encrypt_text(CHAT_X.into(), "hi".into()).unwrap();
        // Not among the candidates, an unknown or malformed id: none.
        assert_eq!(a.peek(&from_b, &[CHAT_Y]), routed(PeekKind::Message, None));
        assert_eq!(
            a.peek(
                &from_b,
                &["not-a-chat", "11111111-2222-4333-8444-555555555555"]
            ),
            routed(PeekKind::Message, None)
        );
        // My own locked message is not "from" any chat of mine.
        let mine = a.core.encrypt_text(CHAT_X.into(), "mine".into()).unwrap();
        assert_eq!(
            a.peek(&mine, &[CHAT_X, CHAT_Y]),
            routed(PeekKind::Message, None)
        );
        // A stranger's device: nothing matches.
        let mut stranger = Device::new();
        assert_eq!(
            stranger.peek(&from_b, &[CHAT_X]),
            routed(PeekKind::Message, None)
        );
        // B still opens nothing spent: A can open it.
        assert_eq!(a.core.decrypt_text(CHAT_X.into(), from_b).unwrap(), "hi");
    }

    #[test]
    fn pairing_blobs_answer_their_chat_id_without_the_store() {
        let mut a = Device::new();
        let mut b = Device::new();
        let invitation = a.core.create_invitation(CHAT_X.into()).unwrap();
        let acceptance = b
            .core
            .accept_invitation(CHAT_X.into(), invitation.clone())
            .unwrap();
        let mut locked = Device::new();
        locked.core.close();
        assert_eq!(
            locked.peek(&invitation, &[]),
            routed(PeekKind::Invitation, Some(CHAT_X))
        );
        assert_eq!(
            locked.peek(&acceptance, &[CHAT_X]),
            routed(PeekKind::Acceptance, Some(CHAT_X))
        );
        // Whitespace-wrapped, as from an e-mail.
        let wrapped = format!("  {}\n {} ", &invitation[..40], &invitation[40..]);
        assert_eq!(
            locked.peek(&wrapped, &[]),
            routed(PeekKind::Invitation, Some(CHAT_X))
        );
        // A message needs the open store.
        let from_b = b.core.encrypt_text(CHAT_X.into(), "x".into()).unwrap();
        assert_eq!(
            locked.core.peek_pasted(from_b, vec![CHAT_X.to_string()]),
            Err(CoreError::StoreLocked)
        );
    }

    #[test]
    fn every_other_text_is_classified() {
        let mut a = Device::new();
        let sealed =
            crate::api::passwords::password_seal_text("pw".into(), "hello".into()).unwrap();
        assert_eq!(a.peek(&sealed, &[]), routed(PeekKind::PasswordText, None));

        let blob = |version: u8, kind: u8, rest: &[u8]| {
            let mut bytes = b"FUZZ".to_vec();
            bytes.push(version);
            bytes.push(kind);
            bytes.extend_from_slice(rest);
            encode_text(&bytes)
        };
        for (text, kind) in [
            (blob(0x02, 0x03, &[1, 2]), PeekKind::NewerVersion),
            (blob(0x01, 0x06, &[1, 2]), PeekKind::NewerVersion),
            (blob(0x01, 0x10, &[0; 97]), PeekKind::Damaged),
            (blob(0x01, 0x20, &[0; 40]), PeekKind::Damaged),
            (blob(0x01, 0x04, &[0; 40]), PeekKind::Damaged),
            (blob(0x00, 0x03, &[1, 2]), PeekKind::Damaged),
            (blob(0x01, 0x03, &[]), PeekKind::Damaged),
            (blob(0x01, 0x01, &[36]), PeekKind::Damaged),
            (blob(0x01, 0x05, &[0; 10]), PeekKind::Damaged),
            ("Fuzz/RlVa".to_string(), PeekKind::Damaged),
            ("Fuzz/%%%".to_string(), PeekKind::Damaged),
            ("hello world".to_string(), PeekKind::NotFuzzzy),
            (String::new(), PeekKind::NotFuzzzy),
        ] {
            assert_eq!(a.peek(&text, &[]), routed(kind, None), "{text:?}");
        }
        // An invitation whose clear chat id is not a chat id: no route.
        let odd = Invitation {
            chat_id: "../../etc".into(),
            a_curve25519: [1; 32],
            a_ed25519: [2; 32],
            a_one_time_key: [3; 32],
            signature: [4; 64],
        };
        assert_eq!(
            a.peek(&encode_text(&odd.encode().unwrap()), &[]),
            routed(PeekKind::Invitation, None)
        );
    }

    fn send_file(dev: &mut Device, chat_id: &str) -> String {
        let input = dev.write("photo.jpg", &[7u8; 5000]);
        let output = dev.dir.join("photo.jpg.fuzz");
        let mut ticket = dev.core.prepare_file_send(chat_id.into(), input).unwrap();
        run_ticket(
            &mut ticket,
            &output,
            &AtomicU8::new(JOB_RUNNING),
            &mut |_| {},
        )
        .unwrap();
        output.to_string_lossy().into_owned()
    }

    fn copy_to(dev: &Device, from: &str, name: &str) -> String {
        let to = dev.dir.join(name);
        fs::copy(from, &to).unwrap();
        to.to_string_lossy().into_owned()
    }

    #[test]
    fn files_are_classified_and_chat_files_routed() {
        let (mut a, mut b, _c) = three();
        let sent = send_file(&mut b, CHAT_X);
        let received = copy_to(&a, &sent, "got.fuzz");
        let before = a.state_bytes(CHAT_X);
        assert_eq!(
            a.peek_file(&received, &[CHAT_Y, CHAT_X]),
            routed(PeekKind::ChatFile, Some(CHAT_X))
        );
        assert_eq!(a.state_bytes(CHAT_X), before);
        // Still receivable: the key message was not spent.
        a.core
            .prepare_file_receive(CHAT_X.into(), received.clone())
            .unwrap();

        // Truncated to its header: damaged, like the receive would say.
        let bytes = fs::read(&sent).unwrap();
        let cut = a.write("cut.fuzz", &bytes[..40]);
        assert_eq!(
            a.peek_file(&cut, &[CHAT_X]),
            routed(PeekKind::Damaged, None)
        );

        // A password container (Basics, a saved history).
        let mut header = FileHeader {
            chunk_size: 1 << 20,
            nonce_prefix: [9; 19],
            key_mode: FileKeyMode::Password {
                salt: [1; 16],
                params: Argon2Params {
                    m_cost: 65536,
                    t_cost: 4,
                    p_cost: 1,
                },
            },
        }
        .encode()
        .unwrap();
        header.extend_from_slice(&[0u8; 32]);
        let password_file = a.write("archive.fuzz", &header);
        assert_eq!(
            a.peek_file(&password_file, &[]),
            routed(PeekKind::PasswordFile, None)
        );

        // Newer, damaged, not ours.
        let newer = a.write("newer.fuzz", b"FUZZ\x02\x04rest");
        assert_eq!(
            a.peek_file(&newer, &[]),
            routed(PeekKind::NewerVersion, None)
        );
        let short = a.write("short.fuzz", b"FUZZ\x01");
        assert_eq!(a.peek_file(&short, &[]), routed(PeekKind::Damaged, None));
        let photo = a.write("plain.jpg", &[0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10]);
        assert_eq!(a.peek_file(&photo, &[]), routed(PeekKind::NotFuzzzy, None));
        let empty = a.write("empty.txt", b"");
        assert_eq!(a.peek_file(&empty, &[]), routed(PeekKind::NotFuzzzy, None));
        assert_eq!(
            a.core
                .peek_file(a.dir.to_string_lossy().into_owned(), vec![]),
            Err(CoreError::Io)
        );
        assert_eq!(
            a.core.peek_file(
                Path::new(&a.dir)
                    .join("missing")
                    .to_string_lossy()
                    .into_owned(),
                vec![]
            ),
            Err(CoreError::Io)
        );
    }

    #[test]
    fn a_text_file_peeks_as_its_text() {
        let (mut a, mut b, _c) = three();
        let from_b = b
            .core
            .encrypt_text(CHAT_X.into(), "in a file".into())
            .unwrap();
        let file = a.write("message.fuzz", format!("{from_b}\n").as_bytes());
        assert_eq!(
            a.peek_file(&file, &[CHAT_X]),
            Peek {
                kind: PeekKind::Message,
                chat_id: Some(CHAT_X.into()),
                is_text_file: true,
            }
        );
        let invitation = Device::new().core.create_invitation(CHAT_Y.into()).unwrap();
        let file = a.write("invite.fuzz", invitation.as_bytes());
        assert_eq!(
            a.peek_file(&file, &[]),
            Peek {
                kind: PeekKind::Invitation,
                chat_id: Some(CHAT_Y.into()),
                is_text_file: true,
            }
        );
        let note = a.write("note.txt", b"just a note");
        assert_eq!(a.peek_file(&note, &[]), routed(PeekKind::NotFuzzzy, None));
    }
}
