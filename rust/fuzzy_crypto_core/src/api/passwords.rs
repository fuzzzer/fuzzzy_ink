use zeroize::Zeroizing;

use crate::error::CoreError;
use crate::passwords;

/// Seals `text` under `password` as a paste-able `Fuzz/` string (0x05 blob:
/// Argon2id m=65536 t=4 p=1 recorded in the header, XChaCha20-Poly1305 with
/// the header as AAD). Every call draws a fresh salt and nonce.
pub fn password_seal_text(password: String, text: String) -> Result<String, CoreError> {
    let password = Zeroizing::new(password.into_bytes());
    passwords::seal_text(&password, &text)
}

/// Inverse of [`password_seal_text`]; whitespace from wrapping is ignored.
/// A wrong password and a tampered blob are both `WrongPassword` (the AEAD
/// cannot tell them apart); anything that is not a 0x05 is `UnsupportedFormat`.
pub fn password_open_text(password: String, blob: String) -> Result<String, CoreError> {
    let password = Zeroizing::new(password.into_bytes());
    passwords::open_text(&password, &blob)
}

/// [`password_seal_text`] for arbitrary bytes, as the binary 0x05 blob (the
/// vault's optional custom-password layer).
pub fn password_seal_bytes(password: String, bytes: Vec<u8>) -> Result<Vec<u8>, CoreError> {
    let password = Zeroizing::new(password.into_bytes());
    passwords::seal_bytes(&password, &bytes)
}

/// Inverse of [`password_seal_bytes`]; the same error rules as [`password_open_text`].
pub fn password_open_bytes(password: String, blob: Vec<u8>) -> Result<Vec<u8>, CoreError> {
    let password = Zeroizing::new(password.into_bytes());
    passwords::open_bytes(&password, &blob)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn text_and_bytes_round_trip_through_the_api() {
        let text = password_seal_text("pw".into(), "hello".into()).unwrap();
        assert_eq!(
            password_open_text("pw".into(), text.clone()).unwrap(),
            "hello"
        );
        assert_eq!(
            password_open_text("px".into(), text).unwrap_err(),
            CoreError::WrongPassword
        );

        let blob = password_seal_bytes("pw".into(), vec![0, 255, 7]).unwrap();
        assert_eq!(
            password_open_bytes("pw".into(), blob.clone()).unwrap(),
            [0, 255, 7]
        );
        assert_eq!(
            password_open_bytes("".into(), blob).unwrap_err(),
            CoreError::WrongPassword
        );
        assert_eq!(
            password_open_text("pw".into(), "Fuzz/".into()).unwrap_err(),
            CoreError::UnsupportedFormat
        );
    }
}
