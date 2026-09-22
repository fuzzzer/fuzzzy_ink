//! Wire formats — every blob and file header, byte-exact per plan §B.4 / §C.
//!
//! Pure encode/decode; no crypto lives here. Fixed-size fields, big-endian length
//! prefixes (`u8` chat id, `u16` Olm bodies, `u32` bodies), no serde on the wire.
//! Every `decode` reads through [`Reader`], which never indexes without a length
//! check, so a truncated or padded input is an `Err`, never a panic.

use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine as _;
use zeroize::Zeroizing;

use crate::error::CoreError;

/// Prefix of every paste-able blob; the Dart side detects it with `text.substring(5)`.
pub const TEXT_PREFIX: &str = "Fuzz/";
/// First four bytes of every blob and file.
pub const MAGIC: [u8; 4] = *b"FUZZ";
/// Outer envelope version.
pub const VERSION: u8 = 0x01;
/// Length of the outer envelope: magic + version + type.
pub const ENVELOPE_LEN: usize = 6;
/// Length of an Ed25519 signature (invitation / acceptance trailer).
pub const SIGNATURE_LEN: usize = 64;
/// Chunk size the file encoder writes (plan §C).
pub const CHUNK_SIZE: u32 = 1 << 20;
/// Smallest chunk size the file decoder accepts.
pub const MIN_CHUNK_SIZE: u32 = 1 << 16;
/// Largest chunk size the file decoder accepts.
pub const MAX_CHUNK_SIZE: u32 = 1 << 24;
/// Byte length of the wrapped store key's ciphertext: 32-byte key + 16-byte tag.
pub const WRAPPED_STORE_KEY_CT_LEN: usize = 48;

/// The type byte of the outer envelope.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum BlobKind {
    Invitation = 0x01,
    Acceptance = 0x02,
    Message = 0x03,
    FileContainer = 0x04,
    PasswordSealed = 0x05,
    /// Secure storage only — never valid on the wire.
    WrappedStoreKey = 0x10,
    /// Isar / state files only — never valid on the wire.
    LocalSeal = 0x20,
}

impl BlobKind {
    fn from_byte(byte: u8) -> Result<Self, CoreError> {
        match byte {
            0x01 => Ok(Self::Invitation),
            0x02 => Ok(Self::Acceptance),
            0x03 => Ok(Self::Message),
            0x04 => Ok(Self::FileContainer),
            0x05 => Ok(Self::PasswordSealed),
            0x10 => Ok(Self::WrappedStoreKey),
            0x20 => Ok(Self::LocalSeal),
            _ => Err(CoreError::UnsupportedFormat),
        }
    }

    /// Whether a blob of this kind may arrive by paste.
    pub fn is_wire(self) -> bool {
        !matches!(self, Self::WrappedStoreKey | Self::LocalSeal)
    }
}

/// `0 = PreKey`, `1 = Normal` — the Olm message type byte.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum OlmType {
    PreKey = 0x00,
    Normal = 0x01,
}

impl OlmType {
    fn from_byte(byte: u8) -> Result<Self, CoreError> {
        match byte {
            0x00 => Ok(Self::PreKey),
            0x01 => Ok(Self::Normal),
            _ => Err(CoreError::Corrupt),
        }
    }
}

/// Argon2id cost parameters as written into every password-derived header.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Argon2Params {
    pub m_cost: u32,
    pub t_cost: u32,
    pub p_cost: u8,
}

impl Argon2Params {
    fn write(&self, out: &mut Vec<u8>) {
        out.extend_from_slice(&self.m_cost.to_be_bytes());
        out.extend_from_slice(&self.t_cost.to_be_bytes());
        out.push(self.p_cost);
    }

    fn read(reader: &mut Reader<'_>) -> Result<Self, CoreError> {
        Ok(Self {
            m_cost: reader.u32_be()?,
            t_cost: reader.u32_be()?,
            p_cost: reader.u8()?,
        })
    }
}

// ---------------------------------------------------------------------------
// Text envelope
// ---------------------------------------------------------------------------

/// `Fuzz/` + base64url (no padding) of `blob`.
pub fn encode_text(blob: &[u8]) -> String {
    let mut text = String::with_capacity(TEXT_PREFIX.len() + blob.len().div_ceil(3) * 4);
    text.push_str(TEXT_PREFIX);
    URL_SAFE_NO_PAD.encode_string(blob, &mut text);
    text
}

/// Inverse of [`encode_text`]. ASCII whitespace anywhere in `text` is ignored
/// (email/SMS wrapping); a missing prefix, padding or any other character is
/// `UnsupportedFormat`.
pub fn decode_text(text: &str) -> Result<Vec<u8>, CoreError> {
    let compact: Vec<u8> = text
        .bytes()
        .filter(|byte| !byte.is_ascii_whitespace())
        .collect();
    let encoded = compact
        .strip_prefix(TEXT_PREFIX.as_bytes())
        .ok_or(CoreError::UnsupportedFormat)?;
    URL_SAFE_NO_PAD
        .decode(encoded)
        .map_err(|_| CoreError::UnsupportedFormat)
}

// ---------------------------------------------------------------------------
// Outer envelope
// ---------------------------------------------------------------------------

/// Writes `FUZZ · 0x01 · kind` and reserves `payload_capacity` more bytes.
fn begin_blob(kind: BlobKind, payload_capacity: usize) -> Vec<u8> {
    let mut out = Vec::with_capacity(ENVELOPE_LEN + payload_capacity);
    out.extend_from_slice(&MAGIC);
    out.push(VERSION);
    out.push(kind as u8);
    out
}

/// Reads the 6-byte envelope; returns the kind and the payload after it.
pub fn decode_envelope(blob: &[u8]) -> Result<(BlobKind, &[u8]), CoreError> {
    let (header, payload) = blob
        .split_first_chunk::<ENVELOPE_LEN>()
        .ok_or(CoreError::UnsupportedFormat)?;
    if header[..4] != MAGIC || header[4] != VERSION {
        return Err(CoreError::UnsupportedFormat);
    }
    Ok((BlobKind::from_byte(header[5])?, payload))
}

/// Reads the envelope and insists it is `expected`.
fn expect_kind(blob: &[u8], expected: BlobKind) -> Result<&[u8], CoreError> {
    let (kind, payload) = decode_envelope(blob)?;
    if kind != expected {
        return Err(CoreError::UnsupportedFormat);
    }
    Ok(payload)
}

/// The paste path: text envelope → outer envelope, rejecting the storage-only
/// kinds (0x10, 0x20). Returns the kind and the whole binary blob (header included).
pub fn decode_pasted(text: &str) -> Result<(BlobKind, Vec<u8>), CoreError> {
    let blob = decode_text(text)?;
    let (kind, _) = decode_envelope(&blob)?;
    if !kind.is_wire() {
        return Err(CoreError::UnsupportedFormat);
    }
    Ok((kind, blob))
}

// ---------------------------------------------------------------------------
// Invitation 0x01
// ---------------------------------------------------------------------------

/// `chat_id_len u8 · chat_id · a_curve25519 32 · a_ed25519 32 · a_one_time_key 32 · sig 64`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Invitation {
    pub chat_id: String,
    pub a_curve25519: [u8; 32],
    pub a_ed25519: [u8; 32],
    pub a_one_time_key: [u8; 32],
    /// Ed25519(A) over [`Invitation::to_be_signed`].
    pub signature: [u8; SIGNATURE_LEN],
}

