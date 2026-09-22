> **HISTORICAL (pre-hardening).** This file describes the pure-Dart crypto stack — `KeyStorageRepository`, `reencryptAllKeys`, the salt + AES verification token, PBE under the app-lock password — all **removed in v1.0.0-rc.1** (F4-4). Kept as the design record of the chat-auth gate; the current gate (store key wrapped by Argon2id in the Rust core, one `rewrap` on password change) is `.agents/project_guide/architecture_state.md` §4. Do not implement anything from this file.

# TASK: Chat Authentication Gate — Finalize Implementation

**Status:** SUPERSEDED — historical, see banner (was: IN_PROGRESS, Doer phase ~70%)

---
### PLAN (by [PLANNER])

**Objective:** Enforce optional password-based authentication for chat access. Vault keeps its own separate password. Basic Encryption and Settings remain unprotected.

#### Phase 1 — Auth Gate (Router + Unlock UI) ✅ DONE
- [x] Create `ChatAuthRepository` — password setup/verify via salt + encrypted token in `FlutterSecureStorage`
- [x] Expand `AuthStateStatus` enum: `initial`, `noAuthRequired`, `locked`, `unlocking`, `authenticated`
- [x] Enhance `FuzzyAuthState` with `copyWith` + `verificationFailed`
- [x] Rewrite `FuzzyAuthStore` cubit: `checkAuthStatus()`, `unlock()`, `lock()`, `onPasswordSetup()`, `changePassword()`
- [x] Create `ChatUnlockPage` (follows `VaultUnlockPage` pattern exactly)
- [x] Add GoRouter redirect: protected routes → `/chat-unlock` when `isLocked`
- [x] Add `BlocListener` for auth state transitions (navigate on unlock, redirect on lock)
- [x] Wire DI: `ChatAuthRepository` → `FuzzyAuthStore`, call `checkAuthStatus()` at startup
- [x] Simplify `FuzzyLinkHandler._isAppLocked()` to use new auth states
- [x] Add all l10n keys (en + ka): 18 chat auth keys

#### Phase 2 — Key Re-encryption with Crash Safety ✅ DONE
- [x] Add `reencryptAllKeys()` to `KeyStorageRepository` with two-phase commit staging
- [x] Add `recoverStagedMigration()` for crash recovery on startup
- [x] Add `changePassword()` to `ChatAuthRepository` — verify old, re-encrypt keys, update verification
- [x] Wire `recoverStagedMigration()` in DI startup

#### Phase 3 — Auth Settings Page ⚠️ IN PROGRESS
- [x] Rewrite `FuzzyUserAuthPage` UI — enable/change/disable password sections
- [ ] **Rewrite `FuzzyUserAuthPreferencesCubit`** — needs `enableAuth()`, `changePassword()`, `disableAuth()` methods
- [ ] Delete old `FuzzyUserAuthEmptyContent` and `FuzzyUserAuthLoadedContent` widgets (no longer used)
- [ ] Update `widgets.dart` barrel file to remove old widget exports

#### Phase 4 — Final Polish
- [ ] Run `fvm dart analyze` across the full project — fix any remaining issues
- [ ] Test the full flow: no-auth → enable → unlock → change password → disable
- [ ] Update `.agents/project_guide/architecture_state.md` with new auth architecture

---
### IMPLEMENTATION (by [DOER])

#### Files Created
| File | Purpose |
|------|---------|
| `lib/src/fuzzy_auth/data/repositories/chat_auth_repository.dart` | Password setup, verify, change, disable via `FlutterSecureStorage` |
| `lib/src/fuzzy_auth/ui/pages/chat_unlock_page/chat_unlock_page.dart` | Lock screen UI with shake animation |

#### Files Modified
| File | Change |
|------|--------|
| `lib/src/fuzzy_auth/bloc/fuzzy_auth_store/components/auth_state_status.dart` | Expanded enum with 5 states + `hasAccess` getter |
| `lib/src/fuzzy_auth/bloc/fuzzy_auth_store/fuzzy_auth_cubit.dart` | Full lifecycle: check → unlock → lock → changePassword |
| `lib/src/fuzzy_auth/bloc/fuzzy_auth_store/fuzzy_auth_state.dart` | Added `copyWith`, `verificationFailed` |
| `lib/src/fuzzy_auth/data/repositories/repositories.dart` | Added `chat_auth_repository.dart` export |
| `lib/src/fuzzy_auth/ui/pages/pages.dart` | Added `chat_unlock_page` export |
| `lib/src/fuzzy_auth/ui/pages/fuzzy_user_auth_page/fuzzy_user_auth_page.dart` | **Rewritten** — full settings page with enable/change/disable sections |
| `lib/src/fuzzzy_seal/data/repositories/keys_repository/key_storage_repository.dart` | Added two-phase commit `reencryptAllKeys()` + `recoverStagedMigration()` |
| `lib/src/app/app_router.dart` | Added `/chat-unlock` route + auth redirect in `redirect()` |
| `lib/src/app/globals/global_bloc_listeners.dart` | Two auth listeners: unlock→home, lock→unlock page |
| `lib/src/app/globals/global_bloc_providers.dart` | Calls `checkAuthStatus()` on `FuzzyAuthStore` at startup |
| `lib/src/core/dependency_injection.dart` | Registered `ChatAuthRepository`, wired into `FuzzyAuthStore`, calls `recoverStagedMigration()` |
| `lib/src/core/services/fuzzy_link/fuzzy_link_handler.dart` | Removed `UserAuthPreferencesRepository` dep, simplified `_isAppLocked()` |
| `lib/src/core/l10n/app_en.arb` | 18 new `chatAuth*` / `chatUnlock*` keys |
| `lib/src/core/l10n/app_ka.arb` | Georgian translations for all 18 keys |

