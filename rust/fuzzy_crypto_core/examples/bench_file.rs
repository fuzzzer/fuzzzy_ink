//! Throughput of the 0x04 file container (plan §C, §H).
//!
//! `cargo run --release --example bench_file -- 16 1024` creates a 16 MiB and a
//! 1 GiB temp file, times a password-mode encrypt and decrypt under a fixed
//! 32-byte key (Argon2id skipped — this measures the STREAM loop and the disk,
//! not the KDF), prints MB/s per direction and deletes the temp files. Peak RSS
//! is the OS's to report: `/usr/bin/time -l` on macOS.

use std::env;
use std::error::Error;
use std::fs::{self, File};
use std::io::{Read, Write};
use std::path::Path;
use std::time::Instant;

use fuzzy_crypto_core::files::{decrypt_with_key, encrypt_with_key};
use sha2::{Digest, Sha256};

const MIB: u64 = 1 << 20;
const KEY: [u8; 32] = [0x42; 32];

fn main() -> Result<(), Box<dyn Error>> {
    let mut sizes: Vec<u64> = env::args()
        .skip(1)
        .map(|arg| arg.parse())
        .collect::<Result<_, _>>()?;
    if sizes.is_empty() {
        sizes = vec![16, 1024];
    }
    let dir = env::temp_dir().join(format!("fuzzy_crypto_core_bench_{}", std::process::id()));
    fs::create_dir_all(&dir)?;
    let result = run(&dir, &sizes);
    let _ = fs::remove_dir_all(&dir);
    result
}

fn run(dir: &Path, sizes: &[u64]) -> Result<(), Box<dyn Error>> {
    println!("{:>9} {:>14} {:>14}", "size", "encrypt", "decrypt");
    for &mib in sizes {
        let plain = dir.join(format!("plain_{mib}.bin"));
        let sealed = dir.join(format!("sealed_{mib}.fuzz"));
        let opened = dir.join(format!("opened_{mib}.bin"));
        let bytes = mib * MIB;
        fill(&plain, bytes)?;

        let started = Instant::now();
        encrypt_with_key(&KEY, &plain, &sealed)?;
        let encrypt_secs = started.elapsed().as_secs_f64();

        let started = Instant::now();
        decrypt_with_key(&KEY, &sealed, &opened)?;
        let decrypt_secs = started.elapsed().as_secs_f64();

        if digest(&plain)? != digest(&opened)? {
            return Err("round trip mismatch".into());
        }
        println!(
            "{:>5} MiB {:>9.0} MB/s {:>9.0} MB/s",
            mib,
            bytes as f64 / encrypt_secs / 1e6,
            bytes as f64 / decrypt_secs / 1e6
        );
        for path in [plain, sealed, opened] {
            fs::remove_file(path)?;
        }
    }
    Ok(())
}

/// Writes `bytes` of a non-constant pattern in 1 MiB pieces.
fn fill(path: &Path, bytes: u64) -> Result<(), Box<dyn Error>> {
    let mut piece = vec![0u8; MIB as usize];
    let mut state: u32 = 0x2545_F491;
    for byte in &mut piece {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        *byte = state as u8;
    }
    let mut file = File::create(path)?;
    let mut left = bytes;
    while left > 0 {
        let len = left.min(MIB) as usize;
        file.write_all(&piece[..len])?;
        left -= len as u64;
    }
    file.sync_all()?;
    Ok(())
}

fn digest(path: &Path) -> Result<[u8; 32], Box<dyn Error>> {
    let mut file = File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buffer = vec![0u8; MIB as usize];
    loop {
        let read = file.read(&mut buffer)?;
        if read == 0 {
            break;
        }
        hasher.update(&buffer[..read]);
    }
    Ok(hasher.finalize().into())
}
