//! Byte-exact test vectors for `documents/security/PROTOCOL.md` (F5-1).
//!
//! Every vector is built from fixed inputs — seeds, keys, salts, nonces, chat
//! id, text — through the same code paths production uses, with the
//! randomness injected via the crate's `*_with` hooks. The files live in
//! `documents/security/vectors/` next to the specification:
//!
//! * `<name>.hex`  — the bytes, lowercase hex, 32 bytes per line (`xxd -r -p`);
//! * `<name>.txt`  — the paste-able `Fuzz/` text where the vector is a wire blob;
//! * `<name>.json` — every input the vector was built from.
//!
//! [`committed_vectors_match`] runs in every `cargo test` and fails when the
//! codec, a constant or a crate drifts from what is committed. To (re)write the
//! files run `FUZZY_WRITE_VECTORS=1 cargo test --locked vectors::write_vectors`;
//! that test also proves a second generation is byte-identical.
//!
//! Only test-only paths know the fixed secrets here; nothing in this module is
//! reachable from the FFI (`rust_input: crate::api`) or from a release build.

use std::collections::BTreeSet;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::AtomicU8;

use serde_json::{json, Value};
use vodozemac::olm::Account;
use vodozemac::{Curve25519PublicKey, Curve25519SecretKey};
use zeroize::Zeroizing;

use crate::files::{self, FileSetup, JOB_RUNNING};
use crate::formats::{
    encode_text, Acceptance, ContentType, Direction, FileHeader, FileKeyBody, FileKeyMode,
    InnerHeader, Message, OlmType, CHUNK_SIZE, MIN_CHUNK_SIZE, SIGNATURE_LEN,
};
use crate::pairing;
use crate::passwords;
use crate::safety;
use crate::state::{serialize_exact, ChatState, Role};
use crate::store::{self, test_support::temp_dir, ARGON2_PARAMS};
use crate::vault;

/// Where the vectors live, relative to the crate: `<repo>/documents/security/vectors`.
const VECTORS_DIR: &str = "../../documents/security/vectors";
const WRITE_ENV: &str = "FUZZY_WRITE_VECTORS";

const CHAT_ID: &str = "6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d";
const PASSWORD: &[u8] = b"pw";
const SALT_11: [u8; 16] = [0x11; 16];
const NONCE_22: [u8; 24] = [0x22; 24];
const NONCE_44: [u8; 24] = [0x44; 24];
const STORE_KEY_33: [u8; 32] = [0x33; 32];
/// A chat's history key (F2-12) — random in production, fixed here.
const HISTORY_KEY_55: [u8; 32] = [0x55; 32];
const FILE_KEY_42: [u8; 32] = [0x42; 32];
const NONCE_PREFIX_90: [u8; 19] = [
    0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a, 0x9b, 0x9c, 0x9d, 0x9e, 0x9f,
    0xa0, 0xa1, 0xa2,
];
const SALT_A0: [u8; 16] = [
    0xa0, 0xa1, 0xa2, 0xa3, 0xa4, 0xa5, 0xa6, 0xa7, 0xa8, 0xa9, 0xaa, 0xab, 0xac, 0xad, 0xae, 0xaf,
];
/// A's account: Ed25519 seed, Curve25519 identity secret, one-time-key secret.
const A_SEEDS: (u8, u8, u8) = (0x01, 0x02, 0x03);
/// B's account: Ed25519 seed, Curve25519 identity secret (no one-time key).
const B_SEEDS: (u8, u8) = (0x04, 0x05);
/// Stands in for vodozemac's pre-key message, whose bytes are randomised.
const PREKEY_PLACEHOLDER: [u8; 5] = [0xa1, 0xa2, 0xa3, 0xa4, 0xa5];
const OLM_BODY_PLACEHOLDER: [u8; 4] = [0xde, 0xad, 0xbe, 0xef];
const FILE_OLM_BODY_PLACEHOLDER: [u8; 3] = [0xf1, 0xf2, 0xf3];
const SAFETY_KEY_A: [u8; 32] = {
    let mut key = [0u8; 32];
    let mut i = 0;
    while i < 32 {
        key[i] = i as u8;
        i += 1;
    }
    key
};
const SAFETY_KEY_B: [u8; 32] = {
    let mut key = [0u8; 32];
    let mut i = 0;
    while i < 32 {
        key[i] = 0xff - i as u8;
        i += 1;
    }
    key
};