---
### WHAT REMAINS — Exact Steps for the Next AI

#### Step 1: Rewrite `FuzzyUserAuthPreferencesCubit`

**File:** `lib/src/fuzzy_auth/bloc/fuzzy_user_auth_preferences_cubit/fuzzy_user_auth_preferences_cubit.dart`

The old cubit only had `getUserAuthPreferences()` and a basic `activateAuth()`. It now needs:

```dart
// Required constructor dependencies:
// - ChatAuthRepository chatAuthRepository
// - ChatGeneralDataListRepository chatGeneralDataListRepository
// - KeyStorageRepository keyStorageRepository
// - FuzzyAuthStore fuzzyAuthStore

Future<void> enableAuth(String password) async {
  // 1. Get all chat IDs via chatGeneralDataListRepository.getAllChats()
  // 2. Call keyStorageRepository.reencryptAllKeys(chatIds, oldPassword: '', newPassword: password)
  //    (old password is '' because keys were "encrypted" with empty string before auth was enabled)
  // 3. Call chatAuthRepository.setupPassword(password)
  // 4. Call fuzzyAuthStore.onPasswordSetup(password)
  // 5. Emit success
}

Future<void> changePassword({required String oldPassword, required String newPassword}) async {
  // 1. Get all chat IDs
  // 2. Call fuzzyAuthStore.changePassword(oldPassword, newPassword, chatIds, keyStorageRepository)
  //    (this already verifies old password, re-encrypts keys, updates verification)
  // 3. Emit success or failure
}

Future<void> disableAuth(String currentPassword) async {
  // 1. Verify current password via chatAuthRepository.verifyPassword()
  // 2. Get all chat IDs
  // 3. Re-encrypt all keys back to empty password: reencryptAllKeys(chatIds, oldPassword: currentPassword, newPassword: '')
  // 4. Call chatAuthRepository.disableAuth()
  // 5. Call fuzzyAuthStore.checkAuthStatus() to transition to noAuthRequired
  // 6. Emit success
}
```

Also update the state file (`fuzzy_user_auth_preferences_state.dart`) — the old `currentAuthPreferences` and `checkCurrentAuthPreferencesStatus` fields are no longer needed. The page no longer uses `StatusBuilder.buildByStatus()`. Keep only `activationStatus` and `activationFailure`.

#### Step 2: Clean Up Old Widgets

- **Delete or empty** `lib/src/fuzzy_auth/ui/pages/fuzzy_user_auth_page/widgets/fuzzy_user_auth_empty_content.dart`
- **Delete or empty** `lib/src/fuzzy_auth/ui/pages/fuzzy_user_auth_page/widgets/fuzzy_user_auth_loaded_content.dart`
- **Update** `lib/src/fuzzy_auth/ui/pages/fuzzy_user_auth_page/widgets/widgets.dart` to remove their exports (or delete the barrel entirely since the page no longer uses sub-widgets)

#### Step 3: Analyze and Fix

```bash
fvm dart analyze lib/
```

Fix any issues. Common ones expected:
- The new `FuzzyUserAuthPage` now creates `FuzzyUserAuthPreferencesCubit` with 4 new constructor params — the cubit constructor must match
- Old `FuzzyUserAuthPreferencesCubit` references (`getUserAuthPreferences`, `activateAuth`) no longer exist

#### Step 4: Verify the No-Auth Path

When no auth is set up:
1. `FuzzyAuthStore.checkAuthStatus()` → `ChatAuthRepository.isChatAuthEnabled()` returns `false` → state = `noAuthRequired`
2. Router redirect checks `authStatus.isLocked` → `false` → no redirect
3. `KeyStorageRepository` reads password from `FuzzyAuthStore` → `''` → same PBE as before
4. App works exactly as it did before this feature

#### Step 5: Update Architecture Docs

Update `.agents/project_guide/architecture_state.md` to reflect the new auth architecture:
- `ChatAuthRepository` — password verification in `FlutterSecureStorage`
- `FuzzyAuthStore` — session auth state with 5-state lifecycle
- `KeyStorageRepository.reencryptAllKeys()` — two-phase commit with crash recovery
- `AppRouter` redirect logic — protects chat + vault routes when auth is locked

---
### KEY DESIGN DECISIONS

1. **Separate from vault password** — Chat auth and vault auth are independent. Defense in depth.
2. **Password stored in volatile memory only** — `FuzzyAuthStore.state.authData.password` is never persisted. Only a verification hash (salt + AES-encrypted token) is stored.
3. **Two-phase commit for re-encryption** — Crash during password change won't corrupt keys. Recovery is automatic on next startup.
4. **No auth = empty password PBE** — When auth is disabled, `KeyStorageRepository` still "encrypts" with `''`. This means keys are technically encrypted but trivially reversible. This is by design — the user chose not to enable protection.
5. **Public keys stay plaintext** — Only private keys and symmetric keys are PBE-encrypted. Public keys need to be accessible for message receipt. This is cryptographically sound.

---
### REVIEW LOG (by [REVIEWER])
*Pending — run after Phase 3 is complete.*

---
### DOCUMENTATION (by [DOCUMENTER])
*Pending — update architecture_state.md after task is fully complete.*
