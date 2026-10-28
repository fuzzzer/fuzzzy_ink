# Lock from other apps: the channel contract (version 1)

**Status:** experimental, 2026-10-26. Built only with `--dart-define=FUZZ_ANYWHERE=true`, in the development
flavour only (the Android declarations, the Mac shortcut, menu bar item and Services, the iPhone App Shortcut; a
staging or production build that carries the flag fails in Gradle and in the Mac build script); the person also
turns on Settings → Other apps → Lock from other apps (off by default). The threat model's draft section "Locking from
other apps" (`documents/security/THREAT_MODEL.md` §2.9) says what this is allowed to do and why.

**Who reads this:** whoever builds the native pieces (the Android selection menu and tile, the Mac Services menu,
shortcut and panel, the iPhone quick sheet). The Dart side is `lib/src/fuzz_anywhere/`
(`FuzzAnywhereChannel` → `FuzzAnywhereService`); its tests are `test/src/fuzz_anywhere/`.

## 1. The shape

- One method channel, `com.fuzzzycore.ink/anywhere`, standard method codec, on the app's own Flutter engine.
  Native code lives in the app's process and calls Dart; Dart is the one store owner and calls Rust. Native code
  never does cryptography, never opens the store and never keeps key material.
- **Dart registers its handler only in a build with the flag.** Without it every call answers "not implemented"
  (`MissingPluginException` / `FlutterMethodNotImplemented`). Treat that as "the feature is not in this build":
  show nothing.
- Every call may carry `v` (an int): the contract version the caller speaks. A `v` above 1 is refused with
  `unsupportedVersion`. Leave it out or send `1`.
- Answers are maps of strings, booleans and ints. A refusal is a `PlatformException` (`FlutterError`) whose
  **code** is one of section 4; it has no message, and its details are either null or `{waitSeconds: int}`.
- Nothing answered or sent ever holds opened text, a password or a key. The only text the app answers is sealed
  output from `lock` and the person's display name.

## 2. Methods (native calls Dart)

| Method | Arguments | Answer | Refusals |
|---|---|---|---|
| `status` | — | `{version: 1, enabled, settingKnown, lockAgainAfterUse, unlocked, setUp, biometric, language?}` | `unsupportedVersion` |
| `unlock` | — | `{status: "unlocked"}` | `disabled`, `notSetUp`, `notReady`, `biometricOff`, `biometricGone`, `notUnlocked` |
| `unlockWithPassword` | `password` (string) | `{status: "unlocked"}` | `disabled`, `notSetUp`, `notReady`, `badRequest` (missing or empty), `wrongPassword` (+ `waitSeconds` when a wait started), `lockedOut` (+ `waitSeconds`), `notUnlocked` |
| `people` | `sourceApp` (string, optional) | `{people: [{id, name, verified, lastUsedHere}]}` | `disabled`, `locked`, `notSetUp`, `notReady`, `badRequest`, `failed` |
| `lock` | `personId`, `text`, `sourceApp` (optional), `copy` (bool, optional) | `{output, kind: "link" \| "text", copied}` | `disabled`, `locked`, `notSetUp`, `notReady`, `badRequest`, `emptyText`, `unknownPerson`, `failed` |
| `peek` | `text` | `{kind, personId?, personName?}` | `disabled`, `locked`, `notSetUp`, `notReady`, `badRequest`, `emptyText`, `failed` |
| `open` | `text` | `{status: "opened", displayId, personId, personName}` | `disabled`, `locked`, `notSetUp`, `notReady`, `badRequest`, `emptyText`, `notForAPerson`, `alreadyOpened`, `tooOld`, `newerApp`, `damaged`, `notFuzzzy`, `notFromYourPeople`, `failed` |
| `show` | `displayId` | `{status: "shown"}` | `unknownDisplay`, `disabled`, `locked`, `notSetUp`, `notReady`, `badRequest` |
| `relock` | — | `{relocked: bool}` | — |
| `openInApp` | `text` | `{status: "shown"}` | `disabled`, `locked`, `notSetUp`, `notReady`, `badRequest` (missing, or a message: those open with `open`), `emptyText`, `newerApp`, `damaged`, `notFuzzzy`, `failed` |

Notes, method by method:

