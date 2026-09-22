/// The crate version, so Dart can prove the bridge is alive.
pub fn core_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

/// Reverses `bytes` — a trivial round trip that proves byte vectors cross the FFI intact.
pub fn round_trip(bytes: Vec<u8>) -> Vec<u8> {
    bytes.into_iter().rev().collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn core_version_matches_cargo() {
        assert_eq!(core_version(), env!("CARGO_PKG_VERSION"));
        assert!(!core_version().is_empty());
    }

    #[test]
    fn round_trip_reverses_bytes() {
        assert_eq!(round_trip(vec![1, 2, 3]), vec![3, 2, 1]);
        assert_eq!(round_trip(Vec::new()), Vec::<u8>::new());
    }
}
