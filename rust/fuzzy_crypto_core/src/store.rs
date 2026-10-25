//! Key hygiene — the 0x10 key-wrapping construction, the sealed per-chat state
//! files, the per-chat local seal of message history (plan §A.2, §B.6, §D;
//! owner decision D-1) and the sealed app settings. Every secret lives in a
//! `Zeroizing` buffer or a `ZeroizeOnDrop` struct; nothing here returns key
//! bytes. The keys above the store key — the master key, its password and
//! recovery wraps — live in `master`.
//!
//! Layouts are the codec's (`formats::WrappedStoreKey` 0x10, `formats::LocalSeal`
//! 0x20); this module only adds the crypto around them.

use std::collections::HashMap;
use std::fs::{self, File, TryLockError};
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, Weak};
use std::thread;
use std::time::Duration;

use argon2::{Algorithm, Argon2, Params, Version};
use chacha20poly1305::aead::{Aead, Payload};
use chacha20poly1305::{KeyInit, XChaCha20Poly1305};
use zeroize::{ZeroizeOnDrop, Zeroizing};

use crate::error::CoreError;
use crate::formats::{Argon2Params, LocalSeal, WrappedStoreKey, WRAPPED_STORE_KEY_CT_LEN};
use crate::master::RECOVERY_LOCK_AAD;
use crate::state::{serialize_exact, ChatState, STATE_FORMAT_VERSION};

/// Directory under the app's support dir that holds every `<chat_id>.state`.
pub const STORE_SUBDIR: &str = "fuzzy_crypto_store";
/// Argon2id cost for every store key we wrap (plan §D): 64 MiB, 4 passes, 1 lane.
pub const ARGON2_PARAMS: Argon2Params = Argon2Params {
    m_cost: 65536,
    t_cost: 4,
    p_cost: 1,
};
/// Largest memory cost (KiB) accepted from a blob header — 256 MiB. Headers are
/// attacker-controlled (a pasted 0x05 password blob, a tampered 0x10 wrapped
/// key), so a tampered `m` must not OOM-kill a phone; our own `ARGON2_PARAMS`
/// sits far below this at 64 MiB (F2-2 review R2).
const MAX_ARGON2_M_COST: u32 = 256 * 1024;
/// Largest pass count accepted from a blob header — a tampered `t` must not hang
/// the app for minutes (F2-2 review R2). Our own `ARGON2_PARAMS` uses 4.
const MAX_ARGON2_T_COST: u32 = 16;

const STATE_AAD_PREFIX: &[u8] = b"chat-state";
const LOCAL_SEAL_AAD_PREFIX: &[u8] = b"local-seal";
const APP_SETTING_AAD_PREFIX: &[u8] = b"app-setting";
/// Longest setting name: names are short constants chosen by the app.
const MAX_SETTING_NAME_LEN: usize = 64;
const STATE_EXTENSION: &str = "state";
const STATE_TMP_EXTENSION: &str = "state.tmp";

/// Serialises every Argon2id run in the process — each one holds 64 MiB (pitfall §F.21).
static ARGON_LOCK: Mutex<()> = Mutex::new(());

/// A 32-byte key that wipes itself on drop.
pub type Key32 = Zeroizing<[u8; 32]>;

/// Fills `dest` from the OS CSPRNG.
pub fn fill_random(dest: &mut [u8]) -> Result<(), CoreError> {
    getrandom::fill(dest).map_err(|_| CoreError::Internal)
}

pub(crate) fn random_array<const N: usize>() -> Result<[u8; N], CoreError> {
    let mut out = [0u8; N];
    fill_random(&mut out)?;
    Ok(out)
}

// ---------------------------------------------------------------------------
// AEAD + KDF primitives (all from the pinned crates)
// ---------------------------------------------------------------------------

pub(crate) fn seal(
    key: &[u8; 32],
    nonce: &[u8; 24],
    aad: &[u8],
    msg: &[u8],
) -> Result<Vec<u8>, CoreError> {
    XChaCha20Poly1305::new(key.into())
        .encrypt(nonce.into(), Payload { msg, aad })
        .map_err(|_| CoreError::Internal)
}

/// Tag failure is `Corrupt`; callers that know better (the wrapped key, a
/// password blob) remap it.
pub(crate) fn open(
    key: &[u8; 32],
    nonce: &[u8; 24],
    aad: &[u8],
    ct: &[u8],
) -> Result<Vec<u8>, CoreError> {
    XChaCha20Poly1305::new(key.into())
        .decrypt(nonce.into(), Payload { msg: ct, aad })
        .map_err(|_| CoreError::Corrupt)
}

/// Argon2id(password, salt, params) → 32-byte KEK. Parameters come from a blob
/// header, so an unusable set is `Corrupt`, never a panic or a runaway allocation.
pub(crate) fn derive_kek(
    password: &[u8],
    salt: &[u8; 16],
    params: Argon2Params,
) -> Result<Key32, CoreError> {
    if params.m_cost > MAX_ARGON2_M_COST || params.t_cost > MAX_ARGON2_T_COST {
        return Err(CoreError::Corrupt);
    }
    let params = Params::new(
        params.m_cost,
        params.t_cost,
        u32::from(params.p_cost),
        Some(32),
    )
    .map_err(|_| CoreError::Corrupt)?;
    let block_count = params.block_count();
    let argon2 = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);
    let mut kek = Zeroizing::new([0u8; 32]);
    // Take the lock BEFORE allocating the block buffer: the point of §F.21 is
    // one Argon2 allocation at a time per process, so the lock must bound peak
    // memory, not only CPU — N concurrent opens with hostile headers would
    // otherwise peak at N × 256 MiB before serialising (F4-1 review N1).
    let _serialised = ARGON_LOCK
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    // `argon2 0.6.0` never wipes its block buffer on drop (`Blocks::drop` only
    // deallocates), so the KEK stays recoverable from the freed 64 MiB until the
    // allocator reuses it (F2-2 review R2, pitfall §F.11). Own the memory in a
    // `Zeroizing` buffer and wipe it ourselves.
    let mut blocks = Zeroizing::new(vec![argon2::Block::new(); block_count]);
    argon2
        .hash_password_into_with_memory(password, salt, kek.as_mut(), blocks.as_mut_slice())
        .map_err(|_| CoreError::Corrupt)?;
    Ok(kek)
}

// ---------------------------------------------------------------------------
// Wrapped store key (0x10)
// ---------------------------------------------------------------------------

/// The 0x10 construction for any 32-byte key: the `aad` names the key's role
/// (`master-key` and `master-key-recovery` for the master key, `vault-key` for
/// a vault under its own password), so a blob wrapped for one role never
/// unwraps as another (F4-1 review N2).
pub(crate) fn wrap_key_with(
    key: &[u8; 32],
    password: &[u8],
    aad: &[u8],
    salt: [u8; 16],
    nonce: [u8; 24],
) -> Result<Vec<u8>, CoreError> {
    let kek = derive_kek(password, &salt, ARGON2_PARAMS)?;
    let ciphertext: [u8; WRAPPED_STORE_KEY_CT_LEN] = seal(&kek, &nonce, aad, key)?
        .try_into()
        .map_err(|_| CoreError::Internal)?;
    Ok(WrappedStoreKey {
        salt,
        params: ARGON2_PARAMS,
        nonce,
        ciphertext,
    }
    .encode())
}