impl Invitation {
    /// Everything the signature covers: the envelope and every field before `sig`.
    pub fn to_be_signed(&self) -> Result<Vec<u8>, CoreError> {
        let mut out = begin_blob(
            BlobKind::Invitation,
            1 + self.chat_id.len() + 96 + SIGNATURE_LEN,
        );
        write_chat_id(&mut out, &self.chat_id)?;
        out.extend_from_slice(&self.a_curve25519);
        out.extend_from_slice(&self.a_ed25519);
        out.extend_from_slice(&self.a_one_time_key);
        Ok(out)
    }

    pub fn encode(&self) -> Result<Vec<u8>, CoreError> {
        let mut out = self.to_be_signed()?;
        out.extend_from_slice(&self.signature);
        Ok(out)
    }

    pub fn decode(blob: &[u8]) -> Result<Self, CoreError> {
        let mut reader = Reader::new(expect_kind(blob, BlobKind::Invitation)?);
        let invitation = Self {
            chat_id: reader.chat_id()?,
            a_curve25519: reader.array()?,
            a_ed25519: reader.array()?,
            a_one_time_key: reader.array()?,
            signature: reader.array()?,
        };
        reader.finish()?;
        Ok(invitation)
    }
}

// ---------------------------------------------------------------------------
// Acceptance 0x02
// ---------------------------------------------------------------------------

/// `chat_id_len u8 · chat_id · b_curve25519 32 · b_ed25519 32 · prekey_len u16 · prekey_msg · sig 64`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Acceptance {
    pub chat_id: String,
    pub b_curve25519: [u8; 32],
    pub b_ed25519: [u8; 32],
    /// `PreKeyMessage::to_bytes()`, 1..=65535 bytes.
    pub prekey_msg: Vec<u8>,
    /// Ed25519(B) over [`Acceptance::to_be_signed`].
    pub signature: [u8; SIGNATURE_LEN],
}

impl Acceptance {
    /// Everything the signature covers: the envelope and every field before `sig`.
    pub fn to_be_signed(&self) -> Result<Vec<u8>, CoreError> {
        let mut out = begin_blob(
            BlobKind::Acceptance,
            1 + self.chat_id.len() + 64 + 2 + self.prekey_msg.len() + SIGNATURE_LEN,
        );
        write_chat_id(&mut out, &self.chat_id)?;
        out.extend_from_slice(&self.b_curve25519);
        out.extend_from_slice(&self.b_ed25519);
        write_u16_prefixed(&mut out, &self.prekey_msg)?;
        Ok(out)
    }

    pub fn encode(&self) -> Result<Vec<u8>, CoreError> {
        let mut out = self.to_be_signed()?;
        out.extend_from_slice(&self.signature);
        Ok(out)
    }

    pub fn decode(blob: &[u8]) -> Result<Self, CoreError> {
        let mut reader = Reader::new(expect_kind(blob, BlobKind::Acceptance)?);
        let acceptance = Self {
            chat_id: reader.chat_id()?,
            b_curve25519: reader.array()?,
            b_ed25519: reader.array()?,
            prekey_msg: reader.u16_prefixed()?,
            signature: reader.array()?,
        };
        reader.finish()?;
        Ok(acceptance)
    }
}

// ---------------------------------------------------------------------------
// Message 0x03
// ---------------------------------------------------------------------------

/// `olm_type u8 · olm_body` — nothing else in the clear, no chat id.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Message {
    pub olm_type: OlmType,
    /// `Message::to_bytes()` / `PreKeyMessage::to_bytes()`, never empty.
    pub olm_body: Vec<u8>,
}

impl Message {
    pub fn encode(&self) -> Result<Vec<u8>, CoreError> {
        if self.olm_body.is_empty() {
            return Err(CoreError::Corrupt);
        }
        let mut out = begin_blob(BlobKind::Message, 1 + self.olm_body.len());
        out.push(self.olm_type as u8);
        out.extend_from_slice(&self.olm_body);
        Ok(out)
    }

    pub fn decode(blob: &[u8]) -> Result<Self, CoreError> {
        let mut reader = Reader::new(expect_kind(blob, BlobKind::Message)?);
        Ok(Self {
            olm_type: OlmType::from_byte(reader.u8()?)?,
            olm_body: reader.rest_non_empty()?,
        })
    }
}

// ---------------------------------------------------------------------------
// Password-sealed blob 0x05
// ---------------------------------------------------------------------------

/// `salt 16 · m_cost u32 · t_cost u32 · p_cost u8 · nonce 24 · ct+tag`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PasswordSealed {
    pub salt: [u8; 16],
    pub params: Argon2Params,
    pub nonce: [u8; 24],
    /// XChaCha20-Poly1305 ciphertext followed by its 16-byte tag.
    pub ciphertext: Vec<u8>,
}

impl PasswordSealed {
    pub fn encode(&self) -> Vec<u8> {
        let mut out = begin_blob(
            BlobKind::PasswordSealed,
            16 + 9 + 24 + self.ciphertext.len(),
        );
        out.extend_from_slice(&self.salt);
        self.params.write(&mut out);
        out.extend_from_slice(&self.nonce);
        out.extend_from_slice(&self.ciphertext);
        out
    }

    pub fn decode(blob: &[u8]) -> Result<Self, CoreError> {
        let mut reader = Reader::new(expect_kind(blob, BlobKind::PasswordSealed)?);
        Ok(Self {
            salt: reader.array()?,
            params: Argon2Params::read(&mut reader)?,
            nonce: reader.array()?,
            ciphertext: reader.rest_at_least(TAG_LEN)?,
        })
    }
}

// ---------------------------------------------------------------------------
// Wrapped store key 0x10
// ---------------------------------------------------------------------------

/// `salt 16 · m u32 · t u32 · p u8 · nonce 24 · ct+tag (32+16)`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct WrappedStoreKey {
    pub salt: [u8; 16],
    pub params: Argon2Params,
    pub nonce: [u8; 24],
    /// The 32-byte store key sealed under the KEK, followed by its 16-byte tag.
    pub ciphertext: [u8; WRAPPED_STORE_KEY_CT_LEN],
}

impl WrappedStoreKey {
    pub fn encode(&self) -> Vec<u8> {
        let mut out = begin_blob(
            BlobKind::WrappedStoreKey,
            16 + 9 + 24 + WRAPPED_STORE_KEY_CT_LEN,
        );
        out.extend_from_slice(&self.salt);
        self.params.write(&mut out);
        out.extend_from_slice(&self.nonce);
        out.extend_from_slice(&self.ciphertext);
        out
    }

    pub fn decode(blob: &[u8]) -> Result<Self, CoreError> {
        let mut reader = Reader::new(expect_kind(blob, BlobKind::WrappedStoreKey)?);
        let wrapped = Self {
            salt: reader.array()?,
            params: Argon2Params::read(&mut reader)?,
            nonce: reader.array()?,
            ciphertext: reader.array()?,
        };
        reader.finish()?;
        Ok(wrapped)
    }
}

// ---------------------------------------------------------------------------
// Local seal 0x20
// ---------------------------------------------------------------------------

