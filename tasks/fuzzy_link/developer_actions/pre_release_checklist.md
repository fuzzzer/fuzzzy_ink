# FuzzyLink — Pre-Release Checklist

> **Priority:** 🔴 Critical (before any app store submission)
> **Requires:** Real devices, both platforms tested

---

## Code Quality

- [ ] `fvm flutter analyze` — 0 issues
- [ ] `fvm flutter test` — all tests pass
- [ ] No `print()` statements left in FuzzyLink code (use `Logger` instead)
- [ ] No `TODO` comments remaining in FuzzyLink files (check with `grep -r "TODO" lib/src/core/services/fuzzy_link/`)

---

## Security Review

- [ ] **Auth gating works**: deep link tapped while app is locked → queues payload → auth → processes
- [ ] **Self-invitation blocked**: tapping your own invitation link shows error, doesn't create duplicate chat
- [ ] **Duplicate acceptance blocked**: tapping acceptance for already-connected chat shows "Already connected!"
- [ ] **Expired links rejected**: links past their `exp` timestamp show expiration message
- [ ] **Invalid/malformed links handled**: garbled URIs show "Invalid link" snackbar, don't crash
- [ ] **Unsupported version links handled**: future version links show "update required" message
- [ ] **No sensitive data in URI**: verify the `fuzzylink://` URI doesn't leak plaintext messages (only encrypted content + chat IDs)

---

## UX Verification

- [ ] **"Share as Link" buttons visible** on:
  - [ ] Chat Invitation page (alongside "Copy Fuzz")
  - [ ] Acceptance Export page (alongside "Copy Acceptance")
  - [ ] Connected Chat page — message share (alongside "Copy Fuzz")
- [ ] **Copy-paste flow still works**: the original "Copy Fuzz" / "Copy Acceptance" buttons are unchanged
- [ ] **Shareable content is hybrid**: shared text contains BOTH the `fuzzylink://` URI AND the raw fuzz text below a separator
- [ ] **Snackbar messages are localized**: switch device language to Georgian, verify all snackbar messages appear in Georgian

---

## Platform-Specific

### Android
- [ ] Intent filter in `AndroidManifest.xml` is correct
- [ ] `launchMode="singleTask"` set on main activity
- [ ] Test on Android 10+ (API 29+) — verify link opens app correctly
- [ ] Test on older Android (API 24-28) — verify backwards compatibility
- [ ] ProGuard/R8 doesn't strip `app_links` in release mode

### iOS
- [ ] `CFBundleURLTypes` in `Info.plist` is correct
- [ ] Test on iOS 15+ — verify link opens app
- [ ] Test on iOS 14 — verify backwards compatibility
- [ ] App doesn't crash when receiving malformed deep link in release mode

---

## Edge Cases to Manually Verify

- [ ] **Rapid-fire links**: tap 3 links in quick succession — app handles all without crash
- [ ] **Link while navigating**: tap a deep link while the user is mid-navigation (e.g., creating a new chat) — verify no navigation stack corruption
- [ ] **Very long payload**: generate a link with a large message payload (~10KB) — verify it doesn't truncate or crash
- [ ] **Link from browser**: type `fuzzylink://invite/...` in Safari/Chrome address bar — verify it opens the app
- [ ] **Link from messaging app**: share a `fuzzylink://` link via iMessage/WhatsApp/Telegram — verify tapping works

---

## Final Sign-Off

| Item | Verified By | Date |
|------|-------------|------|
| All manual tests passed (see `manual_device_testing.md`) | | |
| All platform configs verified (see `platform_config_verification.md`) | | |
| Security review complete | | |
| UX review complete | | |
| Ready for release | | |
