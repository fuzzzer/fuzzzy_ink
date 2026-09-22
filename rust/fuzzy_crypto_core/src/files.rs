//! Chunked authenticated file encryption — the 0x04 container (plan §C).
//!
//! XChaCha20-Poly1305 in the RustCrypto STREAM construction (`aead-stream`,
//! BE32 flavour): chunk `i` is sealed under the nonce
//! `nonce_prefix 19 ‖ i u32 BE ‖ last flag u8` with the AAD
//! `header bytes ‖ i u32 BE`, so a chunk can neither be moved, duplicated,
//! dropped nor detached from its header, and a missing last chunk is a tag
//! failure rather than a short file. Every write goes to `<output>.part`, which
//! is renamed into place only after the final tag verifies and unlinked on
//! every other exit (error or cancel). One chunk is in flight at a time — a file
//! is never read into memory.
//!
//! Two key modes share the loops: password mode (`key_mode 0x02`, the file key
//! is Argon2id of a password) and chat mode (`key_mode 0x01`, a random file key
//! travels inside one Olm message embedded in the header — [`wrap_file_key`] /
//! [`unwrap_file_key`], the F2-4 message path with `content_type 0x02`). In chat
//! mode the header is the only thing that binds the key to the container: it is
//! every chunk's AAD, so a key message re-bound to another container's chunks
//! or nonce prefix fails at chunk 0.

use std::fs::{self, File};
use std::io::{Read, Seek, SeekFrom, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU8, Ordering};
use std::thread;
use std::time::Duration;

use aead_stream::{DecryptorBE32, EncryptorBE32};
use chacha20poly1305::{KeyInit, XChaCha20Poly1305};
use zeroize::Zeroizing;

use crate::error::CoreError;
use crate::formats::{
    Argon2Params, ContentType, FileHeader, FileKeyBody, FileKeyMode, CHUNK_SIZE, ENVELOPE_LEN,
};
use crate::messages;
use crate::state::ChatState;
use crate::store::{self, Key32, ARGON2_PARAMS};

/// `FileJob` control word, read before every chunk.
pub(crate) const JOB_RUNNING: u8 = 0;
/// The loop sleeps [`PAUSE_POLL`] between chunks until resumed or cancelled.
pub(crate) const JOB_PAUSED: u8 = 1;
/// Terminal: the loop unlinks `.part` and returns `Cancelled` at the next chunk.
pub(crate) const JOB_CANCELLED: u8 = 2;

/// Poly1305 tag that follows every chunk.
const TAG_LEN: usize = 16;
/// How often a paused job re-reads its control word.
const PAUSE_POLL: Duration = Duration::from_millis(50);
/// Longest header the decoder can meet: envelope · key_mode · chunk_size ·
/// nonce_prefix · the chat-mode `olm_type u8 · olm_len u16 · olm_body`.
const MAX_HEADER_LEN: usize = ENVELOPE_LEN + 1 + 4 + 19 + 1 + 2 + u16::MAX as usize;

/// Progress callback: fraction of chunks done, once per chunk.
pub(crate) type Progress<'a> = &'a mut dyn FnMut(f64);

/// The per-file values of a password-mode header. Production draws them with
/// [`FileSetup::random`]; tests pin them (and use a small chunk size).
pub(crate) struct FileSetup {
    pub(crate) chunk_size: u32,
    pub(crate) nonce_prefix: [u8; 19],
    pub(crate) salt: [u8; 16],
    pub(crate) params: Argon2Params,
}

impl FileSetup {
    /// Fresh nonce prefix and salt, [`CHUNK_SIZE`] chunks, [`ARGON2_PARAMS`].
    pub(crate) fn random() -> Result<Self, CoreError> {
        let mut nonce_prefix = [0u8; 19];
        store::fill_random(&mut nonce_prefix)?;
        let mut salt = [0u8; 16];
        store::fill_random(&mut salt)?;
        Ok(Self {
            chunk_size: CHUNK_SIZE,
            nonce_prefix,
            salt,
            params: ARGON2_PARAMS,
        })
    }

    fn header(&self) -> FileHeader {
        FileHeader {
            chunk_size: self.chunk_size,
            nonce_prefix: self.nonce_prefix,
            key_mode: FileKeyMode::Password {
                salt: self.salt,
                params: self.params,
            },
        }
    }
}

// ---------------------------------------------------------------------------
// Password mode
// ---------------------------------------------------------------------------

/// Encrypts `input` into the container at `output` under
/// `Argon2id(password, setup.salt, setup.params)`.
pub(crate) fn encrypt_with_password(
    password: &[u8],
    setup: &FileSetup,
    input: &Path,
    output: &Path,
    job: &AtomicU8,
    progress: Progress<'_>,
) -> Result<(), CoreError> {
    let key = store::derive_kek(password, &setup.salt, setup.params)?;
    encrypt_chunks(&key, &setup.header(), input, output, job, progress)
}

/// Decrypts the password-mode container at `input` to `output`. A chat-mode
/// container is `UnsupportedFormat`; a first chunk that fails to open is
/// `WrongPassword` (indistinguishable from a corrupt first chunk — the password
/// is the only input the user controls); any later failure is `Corrupt`.
pub(crate) fn decrypt_with_password(
    password: &[u8],
    input: &Path,
    output: &Path,
    job: &AtomicU8,
    progress: Progress<'_>,
) -> Result<(), CoreError> {
    let key_for = |header: &FileHeader| match &header.key_mode {
        FileKeyMode::Password { salt, params } => store::derive_kek(password, salt, *params),
        FileKeyMode::Chat { .. } => Err(CoreError::UnsupportedFormat),
    };
    decrypt_chunks(
        input,
        output,
        job,
        progress,
        key_for,
        CoreError::WrongPassword,
    )
}

/// Password-mode container under a caller-supplied key — the benchmark path
/// (`examples/bench_file.rs`, F3-4's in-app bench), which skips Argon2id. The
/// header still carries a fresh salt and [`ARGON2_PARAMS`], so the bytes are a
/// valid container that no password opens.
#[doc(hidden)]
pub fn encrypt_with_key(key: &[u8; 32], input: &Path, output: &Path) -> Result<(), CoreError> {
    let setup = FileSetup::random()?;
    let job = AtomicU8::new(JOB_RUNNING);
    encrypt_chunks(key, &setup.header(), input, output, &job, &mut |_| {})
}