/// `nonce 24 · ct+tag`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LocalSeal {
    pub nonce: [u8; 24],
    /// XChaCha20-Poly1305 ciphertext followed by its 16-byte tag.
    pub ciphertext: Vec<u8>,
}

impl LocalSeal {
    pub fn encode(&self) -> Vec<u8> {
        let mut out = begin_blob(BlobKind::LocalSeal, 24 + self.ciphertext.len());
        out.extend_from_slice(&self.nonce);
        out.extend_from_slice(&self.ciphertext);
        out
    }

    pub fn decode(blob: &[u8]) -> Result<Self, CoreError> {
        let mut reader = Reader::new(expect_kind(blob, BlobKind::LocalSeal)?);
        Ok(Self {
            nonce: reader.array()?,
            ciphertext: reader.rest_at_least(TAG_LEN)?,
        })
    }
}

// ---------------------------------------------------------------------------
// File container header 0x04
// ---------------------------------------------------------------------------

/// How the file key is carried in the header.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum FileKeyMode {
    /// `0x01 · olm_type u8 · olm_len u16 · olm_body` — the file key rides in an Olm message.
    Chat {
        olm_type: OlmType,
        olm_body: Vec<u8>,
    },
    /// `0x02 · salt 16 · m_cost u32 · t_cost u32 · p_cost u8` — the file key is Argon2id(password).
    Password {
        salt: [u8; 16],
        params: Argon2Params,
    },
}

const KEY_MODE_CHAT: u8 = 0x01;
const KEY_MODE_PASSWORD: u8 = 0x02;

/// `key_mode u8 · chunk_size u32 · nonce_prefix 19 · <key material per mode>`.
/// The chunk loop that follows the header is F3-1's.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FileHeader {
    /// Encoders write [`CHUNK_SIZE`]; decoders accept `MIN_CHUNK_SIZE..=MAX_CHUNK_SIZE`.
    pub chunk_size: u32,
    pub nonce_prefix: [u8; 19],
    pub key_mode: FileKeyMode,
}

impl FileHeader {
    pub fn encode(&self) -> Result<Vec<u8>, CoreError> {
        let mut out = begin_blob(BlobKind::FileContainer, 1 + 4 + 19 + 64);
        match &self.key_mode {
            FileKeyMode::Chat { olm_type, olm_body } => {
                out.push(KEY_MODE_CHAT);
                out.extend_from_slice(&self.chunk_size.to_be_bytes());
                out.extend_from_slice(&self.nonce_prefix);
                out.push(*olm_type as u8);
                write_u16_prefixed(&mut out, olm_body)?;
            }
            FileKeyMode::Password { salt, params } => {
                out.push(KEY_MODE_PASSWORD);
                out.extend_from_slice(&self.chunk_size.to_be_bytes());
                out.extend_from_slice(&self.nonce_prefix);
                out.extend_from_slice(salt);
                params.write(&mut out);
            }
        }
        Ok(out)
    }

    /// Decodes the header at the start of `file` and returns it with its exact
    /// byte length (the chunks' AAD, and where chunk 0 starts).
    pub fn decode(file: &[u8]) -> Result<(Self, usize), CoreError> {
        let payload = expect_kind(file, BlobKind::FileContainer)?;
        let mut reader = Reader::new(payload);
        let key_mode_byte = reader.u8()?;
        let chunk_size = reader.u32_be()?;
        if !(MIN_CHUNK_SIZE..=MAX_CHUNK_SIZE).contains(&chunk_size) {
            return Err(CoreError::Corrupt);
        }
        let nonce_prefix = reader.array()?;
        let key_mode = match key_mode_byte {
            KEY_MODE_CHAT => FileKeyMode::Chat {
                olm_type: OlmType::from_byte(reader.u8()?)?,
                olm_body: reader.u16_prefixed()?,
            },
            KEY_MODE_PASSWORD => FileKeyMode::Password {
                salt: reader.array()?,
                params: Argon2Params::read(&mut reader)?,
            },
            _ => return Err(CoreError::Corrupt),
        };
        let header_len = ENVELOPE_LEN + reader.consumed();
        Ok((
            Self {
                chunk_size,
                nonce_prefix,
                key_mode,
            },
            header_len,
        ))
    }
}

// ---------------------------------------------------------------------------
// Inner authenticated header (Olm plaintext)
// ---------------------------------------------------------------------------

/// Inner header version.
pub const INNER_VERSION: u8 = 0x01;

/// `0x00 = A→B` (inviter to accepter), `0x01 = B→A`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum Direction {
    AToB = 0x00,
    BToA = 0x01,
}

impl Direction {
    fn from_byte(byte: u8) -> Result<Self, CoreError> {
        match byte {
            0x00 => Ok(Self::AToB),
            0x01 => Ok(Self::BToA),
            _ => Err(CoreError::Corrupt),
        }
    }
}

/// `0x00 handshake/empty · 0x01 text UTF-8 · 0x02 file key envelope`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum ContentType {
    Handshake = 0x00,
    Text = 0x01,
    FileKeyEnvelope = 0x02,
}

impl ContentType {
    fn from_byte(byte: u8) -> Result<Self, CoreError> {
        match byte {
            0x00 => Ok(Self::Handshake),
            0x01 => Ok(Self::Text),
            0x02 => Ok(Self::FileKeyEnvelope),
            _ => Err(CoreError::Corrupt),
        }
    }
}

/// The Olm plaintext of every message and of the file-key envelope:
/// `inner_version u8 · chat_id_len u8 · chat_id · sender_ed25519 32 · recipient_ed25519 32 ·
/// direction u8 · counter u64 · content_type u8 · body_len u32 · body`.
/// Validation against session state is the caller's job (F2-4).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InnerHeader {
    pub chat_id: String,
    pub sender_ed25519: [u8; 32],
    pub recipient_ed25519: [u8; 32],
    pub direction: Direction,
    pub counter: u64,
    pub content_type: ContentType,
    pub body: Vec<u8>,
}

impl InnerHeader {
    pub fn encode(&self) -> Result<Vec<u8>, CoreError> {
        let mut out =
            Vec::with_capacity(2 + self.chat_id.len() + 64 + 1 + 8 + 1 + 4 + self.body.len());
        out.push(INNER_VERSION);
        write_chat_id(&mut out, &self.chat_id)?;
        out.extend_from_slice(&self.sender_ed25519);
        out.extend_from_slice(&self.recipient_ed25519);
        out.push(self.direction as u8);
        out.extend_from_slice(&self.counter.to_be_bytes());
        out.push(self.content_type as u8);
        let body_len = u32::try_from(self.body.len()).map_err(|_| CoreError::Corrupt)?;
        out.extend_from_slice(&body_len.to_be_bytes());
        out.extend_from_slice(&self.body);
        Ok(out)
    }

    pub fn decode(plaintext: &[u8]) -> Result<Self, CoreError> {
        let mut reader = Reader::new(plaintext);
        if reader.u8()? != INNER_VERSION {
            return Err(CoreError::UnsupportedFormat);
        }
        let header = Self {
            chat_id: reader.chat_id()?,
            sender_ed25519: reader.array()?,
            recipient_ed25519: reader.array()?,
            direction: Direction::from_byte(reader.u8()?)?,
            counter: reader.u64_be()?,
            content_type: ContentType::from_byte(reader.u8()?)?,
            body: reader.u32_prefixed()?,
        };
        reader.finish()?;
        Ok(header)
    }
}

