> **HISTORICAL (pre-hardening).** This file describes the pure-Dart crypto stack — `KeyStorageRepository`, `reencryptAllKeys`, the salt + AES verification token, PBE under the app-lock password — all **removed in v1.0.0-rc.1** (F4-4). Kept as the design record of the chat-auth gate; the current gate (store key wrapped by Argon2id in the Rust core, one `rewrap` on password change) is `.agents/project_guide/architecture_state.md` §4. Do not implement anything from this file.

# Session Handoff — Vault & Auth UX Fixes
**Date:** 2026-05-09

## What Was Done

### 1. Vault Three-Dots Menu (✅ Complete)

**File:** `lib/src/app/ui/pages/main_shell_page/main_shell_page.dart`

Replaced the vault's direct lock icon button with a **⋮ (more_vert)** icon that opens a bottom sheet. Currently contains:
- **Lock Vault** — same lock functionality, now behind a modal

This pattern makes it easy to add more vault-level actions (export, settings, etc.) later.

---

### 2. "Disable Chat Protection" Bug Fix (✅ Complete)

**Root Cause:** Three problems combined to make the button appear broken:

1. **Silent empty-password rejection** — `_onDisableAuth()` returned silently when the first field was empty. User got zero feedback.
2. **Wrong success message** — The listener always showed "Chat Protection Enabled" regardless of what operation succeeded (enable, disable, change password, biometric toggle).
3. **Ambiguous field labels** — Both the first and second text fields were labeled "Password", making it unclear which one to fill for disable.

**Files Changed:**

| File | Change |
|---|---|
| `lib/src/fuzzy_auth/bloc/fuzzy_user_auth_preferences_cubit/fuzzy_user_auth_preferences_state.dart` | Added `AuthPreferencesAction` enum and `lastAction` field to state |
| `lib/src/fuzzy_auth/bloc/fuzzy_user_auth_preferences_cubit/fuzzy_user_auth_preferences_cubit.dart` | Each method tags its success emit with the correct `lastAction` |
| `lib/src/fuzzy_auth/ui/pages/fuzzy_user_auth_page/fuzzy_user_auth_page.dart` | Listener uses `switch` on `lastAction` for correct snackbar. `_onDisableAuth` shows snackbar on empty password. Field labels changed to "Current Password" / "New Password" |

**Localization keys added (EN / KA):**
- `chatAuthCurrentPassword` — "Current Password" / "მიმდინარე პაროლი"
- `chatAuthNewPassword` — "New Password" / "ახალი პაროლი"
- `chatAuthEnterPassword` — "Please enter your current password" / "გთხოვთ შეიყვანოთ მიმდინარე პაროლი"
- `vaultLockVault` — "Lock Vault" / "საცავის დაბლოკვა"

---

### 3. Vault Item List Reverted (User Decision)

The user reverted the file-action bottom sheet from `vault_item_list.dart`. The file is back to the original inline navigation pattern where all vault items go directly to the editor on tap.

---

## Outstanding / Must Verify

> **FVM could not install Flutter 3.24.3 during this session** (the toolchain of that era — removed in v1.0.0-rc.1, which moved the repo to Flutter 3.41.7 / Dart 3.11.5), so `dart analyze` and `flutter gen-l10n` could not be run. The generated localization files (`fuzzzy_ink_localizations.dart`, `_en.dart`, `_ka.dart`) were updated **manually**. The next session MUST run:
> ```bash
> fvm flutter gen-l10n
> fvm dart analyze lib/src/fuzzy_auth/ lib/src/app/
> ```

---

## Architecture Notes

### Auth Flow

```
FuzzyUserAuthPage
  └─ BlocConsumer<FuzzyUserAuthPreferencesCubit>
       ├─ listener: shows snackbar based on lastAction
       └─ builder: shows _ChangePasswordSection or _SetupPasswordSection
            based on context.watch<FuzzyAuthStore>().state.status

FuzzyUserAuthPreferencesCubit.disableAuth():
  1. verifyPassword(currentPassword)
  2. reencryptAllKeys(oldPassword → empty)
  3. _chatAuthRepository.disableAuth()      // clears secure storage
  4. _biometricAuthRepository.disable()
  5. _fuzzyAuthStore.checkAuthStatus()       // emits noAuthRequired → triggers UI rebuild
  6. emit(success, lastAction: disable)      // triggers listener snackbar
```

### Key State Types
- `FuzzyAuthStore` (global) — tracks `AuthStateStatus` (initial / noAuthRequired / locked / unlocking / authenticated)
- `FuzzyUserAuthPreferencesCubit` (page-scoped) — tracks `activationStatus` + `lastAction` for settings page operations
- `AuthPreferencesAction` enum — `none | enable | disable | changePassword | enableBiometric | disableBiometric`
