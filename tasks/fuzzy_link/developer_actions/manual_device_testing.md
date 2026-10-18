# FuzzyLink — Manual Device Testing

> **Priority:** 🔴 High
> **Requires:** Physical Android + iOS devices, two separate devices for full flow
> **Time estimate:** ~1-2 hours

---

## Prerequisites

1. Build and install the debug app on both devices:
   ```bash
   fvm flutter run -d <android-device-id>
   fvm flutter run -d <ios-device-id>
   ```

2. Prepare a way to send links between devices (AirDrop, Notes, email, Telegram, etc.)

3. Make sure both devices are on **the same build** so URI scheme versions match.

---

## Test Matrix

### A. Invitation Links

| # | Scenario | Steps | Expected | Android | iOS |
|---|----------|-------|----------|---------|-----|
| A1 | **Cold start** — tap invitation link with app killed | 1. On Device A, create a new chat → "Share as Link" the invitation. 2. Send link to Device B. 3. Kill the app on Device B. 4. Tap the `fuzzylink://invite/...` link on Device B. | App launches → navigates directly to Accept Invitation page with content pre-filled. | ⬜ | ⬜ |
| A2 | **Warm start** — tap invitation link with app in background | Same as A1, but keep the app running in background on Device B. | App foregrounds → navigates to Accept Invitation page. | ⬜ | ⬜ |
| A3 | **Self-invitation blocked** | On Device A, create a chat, "Share as Link", then tap the same link on Device A. | Shows "You can't accept your own invitation" snackbar. Does NOT navigate. | ⬜ | ⬜ |
| A4 | **Expired invitation** | Create an invitation, wait for expiration (or manually edit the `exp` field to be in the past), then tap. | Shows "This invitation link has expired" snackbar. | ⬜ | ⬜ |

### B. Acceptance Links

| # | Scenario | Steps | Expected | Android | iOS |
|---|----------|-------|----------|---------|-----|
| B1 | **Cold start** — tap acceptance link | 1. Device A creates chat, shares invitation. 2. Device B accepts, shares acceptance via link. 3. Kill app on Device A. 4. Tap acceptance link on Device A. | App launches → navigates to invitation page with acceptance pre-filled → completes handshake. | ⬜ | ⬜ |
| B2 | **Warm start** — acceptance link in foreground | Same as B1 but app is in background. | App foregrounds → navigates → completes handshake. | ⬜ | ⬜ |
| B3 | **Duplicate acceptance** | After B1 completes (chat is connected), tap the same acceptance link again. | Shows "Already connected!" snackbar. Does NOT re-handshake. | ⬜ | ⬜ |
| B4 | **Orphan acceptance** | Tap an acceptance link for a chat that doesn't exist locally (e.g., was deleted). | Shows "Chat not found for this acceptance link" snackbar. | ⬜ | ⬜ |

### C. Fuzz Message Links

| # | Scenario | Steps | Expected | Android | iOS |
|---|----------|-------|----------|---------|-----|
| C1 | **Cold start** — tap fuzz message link | 1. On Device A, send a message, tap "Share as Link". 2. Send link to Device B. 3. Kill app on Device B. 4. Tap link. | App launches → navigates to connected chat page with encrypted message pre-filled in input. | ⬜ | ⬜ |
| C2 | **Warm start** — fuzz link in foreground | Same as C1 but app is in background. | App foregrounds → navigates to chat with message pre-filled. | ⬜ | ⬜ |
| C3 | **Missing chat** | Tap a fuzz link for a chatId that doesn't exist locally. | Shows "Chat not found for this message link" snackbar. | ⬜ | ⬜ |

### D. Auth Gating

| # | Scenario | Steps | Expected | Android | iOS |
|---|----------|-------|----------|---------|-----|
| D1 | **Auth-gated cold start** | 1. Enable app lock (PIN/password). 2. Kill app. 3. Tap any `fuzzylink://` link. | App launches → shows auth page → after successful auth, navigates to the correct deep-linked page. | ⬜ | ⬜ |
| D2 | **Auth-gated warm start** | 1. Enable app lock. 2. Background app (it should lock). 3. Tap any `fuzzylink://` link. | App foregrounds → shows auth → after auth, processes the pending payload. | ⬜ | ⬜ |
| D3 | **Auth cancelled** | Same as D1, but dismiss/cancel the auth page. | Deep link payload stays queued. Next successful auth should process it. | ⬜ | ⬜ |

### E. Error & Edge Cases

| # | Scenario | Steps | Expected | Android | iOS |
|---|----------|-------|----------|---------|-----|
| E1 | **Invalid URI** | Open a browser and navigate to `fuzzylink://invite/garbage123`. | App opens → shows "Invalid or unsupported link" snackbar. | ⬜ | ⬜ |
| E2 | **Unsupported version** | Craft a link with `"v": 999` in the payload. | Shows "This link requires a newer version of Fuzzzy Ink" snackbar. | ⬜ | ⬜ |
| E3 | **Fallback text works** | Share an invitation via "Share as Link". On the receiving device, copy the raw fuzz text from the share (below the separator line) instead of tapping the link. Paste it into the manual accept flow. | Manual copy-paste flow still works as before. | ⬜ | ⬜ |
| E4 | **Non-fuzzylink URI** | Tap a regular `https://` link. | Fuzzzy Ink does NOT intercept it. System browser opens. | ⬜ | ⬜ |

---

## How to Test Links Without a Second Device

For quick smoke testing on a single device:

### Android
```bash
# Open a fuzzylink URI via adb
adb shell am start -a android.intent.action.VIEW -d "fuzzylink://invite/YOUR_PAYLOAD_HERE"
```

### iOS
```bash
# Open a fuzzylink URI via xcrun
xcrun simctl openurl booted "fuzzylink://invite/YOUR_PAYLOAD_HERE"
```

> ⚠️ **Note:** Simulator/emulator deep link handling may differ from real devices. Always do final validation on physical hardware.

---

## Quick Payload Generator (for testing)

To create a test payload for `adb`/`xcrun` testing:

```dart
// Run this in a Dart script or flutter test
import 'dart:convert';

void main() {
  final payload = base64Url.encode(utf8.encode(jsonEncode({
    'v': 1,
    't': 'inv',
    'I': base64.encode(utf8.encode('test-chat-id')),
    'P': base64.encode(utf8.encode('{"n":"abc","e":"def"}')),
    'exp': (DateTime.now().add(Duration(hours: 24)).millisecondsSinceEpoch ~/ 1000),
  })));
  print('fuzzylink://invite/$payload');
}
```

---

## Sign-Off

| Platform | Tester | Date | All Pass? |
|----------|--------|------|-----------|
| Android  |        |      |           |
| iOS      |        |      |           |
