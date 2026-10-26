# Redesign building blocks (Fuzzzy Ink, simple launch)

The shared pieces of the approved redesign (HQ `departments/design-media/projects/fuzzzy-ink-simple/DESIGN.md`).
They live in the app until the owner approves the whole app; then they move to the Fuzzzy UI kit. Never add
them to `lib/src/ui_kit/`. Each widget's doc comment says what it is for; this page is the map.

## Where they are

| Piece | File | Use it for |
|---|---|---|
| `InkMark` | `app/ui/widgets/ink_mark/` | The Ink mark everywhere (header 26, lock screen 56, welcome 96, print sheet 18, QR screen). Paints `assets/logo/ink_mark.png` on the dark look and `ink_mark_paper.png` on the light look. |
| `StepsIndicator` | `app/ui/widgets/guided/` | The step bar at the top of every flow ("Step 2 of 3 · Recovery key"). |
| `StepPicture` | `app/ui/widgets/guided/` | The three-dot picture instead of a paragraph. `StepPicture.inviteSteps(context, name:)` is the invite flow's. `justDone` fills a step once. |
| `WhyLink`, `showInkInfoSheet`, `InkInfoTopic` | `app/ui/widgets/guided/` | "Why?" / "How?" / "More" links and the nine explanation sheets. |
| `TipLine`, `KeyTag` | `app/ui/widgets/guided/` | One guiding line (with a trailing `WhyLink`); the "No copy · no screenshots" tag. |
| `HeroGlyph`, `LockSnapGlyph` | `app/ui/widgets/ink_motion/` | The picture slot of result screens when Fuzzzy Cast is off; "Lock done" snap. |
| `InPlaceConfirmButton` | `app/ui/widgets/ink_motion/` | "Copied", "Handed over", "Saved": confirm on the pressed button after the real result. |
| `CheckDraw`, `RowTint`, `ChipSwap`, `LiftIn`, `SettleIn` | `app/ui/widgets/ink_motion/` | Section 10's responses: check draw, new-row glow, chip change, lift after unlock, mark settle. |
| `InkMotion`, `InkMotionTiming`, `InkHaptics` | `app/ui/widgets/ink_motion/` | Whether something may move here (reduced motion, private screen), the named delays, buzzes. |
| `FuzzzyCastReaction`, `FuzzzyCastMoment`, `showInkToast` | `app/ui/widgets/fuzzzy_cast/` | Fuzzz in the picture slot (pass the glyph as `fallback`) or at the start of a confirmation toast. |
| `ActionTile` | `fuzzzy_ink/ui/widgets/home/` | The big Lock / Open tiles. |
| `PersonRow`, `PersonTrustChip`, `WaitNotes` | `fuzzzy_ink/ui/widgets/people/` | A person on Home or in a picker; the trust chip; the two waiting notes. |
| `HistoryRow`, `FileCard`, `LockedTextPreview` | `fuzzzy_ink/ui/widgets/history/` | History rows (never the text); a file with its state; the faded locked text. |
| `SafetyNumberGrid` | `fuzzzy_ink/ui/widgets/safety/` | The 12 × 5 digits of "Is it really X?". |
| `showSealedShareSheet`, `SealedQrCodePage` | `fuzzzy_ink/ui/widgets/share_sheet/` | The one Share button; answers what happened (`SealedShareResult.isDone` for "Share again"). |
| `RecoveryKeyBlock`, `LockoutCountdownBar` | `fuzzy_auth/ui/widgets/` | The recovery key on screen; the truthful lockout bar under Unlock. |
| `AccessPage`, `AccessTitle`, `AccessLine`, `AccessNote`, `runOnTopScreen`, `leaveAccessPage` | `fuzzy_auth/ui/widgets/access_page.dart` | The flow-screen recipe (header, content, bottom buttons); the red, amber or green note with a trailing "Why?"; a toast or sheet on the screen the app moves to. |
| `InkPasswordField`, `NewPasswordFields`, `PasswordMeter` | `fuzzy_auth/ui/widgets/` | A password with its eye; a new password, its meter (Weak · Fair · Good · Strong) and "Type it again". |
| `RecoveryKeyStepView`, `RecoveryKeyExport`, `RecoveryKeyPrintSheet` | `fuzzy_auth/ui/widgets/` | A recovery key shown once with Print and Save as file (through the hand-off folder, wiped after), "I've kept it safe" and the skip dialog. |
| `SettingsSectionLabel`, `SettingsRowIcon`, `SettingsRowText`, `showSettingsChoiceSheet`, `showPasswordConfirmSheet` | `fuzzzy_ink/ui/pages/settings_page/widgets/` | Settings rows and their small sheets (radio choices; one password, private). |

## Rules they already keep

- Kit roles and motion tokens only; both looks; a `qaId` on everything interactive.
- Reduced motion shows the final state at once. Below a `SensitiveScreen` only in-place changes play (no travel,
  glow or Fuzzzy Cast); wrap every private page in `SensitiveScreen`.
- A response starts only after the real result (the copy, the share, the save). Haptics are phones only and never
  the only signal.
- Tests: `test/helpers/redesign_harness.dart` (`pumpRedesign`: look, reduced motion, Fuzzzy Cast, private, text
  size, language).