/// Inverse of [`encrypt_with_key`]; the header's salt and params are ignored.
#[doc(hidden)]
pub fn decrypt_with_key(key: &[u8; 32], input: &Path, output: &Path) -> Result<(), CoreError> {
    let job = AtomicU8::new(JOB_RUNNING);
    decrypt_chunks(
        input,
        output,
        &job,
        &mut |_| {},
        |_| Ok(Zeroizing::new(*key)),
        CoreError::Corrupt,
    )
}

// ---------------------------------------------------------------------------
// Chat mode — the file key rides in one Olm message inside the header
// ---------------------------------------------------------------------------

/// The per-file values of a chat-mode header. Production draws them with
/// [`ChatFileSetup::random`]; tests pin them (and use a small chunk size).
pub(crate) struct ChatFileSetup {
    pub(crate) chunk_size: u32,
    pub(crate) nonce_prefix: [u8; 19],
}

impl ChatFileSetup {
    /// A fresh nonce prefix and [`CHUNK_SIZE`] chunks.
    pub(crate) fn random() -> Result<Self, CoreError> {
        Ok(Self {
            chunk_size: CHUNK_SIZE,
            nonce_prefix: store::random_array()?,
        })
    }
}

/// The send side's Olm step (the whole of it runs under the core lock): draws
/// a random file key, seals `file_key ‖ original_name` into one Olm message on
/// the chat's session with the next send counter — exactly like a text
/// message, `content_type 0x02` — and returns the key with the complete header
/// that embeds the message. The ratchet and counter are committed to `state`;
/// the caller persists before the key leaves this layer. An encoded header
/// that would not fit (`olm_len u16`) fails here, before anything is committed.
pub(crate) fn wrap_file_key(
    state: &mut ChatState,
    original_name: &str,
    setup: &ChatFileSetup,
) -> Result<(Key32, FileHeader), CoreError> {
    validate_original_name(original_name)?;
    let body = FileKeyBody {
        file_key: Zeroizing::new(store::random_array()?),
        original_name: original_name.to_owned(),
    };
    let encoded = body.encode()?;
    let message = messages::encrypt_payload(state, ContentType::FileKeyEnvelope, &encoded)?;
    let header = FileHeader {
        chunk_size: setup.chunk_size,
        nonce_prefix: setup.nonce_prefix,
        key_mode: FileKeyMode::Chat {
            olm_type: message.olm_type,
            olm_body: message.olm_body,
        },
    };
    header.encode()?;
    Ok((body.file_key, header))
}

/// The receive side's Olm step: opens the Olm message embedded in `header`
/// through the same chain as a text message — Olm decrypt (`Replay`, `TooOld`,
/// `Corrupt`), the inner-header binding (`WrongChat`, `Corrupt`), the counter
/// window — and returns the file key with the original name. A password-mode
/// header is `UnsupportedFormat`. Nothing is committed to `state` unless every
/// check passed; the caller persists before the key leaves this layer.
pub(crate) fn unwrap_file_key(
    state: &mut ChatState,
    header: &FileHeader,
) -> Result<(Key32, String), CoreError> {
    let FileKeyMode::Chat { olm_type, olm_body } = &header.key_mode else {
        return Err(CoreError::UnsupportedFormat);
    };
    let body = messages::decrypt_payload(
        state,
        *olm_type,
        olm_body,
        ContentType::FileKeyEnvelope,
        |body| {
            let body = Zeroizing::new(body);
            let body = FileKeyBody::decode(&body)?;
            validate_original_name(&body.original_name)?;
            Ok(body)
        },
    )?;
    Ok((body.file_key, body.original_name))
}

/// Reads and decodes the header of the container at `input` — everything the
/// receive side needs for its Olm step, without touching a chunk. The body is
/// checked structurally here too (at least one tag, a last chunk no shorter
/// than a tag), so a header-only or truncated container — an incomplete
/// transfer — is `Corrupt` before the Olm step spends the file's message.
/// A directory is `Io`.
pub(crate) fn peek_header(input: &Path) -> Result<FileHeader, CoreError> {
    let mut reader = File::open(input).map_err(|_| CoreError::Io)?;
    let metadata = reader.metadata().map_err(|_| CoreError::Io)?;
    if !metadata.is_file() {
        return Err(CoreError::Io);
    }
    let (header, header_bytes) = read_header(&mut reader, metadata.len())?;
    chunk_layout(metadata.len(), header_bytes.len(), header.chunk_size)?;
    Ok(header)
}

/// Longest original name (NAME_MAX on every target; the sender derives it from
/// a real basename, so nothing legitimate is lost).
const MAX_ORIGINAL_NAME_LEN: usize = 255;

/// The original name is a file *name*, never a path: a peer's name lands in
/// the receiver's output path (F3-3), so a separator, NUL, `.` or `..` is
/// `Corrupt` on both sides — the sender only ever derives it from a basename.
/// It is also bounded to [`MAX_ORIGINAL_NAME_LEN`] bytes and free of control
/// characters, so a name the OS would refuse (or one that hides a newline)
/// never gets as far as spending the receiver's ratchet step.
fn validate_original_name(name: &str) -> Result<(), CoreError> {
    if name.is_empty()
        || name == "."
        || name == ".."
        || name.len() > MAX_ORIGINAL_NAME_LEN
        || name
            .bytes()
            .any(|byte| matches!(byte, b'/' | b'\\' | 0x00..=0x1f | 0x7f))
    {
        return Err(CoreError::Corrupt);
    }
    Ok(())
}

// ---------------------------------------------------------------------------
// The STREAM loops (key-mode agnostic: a password-derived or an Olm-wrapped key)
// ---------------------------------------------------------------------------

