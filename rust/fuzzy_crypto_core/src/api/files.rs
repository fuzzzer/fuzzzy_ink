use std::cell::Cell;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU8, Ordering};
use std::sync::Arc;

use flutter_rust_bridge::frb;
use zeroize::Zeroizing;

use crate::api::core::CryptoCore;
use crate::error::CoreError;
use crate::files::{
    self, ChatFileSetup, FileSetup, Progress, JOB_CANCELLED, JOB_PAUSED, JOB_RUNNING,
};
use crate::formats::FileHeader;
use crate::frb_generated::StreamSink;
use crate::store::{validate_chat_id, Key32};

/// One event of a file job — maps 1:1 onto the app's `FileProcessingProgress`.
///
/// `progress` is the fraction of chunks done (one event per chunk). The last
/// event is terminal: `is_complete` on success, `is_cancelled` after
/// [`FileJob::cancel`], or `is_complete` with an `error_message` (the
/// [`CoreError`]'s text: `wrong password`, `corrupt`, `unsupported format`,
/// `io`, `internal`) on failure — no `Err` ever reaches Dart, because frb does
/// not await a stream function's result (`unawaited`).
pub struct FileProgress {
    pub progress: f64,
    pub is_complete: bool,
    pub is_cancelled: bool,
    pub error_message: Option<String>,
}

impl FileProgress {
    fn running(progress: f64) -> Self {
        Self {
            progress,
            is_complete: false,
            is_cancelled: false,
            error_message: None,
        }
    }

    fn finished(progress: f64, result: Result<(), CoreError>) -> Self {
        match result {
            Ok(()) => Self {
                progress: 1.0,
                is_complete: true,
                is_cancelled: false,
                error_message: None,
            },
            Err(CoreError::Cancelled) => Self {
                progress,
                is_complete: false,
                is_cancelled: true,
                error_message: None,
            },
            Err(error) => Self {
                progress,
                is_complete: true,
                is_cancelled: false,
                error_message: Some(error.to_string()),
            },
        }
    }
}

/// The pause/resume/cancel handle of one file job. Create it with
/// [`new_file_job`], hand it to `encrypt_file`/`decrypt_file`/`run_file_job`,
/// and call the methods from Dart while the job runs; the loop reads the word
/// before every chunk. Holds no secret, so the methods are sync.
#[frb(opaque)]
pub struct FileJob {
    state: Arc<AtomicU8>,
}

pub fn new_file_job() -> FileJob {
    FileJob {
        state: Arc::new(AtomicU8::new(JOB_RUNNING)),
    }
}

impl FileJob {
    /// The loop finishes the chunk in flight, then sleeps 50 ms at a time until
    /// [`FileJob::resume`] or [`FileJob::cancel`].
    #[frb(sync)]
    pub fn pause(&self) {
        let _ = self.state.compare_exchange(
            JOB_RUNNING,
            JOB_PAUSED,
            Ordering::AcqRel,
            Ordering::Acquire,
        );
    }

    /// Continues a paused job at the next chunk boundary; a no-op otherwise.
    #[frb(sync)]
    pub fn resume(&self) {
        let _ = self.state.compare_exchange(
            JOB_PAUSED,
            JOB_RUNNING,
            Ordering::AcqRel,
            Ordering::Acquire,
        );
    }

    /// Terminal: the loop unlinks `<output>.part` and emits `is_cancelled` at
    /// the next chunk boundary (also while paused).
    #[frb(sync)]
    pub fn cancel(&self) {
        self.state.store(JOB_CANCELLED, Ordering::Release);
    }
}

// ---------------------------------------------------------------------------
// Password mode (fuzzy_basics) — no store involved
// ---------------------------------------------------------------------------

/// Encrypts the file at `input` into the password-mode 0x04 container at
/// `output` (`.part` until the last chunk is written and fsynced), streaming
/// one [`FileProgress`] per 1 MiB chunk into `sink`. The file key is
/// Argon2id(password) with a fresh salt. Runs on frb's pool and never touches
/// the store, so the chat can keep sending while a file runs.
pub fn encrypt_file(
    password: String,
    input: String,
    output: String,
    job: &FileJob,
    sink: StreamSink<FileProgress>,
) {
    let password = Zeroizing::new(password.into_bytes());
    run(&sink, job, |job, progress| {
        let setup = FileSetup::random()?;
        files::encrypt_with_password(
            &password,
            &setup,
            Path::new(&input),
            Path::new(&output),
            job,
            progress,
        )
    });
}

