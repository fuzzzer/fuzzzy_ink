# Security Policy

Fuzzzy Ink is an offline encryption app: it has no servers, no accounts and no network path of its own.
Its security is the security of the code in this repository — the Rust cryptographic core
(`rust/fuzzy_crypto_core`), the Flutter app around it, and the release builds we publish.

## Supported versions

| Version | Supported |
|---|---|
| `main` branch | Yes |
| Latest release (`v*` tag) | Yes — fixes ship as a new release |
| Older releases | No — please update |

## Reporting a vulnerability

Please do **not** open a public issue for a security problem.

1. **GitHub private vulnerability reporting** (preferred):
   <https://github.com/fuzzzy-bot/fuzzy_chat/security/advisories/new>.
   The form is enabled on the repository (2026-09-13); it keeps the report private until a fix ships.
2. **Email:** <contact@fuzzzycore.com>. A dedicated `security@fuzzzycore.com` mailbox is planned
   and will be listed here and in `security.txt` once its mail route exists.

There is no PGP key yet. If you need to send something confidential, say so in a first plain
email and we will agree on a channel.

Please include the release or commit you tested, the platform, steps to reproduce, and what an
attacker gains. A minimal proof of concept helps; running it against anyone but yourself does not.

## What happens next

- We acknowledge the report within **3 business days** and give you a first assessment within **10 days**.
- We aim to release a fix within **90 days** of the report (coordinated disclosure). If we need more
  time we will tell you why and agree a new date; if a fix ships earlier, disclosure moves earlier too.
- You will be credited in the release notes unless you prefer not to be.
- **EU Cyber Resilience Act.** For a vulnerability that is being actively exploited, we follow the
  CRA reporting timeline that applies since 2026-09-11: an early warning within **24 hours** of becoming
  aware, a notification within **72 hours**, and a final report within **14 days** of a fix being
  available. The Act's full obligations apply from 2027-12-11.

## Scope

In scope:

- the Rust core — pairing, ratchet, message and file encryption, key storage, password formats
  (`rust/fuzzy_crypto_core`, documented in `documents/security/PROTOCOL.md`);
- the Flutter app (`lib/`), including how it stores keys, history and vault items on each platform;
- the build and release pipeline (`.github/workflows/main.yaml`) and the published artifacts.

Out of scope:

- the `development` flavor's file-encryption benchmark tile and its Marionette test instrumentation
  — neither exists in a release build;
- vulnerabilities in third-party dependencies with no Fuzzzy Ink-specific impact (report them
  upstream; a note to us is still welcome);
- attacks that require a compromised or rooted device, or physical access to an unlocked one —
  see the threat model for what the app does and does not defend against.

## Safe harbour

Research done in good faith within this policy — on your own devices and data, without degrading
anyone else's — is authorised. We will not pursue or support legal action against you for it, and
we will not ask you to withhold a report after the fix has shipped and the disclosure date has passed.

## Related documents

- Protocol and wire formats: `documents/security/PROTOCOL.md`
- Threat model: `documents/security/THREAT_MODEL.md`
- Software bills of materials: `documents/security/sbom/rust.cdx.json`, `documents/security/sbom/flutter.cdx.json`
  (regenerated and checked on every CI run by `./sbom.sh`)
- `security.txt` (RFC 9116): `documents/security/security.txt`, served at
  <https://fuzzzycore.com/.well-known/security.txt>
