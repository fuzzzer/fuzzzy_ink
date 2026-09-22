# Fuzzy Vault — Feature Overview

> **Feature Module:** `fuzzy_vault/` (new top-level feature at `lib/src/fuzzy_vault/`)
> **Status:** PLANNING
> **Created:** 2026-05-09

---

## 1. What Is Fuzzy Vault?

Fuzzy Vault is a new section of Fuzzzy Seal that provides a **fully offline, encrypted personal information manager**. It has two primary capabilities:

1. **Password Manager** — Store, search, organize, and quickly copy credentials (username/password pairs, URLs, notes per entry).
2. **Secure Notes** — Rich-text notes with formatting (bold, italic, headings, lists, code blocks), organized in groups, with extreme data durability guarantees.

All data is encrypted at rest using the app's existing `PasswordBasedEncryptionService` (AES-256-GCM + Argon2id key derivation). The user unlocks the vault with a single **master password** — the same paradigm as 1Password, Bitwarden, or KeePass.

---

## 2. Core Principles

| Principle | Description |
|-----------|-------------|
| **Never Lose Data** | Notes contain sensitive info. We use write-ahead journaling, atomic file operations, and periodic auto-save to guarantee no data loss on crash, kill, or power loss. |
| **Offline-Only** | Zero network. Zero servers. Same constraint as the rest of Fuzzzy Seal. |
| **One Master Password** | Single password unlocks the entire vault. Derived key is held in memory only while unlocked; never persisted in plaintext. |
| **Optional Custom Passwords** | Individual notes/passwords or entire groups can have an additional custom password. This is an opt-in layer on top of the master password. |
| **Searchable & Snappy** | Metadata (titles, tags, group names) is indexed in Isar for fast search. Encrypted content is decrypted on-demand when opened. |
| **Export/Import** | Entire vault or selected groups can be exported as an encrypted ZIP archive to a user-chosen directory, enabling cross-device transfer via USB/cloud/etc. |
| **Multi-Directory Read** | The vault reads from a base directory (app's document directory) plus an optional user-configured custom directory. This allows mounting an external or shared folder. |

---

## 3. Architecture Fit

Fuzzy Vault follows the exact same architecture as `fuzzzy_seal/` and `fuzzy_auth/`:

```
lib/src/fuzzy_vault/
├── fuzzy_vault.dart              # Barrel
├── bloc/                         # Cubits + States
│   ├── vault_auth_cubit/         # Master password unlock/lock
│   ├── vault_items_cubit/        # CRUD for passwords & notes
│   ├── vault_groups_cubit/       # Group management
│   ├── vault_search_cubit/       # Search/filter
│   └── vault_export_cubit/       # Export/import operations
├── data/
│   ├── models/                   # Domain data classes
│   │   ├── vault_item.dart       # Base: id, title, group, type, timestamps
│   │   ├── vault_password.dart   # Extends item: username, password, url, notes
│   │   ├── vault_note.dart       # Extends item: rich content (delta JSON)
│   │   ├── vault_group.dart      # Group: id, name, icon, color, custom password flag
│   │   └── enums/
│   └── repositories/
│       ├── vault_repository.dart         # Main CRUD facade
│       ├── vault_crypto_repository.dart  # Encrypt/decrypt operations
│       └── vault_export_repository.dart  # ZIP export/import
├── storage/
│   ├── storage_models/           # Isar schemas
│   │   ├── stored_vault_item.dart
│   │   ├── stored_vault_group.dart
│   │   └── stored_vault_metadata.dart
│   └── local_data_sources/
│       ├── vault_item_local_data_source.dart
│       ├── vault_group_local_data_source.dart
│       └── vault_file_data_source.dart   # File-system operations for encrypted blobs
└── ui/
    ├── pages/
    │   ├── vault_unlock_page/    # Master password entry
    │   ├── vault_home_page/      # Main dashboard: groups + recent items
    │   ├── vault_item_page/      # View/edit a single password or note
    │   ├── vault_group_page/     # Items within a group
    │   └── vault_export_page/    # Export configuration
    └── widgets/
        ├── password_strength_indicator.dart
        ├── vault_search_bar.dart
        ├── vault_item_tile.dart
        ├── rich_text_editor.dart
        └── group_selector.dart
```

### Layer responsibilities (matching existing patterns):
- **Storage** → Isar + file system. `sl.get()` allowed here only.
- **Repositories** → Sealed responses (`Success | Failure`). Never throw.
- **Cubits** → Constructor-injected repos. Exhaustive `switch` on responses.
- **UI** → Uses `context.uiColors`, `context.uiTextStyles`, `FuzzyScaffold`, etc.

---

## 4. Encryption Architecture

```
┌─────────────────────────────────────────────────┐
│                 Master Password                  │
│        (user enters on vault unlock)             │
└──────────────────────┬──────────────────────────┘
                       │ Argon2id (salt per vault)
                       ▼
              ┌─────────────────┐
              │  Master Key     │  ← 256-bit derived key
              │  (in-memory)    │     held only while unlocked
              └────────┬────────┘
                       │
        ┌──────────────┼──────────────────┐
        ▼              ▼                  ▼
   ┌─────────┐  ┌───────────┐   ┌──────────────┐
   │ Item A  │  │  Item B   │   │  Group X     │
   │ AES-GCM │  │  AES-GCM  │   │  Items with  │
   │ encrypt │  │  encrypt  │   │  custom pwd  │
   └─────────┘  └───────────┘   └──────┬───────┘
                                       │ Custom password
                                       │ Argon2id (separate salt)
                                       ▼
                                ┌──────────────┐
                                │ Custom Key   │
                                │ + Master Key │
                                │ (double enc) │
                                └──────────────┘
```

### Encryption flow:
1. **Master password** → Argon2id → **master key** (256-bit). Salt stored alongside encrypted vault metadata.
2. Each item's **content** (password fields, note body) is encrypted with AES-256-GCM using the master key.
3. **Metadata** (title, group ID, item type, timestamps, tags) is stored **plaintext in Isar** for search/indexing.
4. Items/groups with a **custom password** are double-encrypted: first with the custom key, then with the master key. The custom password must be provided in addition to the master password to decrypt.

### Master password verification:
- On first vault creation, we encrypt a known verification token with the master key and store it.
- On unlock, we attempt to decrypt this token. If decryption succeeds (GCM auth tag valid), the password is correct.

---

## 5. Data Durability Strategy

Since notes store **highly sensitive information that must never be lost**:

| Mechanism | Description |
|-----------|-------------|
| **Atomic writes** | Use write-to-temp + rename pattern. Never overwrite in-place. |
| **Auto-save** | Rich text editor auto-saves every 5 seconds (debounced) while editing. |
| **Write-ahead journal** | Before modifying encrypted content, write the operation intent to a journal file. On next launch, replay incomplete journal entries. |
| **Redundant storage** | Encrypted blobs stored in app support directory. Isar metadata is separately backed. |
| **Export reminders** | Optional reminder to export vault periodically. |

---

## 6. Group System

- All items belong to a group. Items not explicitly grouped go into the **"General"** group (created automatically, undeletable).
- Groups have: `id`, `name`, `icon` (emoji), `colorIndex`, `customPasswordHash` (nullable), `sortOrder`.
- Groups can be reordered, renamed, deleted (items move to General), or locked with a custom password.
- Drag-and-drop to move items between groups.

---

## 7. Multi-Directory Support

The vault reads encrypted item files from:

1. **Base directory**: `{appSupportDir}/fuzzy_vault/` — always present, primary write target.
2. **Custom directory** (optional): User-configured path (e.g., external drive, shared folder). Read-only or read-write based on permissions.

On startup, items from both directories are merged by ID. Conflicts (same ID, different timestamps) are resolved by **latest-write-wins** with the older version moved to a `.conflicts/` subfolder.

---

## 8. Export/Import System

### Export:
1. User selects: all items, specific groups, or individual items.
2. User chooses target directory (via `file_picker`).
3. System creates a ZIP containing:
   - `manifest.json` — metadata (version, export date, item count).
   - `items/` — encrypted item blobs (already AES-GCM encrypted).
   - `groups.json` — group definitions (encrypted with export password).
4. The entire ZIP is then encrypted with a user-provided **export password** using `PasswordBasedEncryptionService`.
5. Output: `fuzzy_vault_export_{timestamp}.fvault` file.

### Import:
1. User selects `.fvault` file.
2. User enters the export password.
3. System decrypts ZIP, validates manifest, imports items.
4. Conflict handling: skip duplicates or overwrite (user choice).

---

## 9. Password Strength Assessment

Built-in password strength meter for:
- Vault master password (required strong).
- Stored passwords (informational).
- Export passwords.

### Strength criteria (scored 0–100):
| Factor | Points |
|--------|--------|
| Length ≥ 8 | 10 |
| Length ≥ 12 | +10 |
| Length ≥ 16 | +10 |
| Contains uppercase | 10 |
| Contains lowercase | 10 |
| Contains digits | 10 |
| Contains symbols | 15 |
| No common patterns (123, abc, qwerty) | 15 |
| Not in common password list | 10 |

### Strength levels:
- **0–29**: Weak (red)
- **30–59**: Fair (orange)
- **60–79**: Good (yellow-green)
- **80–100**: Strong (green)

Master password requires minimum **Good (60+)** to proceed.

---

## 10. Rich Text Notes

Notes use a structured delta format (similar to Quill Delta) stored as JSON:

### Supported formatting:
- **Bold**, *Italic*, ~~Strikethrough~~, `Code`
- Headings (H1, H2, H3)
- Bullet lists, Numbered lists
- Checkboxes / To-do items
- Code blocks
- Horizontal dividers
- Links (displayed, not clickable — offline app)

### Implementation approach:
- Custom Flutter widget using `TextField` with `TextSpan` trees.
- Delta format: `[{"insert": "Hello ", "attributes": {"bold": true}}, {"insert": "world\n"}]`
- Stored as JSON → encrypted → persisted as blob.
- No external rich text packages — keep dependency footprint minimal and controlled.

---

## 11. Navigation Integration

New routes added to `AppRouter`:

| Route | Path | Page |
|-------|------|------|
| `vault` | `/vault` | `VaultUnlockPage` (if locked) or `VaultHomePage` |
| `vaultGroup` | `/vault/group` | `VaultGroupPage` (extra: group ID) |
| `vaultItem` | `/vault/item` | `VaultItemPage` (extra: item ID + type) |
| `vaultExport` | `/vault/export` | `VaultExportPage` |

Access point: New entry in the main app navigation (alongside Chat, Basics).

---

## 12. Authentication Gate

The vault is gated behind:
1. **App-level auth** (existing `FuzzyAuthStore`) — if biometrics/PIN is enabled.
2. **Vault master password** — separate from app auth. Required every time vault is opened (configurable auto-lock timeout).

Auto-lock options:
- Immediately on background
- After 1 minute
- After 5 minutes
- After 15 minutes
- Never (until app kill)
