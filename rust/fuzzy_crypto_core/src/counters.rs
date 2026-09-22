//! The per-direction replay / ordering window (plan §B.4).
//!
//! Defence in depth behind Olm's own receiver chain. `recv_highest` is the
//! highest counter accepted so far and `recv_seen_bitmap` is a 64-bit record of
//! the last 64 counters: bit `i` marks counter `recv_highest - i`, so bit 0
//! marks `recv_highest` itself. A fresh chat starts `(0, 0)` — counter 0 has not
//! been seen yet — or `(0, 1)` when the handshake already occupied counter 0
//! (the inviter's B→A direction, F2-3).
//!
//! Olm stays the cryptographic authority and catches the real replays first;
//! this layer turns them into explicit `Replay` / `TooOld` signals and guards
//! against a state-restore bug replaying a counter. The window is 64 wide,
//! ≥ Olm's 40-key store, but the two are not the same shape: Olm's store is per
//! receiving *chain* and keeps a key until it is consumed, this window is per
//! *direction* and drops anything more than 63 behind the newest accepted
//! counter. So this layer can refuse (`TooOld`) a message Olm could still
//! decrypt — strictly safer, never the other way round (F2-4 review N1).

use crate::error::CoreError;

/// The window width in counters — one `u64` bitmap.
const WINDOW: u64 = 64;

/// Decides whether `counter` is a fresh receive against `(highest, bitmap)` and,
/// on acceptance, returns the advanced `(highest, bitmap)`. A counter already in
/// the window is `Replay`; one below it is `TooOld`. Pure — the caller commits
/// the returned pair to state only after every other check has passed.
pub(crate) fn accept(highest: u64, bitmap: u64, counter: u64) -> Result<(u64, u64), CoreError> {
    if counter > highest {
        // Slide the window up; the old highest keeps its bit, the new one takes bit 0.
        let shift = counter - highest;
        let bitmap = if shift >= WINDOW {
            1
        } else {
            (bitmap << shift) | 1
        };
        Ok((counter, bitmap))
    } else {
        let offset = highest - counter;
        if offset >= WINDOW {
            return Err(CoreError::TooOld);
        }
        let mask = 1u64 << offset;
        if bitmap & mask != 0 {
            return Err(CoreError::Replay);
        }
        Ok((highest, bitmap | mask))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn first_counter_zero_is_accepted_when_nothing_seen() {
        // Accepter's initial state: (0, 0) — counter 0 is still pending.
        assert_eq!(accept(0, 0, 0).unwrap(), (0, 1));
    }

    #[test]
    fn monotonic_sequence_shifts_the_window() {
        let (mut highest, mut bitmap) = (0, 1); // handshake occupied counter 0 (inviter)
        for counter in 1..=5 {
            let next = accept(highest, bitmap, counter).unwrap();
            highest = next.0;
            bitmap = next.1;
            assert_eq!(highest, counter);
            assert_eq!(bitmap & 1, 1, "the newest counter is always marked");
        }
        // counters 0..=5 are all marked.
        assert_eq!(bitmap, 0b11_1111);
    }

    #[test]
    fn replay_of_the_highest_is_rejected() {
        let (highest, bitmap) = accept(0, 0, 0).unwrap();
        assert_eq!(accept(highest, bitmap, 0).unwrap_err(), CoreError::Replay);
    }

    #[test]
    fn out_of_order_within_the_window_is_accepted_then_replay() {
        // Accept 5 first (window jumps), then backfill 1..=4, then 0.
        let (highest, bitmap) = accept(0, 0, 5).unwrap();
        assert_eq!(highest, 5);
        let mut bitmap = bitmap;
        for counter in [1, 2, 3, 4, 0] {
            let next = accept(highest, bitmap, counter).unwrap();
            assert_eq!(next.0, 5, "backfill never moves the highest");
            bitmap = next.1;
        }
        assert_eq!(bitmap, 0b11_1111, "0..=5 all marked");
        // Re-delivering any of them is a replay.
        for counter in 0..=5 {
            assert_eq!(accept(5, bitmap, counter).unwrap_err(), CoreError::Replay);
        }
    }

    #[test]
    fn counter_below_the_window_is_too_old() {
        // Highest 100, the window covers 37..=100; 36 fell off the bottom.
        assert_eq!(accept(100, u64::MAX, 36).unwrap_err(), CoreError::TooOld);
        assert_eq!(accept(100, 1, 37).unwrap(), (100, 1 | (1 << 63)));
    }

    #[test]
    fn a_large_forward_jump_resets_the_window_to_the_new_counter() {
        let (highest, bitmap) = accept(0, 1, 1_000).unwrap();
        assert_eq!((highest, bitmap), (1_000, 1));
        // Everything more than 64 behind the new highest is gone.
        assert_eq!(accept(1_000, 1, 900).unwrap_err(), CoreError::TooOld);
    }
}