/// Writes `header` then one sealed chunk per `chunk_size` bytes of `input`
/// (`encrypt_next` for all but the last, `encrypt_last` for the last — an empty
/// file is one `encrypt_last` over 0 bytes) to `<output>.part`, then renames.
pub(crate) fn encrypt_chunks(
    key: &[u8; 32],
    header: &FileHeader,
    input: &Path,
    output: &Path,
    job: &AtomicU8,
    progress: Progress<'_>,
) -> Result<(), CoreError> {
    let header_bytes = header.encode()?;
    let chunk_size = u64::from(header.chunk_size);
    let mut reader = File::open(input).map_err(|_| CoreError::Io)?;
    let input_len = reader.metadata().map_err(|_| CoreError::Io)?.len();
    let chunks = input_len.div_ceil(chunk_size).max(1);
    let last_len = input_len - (chunks - 1) * chunk_size;
    let (mut aad, mut buffer) = chunk_buffers(&header_bytes, header.chunk_size)?;
    let mut stream = Some(EncryptorBE32::from_aead(
        XChaCha20Poly1305::new(key.into()),
        &header.nonce_prefix.into(),
    ));

    let mut part = PartFile::create(output)?;
    part.write(&header_bytes)?;
    for index in 0..chunks {
        check_job(job)?;
        let last = index + 1 == chunks;
        let len = if last { last_len } else { chunk_size };
        read_chunk(&mut reader, &mut buffer, len)?;
        let aad = aad.for_chunk(index)?;
        let sealed = if last {
            stream
                .take()
                .ok_or(CoreError::Internal)?
                .encrypt_last_in_place(aad, &mut *buffer)
        } else {
            stream
                .as_mut()
                .ok_or(CoreError::Internal)?
                .encrypt_next_in_place(aad, &mut *buffer)
        };
        sealed.map_err(|_| CoreError::Internal)?;
        part.write(&buffer)?;
        progress(fraction(index + 1, chunks));
    }
    part.commit(output)
}

