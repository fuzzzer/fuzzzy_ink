# TASK (bug): Android — "Show" on a file bubble opens the share sheet

**Status:** PENDING_PLAN
**Needed before production:** yes (see `before_production.md`)
**Reported by the owner:** 2026-09-22, on the production APK built that day from `ff2b959`.

## Symptom
On Android, pressing **Show** on a sent or received file bubble brings up the system share
popup instead of showing the file in its place (Downloads/Fuzzzy Ink/<chat>).

## Where it comes from
`lib/src/core/utils/reveal_file.dart` → `DeviceFileInteractor.revealFile` on Android calls
`UserFilesChannel.showInFiles(path)`; when that throws a `PlatformException` it silently falls
back to `shareFile` (the share sheet). The Kotlin side is
`android/app/src/main/kotlin/com/fuzzzycore/ink/UserFiles.kt`. So either `showInFiles`
throws on the owner's device (no matching intent / unresolvable content URI for the new
Downloads location) or the fallback is reached for every row.

## Done when
- On a real Android device, **Show** opens the system file manager (or the Files/Downloads
  view) at the file, for both a freshly fuzzed file and a freshly unfuzzed one.
- If the device truly has no file manager, the user sees a toast saying so — not the share sheet.
  **Share** remains its own button and keeps using the share sheet.
- The reason `showInFiles` threw is written in the review log.

---
### PLAN (by [PLANNER])
*To be populated.*

---
### IMPLEMENTATION (by [DOER])

---
### REVIEW LOG (by [REVIEWER])

---
### DOCUMENTATION (by [DOCUMENTER])
