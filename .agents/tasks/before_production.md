# Before Production — what is still left

**Branch:** `production-preparation` (cut 2026-09-22 from the newest work: Rust crypto core,
new ui kit, lighter colours, file rework, Codemagic release pipelines).
**Rule:** when the owner asks "what's left", answer from this list. Add to it, never silently drop
from it. An item leaves the list only when its task file says DONE and the owner has seen it.

| # | Item | Kind | Task file | Status |
|---|------|------|-----------|--------|
| 1 | Message shrinker — re-spell the shared ciphertext in a denser character set (base91 / base2048 / base32768), chosen in Settings and per message, without touching the bytes, the core, storage, or any old message | feature | `message_shrinker.md` | NOT STARTED |
| 2 | Android: pressing **Show** on a file bubble opens the share sheet instead of showing the file | bug | `android_show_file_share_popup.md` | NOT STARTED |

## Not on the list, decided on 2026-09-22
- Spotlight onboarding tour (PR #10) — separate feature; merge only if the owner asks.
- Web build — the Rust core has no web target; the old web branch would break the build.
- Dependabot bumps (go_router 17, share_plus 12, bloc, vibration, launcher_icons) — do in one
  go with a full test run, not piecemeal.
- The empty GitHub Actions workflow (`.github/workflows/main.yaml`) — releases run on
  Codemagic; either fill the workflow or delete it so it stops showing red.