/// Parses the header, derives the key with `key_for`, then opens every chunk
/// (`decrypt_next` on chunks `0..n-1`, `decrypt_last` on chunk `n-1`, where
/// `n = ceil(body_len / (chunk_size + 16))`) and writes each plaintext to
/// `<output>.part` only after its tag verified. A tag failure on chunk 0 is
/// `first_chunk_failure`, on any later chunk `Corrupt`; the `.part` is gone
/// either way. Structural faults (short body, chunk size out of range) are
/// `Corrupt` before anything is created.
pub(crate) fn decrypt_chunks(
    input: &Path,
    output: &Path,
    job: &AtomicU8,
    progress: Progress<'_>,
    key_for: impl FnOnce(&FileHeader) -> Result<Key32, CoreError>,
    first_chunk_failure: CoreError,
) -> Result<(), CoreError> {
    let mut reader = File::open(input).map_err(|_| CoreError::Io)?;
    let file_len = reader.metadata().map_err(|_| CoreError::Io)?.len();
    let (header, header_bytes) = read_header(&mut reader, file_len)?;
    let key = key_for(&header)?;

    let sealed_len = u64::from(header.chunk_size) + TAG_LEN as u64;
    let (chunks, last_len) = chunk_layout(file_len, header_bytes.len(), header.chunk_size)?;
    let (mut aad, mut buffer) = chunk_buffers(&header_bytes, header.chunk_size)?;
    let mut stream = Some(DecryptorBE32::from_aead(
        XChaCha20Poly1305::new((&*key).into()),
        &header.nonce_prefix.into(),
    ));
    reader
        .seek(SeekFrom::Start(header_bytes.len() as u64))
        .map_err(|_| CoreError::Io)?;

    let mut part = PartFile::create(output)?;
    for index in 0..chunks {
        check_job(job)?;
        let last = index + 1 == chunks;
        let len = if last { last_len } else { sealed_len };
        read_chunk(&mut reader, &mut buffer, len)?;
        let aad = aad.for_chunk(index)?;
        let opened = if last {
            stream
                .take()
                .ok_or(CoreError::Internal)?
                .decrypt_last_in_place(aad, &mut *buffer)
        } else {
            stream
                .as_mut()
                .ok_or(CoreError::Internal)?
                .decrypt_next_in_place(aad, &mut *buffer)
        };
        opened.map_err(|_| {
            if index == 0 {
                first_chunk_failure.clone()
            } else {
                CoreError::Corrupt
            }
        })?;
        // Only reached once the tag verified: the buffer now holds plaintext.
        part.write(&buffer)?;
        progress(fraction(index + 1, chunks));
    }
    part.commit(output)
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Reads the longest possible header prefix and decodes it; returns the header
/// and its exact bytes (the chunks' AAD).
fn read_header(reader: &mut File, file_len: u64) -> Result<(FileHeader, Vec<u8>), CoreError> {
    let prefix_len =
        usize::try_from(file_len.min(MAX_HEADER_LEN as u64)).map_err(|_| CoreError::Internal)?;
    let mut prefix = vec![0u8; prefix_len];
    reader.read_exact(&mut prefix).map_err(|_| CoreError::Io)?;
    let (header, header_len) = FileHeader::decode(&prefix)?;
    prefix.truncate(header_len);
    Ok((header, prefix))
}

/// `(chunks, last sealed chunk length)` of a container body of
/// `file_len - header_len` bytes: `Corrupt` when the body is shorter than one
/// tag or its last chunk would be (a header-only or truncated container).
fn chunk_layout(
    file_len: u64,
    header_len: usize,
    chunk_size: u32,
) -> Result<(u64, u64), CoreError> {
    let sealed_len = u64::from(chunk_size) + TAG_LEN as u64;
    let body_len = file_len
        .checked_sub(header_len as u64)
        .filter(|body| *body >= TAG_LEN as u64)
        .ok_or(CoreError::Corrupt)?;
    let chunks = body_len.div_ceil(sealed_len);
    let last_len = body_len - (chunks - 1) * sealed_len;
    if last_len < TAG_LEN as u64 {
        return Err(CoreError::Corrupt);
    }
    Ok((chunks, last_len))
}

/// The AAD scratch and the one chunk buffer (`chunk_size + tag`, wiped on drop).
fn chunk_buffers(
    header_bytes: &[u8],
    chunk_size: u32,
) -> Result<(ChunkAad, Zeroizing<Vec<u8>>), CoreError> {
    let capacity = usize::try_from(chunk_size).map_err(|_| CoreError::Internal)? + TAG_LEN;
    Ok((
        ChunkAad::new(header_bytes),
        Zeroizing::new(Vec::with_capacity(capacity)),
    ))
}

/// Fills `buffer` with exactly `len` bytes from `reader`; a short read (the
/// input changed underneath us) is `Io`.
fn read_chunk(reader: &mut File, buffer: &mut Vec<u8>, len: u64) -> Result<(), CoreError> {
    buffer.clear();
    buffer.resize(usize::try_from(len).map_err(|_| CoreError::Internal)?, 0);
    reader.read_exact(buffer).map_err(|_| CoreError::Io)
}

fn fraction(done: u64, total: u64) -> f64 {
    done as f64 / total as f64
}

/// Blocks while the job is paused; `Cancelled` once it is cancelled.
fn check_job(job: &AtomicU8) -> Result<(), CoreError> {
    loop {
        match job.load(Ordering::Acquire) {
            JOB_CANCELLED => return Err(CoreError::Cancelled),
            JOB_PAUSED => thread::sleep(PAUSE_POLL),
            _ => return Ok(()),
        }
    }
}

/// `header bytes ‖ chunk index u32 BE`, rebuilt in place per chunk.
struct ChunkAad {
    bytes: Vec<u8>,
    header_len: usize,
}

impl ChunkAad {
    fn new(header_bytes: &[u8]) -> Self {
        let mut bytes = Vec::with_capacity(header_bytes.len() + 4);
        bytes.extend_from_slice(header_bytes);
        Self {
            bytes,
            header_len: header_bytes.len(),
        }
    }

    fn for_chunk(&mut self, index: u64) -> Result<&[u8], CoreError> {
        let index = u32::try_from(index).map_err(|_| CoreError::Corrupt)?;
        self.bytes.truncate(self.header_len);
        self.bytes.extend_from_slice(&index.to_be_bytes());
        Ok(&self.bytes)
    }
}

/// `<output>.part` — the only file the loops write. Unless [`PartFile::commit`]
/// renamed it into place, dropping it (any `?` on the way out, a cancel, a
/// panic) unlinks it, so a failed job never leaves plaintext or a half
/// container behind.
struct PartFile {
    path: PathBuf,
    file: Option<File>,
    armed: bool,
}

impl PartFile {
    fn create(output: &Path) -> Result<Self, CoreError> {
        let mut path = output.as_os_str().to_owned();
        path.push(".part");
        let path = PathBuf::from(path);
        let file = store::create_tmp(&path).map_err(|_| CoreError::Io)?;
        Ok(Self {
            path,
            file: Some(file),
            armed: true,
        })
    }

    fn write(&mut self, bytes: &[u8]) -> Result<(), CoreError> {
        self.file
            .as_mut()
            .ok_or(CoreError::Internal)?
            .write_all(bytes)
            .map_err(|_| CoreError::Io)
    }

    /// fsync → close → rename over `output`. On failure the `.part` is unlinked by drop.
    fn commit(mut self, output: &Path) -> Result<(), CoreError> {
        let file = self.file.take().ok_or(CoreError::Internal)?;
        file.sync_all().map_err(|_| CoreError::Io)?;
        drop(file);
        fs::rename(&self.path, output).map_err(|_| CoreError::Io)?;
        self.armed = false;
        Ok(())
    }
}

impl Drop for PartFile {
    fn drop(&mut self) {
        self.file.take();
        if self.armed {
            let _ = fs::remove_file(&self.path);
        }
    }
}

#[cfg(test)]
mod tests {
    use std::path::PathBuf;
    use std::sync::atomic::AtomicU8;
    use std::sync::Arc;
    use std::time::{Duration, Instant};

    use super::*;
    use crate::formats::MIN_CHUNK_SIZE;
    use crate::store::test_support::temp_dir;

    const PASSWORD: &[u8] = b"correct horse";
    const NONCE_PREFIX: [u8; 19] = [
        0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0x9b, 0x9c, 0x9d, 0x9e,
        0x9f, 0xa0, 0xa1, 0xa2,
    ];
    const SALT: [u8; 16] = [
        0xa0, 0xa1, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xab, 0xac, 0xad, 0xae,
        0xaf,
    ];
    /// Cheap Argon2id for the tests that only need *a* key (8 MiB, one pass).
    const FAST_PARAMS: Argon2Params = Argon2Params {
        m_cost: 8 * 1024,
        t_cost: 1,
        p_cost: 1,
    };
    const SMALL_CHUNK: u32 = MIN_CHUNK_SIZE;
    const SEALED_SMALL: usize = SMALL_CHUNK as usize + TAG_LEN;
    const HEADER_LEN: usize = 55;

    /// Pinned salt/prefix, 64 KiB chunks, fast KDF — every test but the golden ones.
    fn small_setup() -> FileSetup {
        FileSetup {
            chunk_size: SMALL_CHUNK,
            nonce_prefix: NONCE_PREFIX,
            salt: SALT,
            params: FAST_PARAMS,
        }
    }

    /// Deterministic non-repeating bytes (xorshift) so a misplaced chunk never
    /// happens to equal another.
    fn pattern(len: usize) -> Vec<u8> {
        let mut state: u64 = 0x9E37_79B9_7F4A_7C15;
        (0..len)
            .map(|_| {
                state ^= state << 13;
                state ^= state >> 7;
                state ^= state << 17;
                state as u8
            })
            .collect()
    }

    struct Files {
        dir: PathBuf,
        plain: PathBuf,
        sealed: PathBuf,
        opened: PathBuf,
    }

    impl Files {
        fn with_plaintext(bytes: &[u8]) -> Self {
            let dir = temp_dir();
            let files = Self {
                plain: dir.join("plain.bin"),
                sealed: dir.join("sealed.fuzz"),
                opened: dir.join("opened.bin"),
                dir,
            };
            fs::write(&files.plain, bytes).unwrap();
            files
        }

        fn part_of(path: &Path) -> PathBuf {
            let mut part = path.as_os_str().to_owned();
            part.push(".part");
            PathBuf::from(part)
        }

        fn assert_no_output(&self) {
            assert!(!self.opened.exists(), "output must be absent");
            assert!(!Self::part_of(&self.opened).exists(), ".part must be gone");
        }

        fn entries(&self) -> Vec<String> {
            let mut names: Vec<String> = fs::read_dir(&self.dir)
                .unwrap()
                .map(|entry| entry.unwrap().file_name().to_string_lossy().into_owned())
                .collect();
            names.sort();
            names
        }
    }

    impl Drop for Files {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.dir);
        }
    }

    fn running() -> AtomicU8 {
        AtomicU8::new(JOB_RUNNING)
    }

    fn encrypt(files: &Files, setup: &FileSetup) -> Vec<f64> {
        let mut events = Vec::new();
        encrypt_with_password(
            PASSWORD,
            setup,
            &files.plain,
            &files.sealed,
            &running(),
            &mut |p| events.push(p),
        )
        .unwrap();
        assert!(!Files::part_of(&files.sealed).exists());
        events
    }

    fn decrypt(files: &Files, password: &[u8]) -> Result<Vec<f64>, CoreError> {
        let mut events = Vec::new();
        decrypt_with_password(
            password,
            &files.sealed,
            &files.opened,
            &running(),
            &mut |p| events.push(p),
        )?;
        Ok(events)
    }

    fn round_trip(len: usize, setup: &FileSetup) -> (Vec<f64>, Vec<f64>) {
        let plaintext = pattern(len);
        let files = Files::with_plaintext(&plaintext);
        let encrypt_events = encrypt(&files, setup);
        let sealed = fs::read(&files.sealed).unwrap();
        let chunks = len.div_ceil(setup.chunk_size as usize).max(1);
        assert_eq!(sealed.len(), HEADER_LEN + len + chunks * TAG_LEN);
        let decrypt_events = decrypt(&files, PASSWORD).unwrap();
        assert_eq!(fs::read(&files.opened).unwrap(), plaintext);
        assert!(!Files::part_of(&files.opened).exists());
        assert_eq!(encrypt_events.len(), chunks);
        assert_eq!(decrypt_events.len(), chunks);
        (encrypt_events, decrypt_events)
    }

    /// Flips one byte of the sealed file at `offset`, or truncates/extends it.
    fn edit_sealed(files: &Files, edit: impl FnOnce(&mut Vec<u8>)) {
        let mut sealed = fs::read(&files.sealed).unwrap();
        edit(&mut sealed);
        fs::write(&files.sealed, sealed).unwrap();
    }

    // --- round trips -------------------------------------------------------

    #[test]
    fn round_trip_empty() {
        let (encrypt_events, decrypt_events) = round_trip(0, &small_setup());
        assert_eq!(encrypt_events, [1.0]);
        assert_eq!(decrypt_events, [1.0]);
    }

    #[test]
    fn round_trip_1_byte() {
        round_trip(1, &small_setup());
    }

    #[test]
    fn round_trip_exact_chunk() {
        // The real 1 MiB chunk size: one full chunk sealed with the last flag.
        let setup = FileSetup {
            chunk_size: CHUNK_SIZE,
            ..small_setup()
        };
        let (events, _) = round_trip(CHUNK_SIZE as usize, &setup);
        assert_eq!(events, [1.0]);
    }

    #[test]
    fn round_trip_multi_chunk() {
        // 2.5 MiB at the real chunk size: two full chunks and a half one.
        let setup = FileSetup {
            chunk_size: CHUNK_SIZE,
            ..small_setup()
        };
        let (events, _) = round_trip(CHUNK_SIZE as usize * 5 / 2, &setup);
        assert_eq!(events.len(), 3);
    }

    #[test]
    fn round_trip_chunk_boundary_plus_one() {
        round_trip(SMALL_CHUNK as usize + 1, &small_setup());
        round_trip(SMALL_CHUNK as usize * 2, &small_setup());
    }

    #[test]
    fn round_trip_with_fixed_key() {
        let plaintext = pattern(SMALL_CHUNK as usize * 3 + 7);
        let files = Files::with_plaintext(&plaintext);
        let key = [0x42u8; 32];
        encrypt_with_key(&key, &files.plain, &files.sealed).unwrap();
        decrypt_with_key(&key, &files.sealed, &files.opened).unwrap();
        assert_eq!(fs::read(&files.opened).unwrap(), plaintext);
        // A fixed-key container is a valid password-mode container that no
        // password opens (the header's salt/params are real, the key is not).
        assert_eq!(
            decrypt(&files, PASSWORD).unwrap_err(),
            CoreError::WrongPassword
        );
        assert_eq!(
            decrypt_with_key(&[0x43u8; 32], &files.sealed, &files.opened).unwrap_err(),
            CoreError::Corrupt
        );
    }

    // --- tampering ---------------------------------------------------------

    #[test]
    fn tamper_one_byte_mid_file_no_plaintext_written() {
        // Three chunks; flip a byte in the middle of chunk 1.
        let files = Files::with_plaintext(&pattern(SMALL_CHUNK as usize * 5 / 2));
        encrypt(&files, &small_setup());
        edit_sealed(&files, |sealed| {
            sealed[HEADER_LEN + SEALED_SMALL + 100] ^= 0x01
        });

        assert_eq!(decrypt(&files, PASSWORD).unwrap_err(), CoreError::Corrupt);
        files.assert_no_output();
    }

    #[test]
    fn tamper_leaves_no_partial_output() {
        // Every chunk of a 4-chunk file, ciphertext byte and tag byte alike:
        // no output path exists afterwards, whichever chunk was hit.
        let len = SMALL_CHUNK as usize * 3 + 1234;
        let files = Files::with_plaintext(&pattern(len));
        encrypt(&files, &small_setup());
        let pristine = fs::read(&files.sealed).unwrap();
        let chunk_starts = [
            HEADER_LEN,
            HEADER_LEN + SEALED_SMALL,
            HEADER_LEN + 2 * SEALED_SMALL,
            HEADER_LEN + 3 * SEALED_SMALL,
        ];
        for (chunk, start) in chunk_starts.into_iter().enumerate() {
            let last_tag_byte = if chunk == 3 {
                pristine.len() - 1
            } else {
                start + SEALED_SMALL - 1
            };
            for offset in [start, start + 17, last_tag_byte] {
                fs::write(&files.sealed, &pristine).unwrap();
                edit_sealed(&files, |sealed| sealed[offset] ^= 0x80);
                let expected = if chunk == 0 {
                    CoreError::WrongPassword
                } else {
                    CoreError::Corrupt
                };
                assert_eq!(
                    decrypt(&files, PASSWORD).unwrap_err(),
                    expected,
                    "chunk {chunk} @{offset}"
                );
                files.assert_no_output();
            }
        }
        // A byte of the header (the AAD) breaks chunk 0 as well.
        fs::write(&files.sealed, &pristine).unwrap();
        edit_sealed(&files, |sealed| sealed[HEADER_LEN - 1] ^= 0x01);
        assert!(decrypt(&files, PASSWORD).is_err());
        files.assert_no_output();
    }

    #[test]
    fn truncated_mid_chunk_detected() {
        let files = Files::with_plaintext(&pattern(SMALL_CHUNK as usize * 5 / 2));
        encrypt(&files, &small_setup());
        // Cut inside the last chunk, leaving more than a tag.
        edit_sealed(&files, |sealed| {
            sealed.truncate(HEADER_LEN + 2 * SEALED_SMALL + 1000)
        });
        assert_eq!(decrypt(&files, PASSWORD).unwrap_err(), CoreError::Corrupt);
        files.assert_no_output();

        // Cut inside chunk 1 — the file now ends with a partial chunk 1.
        encrypt(&files, &small_setup());
        edit_sealed(&files, |sealed| {
            sealed.truncate(HEADER_LEN + SEALED_SMALL + 40)
        });
        assert_eq!(decrypt(&files, PASSWORD).unwrap_err(), CoreError::Corrupt);
        files.assert_no_output();
    }

    #[test]
    fn truncated_at_boundary_detected() {
        let files = Files::with_plaintext(&pattern(SMALL_CHUNK as usize * 5 / 2));
        encrypt(&files, &small_setup());
        // Drop the whole last chunk: chunk 1 was sealed with last flag 0, so
        // `decrypt_last` on it fails.
        edit_sealed(&files, |sealed| {
            sealed.truncate(HEADER_LEN + 2 * SEALED_SMALL)
        });
        assert_eq!(decrypt(&files, PASSWORD).unwrap_err(), CoreError::Corrupt);
        files.assert_no_output();

        // Header only, and header + less than a tag: rejected before any write.
        for keep in [HEADER_LEN, HEADER_LEN + TAG_LEN - 1] {
            encrypt(&files, &small_setup());
            edit_sealed(&files, |sealed| sealed.truncate(keep));
            assert_eq!(decrypt(&files, PASSWORD).unwrap_err(), CoreError::Corrupt);
            files.assert_no_output();
        }
    }

    #[test]
    fn peek_header_rejects_short_bodies_and_directories() {
        // The structural check of `decrypt_chunks` runs at peek time too, so
        // an incomplete transfer is `Corrupt` before any Olm step is spent.
        let files = Files::with_plaintext(&pattern(SMALL_CHUNK as usize * 5 / 2));
        encrypt(&files, &small_setup());
        let pristine = fs::read(&files.sealed).unwrap();
        assert!(peek_header(&files.sealed).is_ok());

        // Header only, header + less than a tag, and a last chunk shorter
        // than a tag (whole chunks + 15 bytes): all `Corrupt`.
        for keep in [
            HEADER_LEN,
            HEADER_LEN + TAG_LEN - 1,
            HEADER_LEN + 2 * SEALED_SMALL + TAG_LEN - 1,
        ] {
            fs::write(&files.sealed, &pristine[..keep]).unwrap();
            assert_eq!(
                peek_header(&files.sealed).unwrap_err(),
                CoreError::Corrupt,
                "kept {keep}"
            );
        }
        // Whole chunks + exactly one tag is structurally fine (an empty last
        // chunk); only the tag itself can reject it, later.
        fs::write(
            &files.sealed,
            &pristine[..HEADER_LEN + 2 * SEALED_SMALL + TAG_LEN],
        )
        .unwrap();
        assert!(peek_header(&files.sealed).is_ok());

        // A directory opens on unix but is never a container.
        assert_eq!(peek_header(&files.dir).unwrap_err(), CoreError::Io);
        // The check reads only the header: a still-unopened container is intact.
        fs::write(&files.sealed, &pristine).unwrap();
        decrypt(&files, PASSWORD).unwrap();
    }

    #[test]
    fn original_name_is_bounded_and_free_of_control_characters() {
        let ok = |name: &str| assert!(validate_original_name(name).is_ok(), "{name:?}");
        let bad = |name: &str| {
            assert_eq!(
                validate_original_name(name).unwrap_err(),
                CoreError::Corrupt,
                "{name:?}"
            )
        };
        ok("report.pdf");
        ok(&"a".repeat(MAX_ORIGINAL_NAME_LEN));
        ok("ანგარიში 2026.pdf");
        ok("\u{202e}gnp.exe"); // not display-safe, but a name the OS accepts
        bad(&"a".repeat(MAX_ORIGINAL_NAME_LEN + 1));
        bad(&"ა".repeat(MAX_ORIGINAL_NAME_LEN / 3 + 1)); // bytes, not chars
        bad("a\nb");
        bad("a\tb");
        bad("a\x7fb");
        bad("\x01");
        // The pre-existing rejections still hold.
        for name in ["", ".", "..", "a/b", "a\\b", "a\0b"] {
            bad(name);
        }
    }

    #[test]
    fn appended_bytes_detected() {
        let files = Files::with_plaintext(&pattern(SMALL_CHUNK as usize * 5 / 2));
        encrypt(&files, &small_setup());
        let pristine = fs::read(&files.sealed).unwrap();
        // A few bytes, exactly one tag, a whole extra chunk: the true last chunk
        // was sealed with last flag 1, so `decrypt_next` on it fails first.
        for extra in [5usize, TAG_LEN, SEALED_SMALL] {
            fs::write(&files.sealed, &pristine).unwrap();
            edit_sealed(&files, |sealed| {
                sealed.extend(std::iter::repeat_n(0xAB, extra))
            });
            assert_eq!(
                decrypt(&files, PASSWORD).unwrap_err(),
                CoreError::Corrupt,
                "+{extra}"
            );
            files.assert_no_output();
        }
    }

    #[test]
    fn reordered_or_duplicated_chunks_detected() {
        let files = Files::with_plaintext(&pattern(SMALL_CHUNK as usize * 3));
        encrypt(&files, &small_setup());
        let pristine = fs::read(&files.sealed).unwrap();
        let chunk = |i: usize| {
            pristine[HEADER_LEN + i * SEALED_SMALL..HEADER_LEN + (i + 1) * SEALED_SMALL].to_vec()
        };

        // Swap chunks 0 and 1: the index in the nonce and AAD no longer matches.
        edit_sealed(&files, |sealed| {
            sealed.truncate(HEADER_LEN);
            sealed.extend(chunk(1));
            sealed.extend(chunk(0));
            sealed.extend(chunk(2));
        });
        assert_eq!(
            decrypt(&files, PASSWORD).unwrap_err(),
            CoreError::WrongPassword
        );
        files.assert_no_output();

        // Duplicate chunk 1 in place of chunk 2.
        edit_sealed(&files, |sealed| {
            sealed.truncate(HEADER_LEN);
            sealed.extend(chunk(0));
            sealed.extend(chunk(1));
            sealed.extend(chunk(1));
        });
        assert_eq!(decrypt(&files, PASSWORD).unwrap_err(), CoreError::Corrupt);
        files.assert_no_output();
    }

    #[test]
    fn wrong_password_rejected() {
        let files = Files::with_plaintext(&pattern(SMALL_CHUNK as usize + 10));
        encrypt(&files, &small_setup());
        assert_eq!(
            decrypt(&files, b"wrong").unwrap_err(),
            CoreError::WrongPassword
        );
        assert_eq!(decrypt(&files, b"").unwrap_err(), CoreError::WrongPassword);
        files.assert_no_output();
        assert!(decrypt(&files, PASSWORD).is_ok());
    }

    #[test]
    fn chat_mode_header_is_unsupported_for_password_decrypt() {
        let files = Files::with_plaintext(b"");
        let header = FileHeader {
            chunk_size: SMALL_CHUNK,
            nonce_prefix: NONCE_PREFIX,
            key_mode: FileKeyMode::Chat {
                olm_type: crate::formats::OlmType::Normal,
                olm_body: vec![0xF1, 0xF2, 0xF3],
            },
        };
        let mut sealed = header.encode().unwrap();
        sealed.extend([0u8; 40]);
        fs::write(&files.sealed, sealed).unwrap();
        assert_eq!(
            decrypt(&files, PASSWORD).unwrap_err(),
            CoreError::UnsupportedFormat
        );
        files.assert_no_output();
    }

    #[test]
    fn chunk_size_out_of_range_rejected() {
        let files = Files::with_plaintext(&pattern(100));
        encrypt(&files, &small_setup());
        // chunk_size sits at bytes 7..11 of the header.
        for bad in [MIN_CHUNK_SIZE - 1, 0, crate::formats::MAX_CHUNK_SIZE + 1] {
            edit_sealed(&files, |sealed| {
                sealed[7..11].copy_from_slice(&bad.to_be_bytes())
            });
            assert_eq!(
                decrypt(&files, PASSWORD).unwrap_err(),
                CoreError::Corrupt,
                "{bad}"
            );
            files.assert_no_output();
        }
        // In range but not the size the file was written with: chunk 0 misparses.
        edit_sealed(&files, |sealed| {
            sealed[7..11].copy_from_slice(&(SMALL_CHUNK * 2).to_be_bytes())
        });
        assert_eq!(
            decrypt(&files, PASSWORD).unwrap_err(),
            CoreError::WrongPassword
        );
        files.assert_no_output();
    }

    #[test]
    fn oversized_argon2_params_rejected_before_any_write() {
        let files = Files::with_plaintext(&pattern(100));
        encrypt(&files, &small_setup());
        // m_cost sits at bytes 46..50 of the password header.
        edit_sealed(&files, |sealed| {
            sealed[46..50].copy_from_slice(&u32::MAX.to_be_bytes())
        });
        assert_eq!(decrypt(&files, PASSWORD).unwrap_err(), CoreError::Corrupt);
        files.assert_no_output();
        assert_eq!(files.entries(), ["plain.bin", "sealed.fuzz"]);
    }

    #[test]
    fn unreadable_input_is_io_and_creates_nothing() {
        let files = Files::with_plaintext(b"x");
        let missing = files.dir.join("missing.bin");
        let mut events = Vec::new();
        let result = encrypt_with_password(
            PASSWORD,
            &small_setup(),
            &missing,
            &files.sealed,
            &running(),
            &mut |p| events.push(p),
        );
        assert_eq!(result.unwrap_err(), CoreError::Io);
        assert!(!files.sealed.exists());
        assert!(!Files::part_of(&files.sealed).exists());
        assert!(events.is_empty());
        assert_eq!(
            decrypt_with_password(PASSWORD, &missing, &files.opened, &running(), &mut |_| {})
                .unwrap_err(),
            CoreError::Io
        );
        files.assert_no_output();
    }

    // --- job control -------------------------------------------------------

    #[test]
    fn cancel_deletes_part() {
        let files = Files::with_plaintext(&pattern(SMALL_CHUNK as usize * 5));
        let job = running();
        let mut events = Vec::new();
        let result = encrypt_with_password(
            PASSWORD,
            &small_setup(),
            &files.plain,
            &files.sealed,
            &job,
            &mut |p| {
                events.push(p);
                job.store(JOB_CANCELLED, Ordering::Release);
            },
        );
        assert_eq!(result.unwrap_err(), CoreError::Cancelled);
        assert_eq!(events, [0.2], "cancelled after chunk 0 of 5");
        assert!(!files.sealed.exists());
        assert!(!Files::part_of(&files.sealed).exists());

        // The same on the decrypt side.
        encrypt(&files, &small_setup());
        let job = running();
        let mut events = Vec::new();
        let result =
            decrypt_with_password(PASSWORD, &files.sealed, &files.opened, &job, &mut |p| {
                events.push(p);
                job.store(JOB_CANCELLED, Ordering::Release);
            });
        assert_eq!(result.unwrap_err(), CoreError::Cancelled);
        assert_eq!(events, [0.2]);
        files.assert_no_output();

        // Cancelled before the first chunk: nothing is ever created.
        let job = AtomicU8::new(JOB_CANCELLED);
        let result =
            decrypt_with_password(PASSWORD, &files.sealed, &files.opened, &job, &mut |_| {});
        assert_eq!(result.unwrap_err(), CoreError::Cancelled);
        files.assert_no_output();
    }

    #[test]
    fn pause_resumes_at_the_chunk_boundary() {
        let files = Files::with_plaintext(&pattern(SMALL_CHUNK as usize * 4));
        let job = Arc::new(running());
        let mut events = Vec::new();
        let resumer = Arc::clone(&job);
        let started = Instant::now();
        let mut resumed_at = None;
        let result = encrypt_with_password(
            PASSWORD,
            &small_setup(),
            &files.plain,
            &files.sealed,
            &job,
            &mut |p| {
                events.push(p);
                if events.len() == 2 {
                    job.store(JOB_PAUSED, Ordering::Release);
                    let resumer = Arc::clone(&resumer);
                    thread::spawn(move || {
                        thread::sleep(Duration::from_millis(200));
                        resumer.store(JOB_RUNNING, Ordering::Release);
                    });
                } else if events.len() == 3 {
                    resumed_at = Some(started.elapsed());
                }
            },
        );
        result.unwrap();
        assert_eq!(events, [0.25, 0.5, 0.75, 1.0]);
        assert!(
            resumed_at.unwrap() >= Duration::from_millis(200),
            "chunk 2 must wait for the resume: {resumed_at:?}"
        );
        assert!(decrypt(&files, PASSWORD).is_ok());
    }

    #[test]
    fn progress_monotonic() {
        let (encrypt_events, decrypt_events) =
            round_trip(SMALL_CHUNK as usize * 4 + 1, &small_setup());
        for events in [encrypt_events, decrypt_events] {
            assert_eq!(events.len(), 5);
            assert!(
                events.windows(2).all(|pair| pair[0] < pair[1]),
                "{events:?}"
            );
            assert!(events.iter().all(|p| (0.0..=1.0).contains(p)));
            assert_eq!(*events.last().unwrap(), 1.0);
        }
    }

    // --- golden ------------------------------------------------------------

    #[test]
    fn golden_header() {
        // Pinned salt and prefix, the production chunk size and Argon2 params:
        // the 55-byte header of F2-1's golden vector, byte for byte.
        let setup = FileSetup {
            chunk_size: CHUNK_SIZE,
            nonce_prefix: NONCE_PREFIX,
            salt: SALT,
            params: ARGON2_PARAMS,
        };
        let files = Files::with_plaintext(b"");
        encrypt(&files, &setup);
        let sealed = fs::read(&files.sealed).unwrap();
        let expected_header = concat!(
            "46555a5a0104",
            "02",
            "00100000",
            "909192939495969798999a9b9c9d9e9fa0a1a2",
            "a0a1a2a3a4a5a6a7a8a9aaabacadaeaf",
            "000100000000000401",
        );
        assert_eq!(hex(&sealed[..HEADER_LEN]), expected_header);
        assert_eq!(
            sealed.len(),
            HEADER_LEN + TAG_LEN,
            "empty file = one tag-only chunk"
        );

        // `random()` writes the same production chunk size and KDF params.
        let random = FileSetup::random().unwrap().header().encode().unwrap();
        assert_eq!(hex(&random[6..11]), "0200100000");
        assert_eq!(hex(&random[46..55]), "000100000000000401");
        assert_ne!(random[11..30], NONCE_PREFIX);
        assert_ne!(random[30..46], SALT);
    }

    #[test]
    fn golden_container_matches_independent_implementation() {
        // Vector produced by pycryptodome (`ChaCha20_Poly1305`, 24-byte nonce)
        // from the spec's nonce/AAD rules — not from this code: key 0x42×32,
        // plaintext = 64 KiB of `pattern` + 5 bytes, 64 KiB chunks, so chunk 0
        // is sealed with nonce `prefix ‖ 00000000 ‖ 00` and chunk 1 with
        // `prefix ‖ 00000001 ‖ 01`, each with AAD `header ‖ index`.
        let setup = FileSetup {
            chunk_size: SMALL_CHUNK,
            nonce_prefix: NONCE_PREFIX,
            salt: SALT,
            params: ARGON2_PARAMS,
        };
        let plaintext = pattern(SMALL_CHUNK as usize + 5);
        let files = Files::with_plaintext(&plaintext);
        let key = [0x42u8; 32];
        encrypt_chunks(
            &key,
            &setup.header(),
            &files.plain,
            &files.sealed,
            &running(),
            &mut |_| {},
        )
        .unwrap();
        let sealed = fs::read(&files.sealed).unwrap();
        assert_eq!(sealed.len(), HEADER_LEN + SEALED_SMALL + 5 + TAG_LEN);
        assert_eq!(
            hex(&sealed[HEADER_LEN..HEADER_LEN + 16]),
            GOLDEN_CHUNK0_FIRST16
        );
        assert_eq!(
            hex(&sealed[HEADER_LEN + SEALED_SMALL - 16..HEADER_LEN + SEALED_SMALL]),
            GOLDEN_CHUNK0_TAG
        );
        assert_eq!(hex(&sealed[HEADER_LEN + SEALED_SMALL..]), GOLDEN_CHUNK1);
        decrypt_with_key(&key, &files.sealed, &files.opened).unwrap();
        assert_eq!(fs::read(&files.opened).unwrap(), plaintext);
    }

    const GOLDEN_CHUNK0_FIRST16: &str = "d3cd63e6069b47124e023f4c6187e0c2";
    const GOLDEN_CHUNK0_TAG: &str = "c64860d9715330bb15b8d74e52cb896b";
    const GOLDEN_CHUNK1: &str = "49fa5b09ab53d52587a5fa767f4926b075f3068f07";

    fn hex(bytes: &[u8]) -> String {
        bytes.iter().map(|b| format!("{b:02x}")).collect()
    }
}