- **`status`.** `enabled` is true only when the sealed switch is known to be on. The switch is sealed under the
  store key, so until the first unlock of this run `settingKnown` is false and `enabled` is false: offer only
  "Unlock Fuzzzy Ink", and after the unlock read `status` again (or wait for `settingsChanged`).
  `biometric` is `"on"` (turned on in Fuzzzy Ink), `"off"` (the device can, Fuzzzy Ink does not) or `"none"`.
  Which kind (face, fingerprint) is the platform's own to read for its icon. `setUp` is false until a master
  password exists (and while the app is still starting). `language` (`en` or `ka`) is there only when the person
  picked a language in Settings → Language; without it the app follows the device, and so does the native sheet
  (English when the device's language is neither). Added 2026-10-26 for the Apple sheets; version 1.
- **`unlock`.** Runs the app's own fingerprint or face prompt (the biometric copy of the master password). On
  Android the prompt needs a `FragmentActivity` in front. Already unlocked: answers at once.
- **`unlockWithPassword`.** The password is sent once, used once and never kept; clear the native field right
  after the call. A wrong one counts against the same limit as the lock screen (5 free tries, then 30 s, 1, 2,
  5, 10, 15 minutes, kept across restarts); during a wait the password is not even tried (`lockedOut`).
- **If the switch turns out to be off at an unlock,** the app locks again at once and answers `disabled`.
- **`people`.** Connected people only. `verified` false means show "Not verified" next to the name before Lock.
  `lastUsedHere` marks the person last locked for from `sourceApp` (a hint for the pre-selection; always show
  the name before Lock). Pre-select only that person, or the only person there is; with several and none
  remembered, nobody is selected and Lock waits for the person's choice. Return (a default button) must not
  lock a pre-selection or text another app sent: only a name the person picked in the sheet (security review
  2026-10-26).
- **`sourceApp`** is the calling app's identity as the platform gives it, without asking any permission: the
  Android calling package (none when the caller did not wait for a result), or on the Mac the app in front when
  the person pressed the shortcut or the menu bar item. A Mac Services request sends none: macOS does not say
  which app asked (any app can call a service with `NSPerformService`), so no person is remembered or
  pre-selected for it. 1 to 200 characters, no control characters; anything else is ignored. The memory of "this app → this person" is sealed under the store key (never in
  `SharedPreferences`/`UserDefaults`), keeps at most 32 apps, and is forgotten when the switch is turned off.
- **`lock`.** Locks `text` for `personId` through the app's own Lock flow, which writes the sent message to that
  person's history exactly as Lock in the app does. `output` is the message link
  (`https://ink.fuzzzycore.com/message#…`) when it fits one (8 192 payload characters), else the `Fuzz/` text
  (`kind: "text"`). Both are sealed and safe to paste anywhere. With `copy: true` the app's own copy guard copies
  it; `copied` says whether it did. The copy is sealed only and marked sensitive, which still pastes everywhere:
  Android keeps it out of the clipboard preview and keyboards' clipboard history, the iPhone keeps it on this
  device and lets it expire, the Mac marks it concealed and transient for clipboard managers. It is cleared after
  2 minutes and at lock. On Android that clear works while Fuzzzy Ink is not in front only blind, so it also
  clears anything copied in another app after it within those 2 minutes; a copy a killed process left behind
  is cleared at the app's next start (security review 2026-10-26). The one
  exception to "cleared at lock": when `relock` locks the app right after the use that made this copy, that copy
  stays through that lock (its 2-minute clear still runs), or "Lock again after each use" would empty the
  clipboard before the person could paste (found live on the Mac, 2026-10-26). Never
  copy anything yourself. Android: always ask for the copy (`copy: true`), so the locked text can be pasted
  and sent at once (owner, 2026-10-28), and also return `output` as `EXTRA_PROCESS_TEXT` when the field is
  editable; Mac
  Services: write `output` to the service pasteboard.
- **`peek`.** What `text` is, without opening it or spending anything (the core's peek). `kind` is `message`,
  `invite`, `reply`, `passwordText`, `newerApp`, `damaged` or `notFuzzzy`. For a message from one of the person's
  people, `personId` and `personName` say whose ("Open the message from Nino?"). A message link is read as its
  message. Call it only when the person brought text to Fuzzzy Ink themselves (chose the menu item, pressed
  Paste in the sheet). Never on a selection change, a clipboard change or a timer.
- **`open`.** Call it only on the person's own **Open** press. The message is opened through the app's Open flow:
  its key is spent (it opens once, on one device) and the text goes into that person's history. The text itself
  is **not** answered: the answer is a `displayId` (valid once, for the latest `open` only, dropped at any lock).
  `notForAPerson` means an invite, a reply or a password-locked text: say "Open it in Fuzzzy Ink" and bring the
  app forward; the person pastes it into Open there.
- **`show`.** Asks the app to show the opened message on its own private screen (the history item, behind the
  lock, out of screenshots, no copy, no selection). Bring the app's window or activity forward first (Mac:
  activate the app; Android: the Flutter activity). `shownClosed` arrives when the person closes it.
- **`openInApp`** (added for "Open in Fuzzzy Ink", additive, version 1). After `open` answered `notForAPerson`
  (an invite, a reply or a password-locked text), on the person's "Open in Fuzzzy Ink" press: bring the app
  forward first, then call it. The app's own Open screen comes up with the sealed text filled in; nothing is
  opened by the call (Open asks again there: Connect, the password). The person goes on in the app, so "Lock
  again after each use" no longer applies to this use; the app's own auto-lock does. A message is refused
  (`badRequest`): it opens only through `open`.
- **`relock`.** Call it when your sheet, panel or activity goes away, whatever happened (locked, cancelled,
  dismissed). It locks the app only when this entry point unlocked it and "Lock again after each use" is on (the
  default); an app the person had already unlocked stays as it was. While a message from `show` is on screen it
  does nothing: closing that screen locks instead. The app's own auto-lock (idle and background times) applies on
  top in every case. One exception (the Android sheet): when the person chose to go on in the app itself ("Open
  Fuzzzy Ink", Open with `show`, "Open in Fuzzzy Ink"), the app is in front and the sheet does not call it.
  Dart then keeps its mark that this entry unlocked the app until the app locks, so the next outside use's
  `relock` may lock the app while the person is using it (it errs toward locking).

## 3. Events (Dart calls native)

Dart calls these on the same channel. Each carries `v: 1`. If native has no handler, Dart ignores it.

| Method | Arguments | When |
|---|---|---|
| `lockChanged` | `unlocked` (bool) | the app locked or unlocked, any way (Lock now, auto-lock, an unlock, `relock`) |
| `settingsChanged` | `enabled`, `lockAgainAfterUse` (bools) | the switches changed; the first read of a run (after the first unlock), even when it reads as before; and `enabled: false` whenever there is no master password (a new install, "Erase everything") |
| `shownClosed` | `displayId` | the private screen `show` opened was closed (or dropped by a lock) |

The first read of a run and the no-password case are sent even though nothing changed in this run: "off"
looks like the starting state, and the native side must still switch off what an earlier run or setup left on
(security review 2026-10-26). On `settingsChanged` with `enabled: false`: switch the entry points off (Android: disable the selection activity
and the tile component; Mac: unregister the services provider and the hot key; iPhone: hide the shortcuts). On
`enabled: true`, switch them on. On `lockChanged` with `unlocked: false`: drop any person list or name you show.

## 4. Refusal codes

| Code | Meaning | What the person sees |
|---|---|---|
| `disabled` | Settings → Lock from other apps is off | nothing (the entry should not be there) |
| `locked` | the app is locked | the unlock step |
| `notSetUp` | no master password yet | "Set up Fuzzzy Ink first" + open the app |
| `notReady` | the app is starting, or its secure storage cannot be read | "Open Fuzzzy Ink" |
| `badRequest` | a missing or wrongly typed argument | a bug: log the code only |
| `unsupportedVersion` | the caller speaks a newer contract | a bug: update together |
| `unknownPerson` | no connected person with that id | refresh `people` |
| `emptyText` | nothing to lock or open | "Write something first" |
| `wrongPassword` | wrong master password (`waitSeconds` when a wait began) | red field, one short line |
| `lockedOut` | too many wrong passwords (`waitSeconds`) | "Wait 0:30" with the real countdown |
| `biometricOff` | fingerprint or face is off in Fuzzzy Ink | the password field |
| `biometricGone` | the device's fingerprints or face changed | the password field |
| `notUnlocked` | prompt cancelled, or another unlock was running | stay on the unlock step |
| `notForAPerson` | an invite, a reply or a password-locked text | "Open it in Fuzzzy Ink" |
| `alreadyOpened` | opened before (it opens once) | "Already opened. It's in {name}'s history." |
| `tooOld` / `newerApp` / `damaged` / `notFuzzzy` / `notFromYourPeople` | as the app's Open screen | the app's Open wording |
| `unknownDisplay` | `show` with an id `open` did not just give | a bug, or a lock came in between |
| `failed` | anything else | "Something went wrong" |

Strings come from the app's `.arb` files (both languages); generate the native string files from them, do not
copy text by hand.

## 5. Rules for native code (from the research's native code rules)

1. **No automatic opening.** `open` only on the person's Open press. No clipboard watcher, no open on selection,
   on paste, on appear or on a timer. `peek` only when the person brought the text in.
2. **Plaintext stays in Fuzzzy Ink, inside Dart.** Native code never receives opened text, so it can never return
   it to another app (Android `EXTRA_PROCESS_TEXT` on Open must not be set), copy it, log it or put it in a
   notification. Text the person types in a native "Write sealed" field goes only to `lock` and is cleared after.
3. **No cryptography, no network.** No CryptoKit, CommonCrypto, `javax.crypto`, Tink, `URLSession`, sockets,
   `INTERNET` permission, analytics or crash reporters.
4. **No logs of text, passwords, names or ids.** Log refusal codes only.
5. **Screen protection.** Native sheets and panels that hold a password or typed text use `FLAG_SECURE` and
   `setHideOverlayWindows(true)` (Android), `sharingType = .none` (Mac), the secure-field technique (iPhone).
6. **One state owner per sheet**, small views, previews for each state (locked, unlocking, choosing, locking,
   done, error); call `relock` when it goes away.
7. **Always show the person's name and the "Not verified" mark before Lock**, even when pre-selected. Pre-select
   only a remembered person or the only one; Return never locks a pre-selection or text another app sent.
8. **The sheet's own text fields keep what is typed** (the message, the master password, shown or hidden): their
   menu offers Paste (iPhone also Select and Select All) and nothing that sends text out (Copy, Cut, Share, Look
   Up, Translate, Services, Writing Tools, another app's text action); the copy shortcuts do nothing; the text
   cannot be dragged out; no autocorrection, spelling, inline prediction or keyboard learning (Android
   `IME_FLAG_NO_PERSONALIZED_LEARNING`). Android: `SealedTextInput.kt`; Mac and iPhone: `InkSealedTextBox`.
9. **Text another app sent is shown whole before Lock takes it.** Another app chooses that text, so the person
   must be able to see every word their name goes on: all of it, scrollable (and larger on request), with its
   length, characters that hide or reorder words shown as their codes (Android), and Lock enabled only once the
   end has been on screen.
10. **Open is two separate presses that cannot be one.** The press that checks whose message it is ("Check" on
    the Mac) spends nothing; Open, which spends it, is armed only a moment (0.6 s) after "Open the message from
    Nino?" shows.

## 6. A whole use, step by step

**Write sealed (the main flow):** `status` → (`unlock` or `unlockWithPassword`) → `people(sourceApp)` → the
person picks and types → `lock(personId, text, sourceApp, copy: true)` → paste or return `output` → `relock`.

**Lock selected text (Android selection, Mac Services):** as above with the selected text as `text`, shown
whole and locked only after its end was on screen (rule 9); show the one-time note "This app may already have saved what you typed. For private words, write them in Fuzzzy Ink
first." (it is the "Why?" line in Settings → Other apps).

**Open:** the person selects or pastes a sealed text → `peek(text)` ("Open the message from Nino?") → a moment
later the person presses Open (rule 10) → `open(text)` → bring the app forward → `show(displayId)` → `shownClosed` → (the app locks again
by itself when this entry unlocked it).

## 7. Changing the contract

Additive changes (a new optional argument, a new answer key, a new event) keep version 1. Anything else raises
`FuzzAnywhereChannel.contractVersion`, this document, the tests in `test/src/fuzz_anywhere/services/` and every
native caller in one change.
