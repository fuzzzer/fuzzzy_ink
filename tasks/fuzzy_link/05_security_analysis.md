# 🔐 Security Analysis — FuzzyLink Threat Model

> This document analyzes the security implications of adding deep link support to Fuzzzy Seal, an offline-first encryption app.

---

## Core Security Principle

> **FuzzyLinks carry the exact same data that users currently copy-paste manually.** The deep link feature changes only the **transport format** (URI instead of raw text), not the **security model**.

This is the most important thing to understand: FuzzyLinks don't weaken security — they just make the existing flow more ergonomic.

---

## 1. Threat Model

### 1.1 Attack: Link Interception (Man-in-the-Middle)

**Scenario:** Attacker intercepts the link while it's being transmitted between users.

**Risk Analysis:**

| Link Type | Data Exposed | Impact |
|-----------|-------------|--------|
| Invitation link | Chat ID + sender's RSA public key | 🟡 Low — public key is *designed* to be public. Chat ID is a UUID with no meaningful info |
| Acceptance link | Chat ID + acceptor's public key + RSA-encrypted symmetric key | 🟢 Minimal — encrypted symmetric key can't be used without sender's private key (stored locally) |
| Fuzz message link | Chat ID + AES-encrypted message | 🟢 Minimal — encrypted message can't be read without the symmetric key (stored locally) |

**Verdict:** Same risk as current copy-paste approach. No degradation.

**Mitigation:** The encryption itself is the mitigation. This is by design — the whole point of Fuzzzy Seal is that the encrypted data is safe to share over any channel.

---

### 1.2 Attack: Replay Attack

**Scenario:** Attacker captures an invitation/acceptance link and replays it later.

**Analysis:**

| Attack | Result |
|--------|--------|
| Replay invitation link | Victim would see InvitationAcceptancePage — but they'd need to manually name the chat and click Accept. If they already have a chat with that sender, they'd see a duplicate name warning |
| Replay acceptance link | Chat ID won't match any pending invitation on the victim's device → "No matching invitation found" error |
| Replay fuzz message link | If chat exists: message is decrypted and added again. Same encrypted content → duplicate message (detectable) |

**Mitigations:**
- Chat name uniqueness check prevents invisible duplicates
- Acceptance links require a matching pending chat ID — can't be replayed against random users
- For fuzz messages: add a message timestamp/nonce in the payload to detect duplicates

**Enhancement (recommended):**
```dart
// Add to fuzz message payload:
{
  "v": 1,
  "t": "fuz",
  "c": "<chat_id>",
  "m": "<encrypted_message>",
  "ts": 1714660060  // Unix timestamp — used for duplicate detection
}
```

---

### 1.3 Attack: Payload Tampering

**Scenario:** Attacker modifies the link payload before it reaches the recipient.

**Analysis:**

| Tampered Field | Result |
|---------------|--------|
| Chat ID | Modified chat ID won't match any local chat → error |
| Public key | Modified public key will cause key mismatch → handshake fails → error |
| Encrypted symmetric key | Modified key can't be decrypted by sender's private key → error |
| Encrypted message | Modified message can't be AES-decrypted → garbled output or decryption failure |

**Verdict:** Cryptographic integrity provides implicit tamper detection. Any modification results in a failure, not a silent corruption.

**Enhancement (recommended for V2):**
Add an HMAC signature to the payload for explicit tamper detection:
```json
{
  "v": 2,
  "t": "fuz",
  "c": "<chat_id>",
  "m": "<encrypted_message>",
  "sig": "<HMAC-SHA256 of payload, keyed with symmetric key>"
}
```
This allows the recipient to verify the message wasn't modified before attempting decryption.

---

### 1.4 Attack: Malicious Link Injection (Phishing)

**Scenario:** Attacker crafts a malicious `fuzzylink://` URL to exploit the app.

**Mitigations:**

1. **Strict payload validation:** Parser validates JSON structure, required fields, and data types before processing
2. **Try-catch on all crypto operations:** Malformed keys/data cause caught exceptions, not crashes
3. **No code execution from payload:** Payloads are pure data (JSON with base64 strings) — no executable content
4. **User confirmation before action:** Invitation links show a confirmation page before accepting (user must name the chat and tap Accept)
5. **No automatic data exfiltration:** Processing a link only affects local storage — no outbound network calls

**Implementation:**
```dart
static FuzzyLinkPayload? parse(Uri uri) {
  try {
    // 1. Validate scheme
    if (uri.scheme != 'fuzzylink') return null;
    
    // 2. Validate type
    final type = FuzzyLinkType.fromUriSegment(uri.host);
    if (type == null) return null;
    
    // 3. Validate payload structure
    final json = _safeDecodePayload(uri.pathSegments.firstOrNull);
    if (json == null) return null;
    
    // 4. Validate version
    final version = json['v'] as int?;
    if (version == null || version > currentVersion) return null;
    
    // 5. Validate required fields per type
    return _validateAndParse(type, json);
  } catch (_) {
    return null; // Any parsing error → invalid link
  }
}
```

