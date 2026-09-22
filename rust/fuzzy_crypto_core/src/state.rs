//! Per-chat state — the body of every sealed `<chat_id>.state` file (plan §B.6).
//!
//! `serde` here is for the file body only; nothing in this module is a wire
//! format. The Olm pickles are serialised as the structs vodozemac ships, never
//! through `AccountPickle::encrypt` (deterministic IV, 8-byte MAC — pitfall §F.12).

use std::io::{self, Write};

use serde::{Deserialize, Serialize};
use vodozemac::olm::{Account, AccountPickle, Session, SessionPickle};
use zeroize::{Zeroize, ZeroizeOnDrop, Zeroizing};

use crate::error::CoreError;

/// The state body version written into every file; anything else is `UnsupportedFormat`.
pub const STATE_FORMAT_VERSION: u8 = 1;

/// Serialises `value` as JSON into an **exactly sized** `Zeroizing` buffer.
///
/// `serde_json::to_vec` starts at 128 bytes and doubles, so for anything larger
/// it reallocates and each freed block keeps an unwiped partial copy of the
/// secret (a ~542 B account pickle reallocates three times; a 5×40-skipped-keys
/// state reaches > 30 KiB) — pitfall §F.11. Count the bytes with a
/// zero-allocation writer first, allocate once, then serialise into it, so the
/// only heap copy is the one `Zeroizing` wipes. Shared by `seal_state`,
/// [`ChatState::account`] and [`ChatState::session`] (F2-2 R1, F2-3 R4).
pub(crate) fn serialize_exact<T: Serialize>(value: &T) -> Result<Zeroizing<Vec<u8>>, CoreError> {
    struct Counter(usize);
    impl Write for Counter {
        fn write(&mut self, buf: &[u8]) -> io::Result<usize> {
            self.0 += buf.len();
            Ok(buf.len())
        }
        fn flush(&mut self) -> io::Result<()> {
            Ok(())
        }
    }

    let mut counter = Counter(0);
    serde_json::to_writer(&mut counter, value).map_err(|_| CoreError::Internal)?;
    let mut buffer = Zeroizing::new(Vec::with_capacity(counter.0));
    serde_json::to_writer(&mut *buffer, value).map_err(|_| CoreError::Internal)?;
    Ok(buffer)
}

/// Which side of the handshake this device took.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Zeroize)]
pub enum Role {
    Inviter,
    Accepter,
}

/// Everything the core remembers about one chat. Zeroised on drop; the two
/// pickles are skipped because vodozemac already zeroises the key material they
/// hold when they drop (plan §A.2).
#[derive(Serialize, Deserialize, ZeroizeOnDrop)]
pub struct ChatState {
    pub format_version: u8,
    pub role: Role,
    pub chat_id: String,
    #[zeroize(skip)]
    pub account: AccountPickle,
    #[zeroize(skip)]
    pub session: Option<SessionPickle>,
    pub our_ed25519: [u8; 32],
    pub peer_curve25519: Option<[u8; 32]>,
    pub peer_ed25519: Option<[u8; 32]>,
    pub send_counter: u64,
    pub recv_highest: u64,
    pub recv_seen_bitmap: u64,
    pub verified: bool,
    pub last_invitation: Option<Vec<u8>>,
    pub last_acceptance: Option<Vec<u8>>,
    /// Seals this chat's message history (owner decision D-1, F2-12): 32 random
    /// bytes drawn when the chat's own key material is created, never derived
    /// from the store key, so one chat's key opens no other chat's history.
    /// Wiped with the rest of the state; lives only inside the sealed file.
    pub history_key: [u8; 32],
}

impl ChatState {
    /// A freshly created chat: no session, no peer, nothing sent or received.
    pub fn new(
        role: Role,
        chat_id: String,
        account: AccountPickle,
        our_ed25519: [u8; 32],
        history_key: [u8; 32],
    ) -> Self {
        Self {
            format_version: STATE_FORMAT_VERSION,
            role,
            chat_id,
            account,
            session: None,
            our_ed25519,
            peer_curve25519: None,
            peer_ed25519: None,
            send_counter: 0,
            recv_highest: 0,
            recv_seen_bitmap: 0,
            verified: false,
            last_invitation: None,
            last_acceptance: None,
            history_key,
        }
    }

    /// The live Olm account behind the stored pickle. `AccountPickle` is not
    /// `Clone` and `Account::from_pickle` moves, so the copy goes through the
    /// pickle's serde form in a residue-free `Zeroizing` buffer (pitfalls §F.11,
    /// §F.12). Write the mutated account back with `account.pickle()`.
    pub fn account(&self) -> Result<Account, CoreError> {
        let json = serialize_exact(&self.account)?;
        let pickle: AccountPickle =
            serde_json::from_slice(&json).map_err(|_| CoreError::Internal)?;
        Ok(Account::from_pickle(pickle))
    }

    /// The live Olm session behind the stored pickle, or `None` for a chat that
    /// is not yet connected. `SessionPickle` is not `Clone` either, so the copy
    /// goes through the same residue-free serde path as [`account`](Self::account)
    /// (pitfalls §F.11, §F.12). Write the ratcheted session back with
    /// `session.pickle()`.
    pub fn session(&self) -> Result<Option<Session>, CoreError> {
        match &self.session {
            None => Ok(None),
            Some(pickle) => {
                let json = serialize_exact(pickle)?;
                let restored: SessionPickle =
                    serde_json::from_slice(&json).map_err(|_| CoreError::Internal)?;
                Ok(Some(Session::from_pickle(restored)))
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const CHAT_ID: &str = "6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d";

    #[test]
    fn account_serialises_into_an_exactly_sized_buffer() {
        let account = Account::new();
        let our_ed25519 = *account.ed25519_key().as_bytes();
        let state = ChatState::new(
            Role::Inviter,
            CHAT_ID.into(),
            account.pickle(),
            our_ed25519,
            [0x55; 32],
        );

        let body = serialize_exact(&state.account).unwrap();
        assert!(
            body.len() > 400,
            "an account pickle is ~542 B, enough to force reallocation: {} B",
            body.len()
        );
        assert_eq!(
            body.capacity(),
            body.len(),
            "the buffer is sized exactly and never reallocates"
        );

        // And `account()` reconstructs the same identity key.
        assert_eq!(
            *state.account().unwrap().ed25519_key().as_bytes(),
            our_ed25519
        );
        assert!(state.session().unwrap().is_none());
    }
}
