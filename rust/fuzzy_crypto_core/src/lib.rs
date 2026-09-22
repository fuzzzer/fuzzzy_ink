// NEVER build this crate (or any CI job) with `--cfg fuzzing`: vodozemac's
// `Ed25519PublicKey::verify` becomes a no-op under it (`types/ed25519.rs`), so
// every invitation/acceptance signature would silently pass (F2-3 review nit 5).

pub mod api;
mod counters;
pub mod error;
pub mod files;
pub mod formats;
mod frb_generated;
pub mod messages;
pub mod pairing;
pub mod passwords;
pub mod safety;
pub mod state;
pub mod store;
pub mod vault;
#[cfg(test)]
mod vectors;