/// Inverse of [`wrap_key_with`] under the same `aad`. A tag failure is
/// `WrongPassword` — the AEAD cannot tell a wrong password from a tampered
/// blob, and the password is the only input the user controls.
pub(crate) fn unwrap_key(blob: &[u8], password: &[u8], aad: &[u8]) -> Result<Key32, CoreError> {
    let wrapped = WrappedStoreKey::decode(blob)?;
    let kek = derive_kek(password, &wrapped.salt, wrapped.params)?;
    let plain = Zeroizing::new(
        open(&kek, &wrapped.nonce, aad, &wrapped.ciphertext)
            .map_err(|_| CoreError::WrongPassword)?,
    );
    let mut key = Zeroizing::new([0u8; 32]);
    if plain.len() != key.len() {
        return Err(CoreError::Corrupt);
    }
    key.copy_from_slice(&plain);
    Ok(key)
}

// ---------------------------------------------------------------------------
// Local seal (0x20) — one chat's message history under that chat's history key
// ---------------------------------------------------------------------------

/// `prefix ‖ chat_id` (no separator — the chat id is fixed-length): the AAD of
/// a state file (`chat-state`).
fn chat_aad(prefix: &[u8], chat_id: &str) -> Vec<u8> {
    let mut aad = Vec::with_capacity(prefix.len() + chat_id.len());
    aad.extend_from_slice(prefix);
    aad.extend_from_slice(chat_id.as_bytes());
    aad
}

/// `local-seal ‖ chat_id ‖ row`: a history seal is bound to its chat and to
/// the row it belongs to (the app passes the row's direction byte and its
/// `Fuzz/` blob text), so a seal copied onto another row — of this chat or
/// another — does not open (security review 2026-10-22). The chat id is
/// fixed-length, so the row needs no separator.
fn local_seal_aad(chat_id: &str, row: &[u8]) -> Vec<u8> {
    let mut aad = chat_aad(LOCAL_SEAL_AAD_PREFIX, chat_id);
    aad.extend_from_slice(row);
    aad
}

/// Seals `bytes` of one `row` of `chat_id`'s history under that chat's
/// `history_key` with a random nonce (owner decision D-1: a per-chat key, not
/// the store key).
pub fn seal_local(
    history_key: &[u8; 32],
    chat_id: &str,
    row: &[u8],
    bytes: &[u8],
) -> Result<Vec<u8>, CoreError> {
    seal_local_with(history_key, chat_id, row, bytes, random_array()?)
}

/// [`seal_local`] with the nonce supplied — the test vectors pin its output.
pub(crate) fn seal_local_with(
    history_key: &[u8; 32],
    chat_id: &str,
    row: &[u8],
    bytes: &[u8],
    nonce: [u8; 24],
) -> Result<Vec<u8>, CoreError> {
    let ciphertext = seal(history_key, &nonce, &local_seal_aad(chat_id, row), bytes)?;
    Ok(LocalSeal { nonce, ciphertext }.encode())
}

/// Inverse of [`seal_local`]; a tag failure — another chat's key or id,
/// another row, or a tampered blob — is `Corrupt`.
pub fn open_local(
    history_key: &[u8; 32],
    chat_id: &str,
    row: &[u8],
    blob: &[u8],
) -> Result<Vec<u8>, CoreError> {
    let sealed = LocalSeal::decode(blob)?;
    open(
        history_key,
        &sealed.nonce,
        &local_seal_aad(chat_id, row),
        &sealed.ciphertext,
    )
}

// ---------------------------------------------------------------------------
// Sealed app settings (0x20 under the store key)
// ---------------------------------------------------------------------------

/// `app-setting ‖ name`; a name is 1..=64 bytes chosen by the app.
fn setting_aad(name: &str) -> Result<Vec<u8>, CoreError> {
    if name.is_empty() || name.len() > MAX_SETTING_NAME_LEN {
        return Err(CoreError::Corrupt);
    }
    let mut aad = Vec::with_capacity(APP_SETTING_AAD_PREFIX.len() + name.len());
    aad.extend_from_slice(APP_SETTING_AAD_PREFIX);
    aad.extend_from_slice(name.as_bytes());
    Ok(aad)
}

/// Seals the setting `name` under the store key, so a setting that guards the
/// app (the auto-lock times) cannot be changed by editing a file.
pub(crate) fn seal_setting_with(
    store_key: &[u8; 32],
    name: &str,
    bytes: &[u8],
    nonce: [u8; 24],
) -> Result<Vec<u8>, CoreError> {
    let ciphertext = seal(store_key, &nonce, &setting_aad(name)?, bytes)?;
    Ok(LocalSeal { nonce, ciphertext }.encode())
}

/// Inverse of [`seal_setting_with`]; another name, another store or a
/// tampered blob is `Corrupt`.
pub(crate) fn open_setting(
    store_key: &[u8; 32],
    name: &str,
    blob: &[u8],
) -> Result<Vec<u8>, CoreError> {
    let sealed = LocalSeal::decode(blob)?;
    open(
        store_key,
        &sealed.nonce,
        &setting_aad(name)?,
        &sealed.ciphertext,
    )
}

// ---------------------------------------------------------------------------
// State files
// ---------------------------------------------------------------------------

/// A chat id is also a file name (`<chat_id>.state`) and a map key, and the
/// codec only guarantees 1..=255 bytes of UTF-8 (FACTS, F2-1 review). Before it
/// touches a path it must have the uuid-v4 shape: 36 chars of lowercase hex with
/// dashes at 8/13/18/23. Anything else is `Corrupt`.
pub fn validate_chat_id(chat_id: &str) -> Result<(), CoreError> {
    const DASHES: [usize; 4] = [8, 13, 18, 23];
    let well_formed = chat_id.len() == 36
        && chat_id.bytes().enumerate().all(|(index, byte)| {
            if DASHES.contains(&index) {
                byte == b'-'
            } else {
                byte.is_ascii_digit() || (b'a'..=b'f').contains(&byte)
            }
        });
    if well_formed {
        Ok(())
    } else {
        Err(CoreError::Corrupt)
    }
}

fn seal_state(store_key: &[u8; 32], state: &ChatState) -> Result<Vec<u8>, CoreError> {
    seal_state_with(store_key, state, random_array()?)
}

/// [`seal_state`] with the nonce supplied — the test vectors pin its output.
pub(crate) fn seal_state_with(
    store_key: &[u8; 32],
    state: &ChatState,
    nonce: [u8; 24],
) -> Result<Vec<u8>, CoreError> {
    // Exactly-sized, residue-free serialisation — a fixed pre-size is not a
    // bound: a receiving side with 5 chains of 40 skipped keys reaches > 30 KiB
    // and any `Vec` growth leaks an unwiped copy of the Olm state (pitfall §F.11,
    // F2-2 review R1).
    let body = serialize_exact(state)?;
    let ciphertext = seal(
        store_key,
        &nonce,
        &chat_aad(STATE_AAD_PREFIX, &state.chat_id),
        &body,
    )?;
    Ok(LocalSeal { nonce, ciphertext }.encode())
}

fn open_state(store_key: &[u8; 32], chat_id: &str, file: &[u8]) -> Result<ChatState, CoreError> {
    let sealed = LocalSeal::decode(file)?;
    let body = Zeroizing::new(open(
        store_key,
        &sealed.nonce,
        &chat_aad(STATE_AAD_PREFIX, chat_id),
        &sealed.ciphertext,
    )?);
    let state: ChatState = serde_json::from_slice(&body).map_err(|_| CoreError::Corrupt)?;
    if state.format_version != STATE_FORMAT_VERSION {
        return Err(CoreError::UnsupportedFormat);
    }
    if state.chat_id != chat_id {
        return Err(CoreError::Corrupt);
    }
    Ok(state)
}

