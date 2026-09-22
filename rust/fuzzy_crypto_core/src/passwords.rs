//! Password-sealed blobs (0x05, plan §B.4/§D) — the Basics text primitive and
//! the vault's optional custom-password layer. The construction is the store
//! key's (`store::derive_kek` is the only Argon2id entry, `store::seal`/`open`
//! the only AEAD); what differs is the AAD, which binds the ciphertext to the
//! blob's own header so a pasted blob cannot be re-typed and the cost
//! parameters it records cannot be swapped without failing the tag.
//!
//! The header is attacker-controlled input (anything pasted into Basics):
//! `derive_kek` refuses `m`/`t` past its caps before allocating a block.

use crate::error::CoreError;
use crate::formats::{self, Argon2Params, PasswordSealed, ENVELOPE_LEN};
use crate::store::{self, ARGON2_PARAMS};

/// Bytes of a 0x05 blob that are authenticated as AAD: the outer envelope, the
/// salt and the three Argon2 cost fields (`FUZZ 01 05 · salt16 · m · t · p`).
/// The nonce that follows is bound by the AEAD itself.
const AAD_LEN: usize = ENVELOPE_LEN + 16 + 9;

/// Seals `bytes` under `password` with a fresh salt and nonce, recording
/// `ARGON2_PARAMS` in the header.
pub fn seal_bytes(password: &[u8], bytes: &[u8]) -> Result<Vec<u8>, CoreError> {
    seal_bytes_with(
        password,
        bytes,
        ARGON2_PARAMS,
        store::random_array()?,
        store::random_array()?,
    )
}

/// [`seal_bytes`] with the parameters and randomness supplied — the golden
/// test pins the output and the fuzz tests use cheap parameters.
pub(crate) fn seal_bytes_with(
    password: &[u8],
    bytes: &[u8],
    params: Argon2Params,
    salt: [u8; 16],
    nonce: [u8; 24],
) -> Result<Vec<u8>, CoreError> {
    let key = store::derive_kek(password, &salt, params)?;
    let mut blob = PasswordSealed {
        salt,
        params,
        nonce,
        ciphertext: Vec::new(),
    }
    .encode();
    let ciphertext = {
        let aad = blob.get(..AAD_LEN).ok_or(CoreError::Internal)?;
        store::seal(&key, &nonce, aad, bytes)?
    };
    blob.extend_from_slice(&ciphertext);
    Ok(blob)
}

/// Inverse of [`seal_bytes`]. A tag failure is `WrongPassword`: the AEAD cannot
/// tell a wrong password from a tampered blob, and the password is the only
/// input the user controls (the same rule as the wrapped store key). A blob
/// that is not a 0x05 is `UnsupportedFormat`; a truncated one, or a header
/// whose cost parameters are unusable, is `Corrupt`.
pub fn open_bytes(password: &[u8], blob: &[u8]) -> Result<Vec<u8>, CoreError> {
    let sealed = PasswordSealed::decode(blob)?;
    // The AAD is the blob's own bytes, not a re-encode of the parsed header.
    let aad = blob.get(..AAD_LEN).ok_or(CoreError::Corrupt)?;
    let key = store::derive_kek(password, &sealed.salt, sealed.params)?;
    store::open(&key, &sealed.nonce, aad, &sealed.ciphertext).map_err(|_| CoreError::WrongPassword)
}

/// `Fuzz/` + base64url of [`seal_bytes`] over the UTF-8 text.
pub fn seal_text(password: &[u8], text: &str) -> Result<String, CoreError> {
    Ok(formats::encode_text(&seal_bytes(
        password,
        text.as_bytes(),
    )?))
}

/// Inverse of [`seal_text`]; whitespace inside the pasted text is ignored.
/// Plaintext that is not UTF-8 (a [`seal_bytes`] blob opened as text) is `Corrupt`.
pub fn open_text(password: &[u8], text: &str) -> Result<String, CoreError> {
    let blob = formats::decode_text(text)?;
    String::from_utf8(open_bytes(password, &blob)?).map_err(|_| CoreError::Corrupt)
}

#[cfg(test)]
mod tests {
    use std::time::Instant;

    use super::*;
    use crate::formats::{decode_envelope, encode_text, BlobKind};

    const PASSWORD: &[u8] = b"pw";
    /// Cheap Argon2id for the many-KDF tests; the header carries it, so `open`
    /// honours it. Production blobs always record `ARGON2_PARAMS` (golden test).
    const FAST_PARAMS: Argon2Params = Argon2Params {
        m_cost: 8 * 1024,
        t_cost: 1,
        p_cost: 1,
    };
    const SALT: [u8; 16] = [0x11; 16];
    const NONCE: [u8; 24] = [0x22; 24];