/// One vector: its bytes and/or text, the inputs it was built from, and an
/// optional extra output file (the state file's decrypted body).
struct Vector {
    name: &'static str,
    bytes: Option<Vec<u8>>,
    text: Option<String>,
    inputs: Value,
    extra: Option<(String, Vec<u8>)>,
}

impl Vector {
    fn bytes(name: &'static str, bytes: Vec<u8>, inputs: Value) -> Self {
        Self {
            name,
            bytes: Some(bytes),
            text: None,
            inputs,
            extra: None,
        }
    }

    fn blob(name: &'static str, bytes: Vec<u8>, inputs: Value) -> Self {
        let text = encode_text(&bytes);
        Self {
            name,
            bytes: Some(bytes),
            text: Some(text),
            inputs,
            extra: None,
        }
    }

    /// Every file this vector owns, with its exact content.
    fn files(&self) -> Vec<(String, Vec<u8>)> {
        let mut files = Vec::new();
        if let Some(bytes) = &self.bytes {
            files.push((format!("{}.hex", self.name), hex_lines(bytes)));
        }
        if let Some(text) = &self.text {
            files.push((
                format!("{}.txt", self.name),
                format!("{text}\n").into_bytes(),
            ));
        }
        let mut inputs = serde_json::to_string_pretty(&self.inputs).expect("json inputs");
        inputs.push('\n');
        files.push((format!("{}.json", self.name), inputs.into_bytes()));
        if let Some((name, content)) = &self.extra {
            files.push((name.clone(), content.clone()));
        }
        files
    }
}

// ---------------------------------------------------------------------------
// Fixed accounts (vodozemac has no "from seed" constructor; its pickle is serde)
// ---------------------------------------------------------------------------

/// An account rebuilt from fixed secrets through the pickle's serde form
/// (`Ed25519KeypairPickle` = `SecretKeys::Normal(32 B)`, `Curve25519KeypairPickle`
/// = 32 B, one-time keys keyed by id) — the F2-3 fixed-key golden's trick.
fn fixed_account(signing: u8, dh: u8, one_time: Option<u8>) -> Account {
    let (next_key_id, private_keys) = match one_time {
        Some(seed) => (1, json!({ "0": vec![seed; 32] })),
        None => (0, json!({})),
    };
    let pickle = json!({
        "signing_key": { "Normal": vec![signing; 32] },
        "diffie_hellman_key": vec![dh; 32],
        "one_time_keys": {
            "next_key_id": next_key_id,
            "public_keys": {},
            "private_keys": private_keys,
        },
        "fallback_keys": { "key_id": 0, "fallback_key": null, "previous_fallback_key": null }
    });
    Account::from_pickle(serde_json::from_value(pickle).expect("account pickle"))
}

fn account_a() -> (Account, Curve25519PublicKey) {
    let (signing, dh, one_time) = A_SEEDS;
    let account = fixed_account(signing, dh, Some(one_time));
    let one_time_key = Curve25519PublicKey::from(&Curve25519SecretKey::from_slice(&[one_time; 32]));
    (account, one_time_key)
}

fn account_b() -> Account {
    let (signing, dh) = B_SEEDS;
    fixed_account(signing, dh, None)
}

fn ed25519(account: &Account) -> [u8; 32] {
    *account.ed25519_key().as_bytes()
}

// ---------------------------------------------------------------------------
// The vectors
// ---------------------------------------------------------------------------