/// Decrypts the password-mode container at `input` to `output`, writing each
/// chunk to `<output>.part` only after its tag verified and renaming at the
/// end; on any failure or cancel the `.part` is removed and no output exists.
/// Failure text: `wrong password` (chunk 0 does not open), `corrupt` (a later
/// chunk, a truncation or appended bytes), `unsupported format` (not a
/// password-mode container).
pub fn decrypt_file(
    password: String,
    input: String,
    output: String,
    job: &FileJob,
    sink: StreamSink<FileProgress>,
) {
    let password = Zeroizing::new(password.into_bytes());
    run(&sink, job, |job, progress| {
        files::decrypt_with_password(
            &password,
            Path::new(&input),
            Path::new(&output),
            job,
            progress,
        )
    });
}

// ---------------------------------------------------------------------------
// Chat mode — two steps: prepare under the core lock, run without it
// ---------------------------------------------------------------------------

/// A prepared chat-mode file job: the Olm work is done and persisted, the file
/// key is inside. `prepare_file_send` / `prepare_file_receive` mint one under
/// the core's lock; [`run_file_job`] consumes it without touching the core, so
/// a running (or paused) file never queues a `close()` or a text message.
/// One-shot: a second run answers `internal`. The key wipes on drop, run or not
/// — a receive ticket that is never run has still consumed the file's message
/// (`replay` on the next prepare), exactly like a decrypted text nobody read.
#[frb(opaque)]
pub struct FileTicket {
    original_name: String,
    inner: Option<PreparedJob>,
}

/// Everything [`run_file_job`] needs; the key is the only secret.
struct PreparedJob {
    key: Key32,
    header: FileHeader,
    input: PathBuf,
    kind: JobKind,
}

enum JobKind {
    Send,
    Receive,
}

impl CryptoCore {
    /// Step one of sending the file at `input` on `chat_id`: draws the file key,
    /// wraps it with the file's name in one Olm message on the session (one
    /// ratchet step, the next send counter — the rules of `encrypt_text`),
    /// persists the state and returns the ticket for [`run_file_job`]. A chat
    /// that is not connected is `Internal`; an unreadable `input`, or one that
    /// is not a regular file (a directory opens fine on unix), is `Io` —
    /// checked first, so no counter is spent on a file that cannot be read.
    pub fn prepare_file_send(
        &mut self,
        chat_id: String,
        input: String,
    ) -> Result<FileTicket, CoreError> {
        validate_chat_id(&chat_id)?;
        let input = PathBuf::from(input);
        let original_name = input
            .file_name()
            .and_then(|name| name.to_str())
            .ok_or(CoreError::Io)?
            .to_owned();
        let readable = std::fs::File::open(&input).map_err(|_| CoreError::Io)?;
        if !readable.metadata().map_err(|_| CoreError::Io)?.is_file() {
            return Err(CoreError::Io);
        }
        let setup = ChatFileSetup::random()?;
        let (key, header) = self.opened_mut()?.with_state_mut(&chat_id, |state| {
            files::wrap_file_key(state, &original_name, &setup)
        })?;
        Ok(FileTicket {
            original_name,
            inner: Some(PreparedJob {
                key,
                header,
                input,
                kind: JobKind::Send,
            }),
        })
    }

    /// Step one of receiving the chat-mode container at `input` on `chat_id`:
    /// reads the header (a header-only or truncated container is `Corrupt`
    /// here, before the message is spent; a directory is `Io`), opens the
    /// embedded Olm message through the same chain as a text message
    /// (`Replay`, `TooOld`, `WrongChat`, `Corrupt` exactly as `decrypt_text`;
    /// a password-mode container is `UnsupportedFormat`),
    /// persists the state and returns the ticket. Nothing is written to disk
    /// besides the state: the output appears only under [`run_file_job`], so a
    /// rejection here leaves no `.part` behind. The original name is on the
    /// ticket — pick the output path from it, then run.
    pub fn prepare_file_receive(
        &mut self,
        chat_id: String,
        input: String,
    ) -> Result<FileTicket, CoreError> {
        validate_chat_id(&chat_id)?;
        let input = PathBuf::from(input);
        let header = files::peek_header(&input)?;
        let (key, original_name) = self
            .opened_mut()?
            .with_state_mut(&chat_id, |state| files::unwrap_file_key(state, &header))?;
        Ok(FileTicket {
            original_name,
            inner: Some(PreparedJob {
                key,
                header,
                input,
                kind: JobKind::Receive,
            }),
        })
    }
}

