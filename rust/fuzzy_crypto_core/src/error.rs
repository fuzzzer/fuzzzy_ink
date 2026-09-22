/// Every error the crypto core reports to Dart (plan §B.4, §B.7).
///
/// Exhaustive by design: frb translates it into a Dart `enum` the service maps
/// onto its own failures. Add a variant only when a feature needs one — never a
/// catch-all string for a case that already has a variant.
///
/// Every variant is payload-free on purpose: frb 2.13 emits a data-carrying enum
/// as a `freezed` sealed class, and `freezed` is not a dependency this app carries
/// (plan §7). The OS message of an `Io` failure therefore stays on the Rust side.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum CoreError {
    /// Unknown magic, version, type byte or text encoding — not a blob this build reads.
    #[error("unsupported format")]
    UnsupportedFormat,
    /// An Ed25519 signature over an invitation or acceptance did not verify.
    #[error("invalid signature")]
    InvalidSignature,
    /// The invitation's one-time key has already been consumed.
    #[error("invitation already used")]
    InvitationAlreadyUsed,
    /// The blob belongs to a different chat than the one it was pasted into.
    #[error("wrong chat")]
    WrongChat,
    /// The blob was already decrypted once.
    #[error("replay")]
    Replay,
    /// The blob's counter fell out of the acceptance window.
    #[error("too old")]
    TooOld,
    /// The bytes are structurally invalid or fail authentication.
    #[error("corrupt")]
    Corrupt,
    /// The password does not open the store, vault or blob.
    #[error("wrong password")]
    WrongPassword,
    /// The store has not been opened (or was closed) in this process.
    #[error("store locked")]
    StoreLocked,
    /// No state exists for the requested chat id.
    #[error("unknown chat")]
    UnknownChat,
    /// A file-system operation failed.
    #[error("io")]
    Io,
    /// A file job was cancelled by the user.
    #[error("cancelled")]
    Cancelled,
    /// An invariant the core relies on did not hold.
    #[error("internal")]
    Internal,
}