fn all_vectors() -> Vec<Vector> {
    let (a, a_one_time_key) = account_a();
    let b = account_b();
    let a_ed = ed25519(&a);
    let b_ed = ed25519(&b);
    let argon2 = json!({
        "algorithm": "Argon2id v0x13",
        "m_cost_kib": ARGON2_PARAMS.m_cost,
        "t_cost": ARGON2_PARAMS.t_cost,
        "p_cost": ARGON2_PARAMS.p_cost,
        "output_len": 32,
    });

    let mut vectors = Vec::new();

    // --- pairing blobs ------------------------------------------------------

    let invitation = pairing::invitation_blob(&a, CHAT_ID, a_one_time_key).expect("invitation");
    vectors.push(Vector::blob(
        "invitation",
        invitation.clone(),
        json!({
            "chat_id": CHAT_ID,
            "a_ed25519_seed": hex(&[A_SEEDS.0; 32]),
            "a_curve25519_secret": hex(&[A_SEEDS.1; 32]),
            "a_one_time_key_secret": hex(&[A_SEEDS.2; 32]),
            "derived": {
                "a_curve25519": hex(&a.curve25519_key().to_bytes()),
                "a_ed25519": hex(&a_ed),
                "a_one_time_key": hex(&a_one_time_key.to_bytes()),
            },
            "signature": "Ed25519(a_ed25519_seed) over bytes[0 .. len-64], envelope included",
        }),
    ));

    let mut acceptance = Acceptance {
        chat_id: CHAT_ID.to_string(),
        b_curve25519: b.curve25519_key().to_bytes(),
        b_ed25519: b_ed,
        prekey_msg: PREKEY_PLACEHOLDER.to_vec(),
        signature: [0; SIGNATURE_LEN],
    };
    acceptance.signature = b
        .sign(acceptance.to_be_signed().expect("acceptance tbs"))
        .to_bytes();
    vectors.push(Vector::blob(
        "acceptance",
        acceptance.encode().expect("acceptance"),
        json!({
            "chat_id": CHAT_ID,
            "b_ed25519_seed": hex(&[B_SEEDS.0; 32]),
            "b_curve25519_secret": hex(&[B_SEEDS.1; 32]),
            "derived": {
                "b_curve25519": hex(&b.curve25519_key().to_bytes()),
                "b_ed25519": hex(&b_ed),
            },
            "prekey_msg": hex(&PREKEY_PLACEHOLDER),
            "prekey_msg_note": "placeholder — a real pre-key message is vodozemac's randomised \
                                output (282 bytes for the 116-byte handshake plaintext)",
            "signature": "Ed25519(b_ed25519_seed) over bytes[0 .. len-64], envelope included",
        }),
    ));

    vectors.push(Vector::blob(
        "message",
        Message {
            olm_type: OlmType::Normal,
            olm_body: OLM_BODY_PLACEHOLDER.to_vec(),
        }
        .encode()
        .expect("message"),
        json!({
            "olm_type": "0x01 Normal",
            "olm_body": hex(&OLM_BODY_PLACEHOLDER),
            "olm_body_note": "placeholder — a real body is vodozemac's `Message::to_bytes()`",
        }),
    ));

    // --- inner headers (Olm plaintexts) --------------------------------------

    let handshake = InnerHeader {
        chat_id: CHAT_ID.to_string(),
        sender_ed25519: b_ed,
        recipient_ed25519: a_ed,
        direction: Direction::BToA,
        counter: 0,
        content_type: ContentType::Handshake,
        body: Vec::new(),
    };
    vectors.push(Vector::bytes(
        "inner_header_handshake",
        handshake.encode().expect("handshake"),
        json!({
            "chat_id": CHAT_ID,
            "sender_ed25519": hex(&b_ed),
            "recipient_ed25519": hex(&a_ed),
            "direction": "0x01 B->A",
            "counter": 0,
            "content_type": "0x00 handshake",
            "body": "",
        }),
    ));

    let text = InnerHeader {
        chat_id: CHAT_ID.to_string(),
        sender_ed25519: a_ed,
        recipient_ed25519: b_ed,
        direction: Direction::AToB,
        counter: 7,
        content_type: ContentType::Text,
        body: b"hello".to_vec(),
    };
    vectors.push(Vector::bytes(
        "inner_header_text",
        text.encode().expect("text header"),
        json!({
            "chat_id": CHAT_ID,
            "sender_ed25519": hex(&a_ed),
            "recipient_ed25519": hex(&b_ed),
            "direction": "0x00 A->B",
            "counter": 7,
            "content_type": "0x01 text",
            "body": "hello",
        }),
    ));

    let file_key_body = FileKeyBody {
        file_key: Zeroizing::new(FILE_KEY_42),
        original_name: "report.pdf".to_string(),
    }
    .encode()
    .expect("file key body");
    vectors.push(Vector::bytes(
        "file_key_body",
        file_key_body.to_vec(),
        json!({
            "file_key": hex(&FILE_KEY_42),
            "original_name": "report.pdf",
        }),
    ));

    let file_key = InnerHeader {
        chat_id: CHAT_ID.to_string(),
        sender_ed25519: a_ed,
        recipient_ed25519: b_ed,
        direction: Direction::AToB,
        counter: 8,
        content_type: ContentType::FileKeyEnvelope,
        body: file_key_body.to_vec(),
    };
    vectors.push(Vector::bytes(
        "inner_header_file_key",
        file_key.encode().expect("file key header"),
        json!({
            "chat_id": CHAT_ID,
            "sender_ed25519": hex(&a_ed),
            "recipient_ed25519": hex(&b_ed),
            "direction": "0x00 A->B",
            "counter": 8,
            "content_type": "0x02 file key envelope",
            "body": "file_key_body.hex",
        }),
    ));

    // --- KDF, wrapping, seals -----------------------------------------------

    let kek = store::derive_kek(PASSWORD, &SALT_11, ARGON2_PARAMS).expect("kek");
    vectors.push(Vector::bytes(
        "argon2id_kek",
        kek.to_vec(),
        json!({
            "password": "pw",
            "salt": hex(&SALT_11),
            "argon2": argon2,
        }),
    ));

    vectors.push(Vector::bytes(
        "wrapped_store_key",
        store::wrap_store_key_with(&STORE_KEY_33, PASSWORD, SALT_11, NONCE_22).expect("wrap"),
        json!({
            "store_key": hex(&STORE_KEY_33),
            "password": "pw",
            "salt": hex(&SALT_11),
            "nonce": hex(&NONCE_22),
            "argon2": argon2,
            "aad": "store-key",
        }),
    ));

    vectors.push(Vector::bytes(
        "wrapped_vault_key",
        vault::wrap_with(&STORE_KEY_33, PASSWORD, SALT_11, NONCE_22).expect("vault wrap"),
        json!({
            "vault_master_key": hex(&STORE_KEY_33),
            "password": "pw",
            "salt": hex(&SALT_11),
            "nonce": hex(&NONCE_22),
            "argon2": argon2,
            "aad": "vault-key",
        }),
    ));

    vectors.push(Vector::bytes(
        "local_seal_chat",
        store::seal_local_with(&HISTORY_KEY_55, CHAT_ID, b"hello", NONCE_44).expect("history seal"),
        json!({
            "history_key": hex(&HISTORY_KEY_55),
            "chat_id": CHAT_ID,
            "nonce": hex(&NONCE_44),
            "aad": format!("local-seal{CHAT_ID}"),
            "plaintext": "hello",
        }),
    ));

    vectors.push(Vector::bytes(
        "vault_item",
        vault::seal_item_with(&STORE_KEY_33, b"item", NONCE_44).expect("vault item"),
        json!({
            "vault_master_key": hex(&STORE_KEY_33),
            "nonce": hex(&NONCE_44),
            "aad": "vault-item",
            "plaintext": "item",
        }),
    ));

    vectors.push(Vector::blob(
        "password_sealed_text",
        passwords::seal_bytes_with(PASSWORD, b"hello", ARGON2_PARAMS, SALT_11, NONCE_22)
            .expect("0x05"),
        json!({
            "password": "pw",
            "salt": hex(&SALT_11),
            "nonce": hex(&NONCE_22),
            "argon2": argon2,
            "key": "argon2id_kek.hex",
            "aad": "the blob's first 31 bytes: FUZZ 01 05 | salt | m | t | p",
            "plaintext": "hello",
        }),
    ));

    // --- state file ---------------------------------------------------------

    let mut state = ChatState::new(
        Role::Inviter,
        CHAT_ID.to_string(),
        a.pickle(),
        a_ed,
        HISTORY_KEY_55,
    );
    state.last_invitation = Some(invitation);
    let body = serialize_exact(&state).expect("state body");
    vectors.push(Vector {
        name: "state_file",
        bytes: Some(store::seal_state_with(&STORE_KEY_33, &state, NONCE_44).expect("state")),
        text: None,
        inputs: json!({
            "store_key": hex(&STORE_KEY_33),
            "nonce": hex(&NONCE_44),
            "aad": format!("chat-state{CHAT_ID}"),
            "state": "a freshly invited chat on A's fixed account (invitation.hex), no session",
            "history_key": hex(&HISTORY_KEY_55),
            "plaintext": "state_file.body.json",
        }),
        extra: Some(("state_file.body.json".to_string(), body.to_vec())),
    });

    // --- files ----------------------------------------------------------------

    let password_setup = FileSetup {
        chunk_size: CHUNK_SIZE,
        nonce_prefix: NONCE_PREFIX_90,
        salt: SALT_A0,
        params: ARGON2_PARAMS,
    };
    let password_header = FileHeader {
        chunk_size: CHUNK_SIZE,
        nonce_prefix: NONCE_PREFIX_90,
        key_mode: FileKeyMode::Password {
            salt: SALT_A0,
            params: ARGON2_PARAMS,
        },
    };
    vectors.push(Vector::bytes(
        "file_header_password",
        password_header.encode().expect("password header"),
        json!({
            "key_mode": "0x02 password",
            "chunk_size": CHUNK_SIZE,
            "nonce_prefix": hex(&NONCE_PREFIX_90),
            "salt": hex(&SALT_A0),
            "argon2": argon2,
        }),
    ));

    vectors.push(Vector::bytes(
        "file_header_chat",
        FileHeader {
            chunk_size: CHUNK_SIZE,
            nonce_prefix: NONCE_PREFIX_90,
            key_mode: FileKeyMode::Chat {
                olm_type: OlmType::PreKey,
                olm_body: FILE_OLM_BODY_PLACEHOLDER.to_vec(),
            },
        }
        .encode()
        .expect("chat header"),
        json!({
            "key_mode": "0x01 chat",
            "chunk_size": CHUNK_SIZE,
            "nonce_prefix": hex(&NONCE_PREFIX_90),
            "olm_type": "0x00 PreKey",
            "olm_body": hex(&FILE_OLM_BODY_PLACEHOLDER),
            "olm_body_note": "placeholder — a real body is vodozemac's `PreKeyMessage::to_bytes()` \
                              of an inner header with content type 0x02 (inner_header_file_key.hex)",
        }),
    ));

    let fox = b"The quick brown fox jumps over the lazy dog";
    let container = {
        let dir = temp_dir();
        let input = dir.join("fox.txt");
        let output = dir.join("fox.fuzz");
        fs::write(&input, fox).expect("write plaintext");
        files::encrypt_with_password(
            PASSWORD,
            &password_setup,
            &input,
            &output,
            &AtomicU8::new(JOB_RUNNING),
            &mut |_| {},
        )
        .expect("password container");
        let container = fs::read(&output).expect("read container");
        let _ = fs::remove_dir_all(&dir);
        container
    };
    vectors.push(Vector::bytes(
        "file_container_password",
        container,
        json!({
            "header": "file_header_password.hex",
            "password": "pw",
            "file_key": "Argon2id(pw, salt a0..af) — same parameters as argon2id_kek.hex, other salt",
            "plaintext": String::from_utf8_lossy(fox),
            "chunks": "one chunk, sealed with the last flag: nonce = prefix | 00000000 | 01, \
                       aad = header (55 bytes) | 00000000",
        }),
    ));

    let two_chunk_plaintext = xorshift_pattern(MIN_CHUNK_SIZE as usize + 5);
    let container = {
        let dir = temp_dir();
        let input = dir.join("pattern.bin");
        let output = dir.join("pattern.fuzz");
        fs::write(&input, &two_chunk_plaintext).expect("write plaintext");
        let header = FileHeader {
            chunk_size: MIN_CHUNK_SIZE,
            nonce_prefix: NONCE_PREFIX_90,
            key_mode: FileKeyMode::Password {
                salt: SALT_A0,
                params: ARGON2_PARAMS,
            },
        };
        files::encrypt_chunks(
            &FILE_KEY_42,
            &header,
            &input,
            &output,
            &AtomicU8::new(JOB_RUNNING),
            &mut |_| {},
        )
        .expect("fixed-key container");
        let container = fs::read(&output).expect("read container");
        let _ = fs::remove_dir_all(&dir);
        container
    };
    vectors.push(Vector::bytes(
        "file_container_fixed_key",
        container,
        json!({
            "key": hex(&FILE_KEY_42),
            "key_note": "the bench path: the header still records salt a0..af and the Argon2 \
                         parameters, but the key was supplied directly — no password opens it",
            "chunk_size": MIN_CHUNK_SIZE,
            "nonce_prefix": hex(&NONCE_PREFIX_90),
            "salt": hex(&SALT_A0),
            "argon2": argon2,
            "plaintext": format!(
                "{} bytes of xorshift64 (state 0x9e3779b97f4a7c15; x ^= x<<13, x ^= x>>7, \
                 x ^= x<<17; low byte per step)",
                two_chunk_plaintext.len()
            ),
            "chunks": "chunk 0 (65536 bytes): nonce = prefix | 00000000 | 00, aad = header | 00000000; \
                       chunk 1 (5 bytes, last): nonce = prefix | 00000001 | 01, aad = header | 00000001",
        }),
    ));

    // --- safety number ------------------------------------------------------

    vectors.push(Vector {
        name: "safety_number",
        bytes: None,
        text: Some(safety::safety_number_for(
            CHAT_ID,
            &SAFETY_KEY_A,
            &SAFETY_KEY_B,
        )),
        inputs: json!({
            "chat_id": CHAT_ID,
            "key_1": hex(&SAFETY_KEY_A),
            "key_2": hex(&SAFETY_KEY_B),
            "digest": "SHA-512(\"FUZZZYINK_SAFETY_NUMBER_V1\" | 0x00 | chat_id | 0x00 | min(key_1, key_2) | max(key_1, key_2))",
            "encoding": "12 groups: big-endian u40 of digest[5i .. 5i+5] mod 100000, zero-padded to 5 digits, space-joined",
        }),
        extra: None,
    });

    vectors
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|byte| format!("{byte:02x}")).collect()
}