impl FileTicket {
    /// The file's name as the sender saw it: the input's file name on a send
    /// ticket, the name carried inside the Olm message on a receive ticket
    /// (a bare name — never a path). Readable before and after the run.
    pub fn original_name(&self) -> String {
        self.original_name.clone()
    }
}

/// Step two: streams the prepared job to `output` — the container for a send
/// ticket, the plaintext for a receive ticket — with the progress, `.part` and
/// cancel rules of the password-mode functions, and never touches the core.
/// A receive ticket opens only the container it was prepared on: chunk 0 of
/// anything else (or a header changed since prepare) is `corrupt`. A second run
/// of the same ticket is `internal`.
pub fn run_file_job(
    ticket: &mut FileTicket,
    output: String,
    job: &FileJob,
    sink: StreamSink<FileProgress>,
) {
    run(&sink, job, |state, progress| {
        run_ticket(ticket, Path::new(&output), state, progress)
    });
}

/// The body of [`run_file_job`] without the sink: consumes the prepared job
/// (`Internal` on a second run) and streams it. A receive ticket decrypts only
/// the container its header was prepared on — `on_disk == header` binds the key
/// to this exact container, so a key message moved onto another container's
/// chunks fails at chunk 0 (`Corrupt`).
pub(crate) fn run_ticket(
    ticket: &mut FileTicket,
    output: &Path,
    state: &AtomicU8,
    progress: Progress<'_>,
) -> Result<(), CoreError> {
    let PreparedJob {
        key,
        header,
        input,
        kind,
    } = ticket.inner.take().ok_or(CoreError::Internal)?;
    match kind {
        JobKind::Send => files::encrypt_chunks(&key, &header, &input, output, state, progress),
        JobKind::Receive => files::decrypt_chunks(
            &input,
            output,
            state,
            progress,
            |on_disk| {
                if *on_disk == header {
                    Ok(key)
                } else {
                    Err(CoreError::Corrupt)
                }
            },
            CoreError::Corrupt,
        ),
    }
}