    /// Derived independently in Python from the spec tables (argon2-cffi +
    /// pycryptodome; scratchpad `f41/golden_f41.py`): password `pw`, salt
    /// `0x11×16`, nonce `0x22×24`, production parameters, text `hello`.
    const GOLDEN_0X05_HEX: &str = concat!(
        "46555a5a0105",
        "11111111111111111111111111111111",
        "000100000000000401",
        "222222222222222222222222222222222222222222222222",
        "91c48d95f987aa35578db22b73cdc5acb4d91f7283",
    );
    const GOLDEN_0X05_TEXT: &str = concat!(
        "Fuzz/RlVaWgEFEREREREREREREREREREREQABAAAAAAAEASIiIiIiIiIiIiIiIiIiIiIi",
        "IiIiIiIiIpHEjZX5h6o1V42yK3PNxay02R9ygw",
    );

    fn hex(text: &str) -> Vec<u8> {
        (0..text.len())
            .step_by(2)
            .map(|i| u8::from_str_radix(&text[i..i + 2], 16).unwrap())
            .collect()
    }

    fn fast_blob(bytes: &[u8]) -> Vec<u8> {
        seal_bytes_with(PASSWORD, bytes, FAST_PARAMS, SALT, NONCE).unwrap()
    }

    #[test]
    fn seal_open_text_round_trip() {
        let started = Instant::now();
        let text = seal_text(PASSWORD, "hello").unwrap();
        let sealed_in = started.elapsed();
        assert!(text.starts_with("Fuzz/"));
        let (kind, _) = decode_envelope(&formats::decode_text(&text).unwrap()).unwrap();
        assert_eq!(kind, BlobKind::PasswordSealed);

        let started = Instant::now();
        assert_eq!(open_text(PASSWORD, &text).unwrap(), "hello");
        let opened_in = started.elapsed();
        println!("password_seal_text: {sealed_in:?}, password_open_text: {opened_in:?} (one Argon2id run each)");

        // Fresh salt and nonce every time: two seals of the same text differ.
        assert_ne!(seal_text(PASSWORD, "hello").unwrap(), text);
        // Empty text and empty password are valid.
        assert_eq!(open_text(b"", &seal_text(b"", "").unwrap()).unwrap(), "");
    }

    #[test]
    fn seal_open_bytes_round_trip() {
        let bytes: Vec<u8> = (0..=255).collect();
        let blob = seal_bytes(PASSWORD, &bytes).unwrap();
        assert_eq!(blob.len(), 6 + 16 + 9 + 24 + bytes.len() + 16);
        assert_eq!(open_bytes(PASSWORD, &blob).unwrap(), bytes);
        // Non-UTF-8 plaintext cannot be opened as text.
        assert_eq!(
            open_text(PASSWORD, &encode_text(&blob)).unwrap_err(),
            CoreError::Corrupt
        );
    }

    #[test]
    fn wrong_password_rejected() {
        let blob = fast_blob(b"secret text");
        assert_eq!(
            open_bytes(b"px", &blob).unwrap_err(),
            CoreError::WrongPassword
        );
        assert_eq!(
            open_bytes(b"", &blob).unwrap_err(),
            CoreError::WrongPassword
        );
        assert_eq!(
            open_text(b"PW", &encode_text(&blob)).unwrap_err(),
            CoreError::WrongPassword
        );
        assert_eq!(open_bytes(PASSWORD, &blob).unwrap(), b"secret text");
    }

    #[test]
    fn golden_0x05() {
        let blob = seal_bytes_with(PASSWORD, b"hello", ARGON2_PARAMS, SALT, NONCE).unwrap();
        assert_eq!(blob, hex(GOLDEN_0X05_HEX));
        assert_eq!(encode_text(&blob), GOLDEN_0X05_TEXT);
        // The independently made blob opens here — pins the KDF parameters, the
        // AAD definition and the layout against a second implementation.
        assert_eq!(
            open_bytes(PASSWORD, &hex(GOLDEN_0X05_HEX)).unwrap(),
            b"hello"
        );
        assert_eq!(open_text(PASSWORD, GOLDEN_0X05_TEXT).unwrap(), "hello");
        // Production blobs record m=65536 t=4 p=1 in the header.
        let fresh = seal_bytes(PASSWORD, b"x").unwrap();
        assert_eq!(&fresh[22..31], &hex("000100000000000401")[..]);
    }