// ---------------------------------------------------------------------------
// File-key envelope body (inner header content type 0x02)
// ---------------------------------------------------------------------------

/// The body of a `content_type 0x02` inner header — the Olm-wrapped file key
/// of a chat-mode 0x04 container (plan §C):
/// `file_key 32 · original_name_len u16 · original_name UTF-8`.
/// The key wipes on drop; the name is checked for UTF-8 only — whether it is a
/// usable file name is the caller's job (F3-2), like the chat id's uuid shape.
pub struct FileKeyBody {
    pub file_key: Zeroizing<[u8; 32]>,
    pub original_name: String,
}

impl FileKeyBody {
    pub fn encode(&self) -> Result<Zeroizing<Vec<u8>>, CoreError> {
        let mut out = Zeroizing::new(Vec::with_capacity(32 + 2 + self.original_name.len()));
        out.extend_from_slice(&*self.file_key);
        write_u16_prefixed(&mut out, self.original_name.as_bytes())?;
        Ok(out)
    }

    pub fn decode(body: &[u8]) -> Result<Self, CoreError> {
        let mut reader = Reader::new(body);
        let file_key = Zeroizing::new(reader.array()?);
        let original_name =
            String::from_utf8(reader.u16_prefixed()?).map_err(|_| CoreError::Corrupt)?;
        reader.finish()?;
        Ok(Self {
            file_key,
            original_name,
        })
    }
}

// ---------------------------------------------------------------------------
// Field helpers
// ---------------------------------------------------------------------------

/// Poly1305 tag length — the minimum size of any `ct+tag` field.
const TAG_LEN: usize = 16;

fn write_chat_id(out: &mut Vec<u8>, chat_id: &str) -> Result<(), CoreError> {
    if chat_id.is_empty() {
        return Err(CoreError::Corrupt);
    }
    let len = u8::try_from(chat_id.len()).map_err(|_| CoreError::Corrupt)?;
    out.push(len);
    out.extend_from_slice(chat_id.as_bytes());
    Ok(())
}

fn write_u16_prefixed(out: &mut Vec<u8>, bytes: &[u8]) -> Result<(), CoreError> {
    if bytes.is_empty() {
        return Err(CoreError::Corrupt);
    }
    let len = u16::try_from(bytes.len()).map_err(|_| CoreError::Corrupt)?;
    out.extend_from_slice(&len.to_be_bytes());
    out.extend_from_slice(bytes);
    Ok(())
}

/// Bounds-checked cursor over a payload. Every read is `Corrupt` when the input
/// is too short; `finish` is `Corrupt` when bytes are left over.
struct Reader<'a> {
    bytes: &'a [u8],
    pos: usize,
}

impl<'a> Reader<'a> {
    fn new(bytes: &'a [u8]) -> Self {
        Self { bytes, pos: 0 }
    }

    fn consumed(&self) -> usize {
        self.pos
    }

