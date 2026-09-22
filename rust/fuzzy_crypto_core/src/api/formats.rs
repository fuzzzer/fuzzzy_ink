use flutter_rust_bridge::frb;

use crate::error::CoreError;
use crate::formats::{self, Acceptance, BlobKind, Invitation};

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
        Ok((BlobKind::WrappedStoreKey | BlobKind::LocalSeal, _)) | Err(_) => BlobType::Unknown,
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
