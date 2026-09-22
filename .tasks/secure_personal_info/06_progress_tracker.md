# Fuzzy Vault — Progress Tracker

> **Document:** Living progress document updated during implementation
> **Last Updated:** 2026-05-09

---

## Overall Status

| Phase | Name | Tasks | Done | Status |
|-------|------|-------|------|--------|
| 1 | Foundation — Storage & Crypto | 5 | 0 | ⬜ Not Started |
| 2 | Repository Layer | 3 | 0 | ⬜ Not Started |
| 3 | BLoC/Cubit Layer | 5 | 0 | ⬜ Not Started |
| 4 | UI — Core Pages | 5 | 0 | ⬜ Not Started |
| 5 | UI — Widgets & Advanced | 5 | 0 | ⬜ Not Started |
| 6 | Integration & Polish | 5 | 0 | ⬜ Not Started |
| **Total** | | **28** | **0** | **0%** |

---

## Detailed Task Status

### Phase 1: Foundation
| # | Task | Status | Assignee | Notes |
|---|------|--------|----------|-------|
| 1.1 | Isar Storage Models | ⬜ TODO | — | — |
| 1.2 | Domain Models | ⬜ TODO | — | — |
| 1.3 | Sealed Response Types | ⬜ TODO | — | — |
| 1.4 | Local Data Sources | ⬜ TODO | — | Depends on 1.1 |
| 1.5 | Password Strength Service | ⬜ TODO | — | — |

### Phase 2: Repositories
| # | Task | Status | Assignee | Notes |
|---|------|--------|----------|-------|
| 2.1 | VaultCryptoRepository | ⬜ TODO | — | Depends on 1.2, 1.3, 1.4 |
| 2.2 | VaultRepository | ⬜ TODO | — | Depends on 1.2, 1.3, 1.4 |
| 2.3 | VaultExportRepository | ⬜ TODO | — | Depends on 2.2 |

### Phase 3: Cubits
| # | Task | Status | Assignee | Notes |
|---|------|--------|----------|-------|
| 3.1 | VaultAuthCubit | ⬜ TODO | — | Depends on 2.1 |
| 3.2 | VaultItemsCubit | ⬜ TODO | — | Depends on 2.2 |
| 3.3 | VaultGroupsCubit | ⬜ TODO | — | Depends on 2.2 |
| 3.4 | VaultSearchCubit | ⬜ TODO | — | Depends on 3.2 |
| 3.5 | VaultExportCubit | ⬜ TODO | — | Depends on 2.3 |

### Phase 4: Core UI
| # | Task | Status | Assignee | Notes |
|---|------|--------|----------|-------|
| 4.1 | Unlock & Create Pages | ⬜ TODO | — | Depends on 3.1, 5.1 |
| 4.2 | Home Page | ⬜ TODO | — | Depends on 3.2, 3.3 |
| 4.3 | Password Item Page | ⬜ TODO | — | Depends on 4.2 |
| 4.4 | Note Item Page | ⬜ TODO | — | Depends on 4.2, 5.2 |
| 4.5 | Group Page | ⬜ TODO | — | Depends on 4.2 |

### Phase 5: Widgets & Advanced
| # | Task | Status | Assignee | Notes |
|---|------|--------|----------|-------|
| 5.1 | Password Strength Widget | ⬜ TODO | — | Depends on 1.5 |
| 5.2 | Rich Text Editor | ⬜ TODO | — | Depends on 1.2; complex widget |
| 5.3 | Search & Tile Widgets | ⬜ TODO | — | Depends on 4.2 |
| 5.4 | Export Page | ⬜ TODO | — | Depends on 3.5 |
| 5.5 | Password Generator Widget | ⬜ TODO | — | Depends on 1.5 |

### Phase 6: Integration
| # | Task | Status | Assignee | Notes |
|---|------|--------|----------|-------|
| 6.1 | Router Integration | ⬜ TODO | — | Depends on 4.1 |
| 6.2 | Localization | ⬜ TODO | — | Depends on all UI |
| 6.3 | Auto-Lock & Lifecycle | ⬜ TODO | — | Depends on 6.1 |
| 6.4 | Testing | ⬜ TODO | — | Depends on 6.1 |
| 6.5 | Documentation Update | ⬜ TODO | — | Depends on 6.4 |

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-05-09 | Module named `fuzzy_vault` | Consistent with `fuzzzy_ink`, `fuzzy_auth`, `fuzzy_basics` naming |
| 2026-05-09 | Encrypted blobs on file system, metadata in Isar | Better performance, atomic writes, multi-directory support |
| 2026-05-09 | Custom password = double encryption (custom + master) | Master password always required; custom password is additive |
| 2026-05-09 | Export decrypts from master key, re-encrypts with export password | Simpler cross-device workflow — user only needs export password to import |
| 2026-05-09 | Rich text editor built from scratch (no external package) | Minimal dependency footprint; full control; offline-only constraint |
| 2026-05-09 | Default group "General" is undeletable | Ensures items always have a home; prevents orphans |
| 2026-05-09 | Metadata (titles, tags) stored unencrypted in Isar | Required for fast search/indexing; content is encrypted |

---

## Resolved Questions

| # | Question | Status | Resolution |
|---|----------|--------|------------|
| 1 | Should titles be encrypted too? | 🟢 Resolved | Keep plaintext for fast search, but add UI hint that metadata is searchable and not locked. |
| 2 | Should we add a "favorites" system? | 🟢 Resolved | Yes, `isFavorite` added to metadata. |
| 3 | Rich text editor: build from scratch or use `flutter_quill`? | 🟢 Resolved | Use existing `flutter_quill` package. |
| 4 | Multi-directory: should custom dir be read-only or read-write? | 🟢 Resolved | Read-write to enable syncing capabilities. |
| 5 | Any features to cut or add? | 🟢 Resolved | Implement all features as specified. |

---

## User Notes

*Space for capturing user feedback, corrections, and evolving requirements during implementation.*

- (none yet)
