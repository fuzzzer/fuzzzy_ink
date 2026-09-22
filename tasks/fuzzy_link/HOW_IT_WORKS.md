# 🔗 FuzzyLink — How It Works

> A concise guide to the FuzzyLink deep link system in Fuzzzy Seal.

---

## What Is FuzzyLink?

FuzzyLink turns encrypted Fuzzzy Seal data (invitations, acceptances, messages) into **tappable links**. Instead of copy-pasting encrypted blobs between apps, users share links that auto-open Fuzzzy Seal and process the payload.

```
Before: 6 manual copy-pastes to connect
After:  3 taps. Zero pasting.
```

**Key principle:** FuzzyLink does NOT break offline-first. It changes the *format* of shared data (raw text → URI), not the security model. No servers, no HTTP, no network calls.

---

## Three Link Types

| Type | URI | Contains | When Tapped |
|------|-----|----------|-------------|
| Invitation | `fuzzylink://invite/<payload>` | Chat ID + RSA public key | Opens acceptance page (pre-filled) |
| Acceptance | `fuzzylink://accept/<payload>` | Chat ID + public key + encrypted symmetric key | Completes handshake → opens chat |
| Fuzz Message | `fuzzylink://fuzz/<payload>` | Chat ID + encrypted message | Opens chat with message pre-filled |

**Payload format:** JSON → UTF-8 → Base64URL, appended to the URI path.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  Platform (Android/iOS/macOS)                                │
│  Intent filter / CFBundleURLTypes → fuzzylink:// scheme      │
└──────────────────┬───────────────────────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────────────────────┐
│  FuzzyLinkService  (lib/src/core/services/fuzzy_link/)       │
│  Wraps `app_links` package                                   │
│  • getInitialLink() — cold start                             │
│  • onLinkReceived   — warm start stream                      │
└──────────────────┬───────────────────────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────────────────────┐
│  FuzzyLinkHandler                                            │
│  1. Parse URI → FuzzyLinkPayload (via FuzzyLinkParser)       │
│  2. Validate: version, expiration, structure                 │
│  3. Auth gate: if locked → queue payload, process after auth │
│  4. Route: invitation/acceptance/fuzz → correct page via     │
│     GoRouter (AppRouter.routerInstance)                       │
│  5. Edge cases: self-invite, duplicate acceptance, missing   │
│     chat → localized snackbar messages                       │
└──────────────────┬───────────────────────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────────────────────┐
│  GoRouter (AppRouter)                                        │
│  9 routes, all pages use `context.push/go`                   │
│  Deep link payloads passed via GoRouter's `extra` parameter  │
└──────────────────────────────────────────────────────────────┘
```

---

## Widget Tree Integration

```dart
App
 └─ GlobalBlocProviders        // provides FuzzyAuthStore
     └─ GlobalBlocListeners    // listens for auth → processPendingPayload()
         └─ FuzzyLinkListener  // initializes FuzzyLinkHandler on mount
             └─ MaterialApp.router(routerConfig: AppRouter.router(...))
```

- **FuzzyLinkListener** — `StatefulWidget` that calls `handler.initialize()` in `initState` and `handler.dispose()` in `dispose`.
- **GlobalBlocListeners** — has a `BlocListener<FuzzyAuthStore>` that calls `handler.processPendingPayload()` when auth transitions from `initial` → `authenticated`.

---

## Auth Gating Flow

```
Link arrives → _isAppLocked()?
  ├─ NO  → process immediately
  └─ YES → store in _pendingPayload
           User completes auth →
           GlobalBlocListeners detects auth success →
           calls processPendingPayload() →
           processes queued link
```

---

## Sharing Flow (Outbound)

When a user taps "Share as Link":

1. `FuzzyLinkGenerator.generateInvitationLink(content)` creates the `fuzzylink://` URI
2. `FuzzyLinkGenerator.generateShareableContent(...)` wraps it in hybrid text:
   ```
   🔐 Fuzzzy Seal Invitation
   
   Tap to connect:
   fuzzylink://invite/eyJ2...
   
   ────────────────────
   Can't tap? Copy and paste into Fuzzzy Seal:
   {"I":"aGVsbG8t...","P":"eyJuIjoi..."}
   ```
3. `Share.share(shareableText)` opens the native share sheet

The hybrid format ensures both link-capable and non-link-capable platforms work.

---

## Security Validation Chain

Every incoming link passes through:

1. **Scheme check** — must be `fuzzylink://`
2. **Type validation** — path must be `invite`, `accept`, or `fuzz`
3. **Base64URL decode** — wrapped in try-catch
4. **JSON parse** — validates structure and required fields
5. **Version check** — `v > currentVersion` → "update required"
6. **Expiration check** — `exp` field for invite/accept (24h TTL)
7. **Self-invitation check** — compares chat ID against local chats
8. **Duplicate acceptance check** — verifies chat isn't already connected

Any failure → localized snackbar, no crash.

---

## Key Files

| File | Role |
|------|------|
| `lib/src/core/services/fuzzy_link/fuzzy_link_handler.dart` | Brain — receives, validates, routes links |
| `lib/src/core/services/fuzzy_link/fuzzy_link_parser.dart` | URI → `FuzzyLinkPayload` |
| `lib/src/core/services/fuzzy_link/fuzzy_link_generator.dart` | Data → URI + shareable text |
| `lib/src/core/services/fuzzy_link/fuzzy_link_service.dart` | `app_links` wrapper |
| `lib/src/core/services/fuzzy_link/components/fuzzy_link_payload.dart` | Sealed class: 3 payload subtypes |
| `lib/src/core/services/fuzzy_link/components/fuzzy_link_type.dart` | Enum: `invitation`, `acceptance`, `fuzz` |
| `lib/src/app/app_router.dart` | GoRouter config, `routerInstance` for handler |
| `lib/src/app/components/fuzzy_link_listener.dart` | Lifecycle widget wrapping `MaterialApp` |
| `lib/src/core/dependency_injection.dart` | Registers `FuzzyLinkService` + `FuzzyLinkHandler` |

---

## For Security Details

**→ See:** `tasks/05_security_analysis.md` — full threat model, 6 attack vectors analyzed, all mitigated.