/// Lowercase hex, 32 bytes per line, newline-terminated.
fn hex_lines(bytes: &[u8]) -> Vec<u8> {
    let mut out = String::with_capacity(bytes.len() * 2 + bytes.len() / 32 + 1);
    for line in bytes.chunks(32) {
        out.push_str(&hex(line));
        out.push('\n');
    }
    out.into_bytes()
}

/// The `files::tests` xorshift pattern: deterministic, non-repeating bytes.
fn xorshift_pattern(len: usize) -> Vec<u8> {
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

fn vectors_dir() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join(VECTORS_DIR)
}

/// Every file the vectors own, sorted by name.
fn expected_files() -> Vec<(String, Vec<u8>)> {
    let mut files: Vec<_> = all_vectors().iter().flat_map(Vector::files).collect();
    files.sort_by(|a, b| a.0.cmp(&b.0));
    files
}

fn write_mode() -> bool {
    std::env::var_os(WRITE_ENV).is_some_and(|value| value == "1")
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

/// Writes every vector under `documents/security/vectors/` — only when
/// `FUZZY_WRITE_VECTORS=1`; a plain `cargo test` leaves the files alone. A
/// second generation must reproduce the written bytes exactly.
#[test]
fn write_vectors() {
    if !write_mode() {
        return;
    }
    let dir = vectors_dir();
    fs::create_dir_all(&dir).expect("vectors dir");
    let written = expected_files();
    for (name, content) in &written {
        fs::write(dir.join(name), content).expect("write vector");
    }
    let again = expected_files();
    assert_eq!(
        written, again,
        "a second generation must be byte-identical to the first"
    );
    println!("wrote {} files to {}", written.len(), dir.display());
}

/// The committed vectors are what this build produces — every `.hex`, `.txt`
/// and `.json`, byte for byte, and no file the generator does not own.
#[test]
fn committed_vectors_match() {
    let dir = vectors_dir();
    let expected = expected_files();
    let mut failures = Vec::new();
    for (name, content) in &expected {
        match fs::read(dir.join(name)) {
            Ok(on_disk) if on_disk == *content => {}
            Ok(_) => failures.push(format!("{name}: differs from this build's output")),
            Err(error) => failures.push(format!("{name}: {error}")),
        }
    }
    let owned: BTreeSet<&str> = expected.iter().map(|(name, _)| name.as_str()).collect();
    let on_disk: BTreeSet<String> = fs::read_dir(&dir)
        .expect("vectors dir")
        .map(|entry| {
            entry
                .expect("dir entry")
                .file_name()
                .to_string_lossy()
                .into_owned()
        })
        .filter(|name| name != "README.md")
        .collect();
    for stray in on_disk.iter().filter(|name| !owned.contains(name.as_str())) {
        failures.push(format!("{stray}: not produced by the generator"));
    }
    assert!(
        failures.is_empty(),
        "documents/security/vectors drifted (run `{WRITE_ENV}=1 cargo test --locked \
         vectors::write_vectors` after a deliberate format change):\n{}",
        failures.join("\n")
    );
}