    #[test]
    fn whitespace_tolerant_and_kind_checked() {
        let wrapped_text = GOLDEN_0X05_TEXT
            .chars()
            .enumerate()
            .map(|(i, c)| {
                if i % 20 == 19 {
                    format!("{c}\r\n ")
                } else {
                    c.to_string()
                }
            })
            .collect::<String>();
        assert_eq!(open_text(PASSWORD, &wrapped_text).unwrap(), "hello");

        // Not a 0x05: a wrapped store key, a local seal, garbage, no prefix.
        let mut retyped = hex(GOLDEN_0X05_HEX);
        retyped[5] = 0x10;
        assert_eq!(
            open_bytes(PASSWORD, &retyped).unwrap_err(),
            CoreError::UnsupportedFormat
        );
        retyped[5] = 0x20;
        assert_eq!(
            open_text(PASSWORD, &encode_text(&retyped)).unwrap_err(),
            CoreError::UnsupportedFormat
        );
        assert_eq!(
            open_text(PASSWORD, "not a blob").unwrap_err(),
            CoreError::UnsupportedFormat
        );
        assert_eq!(
            open_bytes(PASSWORD, b"").unwrap_err(),
            CoreError::UnsupportedFormat
        );
    }

    #[test]
    fn params_authenticated() {
        // t_cost 4 → 5 (still under the cap): the KDF and the AAD both change → the tag fails.
        let mut blob = hex(GOLDEN_0X05_HEX);
        blob[29] ^= 0x01;
        assert_eq!(
            open_bytes(PASSWORD, &blob).unwrap_err(),
            CoreError::WrongPassword
        );
        // Parameters past the caps are refused before any block is allocated.
        let mut oversized = hex(GOLDEN_0X05_HEX);
        oversized[22..26].copy_from_slice(&u32::MAX.to_be_bytes());
        assert_eq!(
            open_bytes(PASSWORD, &oversized).unwrap_err(),
            CoreError::Corrupt
        );
        let mut too_many_passes = hex(GOLDEN_0X05_HEX);
        too_many_passes[26..30].copy_from_slice(&17u32.to_be_bytes());
        assert_eq!(
            open_bytes(PASSWORD, &too_many_passes).unwrap_err(),
            CoreError::Corrupt
        );
        let mut no_lanes = hex(GOLDEN_0X05_HEX);
        no_lanes[30] = 0;
        assert_eq!(
            open_bytes(PASSWORD, &no_lanes).unwrap_err(),
            CoreError::Corrupt
        );
    }

    #[test]
    fn unicode_text() {
        let text = "ქართული · 日本語 · emoji 🔐 · e\u{301} · \u{200b}";
        let blob = seal_text(PASSWORD, text).unwrap();
        assert_eq!(open_text(PASSWORD, &blob).unwrap(), text);
        let sealed = fast_blob(text.as_bytes());
        assert_eq!(open_text(PASSWORD, &encode_text(&sealed)).unwrap(), text);
    }

    /// Every truncation and every single-byte flip of a blob is an error, never
    /// a panic, and never a plaintext.
    #[test]
    fn truncate_and_flip_never_panic() {
        let blob = fast_blob(b"fuzz me");
        let mut outcomes = [0usize; 3];
        for len in 0..blob.len() {
            let error = open_bytes(PASSWORD, &blob[..len]).unwrap_err();
            let kind = match error {
                CoreError::UnsupportedFormat => 0,
                CoreError::Corrupt => 1,
                CoreError::WrongPassword => 2,
                other => panic!("unexpected {other:?} at length {len}"),
            };
            outcomes[kind] += 1;
        }
        // Envelope faults, structural faults and tag failures all occur.
        assert!(outcomes.iter().all(|count| *count > 0), "{outcomes:?}");

        for index in 0..blob.len() {
            let mut flipped = blob.clone();
            flipped[index] ^= 0x01;
            let error = open_bytes(PASSWORD, &flipped).unwrap_err();
            let expected: &[CoreError] = match index {
                0..=5 => &[CoreError::UnsupportedFormat],
                22..=30 => &[CoreError::WrongPassword, CoreError::Corrupt],
                _ => &[CoreError::WrongPassword],
            };
            assert!(expected.contains(&error), "byte {index}: {error:?}");
        }
        let mut extended = blob;
        extended.push(0);
        assert_eq!(
            open_bytes(PASSWORD, &extended).unwrap_err(),
            CoreError::WrongPassword
        );
    }
}