---

### 1.5 Attack: URI Scheme Hijacking

**Scenario:** A malicious app registers the same `fuzzylink://` custom scheme and intercepts links intended for Fuzzzy Seal.

**Risk:** On Android, multiple apps can register the same custom scheme. The OS shows a disambiguation dialog. On iOS, behavior is undefined (last-installed app wins in some cases).

**Mitigations:**

1. **Short-term (custom scheme):**
   - Use a distinctive scheme: `fuzzylink` is unlikely to collide
   - The intercepting app can't do anything useful with the encrypted payload (no keys)
   - Users will see a disambiguation dialog and can choose the correct app

2. **Long-term (if needed):**
   - Migrate to Android App Links (`https://fuzzzyseal.app/.well-known/assetlinks.json`) + iOS Universal Links
   - This requires hosting a domain but provides verified app association
   - **Only pursue this if scheme hijacking becomes a real-world concern**

**Verdict:** Low risk for a privacy-focused niche app. Custom scheme is sufficient for the initial release.

---

### 1.6 Attack: Clipboard Snooping (Comparison)

**Interesting note:** Deep links are actually **more secure** than the current copy-paste approach!

| Method | Clipboard Exposure | Risk |
|--------|-------------------|------|
| Copy-paste (current) | Encrypted text sits in clipboard — accessible to any app with clipboard access | 🟡 Medium |
| Deep link (new) | Data goes directly to Fuzzzy Seal via OS intent — never touches clipboard | 🟢 Low |

**FuzzyLinks reduce clipboard exposure**, which is a meaningful privacy improvement on platforms where apps can read the clipboard (notably pre-Android 12 and pre-iOS 14).

---

## 2. Security Decisions

### 2.1 Do We Need HTTPS Universal Links?

**No — not for the initial release.** Custom URI schemes (`fuzzylink://`) are sufficient because:

1. The payloads are already encrypted — interception is useless
2. No server infrastructure aligns with offline-first philosophy
3. URI scheme hijacking is a theoretical risk, not a practical one for this app's audience
4. Universal links require domain hosting (infrastructure cost + complexity)

**Revisit if:** Fuzzzy Seal gains mainstream adoption and custom scheme collision becomes a real issue.

### 2.2 Do We Need End-to-End Signing?

**Not for V1.** The existing RSA/AES encryption provides implicit tamper detection. An explicit HMAC signature is a V2 enhancement.

### 2.3 Do We Need a Payload Expiration?

**Recommended for invitations and acceptances:**

```json
{
  "v": 1,
  "t": "inv",
  "I": "...",
  "P": "...",
  "exp": 1714746460  // Expires 24 hours after generation
}
```

- Invitation links: expire after 24 hours (configurable)
- Acceptance links: expire after 24 hours
- Fuzz message links: no expiration (messages are timeless)

**Benefits:**
- Reduces window for replay attacks
- Encourages timely key exchange (good operational security practice)
- Clear UX: "This invitation has expired. Ask the sender to create a new one."

### 2.4 Should Fuzz Links Contain the Chat ID?

**Yes, but with a consideration:** The chat ID is a UUID that means nothing outside the app. It doesn't reveal user identity, chat name, or content. It's only used to look up the correct symmetric key locally.

An attacker who sees the chat ID in a fuzz link can't:
- Determine who's chatting
- Correlate it with any external identity
- Use it to decrypt anything without the local key

**Safe to include in plaintext in the URI.**

---

## 3. Security Implementation Checklist

| # | Item | Priority | Phase |
|---|------|----------|-------|
| 1 | Strict payload validation (type, version, fields) | 🔴 Critical | Phase 0 |
| 2 | Try-catch on all parsing and crypto operations | 🔴 Critical | Phase 0 |
| 3 | User confirmation before processing invitation links | 🔴 Critical | Phase 2 |
| 4 | Auth-gated deep link processing (pending payload queue) | 🔴 Critical | Phase 1 |
| 5 | Self-invitation detection (can't accept your own invite) | 🟡 High | Phase 2 |
| 6 | Duplicate acceptance detection | 🟡 High | Phase 3 |
| 7 | Payload expiration for invitations/acceptances | 🟢 Recommended | Phase 2/3 |
| 8 | Message deduplication (timestamp/nonce) | 🟢 Recommended | Phase 4 |
| 9 | HMAC signing (V2) | 🔵 Future | V2 |
| 10 | Universal Links migration (if needed) | 🔵 Future | V2+ |

---

## 4. Summary

| Question | Answer |
|----------|--------|
| Does FuzzyLink weaken Fuzzzy Seal's security? | **No** — same data, different format |
| Does it introduce network dependencies? | **No** — zero network calls |
| Does it require server infrastructure? | **No** — custom URI scheme, no domain needed |
| Is it more secure than copy-paste? | **Yes** — avoids clipboard exposure |
| Are there new attack surfaces? | **Minimal** — URI scheme hijacking (low risk), phishing (mitigated by validation) |
| Is the offline-first principle preserved? | **100%** |
