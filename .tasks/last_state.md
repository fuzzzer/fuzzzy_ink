# Last State Log

Append-only log of completed task snapshots, newest at top.

---

## 2026-05-09 — Rename "Master Password" → "Vault Password" + co-locate biometric settings

**What changed**
- Renamed user-facing string and arb key `vaultMasterPassword` → `vaultPassword`. Updated every call site.
- Removed the redundant `vaultPassword: "Password"` arb entry (item-type label) and pointed [vault_item_editor_page.dart:182](lib/src/fuzzy_vault/ui/pages/vault_item_editor_page/vault_item_editor_page.dart#L182) at the existing `vaultPasswordLabel`.
- Fixed a stale label in chat auth page where `oldPasswordController` mistakenly used `vaultMasterPassword` — now uses `chatAuthPassword`.
- Co-located both biometric toggles in [fuzzy_user_auth_page.dart](lib/src/fuzzy_auth/ui/pages/fuzzy_user_auth_page/fuzzy_user_auth_page.dart):
  - Existing chat biometric section (uses chat password from change-password block).
  - New `_VaultBiometricSection` with its own `_vaultPasswordController` and visibility toggle. Watches `VaultAuthCubit`. If no vault exists, shows a "Create a vault first" hint.
- Section divider + new "Vault Authentication" subsection header inserted between chat and vault portions.
- Removed the fingerprint icon button + bottom sheet from [vault_search_bar.dart](lib/src/fuzzy_vault/ui/pages/vault_home_page/widgets/vault_search_bar.dart) — search bar reverted to its original simple form.
- Cleaned up `lib/src/core/l10n/l10n.dart` — removed dangling `export 'generated_localizations/generated_localizations.dart'` (file was already deleted in working tree).

**New l10n keys** (en + ka): `vaultAuthentication`, `vaultAuthenticationDescription`, `vaultNotCreated`. Existing key `vaultBiometricInvalidPassword` text updated from "master password" → "vault password".

**Files touched**
- `lib/src/core/l10n/app_en.arb`
- `lib/src/core/l10n/app_ka.arb`
- `lib/src/core/l10n/l10n.dart`
- `lib/src/core/l10n/generated_localizations/*.dart` (regenerated via `fvm flutter gen-l10n`)
- `lib/src/fuzzy_auth/ui/pages/fuzzy_user_auth_page/fuzzy_user_auth_page.dart`
- `lib/src/fuzzy_vault/ui/pages/vault_create_page/vault_create_page.dart`
- `lib/src/fuzzy_vault/ui/pages/vault_unlock_page/vault_unlock_page.dart`
- `lib/src/fuzzy_vault/ui/pages/vault_item_editor_page/vault_item_editor_page.dart`
- `lib/src/fuzzy_vault/ui/pages/vault_home_page/widgets/vault_search_bar.dart`

**Verification**: `fvm dart analyze lib/` → no issues.

**Next**: Plan and implement the encrypted-files vault tab (third tab in vault home, group-scoped, AES via existing `fuzzy_basics` flow, key from vault password or per-group custom password). Awaiting user sign-off on implementation plan before starting.

---