    fn take(&mut self, len: usize) -> Result<&'a [u8], CoreError> {
        let end = self.pos.checked_add(len).ok_or(CoreError::Corrupt)?;
        let slice = self.bytes.get(self.pos..end).ok_or(CoreError::Corrupt)?;
        self.pos = end;
        Ok(slice)
    }

    fn array<const N: usize>(&mut self) -> Result<[u8; N], CoreError> {
        self.take(N)?.try_into().map_err(|_| CoreError::Corrupt)
    }

    fn u8(&mut self) -> Result<u8, CoreError> {
        Ok(self.array::<1>()?[0])
    }

    fn u16_be(&mut self) -> Result<u16, CoreError> {
        Ok(u16::from_be_bytes(self.array()?))
    }

    fn u32_be(&mut self) -> Result<u32, CoreError> {
        Ok(u32::from_be_bytes(self.array()?))
    }

    fn u64_be(&mut self) -> Result<u64, CoreError> {
        Ok(u64::from_be_bytes(self.array()?))
    }

    /// `u8` length prefix, then non-empty UTF-8.
    fn chat_id(&mut self) -> Result<String, CoreError> {
        let len = usize::from(self.u8()?);
        if len == 0 {
            return Err(CoreError::Corrupt);
        }
        String::from_utf8(self.take(len)?.to_vec()).map_err(|_| CoreError::Corrupt)
    }

    /// `u16` length prefix, then that many bytes (never zero).
    fn u16_prefixed(&mut self) -> Result<Vec<u8>, CoreError> {
        let len = usize::from(self.u16_be()?);
        if len == 0 {
            return Err(CoreError::Corrupt);
        }
        Ok(self.take(len)?.to_vec())
    }

    /// `u32` length prefix, then that many bytes (zero allowed — handshake bodies are empty).
    fn u32_prefixed(&mut self) -> Result<Vec<u8>, CoreError> {
        let len = usize::try_from(self.u32_be()?).map_err(|_| CoreError::Corrupt)?;
        Ok(self.take(len)?.to_vec())
    }

    fn rest(&mut self) -> &'a [u8] {
        let rest = self.bytes.get(self.pos..).unwrap_or_default();
        self.pos = self.bytes.len();
        rest
    }

    fn rest_non_empty(&mut self) -> Result<Vec<u8>, CoreError> {
        self.rest_at_least(1)
    }

    fn rest_at_least(&mut self, min: usize) -> Result<Vec<u8>, CoreError> {
        let rest = self.rest();
        if rest.len() < min {
            return Err(CoreError::Corrupt);
        }
        Ok(rest.to_vec())
    }

    fn finish(&self) -> Result<(), CoreError> {
        if self.pos == self.bytes.len() {
            Ok(())
        } else {
            Err(CoreError::Corrupt)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CHAT_ID: &str = "6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d";
    // `24` = 36, then the uuid's UTF-8.
    const CHAT_ID_FIELD_HEX: &str =
        "2436663165396232632d336434612d346635622d386336642d376538663961306231633264";
    const A_CURVE_HEX: &str = "1111111111111111111111111111111111111111111111111111111111111111";
    const A_ED_HEX: &str = "2222222222222222222222222222222222222222222222222222222222222222";
    const A_OTK_HEX: &str = "3333333333333333333333333333333333333333333333333333333333333333";
    const SIG_A_HEX: &str = "44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444";
    const B_CURVE_HEX: &str = "5555555555555555555555555555555555555555555555555555555555555555";
    const B_ED_HEX: &str = "6666666666666666666666666666666666666666666666666666666666666666";
    const SIG_B_HEX: &str = "77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777";
    const SALT_HEX: &str = "a0a1a2a3a4a5a6a7a8a9aaabacadaeaf";
    const NONCE_HEX: &str = "b0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7";
    const NONCE_PREFIX_HEX: &str = "909192939495969798999a9b9c9d9e9fa0a1a2";

    const INVITATION_HEX: &str = concat!(
        "46555a5a0101",
        "2436663165396232632d336434612d346635622d386336642d376538663961306231633264",
        "1111111111111111111111111111111111111111111111111111111111111111",
        "2222222222222222222222222222222222222222222222222222222222222222",
        "3333333333333333333333333333333333333333333333333333333333333333",
        "44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444",
    );
    const ACCEPTANCE_HEX: &str = concat!(
        "46555a5a0102",
        "2436663165396232632d336434612d346635622d386336642d376538663961306231633264",
        "5555555555555555555555555555555555555555555555555555555555555555",
        "6666666666666666666666666666666666666666666666666666666666666666",
        "0005a1a2a3a4a5",
        "77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777",
    );
    const MESSAGE_HEX: &str = "46555a5a010301deadbeef";
    const PASSWORD_SEALED_HEX: &str = concat!(
        "46555a5a0105",
        "a0a1a2a3a4a5a6a7a8a9aaabacadaeaf",
        "000100000000000401",
        "b0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7",
        "cccccccccccccccccccccccccccccccccccccccc",
    );
    const WRAPPED_STORE_KEY_HEX: &str = concat!(
        "46555a5a0110",
        "a0a1a2a3a4a5a6a7a8a9aaabacadaeaf",
        "000100000000000401",
        "b0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7",
        "eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
    );
    const LOCAL_SEAL_HEX: &str = concat!(
        "46555a5a0120",
        "b0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7",
        "dddddddddddddddddddddddddddddddddd",
    );
    const FILE_HEADER_CHAT_HEX: &str = concat!(
        "46555a5a0104",
        "01",
        "00100000",
        "909192939495969798999a9b9c9d9e9fa0a1a2",
        "00",
        "0003f1f2f3",
    );
    const FILE_HEADER_PASSWORD_HEX: &str = concat!(
        "46555a5a0104",
        "02",
        "00100000",
        "909192939495969798999a9b9c9d9e9fa0a1a2",
        "a0a1a2a3a4a5a6a7a8a9aaabacadaeaf",
        "000100000000000401",
    );
    const INNER_HEADER_HEX: &str = concat!(
        "01",
        "2436663165396232632d336434612d346635622d386336642d376538663961306231633264",
        "2222222222222222222222222222222222222222222222222222222222222222",
        "6666666666666666666666666666666666666666666666666666666666666666",
        "01",
        "0000000000000102",
        "01",
        "00000002",
        "6869",
    );

    const MESSAGE_TEXT: &str = "Fuzz/RlVaWgEDAd6tvu8";
    const INVITATION_TEXT: &str = "Fuzz/RlVaWgEBJDZmMWU5YjJjLTNkNGEtNGY1Yi04YzZkLTdlOGY5YTBiMWMyZBERERERERERERERERERERERERERERERERERERERERERIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzMzM0REREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREREQ";

    fn hex(text: &str) -> Vec<u8> {
        (0..text.len())
            .step_by(2)
            .map(|i| u8::from_str_radix(&text[i..i + 2], 16).expect("test hex"))
            .collect()
    }

    fn arr<const N: usize>(text: &str) -> [u8; N] {
        hex(text).try_into().expect("test array length")
    }

    fn params() -> Argon2Params {
        Argon2Params {
            m_cost: 65536,
            t_cost: 4,
            p_cost: 1,
        }
    }

    fn invitation() -> Invitation {
        Invitation {
            chat_id: CHAT_ID.to_string(),
            a_curve25519: arr(A_CURVE_HEX),
            a_ed25519: arr(A_ED_HEX),
            a_one_time_key: arr(A_OTK_HEX),
            signature: arr(SIG_A_HEX),
        }
    }

    fn acceptance() -> Acceptance {
        Acceptance {
            chat_id: CHAT_ID.to_string(),
            b_curve25519: arr(B_CURVE_HEX),
            b_ed25519: arr(B_ED_HEX),
            prekey_msg: vec![0xA1, 0xA2, 0xA3, 0xA4, 0xA5],
            signature: arr(SIG_B_HEX),
        }
    }

    fn message() -> Message {
        Message {
            olm_type: OlmType::Normal,
            olm_body: vec![0xDE, 0xAD, 0xBE, 0xEF],
        }
    }

    fn password_sealed() -> PasswordSealed {
        PasswordSealed {
            salt: arr(SALT_HEX),
            params: params(),
            nonce: arr(NONCE_HEX),
            ciphertext: vec![0xCC; 20],
        }
    }

    fn wrapped_store_key() -> WrappedStoreKey {
        WrappedStoreKey {
            salt: arr(SALT_HEX),
            params: params(),
            nonce: arr(NONCE_HEX),
            ciphertext: [0xEE; WRAPPED_STORE_KEY_CT_LEN],
        }
    }

    fn local_seal() -> LocalSeal {
        LocalSeal {
            nonce: arr(NONCE_HEX),
            ciphertext: vec![0xDD; 17],
        }
    }

    fn file_header_chat() -> FileHeader {
        FileHeader {
            chunk_size: CHUNK_SIZE,
            nonce_prefix: arr(NONCE_PREFIX_HEX),
            key_mode: FileKeyMode::Chat {
                olm_type: OlmType::PreKey,
                olm_body: vec![0xF1, 0xF2, 0xF3],
            },
        }
    }

    fn file_header_password() -> FileHeader {
        FileHeader {
            chunk_size: CHUNK_SIZE,
            nonce_prefix: arr(NONCE_PREFIX_HEX),
            key_mode: FileKeyMode::Password {
                salt: arr(SALT_HEX),
                params: params(),
            },
        }
    }

    fn inner_header() -> InnerHeader {
        InnerHeader {
            chat_id: CHAT_ID.to_string(),
            sender_ed25519: arr(A_ED_HEX),
            recipient_ed25519: arr(B_ED_HEX),
            direction: Direction::BToA,
            counter: 258,
            content_type: ContentType::Text,
            body: b"hi".to_vec(),
        }
    }

    // --- golden bytes ------------------------------------------------------

    #[test]
    fn invitation_golden_bytes() {
        let blob = invitation().encode().unwrap();
        assert_eq!(blob, hex(INVITATION_HEX));
        assert_eq!(blob.len(), 203);
        assert_eq!(
            invitation().to_be_signed().unwrap(),
            blob[..blob.len() - SIGNATURE_LEN]
        );
        assert_eq!(Invitation::decode(&blob).unwrap(), invitation());
        assert_eq!(
            hex(CHAT_ID_FIELD_HEX),
            blob[ENVELOPE_LEN..ENVELOPE_LEN + 37]
        );
    }

    #[test]
    fn acceptance_golden_bytes() {
        let blob = acceptance().encode().unwrap();
        assert_eq!(blob, hex(ACCEPTANCE_HEX));
        assert_eq!(
            acceptance().to_be_signed().unwrap(),
            blob[..blob.len() - SIGNATURE_LEN]
        );
        assert_eq!(Acceptance::decode(&blob).unwrap(), acceptance());
    }

    #[test]
    fn message_golden_bytes() {
        let blob = message().encode().unwrap();
        assert_eq!(blob, hex(MESSAGE_HEX));
        assert_eq!(Message::decode(&blob).unwrap(), message());
        let prekey = Message {
            olm_type: OlmType::PreKey,
            ..message()
        };
        assert_eq!(prekey.encode().unwrap(), hex("46555a5a010300deadbeef"));
    }

    #[test]
    fn password_sealed_golden_bytes() {
        let blob = password_sealed().encode();
        assert_eq!(blob, hex(PASSWORD_SEALED_HEX));
        assert_eq!(PasswordSealed::decode(&blob).unwrap(), password_sealed());
    }

    #[test]
    fn wrapped_store_key_golden_bytes() {
        let blob = wrapped_store_key().encode();
        assert_eq!(blob, hex(WRAPPED_STORE_KEY_HEX));
        assert_eq!(blob.len(), 103);
        assert_eq!(WrappedStoreKey::decode(&blob).unwrap(), wrapped_store_key());
    }

    #[test]
    fn local_seal_golden_bytes() {
        let blob = local_seal().encode();
        assert_eq!(blob, hex(LOCAL_SEAL_HEX));
        assert_eq!(LocalSeal::decode(&blob).unwrap(), local_seal());
    }

    #[test]
    fn file_header_chat_golden_bytes_and_len() {
        let bytes = file_header_chat().encode().unwrap();
        assert_eq!(bytes, hex(FILE_HEADER_CHAT_HEX));
        let mut file = bytes.clone();
        file.extend_from_slice(&[0x99; 40]); // chunk bytes after the header
        let (header, header_len) = FileHeader::decode(&file).unwrap();
        assert_eq!(header, file_header_chat());
        assert_eq!(header_len, 36);
        assert_eq!(header_len, bytes.len());
    }

    #[test]
    fn file_header_password_golden_bytes_and_len() {
        let bytes = file_header_password().encode().unwrap();
        assert_eq!(bytes, hex(FILE_HEADER_PASSWORD_HEX));
        let (header, header_len) = FileHeader::decode(&bytes).unwrap();
        assert_eq!(header, file_header_password());
        assert_eq!(header_len, 55);
    }

    #[test]
    fn inner_header_golden_bytes() {
        let bytes = inner_header().encode().unwrap();
        assert_eq!(bytes, hex(INNER_HEADER_HEX));
        assert_eq!(InnerHeader::decode(&bytes).unwrap(), inner_header());
    }

    #[test]
    fn inner_header_empty_handshake_body_round_trips() {
        let handshake = InnerHeader {
            direction: Direction::AToB,
            counter: 0,
            content_type: ContentType::Handshake,
            body: Vec::new(),
            ..inner_header()
        };
        let bytes = handshake.encode().unwrap();
        assert_eq!(
            &bytes[bytes.len() - 14..],
            hex("0000000000000000000000000000")
        );
        assert_eq!(InnerHeader::decode(&bytes).unwrap(), handshake);
    }

    // --- file-key envelope body (content type 0x02) ------------------------

    #[test]
    fn file_key_body_golden_bytes() {
        // `file_key 32 · original_name_len u16 · original_name`: key 0x42×32,
        // then `000a` = 10 and "report.pdf".
        let body = FileKeyBody {
            file_key: Zeroizing::new([0x42; 32]),
            original_name: "report.pdf".into(),
        };
        let bytes = body.encode().unwrap();
        assert_eq!(
            *bytes,
            hex(concat!(
                "4242424242424242424242424242424242424242424242424242424242424242",
                "000a",
                "7265706f72742e706466",
            ))
        );
        assert_eq!(bytes.capacity(), bytes.len(), "no reallocation residue");
        let decoded = FileKeyBody::decode(&bytes).unwrap();
        assert_eq!(*decoded.file_key, [0x42; 32]);
        assert_eq!(decoded.original_name, "report.pdf");
    }

    #[test]
    fn file_key_body_rejects_short_empty_trailing_and_non_utf8() {
        let good = FileKeyBody {
            file_key: Zeroizing::new([0x42; 32]),
            original_name: "a".into(),
        }
        .encode()
        .unwrap();
        for cut in 0..good.len() {
            assert_eq!(
                FileKeyBody::decode(&good[..cut]).err().unwrap(),
                CoreError::Corrupt,
                "prefix {cut}"
            );
        }
        let mut trailing = good.to_vec();
        trailing.push(0);
        assert_eq!(
            FileKeyBody::decode(&trailing).err().unwrap(),
            CoreError::Corrupt
        );
        // An empty name is refused on both sides.
        let mut empty = [0x42u8; 32].to_vec();
        empty.extend([0, 0]);
        assert_eq!(
            FileKeyBody::decode(&empty).err().unwrap(),
            CoreError::Corrupt
        );
        assert_eq!(
            FileKeyBody {
                file_key: Zeroizing::new([0x42; 32]),
                original_name: String::new(),
            }
            .encode()
            .unwrap_err(),
            CoreError::Corrupt
        );
        let mut bad_utf8 = [0x42u8; 32].to_vec();
        bad_utf8.extend([0, 2, 0xFF, 0xFE]);
        assert_eq!(
            FileKeyBody::decode(&bad_utf8).err().unwrap(),
            CoreError::Corrupt
        );
    }

    // --- text envelope -----------------------------------------------------

    #[test]
    fn text_envelope_golden() {
        assert_eq!(encode_text(&hex(MESSAGE_HEX)), MESSAGE_TEXT);
        assert_eq!(encode_text(&hex(INVITATION_HEX)), INVITATION_TEXT);
        assert_eq!(decode_text(MESSAGE_TEXT).unwrap(), hex(MESSAGE_HEX));
        assert_eq!(decode_text(INVITATION_TEXT).unwrap(), hex(INVITATION_HEX));
    }

    #[test]
    fn text_decode_ignores_ascii_whitespace() {
        assert_eq!(decode_text("Fuzz/ABCD").unwrap(), vec![0x00, 0x10, 0x83]);
        assert_eq!(
            decode_text("Fuzz/AB\r\n CD").unwrap(),
            vec![0x00, 0x10, 0x83]
        );
        assert_eq!(
            decode_text(" Fuzz/\tA B\nC D \r\n").unwrap(),
            vec![0x00, 0x10, 0x83]
        );

        let wrapped: String = INVITATION_TEXT
            .as_bytes()
            .chunks(60)
            .map(|line| std::str::from_utf8(line).unwrap())
            .collect::<Vec<_>>()
            .join("\r\n");
        assert_eq!(decode_text(&wrapped).unwrap(), hex(INVITATION_HEX));
    }

    #[test]
    fn text_decode_rejects_padding() {
        assert_eq!(
            decode_text("Fuzz/RlVaWgEDAA=="),
            Err(CoreError::UnsupportedFormat)
        );
        assert_eq!(
            decode_text("Fuzz/RlVaWgEDAd6tvu8="),
            Err(CoreError::UnsupportedFormat)
        );
    }

    #[test]
    fn text_decode_rejects_missing_prefix_and_foreign_characters() {
        assert_eq!(
            decode_text("RlVaWgEDAd6tvu8"),
            Err(CoreError::UnsupportedFormat)
        );
        assert_eq!(
            decode_text("fuzz/RlVaWgEDAd6tvu8"),
            Err(CoreError::UnsupportedFormat)
        );
        assert_eq!(decode_text(""), Err(CoreError::UnsupportedFormat));
        // standard (non-url) alphabet, punctuation, non-ASCII, vertical tab
        for text in [
            "Fuzz/RlVa+gEDAA",
            "Fuzz/RlVa/gEDAA",
            "Fuzz/RlVaWgEDAA!",
            "Fuzz/RlVaWgEDAAé",
            "Fuzz/RlVaWg\x0bEDAA",
        ] {
            assert_eq!(
                decode_text(text),
                Err(CoreError::UnsupportedFormat),
                "{text:?}"
            );
        }
    }

    // --- outer envelope ----------------------------------------------------

    #[test]
    fn envelope_rejects_unknown_magic_version_type() {
        let ok = hex("46555a5a010300");
        assert_eq!(decode_envelope(&ok).unwrap().0, BlobKind::Message);
        for (case, bytes) in [
            ("magic", hex("46555a78010300")),
            ("version", hex("46555a5a020300")),
            ("version 0", hex("46555a5a000300")),
            ("type 0x00", hex("46555a5a010000")),
            ("type 0x06", hex("46555a5a010600")),
            ("type 0xff", hex("46555a5a01ff00")),
            ("short", hex("46555a5a01")),
            ("empty", Vec::new()),
        ] {
            assert_eq!(
                decode_envelope(&bytes),
                Err(CoreError::UnsupportedFormat),
                "{case}"
            );
        }
        assert_eq!(
            decode_text("Fuzz/RlVaWgIDAA").and_then(|b| decode_envelope(&b).map(|e| e.0)),
            Err(CoreError::UnsupportedFormat)
        );
        assert_eq!(
            decode_text("Fuzz/RlVaeAEDAA").and_then(|b| decode_envelope(&b).map(|e| e.0)),
            Err(CoreError::UnsupportedFormat)
        );
        assert_eq!(
            decode_text("Fuzz/RlVaWgEGAA").and_then(|b| decode_envelope(&b).map(|e| e.0)),
            Err(CoreError::UnsupportedFormat)
        );
    }

    #[test]
    fn pasted_rejects_storage_only_kinds() {
        let wrapped_text = encode_text(&hex(WRAPPED_STORE_KEY_HEX));
        let seal_text = encode_text(&hex(LOCAL_SEAL_HEX));
        assert_eq!(
            decode_pasted(&wrapped_text),
            Err(CoreError::UnsupportedFormat)
        );
        assert_eq!(decode_pasted(&seal_text), Err(CoreError::UnsupportedFormat));
        // …while the binary decoders still read them (they never arrive by paste).
        assert!(WrappedStoreKey::decode(&hex(WRAPPED_STORE_KEY_HEX)).is_ok());
        assert!(LocalSeal::decode(&hex(LOCAL_SEAL_HEX)).is_ok());
        assert!(!BlobKind::WrappedStoreKey.is_wire());
        assert!(!BlobKind::LocalSeal.is_wire());
    }

    #[test]
    fn pasted_accepts_every_wire_kind_and_returns_whole_blob() {
        for (kind, blob_hex) in [
            (BlobKind::Invitation, INVITATION_HEX),
            (BlobKind::Acceptance, ACCEPTANCE_HEX),
            (BlobKind::Message, MESSAGE_HEX),
            (BlobKind::FileContainer, FILE_HEADER_CHAT_HEX),
            (BlobKind::PasswordSealed, PASSWORD_SEALED_HEX),
        ] {
            let blob = hex(blob_hex);
            assert_eq!(decode_pasted(&encode_text(&blob)).unwrap(), (kind, blob));
        }
    }

    #[test]
    fn typed_decode_rejects_other_kinds() {
        assert_eq!(
            Invitation::decode(&hex(ACCEPTANCE_HEX)),
            Err(CoreError::UnsupportedFormat)
        );
        assert_eq!(
            Acceptance::decode(&hex(INVITATION_HEX)),
            Err(CoreError::UnsupportedFormat)
        );
        assert_eq!(
            Message::decode(&hex(LOCAL_SEAL_HEX)),
            Err(CoreError::UnsupportedFormat)
        );
        assert_eq!(
            PasswordSealed::decode(&hex(WRAPPED_STORE_KEY_HEX)),
            Err(CoreError::UnsupportedFormat)
        );
        assert_eq!(
            WrappedStoreKey::decode(&hex(PASSWORD_SEALED_HEX)),
            Err(CoreError::UnsupportedFormat)
        );
        assert_eq!(
            LocalSeal::decode(&hex(MESSAGE_HEX)),
            Err(CoreError::UnsupportedFormat)
        );
        assert_eq!(
            FileHeader::decode(&hex(MESSAGE_HEX)),
            Err(CoreError::UnsupportedFormat)
        );
    }

    // --- truncation / trailing bytes (never panic) -------------------------

    #[test]
    fn every_prefix_of_every_blob_is_an_error_not_a_panic() {
        // `fixed_len` = the bytes a layout needs before its open-ended tail (if any):
        // every shorter prefix must be an `Err`; every prefix must return, never panic.
        fn check(name: &str, blob: &[u8], fixed_len: usize, decode: &dyn Fn(&[u8]) -> bool) {
            for cut in 0..blob.len() {
                let decoded = decode(&blob[..cut]);
                assert!(
                    cut >= fixed_len || !decoded,
                    "{name}: prefix of {cut} bytes decoded"
                );
            }
            assert!(decode(blob), "{name}: full blob must decode");
        }
        let invitation = hex(INVITATION_HEX);
        check("invitation", &invitation, invitation.len(), &|b| {
            Invitation::decode(b).is_ok()
        });
        let acceptance = hex(ACCEPTANCE_HEX);
        check("acceptance", &acceptance, acceptance.len(), &|b| {
            Acceptance::decode(b).is_ok()
        });
        let wrapped = hex(WRAPPED_STORE_KEY_HEX);
        check("wrapped_store_key", &wrapped, wrapped.len(), &|b| {
            WrappedStoreKey::decode(b).is_ok()
        });
        let inner = hex(INNER_HEADER_HEX);
        check("inner_header", &inner, inner.len(), &|b| {
            InnerHeader::decode(b).is_ok()
        });
        // open-ended tails: olm_body / ct+tag / the chunks after a file header
        check("message", &hex(MESSAGE_HEX), ENVELOPE_LEN + 1 + 1, &|b| {
            Message::decode(b).is_ok()
        });
        check(
            "password_sealed",
            &hex(PASSWORD_SEALED_HEX),
            ENVELOPE_LEN + 16 + 9 + 24 + TAG_LEN,
            &|b| PasswordSealed::decode(b).is_ok(),
        );
        check(
            "local_seal",
            &hex(LOCAL_SEAL_HEX),
            ENVELOPE_LEN + 24 + TAG_LEN,
            &|b| LocalSeal::decode(b).is_ok(),
        );
        let chat_header = hex(FILE_HEADER_CHAT_HEX);
        check("file_header_chat", &chat_header, chat_header.len(), &|b| {
            FileHeader::decode(b).is_ok()
        });
        let password_header = hex(FILE_HEADER_PASSWORD_HEX);
        check(
            "file_header_password",
            &password_header,
            password_header.len(),
            &|b| FileHeader::decode(b).is_ok(),
        );
        check("envelope", &hex("46555a5a0103"), ENVELOPE_LEN, &|b| {
            decode_envelope(b).is_ok()
        });
    }

    #[test]
    fn truncated_payloads_are_corrupt_not_unsupported() {
        let invitation = hex(INVITATION_HEX);
        assert_eq!(
            Invitation::decode(&invitation[..invitation.len() - 1]),
            Err(CoreError::Corrupt)
        );
        assert_eq!(
            Invitation::decode(&invitation[..ENVELOPE_LEN]),
            Err(CoreError::Corrupt)
        );
        let acceptance = hex(ACCEPTANCE_HEX);
        assert_eq!(
            Acceptance::decode(&acceptance[..acceptance.len() - 1]),
            Err(CoreError::Corrupt)
        );
        assert_eq!(
            Message::decode(&hex("46555a5a0103")),
            Err(CoreError::Corrupt)
        );
        let file_header = hex(FILE_HEADER_CHAT_HEX);
        assert_eq!(
            FileHeader::decode(&file_header[..file_header.len() - 1]),
            Err(CoreError::Corrupt)
        );
        let inner = hex(INNER_HEADER_HEX);
        assert_eq!(
            InnerHeader::decode(&inner[..inner.len() - 1]),
            Err(CoreError::Corrupt)
        );
    }

    #[test]
    fn trailing_bytes_are_corrupt_for_fixed_layouts() {
        for (name, blob_hex) in [
            ("invitation", INVITATION_HEX),
            ("acceptance", ACCEPTANCE_HEX),
            ("wrapped_store_key", WRAPPED_STORE_KEY_HEX),
        ] {
            let mut blob = hex(blob_hex);
            blob.push(0x00);
            let result = match name {
                "invitation" => Invitation::decode(&blob).map(drop),
                "acceptance" => Acceptance::decode(&blob).map(drop),
                _ => WrappedStoreKey::decode(&blob).map(drop),
            };
            assert_eq!(result, Err(CoreError::Corrupt), "{name}");
        }
        let mut inner = hex(INNER_HEADER_HEX);
        inner.push(0x00);
        assert_eq!(InnerHeader::decode(&inner), Err(CoreError::Corrupt));
    }

    // --- field validation --------------------------------------------------

    #[test]
    fn file_header_chunk_size_bounds() {
        let with_chunk = |chunk_size: u32| {
            FileHeader {
                chunk_size,
                ..file_header_password()
            }
            .encode()
            .unwrap()
        };
        assert!(FileHeader::decode(&with_chunk(MIN_CHUNK_SIZE)).is_ok());
        assert!(FileHeader::decode(&with_chunk(MAX_CHUNK_SIZE)).is_ok());
        assert_eq!(
            FileHeader::decode(&with_chunk(MIN_CHUNK_SIZE - 1)),
            Err(CoreError::Corrupt)
        );
        assert_eq!(
            FileHeader::decode(&with_chunk(MAX_CHUNK_SIZE + 1)),
            Err(CoreError::Corrupt)
        );
        assert_eq!(FileHeader::decode(&with_chunk(0)), Err(CoreError::Corrupt));
        assert_eq!(CHUNK_SIZE, 1_048_576);
    }

    #[test]
    fn file_header_rejects_unknown_key_mode_and_olm_type() {
        let mut bytes = hex(FILE_HEADER_PASSWORD_HEX);
        bytes[ENVELOPE_LEN] = 0x03;
        assert_eq!(FileHeader::decode(&bytes), Err(CoreError::Corrupt));
        bytes[ENVELOPE_LEN] = 0x00;
        assert_eq!(FileHeader::decode(&bytes), Err(CoreError::Corrupt));
        let mut chat = hex(FILE_HEADER_CHAT_HEX);
        chat[ENVELOPE_LEN + 1 + 4 + 19] = 0x02;
        assert_eq!(FileHeader::decode(&chat), Err(CoreError::Corrupt));
    }

    #[test]
    fn unknown_enum_bytes_are_rejected() {
        let mut message = hex(MESSAGE_HEX);
        message[ENVELOPE_LEN] = 0x02;
        assert_eq!(Message::decode(&message), Err(CoreError::Corrupt));

        let inner = hex(INNER_HEADER_HEX);
        let direction_at = 1 + 37 + 64;
        let mut bad_direction = inner.clone();
        bad_direction[direction_at] = 0x02;
        assert_eq!(InnerHeader::decode(&bad_direction), Err(CoreError::Corrupt));
        let mut bad_content = inner.clone();
        bad_content[direction_at + 1 + 8] = 0x03;
        assert_eq!(InnerHeader::decode(&bad_content), Err(CoreError::Corrupt));
        let mut bad_version = inner;
        bad_version[0] = 0x02;
        assert_eq!(
            InnerHeader::decode(&bad_version),
            Err(CoreError::UnsupportedFormat)
        );
    }

    #[test]
    fn chat_id_must_be_non_empty_utf8_and_fit_u8() {
        assert_eq!(
            Invitation {
                chat_id: String::new(),
                ..invitation()
            }
            .encode(),
            Err(CoreError::Corrupt)
        );
        assert_eq!(
            InnerHeader {
                chat_id: "x".repeat(256),
                ..inner_header()
            }
            .encode(),
            Err(CoreError::Corrupt)
        );
        let mut zero_len = hex(INVITATION_HEX);
        zero_len[ENVELOPE_LEN] = 0x00;
        assert_eq!(Invitation::decode(&zero_len), Err(CoreError::Corrupt));
        let mut bad_utf8 = hex(INVITATION_HEX);
        bad_utf8[ENVELOPE_LEN + 1] = 0xFF;
        assert_eq!(Invitation::decode(&bad_utf8), Err(CoreError::Corrupt));
        let mut bad_inner = hex(INNER_HEADER_HEX);
        bad_inner[2] = 0xFF;
        assert_eq!(InnerHeader::decode(&bad_inner), Err(CoreError::Corrupt));
    }

    #[test]
    fn empty_olm_bodies_are_rejected() {
        assert_eq!(
            Message {
                olm_body: Vec::new(),
                ..message()
            }
            .encode(),
            Err(CoreError::Corrupt)
        );
        assert_eq!(
            Message::decode(&hex("46555a5a010301")),
            Err(CoreError::Corrupt)
        );
        assert_eq!(
            Acceptance {
                prekey_msg: Vec::new(),
                ..acceptance()
            }
            .encode(),
            Err(CoreError::Corrupt)
        );
        assert_eq!(
            Acceptance {
                prekey_msg: vec![0; 65_536],
                ..acceptance()
            }
            .encode(),
            Err(CoreError::Corrupt)
        );
        let mut zero_prekey = hex(ACCEPTANCE_HEX);
        // prekey_len 0005 → 0000, then drop the five body bytes so the sig still lands at the end
        zero_prekey[ENVELOPE_LEN + 37 + 64 + 1] = 0x00;
        zero_prekey.drain(ENVELOPE_LEN + 37 + 64 + 2..ENVELOPE_LEN + 37 + 64 + 7);
        assert_eq!(Acceptance::decode(&zero_prekey), Err(CoreError::Corrupt));
        assert_eq!(
            FileHeader {
                key_mode: FileKeyMode::Chat {
                    olm_type: OlmType::Normal,
                    olm_body: Vec::new(),
                },
                ..file_header_chat()
            }
            .encode(),
            Err(CoreError::Corrupt)
        );
    }

    #[test]
    fn sealed_ciphertext_shorter_than_a_tag_is_corrupt() {
        let short_password = hex(PASSWORD_SEALED_HEX);
        let cut = short_password.len() - 5;
        assert_eq!(
            PasswordSealed::decode(&short_password[..cut]),
            Err(CoreError::Corrupt)
        );
        let exact_tag = &short_password[..short_password.len() - 4];
        assert_eq!(
            PasswordSealed::decode(exact_tag).unwrap().ciphertext.len(),
            16
        );
        let seal = hex(LOCAL_SEAL_HEX);
        assert_eq!(
            LocalSeal::decode(&seal[..seal.len() - 2]),
            Err(CoreError::Corrupt)
        );
    }
}