/// Runs `work` with a progress callback that forwards to `sink`, then emits
/// the terminal event. Send failures are ignored: Dart dropping the stream
/// must not fail the job (the `.part` rules hold regardless).
fn run(
    sink: &StreamSink<FileProgress>,
    job: &FileJob,
    work: impl FnOnce(&AtomicU8, Progress<'_>) -> Result<(), CoreError>,
) {
    let last = Cell::new(0.0);
    let result = work(&job.state, &mut |progress| {
        last.set(progress);
        let _ = sink.add(FileProgress::running(progress));
    });
    let _ = sink.add(FileProgress::finished(last.get(), result));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn job_state_transitions() {
        let job = new_file_job();
        let state = |job: &FileJob| job.state.load(Ordering::Acquire);
        assert_eq!(state(&job), JOB_RUNNING);
        job.resume();
        assert_eq!(state(&job), JOB_RUNNING, "resume while running is a no-op");
        job.pause();
        assert_eq!(state(&job), JOB_PAUSED);
        job.pause();
        assert_eq!(state(&job), JOB_PAUSED);
        job.resume();
        assert_eq!(state(&job), JOB_RUNNING);
        job.pause();
        job.cancel();
        assert_eq!(state(&job), JOB_CANCELLED, "cancel wins over pause");
        job.resume();
        assert_eq!(state(&job), JOB_CANCELLED, "cancel is terminal");
        job.pause();
        assert_eq!(state(&job), JOB_CANCELLED);
    }

    #[test]
    fn terminal_events_follow_the_dart_contract() {
        let done = FileProgress::finished(0.4, Ok(()));
        assert!(done.is_complete && !done.is_cancelled && done.error_message.is_none());
        assert_eq!(done.progress, 1.0);

        let cancelled = FileProgress::finished(0.4, Err(CoreError::Cancelled));
        assert!(cancelled.is_cancelled && !cancelled.is_complete);
        assert_eq!(cancelled.progress, 0.4);
        assert!(cancelled.error_message.is_none());

        let failed = FileProgress::finished(0.4, Err(CoreError::WrongPassword));
        assert!(failed.is_complete && !failed.is_cancelled);
        assert_eq!(failed.error_message.as_deref(), Some("wrong password"));
        assert_eq!(
            FileProgress::finished(0.0, Err(CoreError::Corrupt))
                .error_message
                .as_deref(),
            Some("corrupt")
        );
        assert_eq!(
            FileProgress::finished(0.0, Err(CoreError::StoreLocked))
                .error_message
                .as_deref(),
            Some("store locked")
        );
    }

    // -----------------------------------------------------------------------
    // Chat mode — the two-step prepare/run path end to end (no StreamSink, so
    // `run_ticket` stands in for `run_file_job`; the sink wiring is the only
    // difference and `terminal_events_follow_the_dart_contract` covers it).
    // -----------------------------------------------------------------------

    use std::fs;
    use std::path::PathBuf;

    use vodozemac::olm::DecryptionError;

    use crate::api::core::{create_store_key, open_store};
    use crate::files::ChatFileSetup;
    use crate::formats::{FileHeader, FileKeyMode, OlmType, CHUNK_SIZE};
    use crate::store::test_support::temp_dir;
    use crate::store::STORE_SUBDIR;

    const CHAT_X: &str = "6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d";
    const CHAT_Y: &str = "0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d";

    /// One device with its own store directory and open handle.
    struct Device {
        dir: PathBuf,
        core: CryptoCore,
    }

    impl Device {
        fn new() -> Self {
            let dir = temp_dir();
            let core = open_store(
                dir.to_string_lossy().into_owned(),
                create_store_key("".into()).unwrap(),
                "".into(),
            )
            .unwrap();
            Self { dir, core }
        }

        fn path(&self, name: &str) -> PathBuf {
            self.dir.join(name)
        }

        fn write_plain(&self, name: &str, bytes: &[u8]) -> PathBuf {
            let path = self.path(name);
            fs::write(&path, bytes).unwrap();
            path
        }

        fn send_counter(&self, chat_id: &str) -> u64 {
            self.core
                .opened()
                .unwrap()
                .load_state(chat_id)
                .unwrap()
                .send_counter
        }

        fn recv_highest(&self, chat_id: &str) -> u64 {
            self.core
                .opened()
                .unwrap()
                .load_state(chat_id)
                .unwrap()
                .recv_highest
        }

        /// The sealed on-disk state file, for byte-identical assertions.
        fn state_bytes(&self, chat_id: &str) -> Vec<u8> {
            fs::read(self.dir.join(STORE_SUBDIR).join(format!("{chat_id}.state"))).unwrap()
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

    fn running() -> AtomicU8 {
        AtomicU8::new(JOB_RUNNING)
    }

    /// Runs a prepared ticket to `output`, returning the progress events.
    fn run(ticket: &mut FileTicket, output: &Path) -> Result<Vec<f64>, CoreError> {
        let mut events = Vec::new();
        run_ticket(ticket, output, &running(), &mut |p| events.push(p))?;
        Ok(events)
    }

    fn part_of(path: &Path) -> PathBuf {
        let mut part = path.as_os_str().to_owned();
        part.push(".part");
        PathBuf::from(part)
    }

    fn assert_absent(output: &Path) {
        assert!(!output.exists(), "output must be absent");
        assert!(!part_of(output).exists(), ".part must be gone");
    }

    /// Sender encrypts `plaintext` (named `name`) for `chat_id`; returns the
    /// container path.
    fn send(dev: &mut Device, chat_id: &str, name: &str, plaintext: &[u8]) -> PathBuf {
        let input = dev.write_plain(name, plaintext);
        let sealed = dev.path(&format!("{name}.fuzz"));
        let mut ticket = dev
            .core
            .prepare_file_send(chat_id.into(), input.to_string_lossy().into_owned())
            .unwrap();
        assert_eq!(ticket.original_name(), name);
        run(&mut ticket, &sealed).unwrap();
        sealed
    }

    #[test]
    fn chat_mode_round_trip() {
        let mut a = Device::new();
        let mut b = Device::new();
        pair(&mut a, &mut b, CHAT_X);

        let plaintext = pattern(CHUNK_SIZE as usize * 5 / 2 + 17); // three chunks
        let sealed = send(&mut a, CHAT_X, "report.pdf", &plaintext);
        assert_eq!(a.send_counter(CHAT_X), 1, "the file spent one ratchet step");

        // The container is self-contained: magic, chat key mode, chunk size.
        let bytes = fs::read(&sealed).unwrap();
        assert_eq!(&bytes[..7], &[0x46, 0x55, 0x5A, 0x5A, 0x01, 0x04, 0x01]);

        let output = b.path("received.bin");
        let mut ticket = b
            .core
            .prepare_file_receive(CHAT_X.into(), sealed.to_string_lossy().into_owned())
            .unwrap();
        assert_eq!(
            ticket.original_name(),
            "report.pdf",
            "original name restored"
        );
        assert_eq!(b.recv_highest(CHAT_X), 0, "counter 0 (the file) accepted");
        let events = run(&mut ticket, &output).unwrap();
        assert_eq!(events.len(), 3);
        assert_eq!(fs::read(&output).unwrap(), plaintext);
        assert!(!part_of(&output).exists());
    }

    #[test]
    fn chat_mode_round_trip_multi_chunk_both_directions() {
        let mut a = Device::new();
        let mut b = Device::new();
        pair(&mut a, &mut b, CHAT_X);

        // A → B, then B → A: each direction's counter advances independently.
        let p1 = pattern(CHUNK_SIZE as usize * 2);
        let sealed1 = send(&mut a, CHAT_X, "a.bin", &p1);
        let out1 = b.path("a_out.bin");
        let mut t1 = b
            .core
            .prepare_file_receive(CHAT_X.into(), sealed1.to_string_lossy().into_owned())
            .unwrap();
        run(&mut t1, &out1).unwrap();
        assert_eq!(fs::read(&out1).unwrap(), p1);

        let p2 = pattern(CHUNK_SIZE as usize + 3);
        let b_before = b.send_counter(CHAT_X);
        let sealed2 = send(&mut b, CHAT_X, "b.bin", &p2);
        assert_eq!(
            b.send_counter(CHAT_X),
            b_before + 1,
            "the file spent one step"
        );
        let out2 = a.path("b_out.bin");
        let mut t2 = a
            .core
            .prepare_file_receive(CHAT_X.into(), sealed2.to_string_lossy().into_owned())
            .unwrap();
        run(&mut t2, &out2).unwrap();
        assert_eq!(fs::read(&out2).unwrap(), p2);
    }

    #[test]
    fn wrong_chat_rejected_before_any_write() {
        let mut a = Device::new();
        let mut a2 = Device::new();
        let mut b = Device::new();
        pair(&mut a, &mut b, CHAT_X);
        pair(&mut a2, &mut b, CHAT_Y);

        let sealed = send(&mut a, CHAT_X, "secret.bin", &pattern(1000));
        let output = b.path("out.bin");
        let before = b.recv_highest(CHAT_Y);

        // The CHAT_X container pasted into CHAT_Y: Olm's MAC is under X's
        // session, so it fails at prepare — no chunk is ever read or written.
        assert_eq!(
            b.core
                .prepare_file_receive(CHAT_Y.into(), sealed.to_string_lossy().into_owned())
                .err()
                .unwrap(),
            CoreError::Corrupt
        );
        assert_absent(&output);
        assert_eq!(b.recv_highest(CHAT_Y), before, "Y's counter untouched");
    }

    #[test]
    fn replayed_file_rejected() {
        let mut a = Device::new();
        let mut b = Device::new();
        pair(&mut a, &mut b, CHAT_X);

        let sealed = send(&mut a, CHAT_X, "once.bin", &pattern(500));
        let sealed_text = sealed.to_string_lossy().into_owned();

        let out1 = b.path("out1.bin");
        let mut t1 = b
            .core
            .prepare_file_receive(CHAT_X.into(), sealed_text.clone())
            .unwrap();
        run(&mut t1, &out1).unwrap();
        assert_eq!(fs::read(&out1).unwrap(), pattern(500));

        // The key message consumed the ratchet step; preparing it again is a
        // replay, and nothing is written for the second output.
        let out2 = b.path("out2.bin");
        assert_eq!(
            b.core
                .prepare_file_receive(CHAT_X.into(), sealed_text)
                .err()
                .unwrap(),
            CoreError::Replay
        );
        assert_absent(&out2);
    }

    #[test]
    fn incomplete_container_rejected_before_the_message_is_spent() {
        let mut a = Device::new();
        let mut b = Device::new();
        pair(&mut a, &mut b, CHAT_X);

        let plaintext = pattern(CHUNK_SIZE as usize + 100); // two chunks
        let sealed = send(&mut a, CHAT_X, "partial.bin", &plaintext);
        let pristine = fs::read(&sealed).unwrap();
        let header_len = crate::files::peek_header(&sealed)
            .unwrap()
            .encode()
            .unwrap()
            .len();
        let sealed_text = sealed.to_string_lossy().into_owned();
        let output = b.path("out.bin");
        let before = b.state_bytes(CHAT_X);

        // Header only, header + 15 bytes, and a last chunk shorter than a tag:
        // every one is `Corrupt` at prepare with B's state byte-identical —
        // the file's message is still unspent.
        for keep in [
            header_len,
            header_len + 15,
            header_len + CHUNK_SIZE as usize + 16 + 15,
        ] {
            fs::write(&sealed, &pristine[..keep]).unwrap();
            assert_eq!(
                b.core
                    .prepare_file_receive(CHAT_X.into(), sealed_text.clone())
                    .err()
                    .unwrap(),
                CoreError::Corrupt,
                "kept {keep}"
            );
            assert_absent(&output);
            assert_eq!(
                b.state_bytes(CHAT_X),
                before,
                "state untouched after {keep}"
            );
        }

        // The complete container then receives normally — no `Replay`.
        fs::write(&sealed, &pristine).unwrap();
        let mut ticket = b
            .core
            .prepare_file_receive(CHAT_X.into(), sealed_text)
            .unwrap();
        run(&mut ticket, &output).unwrap();
        assert_eq!(fs::read(&output).unwrap(), plaintext);
    }

    #[test]
    fn directories_are_io_on_both_sides_and_spend_nothing() {
        let mut a = Device::new();
        let mut b = Device::new();
        pair(&mut a, &mut b, CHAT_X);

        let dir = a.path("a_folder");
        fs::create_dir(&dir).unwrap();
        let dir_text = dir.to_string_lossy().into_owned();
        let a_before = a.state_bytes(CHAT_X);
        assert_eq!(
            a.core
                .prepare_file_send(CHAT_X.into(), dir_text.clone())
                .err()
                .unwrap(),
            CoreError::Io
        );
        assert_eq!(a.state_bytes(CHAT_X), a_before, "no step spent");

        let b_before = b.state_bytes(CHAT_X);
        assert_eq!(
            b.core
                .prepare_file_receive(CHAT_X.into(), dir_text)
                .err()
                .unwrap(),
            CoreError::Io
        );
        assert_eq!(b.state_bytes(CHAT_X), b_before, "no step spent");
        assert_absent(&b.path("out.bin"));
    }

    #[test]
    fn forward_secrecy_for_files() {
        // After the file key message is used, the Olm key is destroyed: the key
        // message is unrecoverable even from the raw session, not merely refused.
        let mut a = Device::new();
        let mut b = Device::new();
        pair(&mut a, &mut b, CHAT_X);

        let sealed = send(&mut a, CHAT_X, "fs.bin", &pattern(300));
        let olm = {
            let header = crate::files::peek_header(&sealed).unwrap();
            let FileKeyMode::Chat { olm_type, olm_body } = header.key_mode else {
                unreachable!()
            };
            match olm_type {
                OlmType::PreKey => vodozemac::olm::OlmMessage::PreKey(
                    vodozemac::olm::PreKeyMessage::from_bytes(&olm_body).unwrap(),
                ),
                OlmType::Normal => vodozemac::olm::OlmMessage::Normal(
                    vodozemac::olm::Message::from_bytes(&olm_body).unwrap(),
                ),
            }
        };

        let out = b.path("out.bin");
        let mut ticket = b
            .core
            .prepare_file_receive(CHAT_X.into(), sealed.to_string_lossy().into_owned())
            .unwrap();
        run(&mut ticket, &out).unwrap();

        // The raw session can no longer open the key message — the key is gone.
        let mut session = b
            .core
            .opened()
            .unwrap()
            .load_state(CHAT_X)
            .unwrap()
            .session()
            .unwrap()
            .unwrap();
        assert!(matches!(
            session.decrypt(&olm),
            Err(DecryptionError::MissingMessageKey(_))
        ));
    }

    #[test]
    fn ticket_is_one_shot() {
        let mut a = Device::new();
        let mut b = Device::new();
        pair(&mut a, &mut b, CHAT_X);

        let input = a.write_plain("os.bin", &pattern(200));
        let sealed = a.path("os.fuzz");
        let mut ticket = a
            .core
            .prepare_file_send(CHAT_X.into(), input.to_string_lossy().into_owned())
            .unwrap();
        run(&mut ticket, &sealed).unwrap();
        // A second run of the same ticket has nothing left to do.
        let sealed2 = a.path("os2.fuzz");
        assert_eq!(run(&mut ticket, &sealed2).unwrap_err(), CoreError::Internal);
        assert_absent(&sealed2);
    }

    #[test]
    fn rebound_key_message_is_corrupt() {
        // The file key rides in the header, but the chunks are AAD-bound to the
        // *exact* header bytes (nonce prefix included). Move the key message onto
        // a header with a different nonce prefix over the same chunks: the Olm
        // message still opens (the key is obtained), but chunk 0 fails its tag.
        let mut a = Device::new();
        let mut b = Device::new();
        pair(&mut a, &mut b, CHAT_X);

        let sealed = send(&mut a, CHAT_X, "orig.bin", &pattern(1000));
        let bytes = fs::read(&sealed).unwrap();
        let header = crate::files::peek_header(&sealed).unwrap();
        let FileKeyMode::Chat { olm_type, olm_body } = header.key_mode.clone() else {
            unreachable!()
        };
        let header_len = header.encode().unwrap().len();
        let chunks = &bytes[header_len..];

        // Same key message, a different nonce prefix → a different container.
        let rebound_header = FileHeader {
            chunk_size: header.chunk_size,
            nonce_prefix: [0x77; 19],
            key_mode: FileKeyMode::Chat { olm_type, olm_body },
        };
        let mut rebound = rebound_header.encode().unwrap();
        rebound.extend_from_slice(chunks);
        let rebound_path = b.path("rebound.fuzz");
        fs::write(&rebound_path, &rebound).unwrap();

        let out = b.path("out.bin");
        // prepare succeeds — the Olm message is valid and yields the key ...
        let mut ticket = b
            .core
            .prepare_file_receive(CHAT_X.into(), rebound_path.to_string_lossy().into_owned())
            .unwrap();
        // ... but the chunks, sealed under the original nonce prefix and AAD,
        // fail under the re-bound header.
        assert_eq!(run(&mut ticket, &out).unwrap_err(), CoreError::Corrupt);
        assert_absent(&out);
    }

    #[test]
    fn golden_header_chat_mode() {
        // Fixed nonce prefix and chunk size → fixed header bytes, except the Olm
        // body (and its u16 length), which is non-deterministic by nature.
        let mut a = Device::new();
        let mut b = Device::new();
        pair(&mut a, &mut b, CHAT_X);

        let setup = ChatFileSetup {
            chunk_size: CHUNK_SIZE,
            nonce_prefix: [
                0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0x9b, 0x9c, 0x9d,
                0x9e, 0x9f, 0xa0, 0xa1, 0xa2,
            ],
        };
        let (_key, header) = a
            .core
            .opened_mut()
            .unwrap()
            .with_state_mut(CHAT_X, |state| {
                crate::files::wrap_file_key(state, "report.pdf", &setup)
            })
            .unwrap();
        let bytes = header.encode().unwrap();

        // FUZZ 01 04 · key_mode 01 · chunk_size 00100000 · nonce_prefix(19).
        let fixed = "46555a5a010401\
                     00100000\
                     909192939495969798999a9b9c9d9e9fa0a1a2";
        assert_eq!(hex(&bytes[..6 + 1 + 4 + 19]), fixed);
        // olm_type ∈ {00, 01}, then the u16 length of the olm body, then the body.
        let olm_type = bytes[6 + 1 + 4 + 19];
        assert!(olm_type == 0x00 || olm_type == 0x01);
        let olm_len = u16::from_be_bytes([bytes[6 + 24 + 1], bytes[6 + 24 + 2]]) as usize;
        assert_eq!(
            bytes.len(),
            6 + 1 + 4 + 19 + 1 + 2 + olm_len,
            "olm body length pinned"
        );
    }

    #[test]
    fn tampered_chat_header_corrupt() {
        // Flip each byte of the container header in turn: either prepare fails
        // (the key message or the codec) or the subsequent run fails (the AAD),
        // and no output is ever produced. No flip panics.
        let mut a = Device::new();
        let mut b = Device::new();
        pair(&mut a, &mut b, CHAT_X);

        let sealed = send(&mut a, CHAT_X, "t.bin", &pattern(700));
        let pristine = fs::read(&sealed).unwrap();
        let header_len = crate::files::peek_header(&sealed)
            .unwrap()
            .encode()
            .unwrap()
            .len();

        let out = b.path("out.bin");
        for offset in 0..header_len {
            for mask in [0x01u8, 0x80] {
                let mut tampered = pristine.clone();
                tampered[offset] ^= mask;
                fs::write(&sealed, &tampered).unwrap();
                let sealed_text = sealed.to_string_lossy().into_owned();
                match b.core.prepare_file_receive(CHAT_X.into(), sealed_text) {
                    Err(_) => {}
                    Ok(mut ticket) => {
                        // prepare passed; the run must then reject (bad AAD/chunks).
                        assert!(
                            run(&mut ticket, &out).is_err(),
                            "header flip @{offset} mask {mask:#x} must be rejected"
                        );
                    }
                }
                assert_absent(&out);
            }
        }
    }

    #[test]
    fn fuzz_flips_on_the_key_message_never_panic_or_leak() {
        // Every single-byte flip of the Olm key message: prepare either yields a
        // key (then the unrelated chunks fail the AAD) or rejects, never panics,
        // never leaves an output behind.
        let mut a = Device::new();
        let mut b = Device::new();
        pair(&mut a, &mut b, CHAT_X);

        let sealed = send(&mut a, CHAT_X, "f.bin", &pattern(400));
        let pristine = fs::read(&sealed).unwrap();
        let header = crate::files::peek_header(&sealed).unwrap();
        let header_len = header.encode().unwrap().len();
        let FileKeyMode::Chat { olm_body, .. } = header.key_mode else {
            unreachable!()
        };
        // The olm body is the tail of the header: [header_len - olm_body.len() .. header_len).
        let olm_start = header_len - olm_body.len();

        let out = b.path("out.bin");
        for offset in olm_start..header_len {
            for bit in 0..8u8 {
                let mut tampered = pristine.clone();
                tampered[offset] ^= 1 << bit;
                fs::write(&sealed, &tampered).unwrap();
                // A flip may reject at prepare, or (Olm's canonicalisation
                // malleability — F2-4 review row 7) decode to the *same* key
                // message and pass prepare; either way the run then fails,
                // because the flipped header is every chunk's AAD. What must
                // always hold: no panic, and never an output on disk.
                match b
                    .core
                    .prepare_file_receive(CHAT_X.into(), sealed.to_string_lossy().into_owned())
                {
                    Err(_) => {}
                    Ok(mut ticket) => {
                        assert!(run(&mut ticket, &out).is_err(), "flip @{offset} bit {bit}");
                    }
                }
                assert_absent(&out);
            }
        }
    }

    /// Deterministic non-repeating bytes (xorshift), shared with `files.rs`.
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

    fn hex(bytes: &[u8]) -> String {
        bytes.iter().map(|b| format!("{b:02x}")).collect()
    }
}