/// Creates the temp file, `0o600` on unix so the sealed state is never group- or
/// world-readable (F2-2 review nit).
pub(crate) fn create_tmp(path: &Path) -> io::Result<File> {
    let mut options = fs::OpenOptions::new();
    options.write(true).create(true).truncate(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    options.open(path)
}

/// `<file>.tmp` → write → fsync → rename over `path` → fsync the directory
/// (pitfall §F.14, F2-2 review nit). The directory fsync makes the rename durable
/// across a power loss, so a counter is never reused after one. A failed attempt
/// leaves no temp file behind and never touches the previous `path`.
fn write_atomically(path: &Path, bytes: &[u8]) -> Result<(), CoreError> {
    let tmp = path.with_extension(STATE_TMP_EXTENSION);
    let written = (|| -> io::Result<()> {
        let mut file = create_tmp(&tmp)?;
        file.write_all(bytes)?;
        file.sync_all()?;
        drop(file);
        fs::rename(&tmp, path)?;
        // On POSIX the rename is durable only once the directory entry is synced;
        // a directory handle cannot be opened this way on Windows.
        #[cfg(unix)]
        if let Some(parent) = path.parent() {
            File::open(parent)?.sync_all()?;
        }
        Ok(())
    })();
    if written.is_err() {
        let _ = fs::remove_file(&tmp);
    }
    written.map_err(|_| CoreError::Io)
}

/// Extension of the lock file beside the store directory
/// (`<store_dir>/fuzzy_crypto_store.lock`).
const LOCK_EXTENSION: &str = "lock";
/// How long `open` waits for another holder of the lock to let go (a copy of
/// the app that is just quitting) before it answers `Io`.
const LOCK_ATTEMPTS: u32 = 20;
const LOCK_RETRY: Duration = Duration::from_millis(50);

/// The exclusive OS lock on one store directory, held for as long as any
/// handle of this process has the store open. Two processes on one store would
/// each cache a chat's state and write it back over the other's — a counter or
/// a message key could be used twice (PROTOCOL.md §17). The OS releases the lock
/// when the file closes: on the last handle's drop, or when the process dies.
struct StoreLock {
    _file: File,
}

/// The store directories this process has locked. A second handle on the same
/// directory in the same process (the app opens the new handle before closing
/// the old one) shares the lock instead of colliding with it: an OS file lock
/// is per open file, so a second lock from this process would refuse itself.
static HELD_LOCKS: Mutex<Vec<(PathBuf, Weak<StoreLock>)>> = Mutex::new(Vec::new());

/// Takes (or shares, within this process) the exclusive lock on `root`. Another
/// process that holds it makes this `Io` after about a second of retries.
fn lock_store(root: &Path) -> Result<Arc<StoreLock>, CoreError> {
    let mut held = HELD_LOCKS.lock().map_err(|_| CoreError::Internal)?;
    held.retain(|(_, lock)| lock.strong_count() > 0);
    if let Some(lock) = held
        .iter()
        .find(|(path, _)| path == root)
        .and_then(|(_, lock)| lock.upgrade())
    {
        return Ok(lock);
    }
    let file = fs::OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .open(root.with_extension(LOCK_EXTENSION))
        .map_err(|_| CoreError::Io)?;
    let mut attempt = 1;
    loop {
        match file.try_lock() {
            Ok(()) => break,
            Err(TryLockError::WouldBlock) if attempt < LOCK_ATTEMPTS => {
                attempt += 1;
                thread::sleep(LOCK_RETRY);
            }
            Err(_) => return Err(CoreError::Io),
        }
    }
    let lock = Arc::new(StoreLock { _file: file });
    held.push((root.to_path_buf(), Arc::downgrade(&lock)));
    Ok(lock)
}

/// Best effort: writes zeros over every byte of the regular file at `path`
/// **in place** — opened without truncation, so the file system reuses the
/// blocks that held the ciphertext instead of freeing them and writing the
/// zeros elsewhere — and syncs. On a copy-on-write file system (APFS, Btrfs)
/// or flash with wear levelling the old blocks may still survive; there the
/// guarantee is the platform's disk encryption (PROTOCOL.md §10.3). A missing
/// file, a link or any error is ignored: the unlink that follows still runs.
fn overwrite_in_place(path: &Path) {
    let Ok(metadata) = fs::symlink_metadata(path) else {
        return;
    };
    if !metadata.is_file() {
        return;
    }
    let _ = fs::OpenOptions::new()
        .write(true)
        .truncate(false)
        .open(path)
        .and_then(|mut file| {
            let zeros = [0u8; 4096];
            let mut left = metadata.len();
            while left > 0 {
                let step = usize::try_from(left.min(zeros.len() as u64)).unwrap_or(zeros.len());
                file.write_all(&zeros[..step])?;
                left -= step as u64;
            }
            file.sync_all()
        });
}

/// An unlocked store: the store key, its directory and the lazily loaded states.
/// The cache only ever holds states that are on disk — any failure evicts.
/// While it exists, no other process can open the same store.
#[derive(ZeroizeOnDrop)]
pub struct OpenStore {
    store_key: Key32,
    #[zeroize(skip)]
    root: PathBuf,
    #[zeroize(skip)]
    cache: HashMap<String, ChatState>,
    #[zeroize(skip)]
    _lock: Arc<StoreLock>,
}

impl OpenStore {
    /// Creates `<store_dir>/fuzzy_crypto_store/` if missing, takes the store's
    /// exclusive lock (`Io` while another process — a second copy of the app —
    /// has it open) and takes ownership of the key.
    pub fn open(store_dir: &Path, store_key: Key32) -> Result<Self, CoreError> {
        let root = store_dir.join(STORE_SUBDIR);
        fs::create_dir_all(&root).map_err(|_| CoreError::Io)?;
        let root = fs::canonicalize(root).map_err(|_| CoreError::Io)?;
        let lock = lock_store(&root)?;
        Ok(Self {
            store_key,
            root,
            cache: HashMap::new(),
            _lock: lock,
        })
    }

    /// `<root>/<chat_id>.state`, validated and proven to stay inside `root`.
    fn state_path(&self, chat_id: &str) -> Result<PathBuf, CoreError> {
        validate_chat_id(chat_id)?;
        let path = self.root.join(chat_id).with_extension(STATE_EXTENSION);
        if path.starts_with(&self.root) {
            Ok(path)
        } else {
            Err(CoreError::Corrupt)
        }
    }

    /// Seals and writes `state` atomically; does not touch the cache.
    pub fn save_state(&self, state: &ChatState) -> Result<(), CoreError> {
        let path = self.state_path(&state.chat_id)?;
        let file = seal_state(&self.store_key, state)?;
        write_atomically(&path, &file)
    }

    /// Reads and opens `<chat_id>.state`; missing → `UnknownChat`.
    pub fn load_state(&self, chat_id: &str) -> Result<ChatState, CoreError> {
        let file = fs::read(self.state_path(chat_id)?).map_err(|error| {
            if error.kind() == io::ErrorKind::NotFound {
                CoreError::UnknownChat
            } else {
                CoreError::Io
            }
        })?;
        open_state(&self.store_key, chat_id, &file)
    }

    /// Persists a new or replaced state and caches it.
    pub fn put_state(&mut self, state: ChatState) -> Result<(), CoreError> {
        self.save_state(&state)?;
        self.cache.insert(state.chat_id.clone(), state);
        Ok(())
    }

    /// Loads (lazily), mutates and **saves before returning**. If the mutation
    /// or the save fails the cached copy is evicted, so the next call re-reads
    /// whatever is on disk.
    pub fn with_state_mut<T>(
        &mut self,
        chat_id: &str,
        mutate: impl FnOnce(&mut ChatState) -> Result<T, CoreError>,
    ) -> Result<T, CoreError> {
        if !self.cache.contains_key(chat_id) {
            let state = self.load_state(chat_id)?;
            self.cache.insert(chat_id.to_string(), state);
        }
        let path = self.state_path(chat_id)?;
        let result = match self.cache.get_mut(chat_id) {
            Some(state) => mutate(state)
                .and_then(|value| seal_state(&self.store_key, state).map(|file| (value, file))),
            None => Err(CoreError::Internal),
        };
        let saved = result.and_then(|(value, file)| write_atomically(&path, &file).map(|()| value));
        if saved.is_err() {
            self.cache.remove(chat_id);
        }
        saved
    }

    /// Overwrites the state file with zeros in place (best effort), unlinks it
    /// and evicts the cache. A chat with no state file is already deleted.
    pub fn delete_chat(&mut self, chat_id: &str) -> Result<(), CoreError> {
        let path = self.state_path(chat_id)?;
        self.cache.remove(chat_id);
        // Sweep a `.state.tmp` left by a crash between write and rename (F2-2
        // review nit) — ciphertext, but "delete" should leave nothing.
        let tmp = path.with_extension(STATE_TMP_EXTENSION);
        overwrite_in_place(&tmp);
        let _ = fs::remove_file(tmp);
        match fs::symlink_metadata(&path) {
            Ok(_) => {}
            Err(error) if error.kind() == io::ErrorKind::NotFound => return Ok(()),
            Err(_) => return Err(CoreError::Io),
        }
        overwrite_in_place(&path);
        fs::remove_file(&path).map_err(|_| CoreError::Io)
    }

    /// `chat_id`'s history key — from the cache when the state is loaded, else
    /// read from disk (`UnknownChat` when the chat does not exist). The state's
    /// copy is wiped with the state; this one with the returned `Key32`.
    fn history_key(&self, chat_id: &str) -> Result<Key32, CoreError> {
        let key = match self.cache.get(chat_id) {
            Some(state) => Zeroizing::new(state.history_key),
            None => Zeroizing::new(self.load_state(chat_id)?.history_key),
        };
        Ok(key)
    }

    /// Seals `bytes` of one `row` of `chat_id`'s message history under that
    /// chat's key.
    pub fn seal_local(
        &self,
        chat_id: &str,
        row: &[u8],
        bytes: &[u8],
    ) -> Result<Vec<u8>, CoreError> {
        seal_local(&*self.history_key(chat_id)?, chat_id, row, bytes)
    }

    /// Inverse of [`OpenStore::seal_local`] for the same chat and row; another
    /// chat's or row's blob is `Corrupt`, a deleted chat's is `UnknownChat`.
    pub fn open_local(&self, chat_id: &str, row: &[u8], blob: &[u8]) -> Result<Vec<u8>, CoreError> {
        open_local(&*self.history_key(chat_id)?, chat_id, row, blob)
    }

    /// Seals the app setting `name` under the store key with a fresh nonce.
    pub fn seal_setting(&self, name: &str, bytes: &[u8]) -> Result<Vec<u8>, CoreError> {
        seal_setting_with(&self.store_key, name, bytes, random_array()?)
    }

    /// Inverse of [`OpenStore::seal_setting`].
    pub fn open_setting(&self, name: &str, blob: &[u8]) -> Result<Vec<u8>, CoreError> {
        open_setting(&self.store_key, name, blob)
    }

    /// Seals the recovery lock — a public key, so this is for integrity only —
    /// under the store key: a 0x20 with AAD `recovery-lock`. A lock swapped in
    /// the secure storage then does not open, so nobody without the store key
    /// can make the app seal a vault key to a lock of theirs.
    pub fn seal_recovery_lock(&self, lock: &[u8; 32]) -> Result<Vec<u8>, CoreError> {
        let nonce = random_array()?;
        let ciphertext = seal(&self.store_key, &nonce, RECOVERY_LOCK_AAD, lock)?;
        Ok(LocalSeal { nonce, ciphertext }.encode())
    }

    /// Inverse of [`OpenStore::seal_recovery_lock`]; another store's lock, a
    /// tampered blob or a body that is not 32 bytes is `Corrupt`.
    pub fn open_recovery_lock(&self, blob: &[u8]) -> Result<[u8; 32], CoreError> {
        let sealed = LocalSeal::decode(blob)?;
        let plain = open(
            &self.store_key,
            &sealed.nonce,
            RECOVERY_LOCK_AAD,
            &sealed.ciphertext,
        )?;
        plain.try_into().map_err(|_| CoreError::Corrupt)
    }

    /// Seals a received file's key under `chat_id`'s history key.
    pub fn seal_kept_file_key(
        &self,
        chat_id: &str,
        file_key: &[u8; 32],
    ) -> Result<Vec<u8>, CoreError> {
        seal_kept_file_key(&*self.history_key(chat_id)?, chat_id, file_key)
    }

    /// Inverse of [`OpenStore::seal_kept_file_key`]; a deleted chat's blob is
    /// `UnknownChat`.
    pub fn open_kept_file_key(&self, chat_id: &str, blob: &[u8]) -> Result<Key32, CoreError> {
        open_kept_file_key(&*self.history_key(chat_id)?, chat_id, blob)
    }

    #[cfg(test)]
    fn is_cached(&self, chat_id: &str) -> bool {
        self.cache.contains_key(chat_id)
    }
}

// ---------------------------------------------------------------------------
// Kept file keys (0x20) — a received file the app keeps, under the history key
// ---------------------------------------------------------------------------

const KEPT_FILE_KEY_AAD_PREFIX: &[u8] = b"kept-file-key";

/// Seals the file key of a received chat-mode container the app keeps, under
/// the chat's `history_key` with a random nonce: a 0x20 blob with AAD
/// `kept-file-key` ‖ chat id, so a history seal never opens as a file key and
/// a file key never as history. The container's key message is single-use;
/// this seal is what lets the kept container be opened again (`PROTOCOL.md`
/// §9.6).
pub fn seal_kept_file_key(
    history_key: &[u8; 32],
    chat_id: &str,
    file_key: &[u8; 32],
) -> Result<Vec<u8>, CoreError> {
    let nonce = random_array()?;
    let ciphertext = seal(
        history_key,
        &nonce,
        &chat_aad(KEPT_FILE_KEY_AAD_PREFIX, chat_id),
        file_key,
    )?;
    Ok(LocalSeal { nonce, ciphertext }.encode())
}

/// Inverse of [`seal_kept_file_key`]; a tag failure (another chat's key or id,
/// a history seal, a tampered blob) or a body that is not 32 bytes is `Corrupt`.
pub fn open_kept_file_key(
    history_key: &[u8; 32],
    chat_id: &str,
    blob: &[u8],
) -> Result<Key32, CoreError> {
    let sealed = LocalSeal::decode(blob)?;
    let plain = Zeroizing::new(open(
        history_key,
        &sealed.nonce,
        &chat_aad(KEPT_FILE_KEY_AAD_PREFIX, chat_id),
        &sealed.ciphertext,
    )?);
    let mut file_key = Zeroizing::new([0u8; 32]);
    if plain.len() != file_key.len() {
        return Err(CoreError::Corrupt);
    }
    file_key.copy_from_slice(&plain);
    Ok(file_key)
}

#[cfg(test)]
pub(crate) mod test_support {
    use std::path::PathBuf;

    use vodozemac::olm::Account;

    use crate::error::CoreError;
    use crate::state::{ChatState, Role};

    /// A fresh, unique directory under the OS temp dir.
    pub fn temp_dir() -> PathBuf {
        let mut tag = [0u8; 8];
        super::fill_random(&mut tag).expect("os rng");
        let dir = std::env::temp_dir().join(format!(
            "fuzzy_crypto_core_test_{}_{}",
            std::process::id(),
            u64::from_be_bytes(tag)
        ));
        std::fs::create_dir_all(&dir).expect("temp dir");
        dir
    }

    /// The error of a result whose `Ok` type has no `Debug` (`ChatState` must not print itself).
    pub fn err_of<T>(result: Result<T, CoreError>) -> CoreError {
        match result {
            Ok(_) => panic!("expected an error"),
            Err(error) => error,
        }
    }

    /// The minimal state F2-3 will fill: an unpaired inviter with a fresh Olm
    /// account and its own history key.
    pub fn fresh_state(chat_id: &str) -> ChatState {
        let account = Account::new();
        let our_ed25519 = *account.ed25519_key().as_bytes();
        ChatState::new(
            Role::Inviter,
            chat_id.to_string(),
            account.pickle(),
            our_ed25519,
            super::random_array().expect("os rng"),
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const STORE_KEY: [u8; 32] = [0x33; 32];
    const HISTORY_KEY: [u8; 32] = [0x55; 32];
    const LOCAL_CHAT_ID: &str = "6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d";

    mod state {
        use super::test_support::{err_of, fresh_state, temp_dir};
        use super::*;

        const CHAT_ID: &str = "6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d";

        fn open_store(dir: &Path, key: [u8; 32]) -> OpenStore {
            OpenStore::open(dir, Zeroizing::new(key)).unwrap()
        }

        fn state_files(store: &OpenStore) -> Vec<String> {
            let mut names: Vec<String> = fs::read_dir(&store.root)
                .unwrap()
                .map(|entry| entry.unwrap().file_name().to_string_lossy().into_owned())
                .collect();
            names.sort();
            names
        }

        #[test]
        fn save_load_round_trip() {
            let dir = temp_dir();
            let mut store = open_store(&dir, STORE_KEY);
            let mut state = fresh_state(CHAT_ID);
            state.send_counter = 7;
            state.verified = true;
            state.last_invitation = Some(vec![1, 2, 3]);
            let account_json = serde_json::to_string(&state.account).unwrap();
            let our_ed25519 = state.our_ed25519;
            let history_key = state.history_key;
            store.put_state(state).unwrap();

            let reopened = open_store(&dir, STORE_KEY);
            let loaded = reopened.load_state(CHAT_ID).unwrap();

            assert_eq!(loaded.format_version, STATE_FORMAT_VERSION);
            assert_eq!(loaded.role, crate::state::Role::Inviter);
            assert_eq!(loaded.chat_id, CHAT_ID);
            assert_eq!(
                serde_json::to_string(&loaded.account).unwrap(),
                account_json
            );
            assert!(loaded.session.is_none());
            assert_eq!(loaded.our_ed25519, our_ed25519);
            assert_eq!(loaded.history_key, history_key);
            assert_eq!(loaded.send_counter, 7);
            assert!(loaded.verified);
            assert_eq!(loaded.last_invitation, Some(vec![1, 2, 3]));
            assert_eq!(state_files(&store), vec![format!("{CHAT_ID}.state")]);
            let _ = fs::remove_dir_all(dir);
        }

        #[test]
        fn save_overwrites_existing() {
            let dir = temp_dir();
            let mut store = open_store(&dir, STORE_KEY);
            store.put_state(fresh_state(CHAT_ID)).unwrap();
            let first = fs::read(store.state_path(CHAT_ID).unwrap()).unwrap();

            let mut second_state = fresh_state(CHAT_ID);
            second_state.send_counter = 2;
            store.put_state(second_state).unwrap();
            let second = fs::read(store.state_path(CHAT_ID).unwrap()).unwrap();

            assert_ne!(first, second);
            assert_eq!(store.load_state(CHAT_ID).unwrap().send_counter, 2);
            assert_eq!(state_files(&store), vec![format!("{CHAT_ID}.state")]);
            let _ = fs::remove_dir_all(dir);
        }

        #[test]
        fn tmp_file_never_left_behind() {
            let dir = temp_dir();
            let mut store = open_store(&dir, STORE_KEY);

            for counter in 0..3 {
                let mut state = fresh_state(CHAT_ID);
                state.send_counter = counter;
                store.put_state(state).unwrap();
                assert_eq!(state_files(&store), vec![format!("{CHAT_ID}.state")]);
            }
            let _ = fs::remove_dir_all(dir);
        }

        #[test]
        fn crash_between_write_and_rename_leaves_a_stale_tmp_that_is_ignored() {
            let dir = temp_dir();
            let mut store = open_store(&dir, STORE_KEY);
            let tmp = store
                .state_path(CHAT_ID)
                .unwrap()
                .with_extension(STATE_TMP_EXTENSION);

            // Crash before any state existed: only the temp file survives.
            fs::write(&tmp, b"half-written garbage").unwrap();
            assert_eq!(err_of(store.load_state(CHAT_ID)), CoreError::UnknownChat);
            store.put_state(fresh_state(CHAT_ID)).unwrap();
            assert_eq!(state_files(&store), vec![format!("{CHAT_ID}.state")]);
            assert!(store.load_state(CHAT_ID).is_ok());

            // Crash while replacing a good state: the old file is still the one that opens.
            let good = fs::read(store.state_path(CHAT_ID).unwrap()).unwrap();
            fs::write(&tmp, b"half-written garbage").unwrap();
            assert_eq!(fs::read(store.state_path(CHAT_ID).unwrap()).unwrap(), good);
            assert!(open_store(&dir, STORE_KEY).load_state(CHAT_ID).is_ok());
            let _ = fs::remove_dir_all(dir);
        }

        #[test]
        fn wrong_store_key_cannot_open() {
            let dir = temp_dir();
            let mut store = open_store(&dir, STORE_KEY);
            store.put_state(fresh_state(CHAT_ID)).unwrap();

            let other = open_store(&dir, [0x44; 32]);

            assert_eq!(err_of(other.load_state(CHAT_ID)), CoreError::Corrupt);
            let _ = fs::remove_dir_all(dir);
        }

        #[test]
        fn corrupt_missing_and_foreign_files() {
            let dir = temp_dir();
            let mut store = open_store(&dir, STORE_KEY);
            store.put_state(fresh_state(CHAT_ID)).unwrap();
            let path = store.state_path(CHAT_ID).unwrap();
            let good = fs::read(&path).unwrap();

            let mut flipped = good.clone();
            flipped[40] ^= 0x80;
            fs::write(&path, &flipped).unwrap();
            assert_eq!(err_of(store.load_state(CHAT_ID)), CoreError::Corrupt);

            fs::write(&path, &good[..20]).unwrap();
            assert_eq!(err_of(store.load_state(CHAT_ID)), CoreError::Corrupt);

            fs::write(
                &path,
                crate::master::wrap_with_password(&STORE_KEY, b"pw").unwrap(),
            )
            .unwrap();
            assert_eq!(
                err_of(store.load_state(CHAT_ID)),
                CoreError::UnsupportedFormat
            );

            // The AAD binds the file to its chat id: a renamed file does not open.
            let other_id = "0badf00d-0000-4000-8000-000000000000";
            fs::write(store.state_path(other_id).unwrap(), &good).unwrap();
            assert_eq!(err_of(store.load_state(other_id)), CoreError::Corrupt);

            assert_eq!(
                err_of(store.load_state("00000000-0000-4000-8000-000000000000")),
                CoreError::UnknownChat
            );
            let _ = fs::remove_dir_all(dir);
        }

        #[test]
        fn with_state_mut_persists_before_returning_and_evicts_on_error() {
            let dir = temp_dir();
            let mut store = open_store(&dir, STORE_KEY);
            store.put_state(fresh_state(CHAT_ID)).unwrap();

            let counter = store
                .with_state_mut(CHAT_ID, |state| {
                    state.send_counter += 1;
                    Ok(state.send_counter)
                })
                .unwrap();
            assert_eq!(counter, 1);
            assert_eq!(
                open_store(&dir, STORE_KEY)
                    .load_state(CHAT_ID)
                    .unwrap()
                    .send_counter,
                1
            );

            let failed = store.with_state_mut(CHAT_ID, |state| {
                state.send_counter = 99;
                Err::<(), _>(CoreError::Replay)
            });
            assert_eq!(failed.unwrap_err(), CoreError::Replay);
            assert!(!store.is_cached(CHAT_ID), "a failed mutation is forgotten");
            assert_eq!(store.load_state(CHAT_ID).unwrap().send_counter, 1);

            // Lazily loads from disk into the cache on first use.
            let mut fresh = open_store(&dir, STORE_KEY);
            assert!(!fresh.is_cached(CHAT_ID));
            fresh.with_state_mut(CHAT_ID, |_| Ok(())).unwrap();
            assert!(fresh.is_cached(CHAT_ID));
            assert_eq!(
                fresh
                    .with_state_mut("00000000-0000-4000-8000-000000000000", |_| Ok(()))
                    .unwrap_err(),
                CoreError::UnknownChat
            );
            let _ = fs::remove_dir_all(dir);
        }

        #[test]
        fn chat_id_must_be_a_uuid_v4_shape() {
            let dir = temp_dir();
            let mut store = open_store(&dir, STORE_KEY);
            let long = "a".repeat(255);
            let bad = [
                "",
                "../../x",
                "a/b",
                "a\\b",
                long.as_str(),
                "6F1E9B2C-3D4A-4F5B-8C6D-7E8F9A0B1C2D",
                "6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2",
                "6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d0",
                "6f1e9b2c03d4a-4f5b-8c6d-7e8f9a0b1c2d",
                "6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2g",
                "6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2\u{e9}",
                "../e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d",
            ];

            for chat_id in bad {
                assert_eq!(
                    validate_chat_id(chat_id).unwrap_err(),
                    CoreError::Corrupt,
                    "{chat_id:?}"
                );
                assert_eq!(
                    store.put_state(fresh_state(chat_id)).unwrap_err(),
                    CoreError::Corrupt,
                    "{chat_id:?}"
                );
                assert_eq!(err_of(store.load_state(chat_id)), CoreError::Corrupt);
                assert_eq!(store.delete_chat(chat_id).unwrap_err(), CoreError::Corrupt);
                assert_eq!(
                    store.with_state_mut(chat_id, |_| Ok(())).unwrap_err(),
                    CoreError::Corrupt
                );
            }
            assert!(state_files(&store).is_empty());

            validate_chat_id(CHAT_ID).unwrap();
            let path = store.state_path(CHAT_ID).unwrap();
            assert!(path.starts_with(&store.root));
            assert_eq!(
                path.file_name().unwrap().to_str().unwrap(),
                format!("{CHAT_ID}.state")
            );
            let _ = fs::remove_dir_all(dir);
        }

        #[test]
        fn delete_chat_zeroes_unlinks_and_is_idempotent() {
            let dir = temp_dir();
            let mut store = open_store(&dir, STORE_KEY);
            store.put_state(fresh_state(CHAT_ID)).unwrap();
            assert!(store.is_cached(CHAT_ID));

            store.delete_chat(CHAT_ID).unwrap();

            assert!(!store.is_cached(CHAT_ID));
            assert!(state_files(&store).is_empty());
            assert_eq!(err_of(store.load_state(CHAT_ID)), CoreError::UnknownChat);
            store.delete_chat(CHAT_ID).unwrap();
            let _ = fs::remove_dir_all(dir);
        }

        /// The zeros go over the ciphertext's own bytes: a second name for the
        /// same file (a hard link) sees them, at the full original length —
        /// for the state file and for a stale `.state.tmp` alike.
        #[test]
        fn delete_chat_overwrites_in_place_before_unlinking() {
            let dir = temp_dir();
            let mut store = open_store(&dir, STORE_KEY);
            store.put_state(fresh_state(CHAT_ID)).unwrap();
            let state = store.root.join(format!("{CHAT_ID}.state"));
            let tmp = store.root.join(format!("{CHAT_ID}.state.tmp"));
            fs::write(&tmp, [0xAB; 1000]).unwrap();
            let state_len = fs::metadata(&state).unwrap().len();
            assert!(fs::read(&state).unwrap().iter().any(|byte| *byte != 0));

            let state_twin = dir.join("state.twin");
            let tmp_twin = dir.join("tmp.twin");
            fs::hard_link(&state, &state_twin).unwrap();
            fs::hard_link(&tmp, &tmp_twin).unwrap();

            store.delete_chat(CHAT_ID).unwrap();

            assert!(!state.exists() && !tmp.exists());
            let state_bytes = fs::read(&state_twin).unwrap();
            assert_eq!(state_bytes.len() as u64, state_len);
            assert!(state_bytes.iter().all(|byte| *byte == 0));
            let tmp_bytes = fs::read(&tmp_twin).unwrap();
            assert_eq!(tmp_bytes.len(), 1000);
            assert!(tmp_bytes.iter().all(|byte| *byte == 0));
            let _ = fs::remove_dir_all(dir);
        }

        /// The lock file a store holds, opened the way another process would.
        fn foreign_handle(store_dir: &Path) -> File {
            fs::OpenOptions::new()
                .read(true)
                .write(true)
                .open(store_dir.join(format!("{STORE_SUBDIR}.{LOCK_EXTENSION}")))
                .unwrap()
        }

        /// Two handles in one process share the lock (the app opens the new
        /// one before it closes the old one); it is released with the last.
        #[test]
        fn handles_in_one_process_share_the_lock_until_the_last_closes() {
            let dir = temp_dir();
            let first = open_store(&dir, STORE_KEY);
            let second = open_store(&dir, STORE_KEY);
            let probe = foreign_handle(&dir);
            assert!(matches!(probe.try_lock(), Err(TryLockError::WouldBlock)));
            drop(first);
            assert!(matches!(probe.try_lock(), Err(TryLockError::WouldBlock)));
            drop(second);
            probe.try_lock().expect("released with the last handle");
            drop(probe);
            let _ = fs::remove_dir_all(dir);
        }

        /// Whoever holds the lock first wins: an open while another holder has
        /// it is `Io` and touches nothing; once it is released the open works.
        #[test]
        fn open_is_refused_while_another_holder_has_the_lock() {
            let dir = temp_dir();
            drop(open_store(&dir, STORE_KEY)); // creates the directory and lock file
            let other = foreign_handle(&dir);
            other.try_lock().unwrap();
            assert_eq!(
                err_of(OpenStore::open(&dir, Zeroizing::new(STORE_KEY))),
                CoreError::Io
            );
            drop(other);
            drop(open_store(&dir, STORE_KEY));
            let _ = fs::remove_dir_all(dir);
        }

        const CHILD_DIR_ENV: &str = "FUZZY_STORE_LOCK_CHILD_DIR";
        const CHILD_EXPECT_ENV: &str = "FUZZY_STORE_LOCK_CHILD_EXPECT";

        /// Only does something when [`a_second_copy_of_the_app_cannot_open_the_store`]
        /// runs this test binary again as a second process: it opens the store
        /// and exits 0 when the result is the one the parent expects.
        #[test]
        fn second_process_probe() {
            let (Some(dir), Some(expect)) = (
                std::env::var_os(CHILD_DIR_ENV),
                std::env::var_os(CHILD_EXPECT_ENV),
            ) else {
                return;
            };
            let outcome = match OpenStore::open(Path::new(&dir), Zeroizing::new(STORE_KEY)) {
                Ok(_) => "opened",
                Err(CoreError::Io) => "refused",
                Err(_) => "other",
            };
            std::process::exit(if expect == outcome { 0 } else { 1 });
        }

        /// A real second process — a second copy of the app — is refused while
        /// the first has the store open, and can open it once the first lets go.
        #[test]
        fn a_second_copy_of_the_app_cannot_open_the_store() {
            let dir = temp_dir();
            let second_process = |expect: &str| {
                std::process::Command::new(std::env::current_exe().unwrap())
                    .args([
                        "--exact",
                        "store::tests::state::second_process_probe",
                        "--test-threads=1",
                    ])
                    .env(CHILD_DIR_ENV, &dir)
                    .env(CHILD_EXPECT_ENV, expect)
                    .stdout(std::process::Stdio::null())
                    .status()
                    .unwrap()
                    .success()
            };
            let first = open_store(&dir, STORE_KEY);
            assert!(second_process("refused"), "a second process got the store");
            drop(first);
            assert!(second_process("opened"), "the lock outlived the store");
            let _ = fs::remove_dir_all(dir);
        }

        #[test]
        fn state_body_is_exactly_sized_with_full_skipped_key_stores() {
            use vodozemac::olm::{Account, OlmMessage, SessionConfig};

            // Build B's session carrying vodozemac's maximum retained state:
            // MAX_RECEIVING_CHAINS (5) chains each holding MAX_MESSAGE_KEYS (40)
            // skipped keys — the worst case for the serialised body (pitfall §F.11).
            let a = Account::new();
            let mut b = Account::new();
            let b_otk = b.generate_one_time_keys(1).created[0];
            b.mark_keys_as_published();

            let mut a_session = a
                .create_outbound_session(SessionConfig::version_1(), b.curve25519_key(), b_otk)
                .unwrap();
            let establish = match a_session.encrypt(b"establish".as_slice()).unwrap() {
                OlmMessage::PreKey(message) => message,
                OlmMessage::Normal(_) => panic!("the first message is always a pre-key"),
            };
            let mut b_session = b
                .create_inbound_session(SessionConfig::version_1(), a.curve25519_key(), &establish)
                .unwrap()
                .session;

            // Five rounds: A sends 41 on its current chain, B decrypts only the
            // last (40 skipped keys cached), then B replies so A ratchets and the
            // next round opens a fresh receiving chain on B.
            for _ in 0..5 {
                let mut last = None;
                for index in 0..41u32 {
                    last = Some(a_session.encrypt(index.to_be_bytes().as_slice()).unwrap());
                }
                b_session.decrypt(&last.unwrap()).unwrap();
                let reply = b_session.encrypt(b"reply".as_slice()).unwrap();
                a_session.decrypt(&reply).unwrap();
            }

            let mut state = fresh_state(CHAT_ID);
            state.account = b.pickle();
            state.session = Some(b_session.pickle());

            let body = serialize_exact(&state).unwrap();
            assert!(
                body.len() > 30_000,
                "5x40 skipped keys is a large body: {} B",
                body.len()
            );
            assert_eq!(
                body.capacity(),
                body.len(),
                "the buffer is sized exactly and never reallocates"
            );

            // It still seals and reloads.
            let dir = temp_dir();
            let mut store = open_store(&dir, STORE_KEY);
            store.put_state(state).unwrap();
            assert!(store.load_state(CHAT_ID).is_ok());
            let _ = fs::remove_dir_all(dir);
        }
    }

    mod local {
        use super::*;

        const OTHER_CHAT_ID: &str = "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d";
        /// A row's binding as the app forms it: direction byte ‖ blob text.
        const ROW: &[u8] = b"\x01Fuzz/RlVaWgEDAd6tvu8";
        const OTHER_ROW: &[u8] = b"\x00Fuzz/RlVaWgEDAd6tvu8";

        #[test]
        fn seal_open_round_trip() {
            for message in [&b""[..], b"hi", &[0u8; 4096]] {
                let blob = seal_local(&HISTORY_KEY, LOCAL_CHAT_ID, ROW, message).unwrap();
                assert_eq!(&blob[..6], b"FUZZ\x01\x20");
                assert_eq!(blob.len(), 6 + 24 + message.len() + 16);
                assert_eq!(
                    open_local(&HISTORY_KEY, LOCAL_CHAT_ID, ROW, &blob).unwrap(),
                    message
                );
            }

            let first = seal_local(&HISTORY_KEY, LOCAL_CHAT_ID, ROW, b"same").unwrap();
            let second = seal_local(&HISTORY_KEY, LOCAL_CHAT_ID, ROW, b"same").unwrap();
            assert_ne!(first[6..30], second[6..30], "fresh nonce per seal");
        }

        #[test]
        fn tamper_detected() {
            let blob = seal_local(&HISTORY_KEY, LOCAL_CHAT_ID, ROW, b"history entry").unwrap();

            for index in 6..blob.len() {
                let mut tampered = blob.clone();
                tampered[index] ^= 0x01;
                assert_eq!(
                    open_local(&HISTORY_KEY, LOCAL_CHAT_ID, ROW, &tampered).unwrap_err(),
                    CoreError::Corrupt,
                    "byte {index}"
                );
            }
            // Another chat's key, and the right key under another chat's id (the AAD).
            assert_eq!(
                open_local(&[0x44; 32], LOCAL_CHAT_ID, ROW, &blob).unwrap_err(),
                CoreError::Corrupt
            );
            assert_eq!(
                open_local(&HISTORY_KEY, OTHER_CHAT_ID, ROW, &blob).unwrap_err(),
                CoreError::Corrupt
            );
            assert_eq!(
                open_local(&HISTORY_KEY, LOCAL_CHAT_ID, ROW, &blob[..blob.len() - 1]).unwrap_err(),
                CoreError::Corrupt
            );
            let wrapped = crate::master::wrap_with_password(&STORE_KEY, b"pw").unwrap();
            assert_eq!(
                open_local(&HISTORY_KEY, LOCAL_CHAT_ID, ROW, &wrapped).unwrap_err(),
                CoreError::UnsupportedFormat
            );
        }

        /// Security review 2026-10-22: a seal moved to another row — another
        /// message, or the same blob shown in the other direction — does not open.
        #[test]
        fn seal_is_bound_to_its_row() {
            let blob = seal_local(&HISTORY_KEY, LOCAL_CHAT_ID, ROW, b"mine").unwrap();
            assert_eq!(
                open_local(&HISTORY_KEY, LOCAL_CHAT_ID, OTHER_ROW, &blob).unwrap_err(),
                CoreError::Corrupt
            );
            assert_eq!(
                open_local(&HISTORY_KEY, LOCAL_CHAT_ID, b"", &blob).unwrap_err(),
                CoreError::Corrupt
            );
            assert_eq!(
                open_local(&HISTORY_KEY, LOCAL_CHAT_ID, &ROW[..ROW.len() - 1], &blob).unwrap_err(),
                CoreError::Corrupt
            );
        }

        #[test]
        fn kept_file_key_round_trip_and_domain_separation() {
            let file_key = [0x66u8; 32];
            let blob = seal_kept_file_key(&HISTORY_KEY, LOCAL_CHAT_ID, &file_key).unwrap();
            assert_eq!(&blob[..6], b"FUZZ\x01\x20");
            assert_eq!(blob.len(), 6 + 24 + 32 + 16);
            assert_eq!(
                *open_kept_file_key(&HISTORY_KEY, LOCAL_CHAT_ID, &blob).unwrap(),
                file_key
            );

            // A file key never opens as history, and history never as a file key,
            // whatever row the history seal is bound to (an empty row leaves only
            // the label to tell them apart).
            for row in [&b""[..], &b"\x00Fuzz/row"[..]] {
                assert_eq!(
                    open_local(&HISTORY_KEY, LOCAL_CHAT_ID, row, &blob).unwrap_err(),
                    CoreError::Corrupt
                );
                let history = seal_local(&HISTORY_KEY, LOCAL_CHAT_ID, row, &file_key).unwrap();
                assert_eq!(
                    open_kept_file_key(&HISTORY_KEY, LOCAL_CHAT_ID, &history).unwrap_err(),
                    CoreError::Corrupt
                );
            }
            // Another chat's id or key, a tampered byte, a short blob.
            assert_eq!(
                open_kept_file_key(&HISTORY_KEY, OTHER_CHAT_ID, &blob).unwrap_err(),
                CoreError::Corrupt
            );
            assert_eq!(
                open_kept_file_key(&[0x44; 32], LOCAL_CHAT_ID, &blob).unwrap_err(),
                CoreError::Corrupt
            );
            for index in 6..blob.len() {
                let mut tampered = blob.clone();
                tampered[index] ^= 0x01;
                assert_eq!(
                    open_kept_file_key(&HISTORY_KEY, LOCAL_CHAT_ID, &tampered).unwrap_err(),
                    CoreError::Corrupt,
                    "byte {index}"
                );
            }
            assert_eq!(
                open_kept_file_key(&HISTORY_KEY, LOCAL_CHAT_ID, &blob[..blob.len() - 1])
                    .unwrap_err(),
                CoreError::Corrupt
            );
        }

        #[test]
        fn kept_file_key_must_be_32_bytes() {
            // A blob under the kept-file AAD whose body is not a key.
            let nonce = [0x11u8; 24];
            let ciphertext = seal(
                &HISTORY_KEY,
                &nonce,
                &chat_aad(KEPT_FILE_KEY_AAD_PREFIX, LOCAL_CHAT_ID),
                b"short",
            )
            .unwrap();
            let blob = LocalSeal { nonce, ciphertext }.encode();
            assert_eq!(
                open_kept_file_key(&HISTORY_KEY, LOCAL_CHAT_ID, &blob).unwrap_err(),
                CoreError::Corrupt
            );
        }

        #[test]
        fn opens_the_golden_blob() {
            // XChaCha20-Poly1305(history key 0x55*32, nonce 0x44*24, AAD "local-seal" ‖
            // chat id ‖ 0x01 ‖ "Fuzz/RlVaWgEDAd6tvu8", "hello"), computed with
            // pycryptodome from the spec — the `local_seal_chat` vector.
            let golden = hex(concat!(
                "46555a5a0120",
                "444444444444444444444444444444444444444444444444",
                "a5610b8a8e",
                "447cd8ea5654bc53ae6942bd3a999d71",
            ));

            assert_eq!(
                open_local(&HISTORY_KEY, LOCAL_CHAT_ID, ROW, &golden).unwrap(),
                b"hello"
            );
            assert_eq!(
                seal_local_with(&HISTORY_KEY, LOCAL_CHAT_ID, ROW, b"hello", [0x44; 24]).unwrap(),
                golden
            );
        }
    }

    mod settings {
        use super::*;

        #[test]
        fn seal_open_round_trip_and_golden() {
            // XChaCha20-Poly1305(store key 0x33*32, nonce 0x44*24, AAD "app-setting" ‖
            // "auto-lock", "{}"), computed with pycryptodome from the spec.
            let golden = hex(concat!(
                "46555a5a0120",
                "444444444444444444444444444444444444444444444444",
                "63db",
                "e1d5670b9abea7b876bb726bd2518c55",
            ));
            assert_eq!(
                seal_setting_with(&STORE_KEY, "auto-lock", b"{}", [0x44; 24]).unwrap(),
                golden
            );
            assert_eq!(
                open_setting(&STORE_KEY, "auto-lock", &golden).unwrap(),
                b"{}"
            );
        }

        #[test]
        fn another_name_store_or_tampering_is_corrupt() {
            let blob = seal_setting_with(&STORE_KEY, "auto-lock", b"{}", [0x44; 24]).unwrap();
            assert_eq!(
                open_setting(&STORE_KEY, "auto-lock-x", &blob).unwrap_err(),
                CoreError::Corrupt
            );
            assert_eq!(
                open_setting(&[0x34; 32], "auto-lock", &blob).unwrap_err(),
                CoreError::Corrupt
            );
            let mut flipped = blob.clone();
            flipped[31] ^= 1;
            assert_eq!(
                open_setting(&STORE_KEY, "auto-lock", &flipped).unwrap_err(),
                CoreError::Corrupt
            );
            // A history seal under the same key is not a setting.
            let history = seal_local(&STORE_KEY, LOCAL_CHAT_ID, b"", b"{}").unwrap();
            assert_eq!(
                open_setting(&STORE_KEY, "auto-lock", &history).unwrap_err(),
                CoreError::Corrupt
            );
            assert_eq!(
                seal_setting_with(&STORE_KEY, "", b"{}", [0x44; 24]).unwrap_err(),
                CoreError::Corrupt
            );
            assert_eq!(
                seal_setting_with(&STORE_KEY, &"n".repeat(65), b"{}", [0x44; 24]).unwrap_err(),
                CoreError::Corrupt
            );
        }
    }

    fn hex(text: &str) -> Vec<u8> {
        (0..text.len())
            .step_by(2)
            .map(|index| u8::from_str_radix(&text[index..index + 2], 16).unwrap())
            .collect()
    }
}
