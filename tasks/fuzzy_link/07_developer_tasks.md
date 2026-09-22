# 👤 Developer Tasks — Remaining Manual Steps

> All design decisions are resolved. What remains are testing and post-ship tasks.

---

## Resolved Decisions (for reference)

| Decision | Resolution |
|----------|------------|
| URI scheme name | `fuzzylink://` |
| Deep link package | `app_links` (^6.4.0) |
| GoRouter migration | Full migration — all `Navigator.push` replaced |
| iOS bundle identifier | `com.fuzzzycore.seal` |
| Payload expiration | 24h for invitations & acceptances, no expiration for fuzz messages |
| QR code support | Deferred to V2 |
| Georgian translations | Core keys added in both EN + KA |

---

## ⬜ Remaining Tasks

### 1. Test Deep Links on Physical Devices — 🔴 HIGH

Deep links behave differently on real devices vs simulators. This is the **primary remaining work**.

**→ Full test matrix:** `tasks/developer_actions/manual_device_testing.md`

**Quick smoke test commands:**
```bash
# Android (via adb)
adb shell am start -a android.intent.action.VIEW \
  -d "fuzzylink://invite/YOUR_PAYLOAD" \
  com.fuzzzycore.seal

# iOS (via simulator)
xcrun simctl openurl booted "fuzzylink://invite/YOUR_PAYLOAD"

# macOS
open "fuzzylink://invite/YOUR_PAYLOAD"
```

### 2. Verify App Icon / Launch Screen — 🟡 MEDIUM

When a user taps a FuzzyLink, the app launches with the current splash screen. Verify it looks good as a "first impression" moment.

### 3. Update Store Listing / Privacy Policy — 🟢 LOW (Post-Ship)

- Update App Store/Play Store description to mention deep link feature
- Ensure privacy policy covers `fuzzylink://` URL scheme handling (no data collected)
