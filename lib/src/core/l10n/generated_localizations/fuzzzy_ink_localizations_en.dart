// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'fuzzzy_ink_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class FuzzzyInkLocalizationsEn extends FuzzzyInkLocalizations {
  FuzzzyInkLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get chat => 'Chat';

  @override
  String get fuzzzyInk => 'Fuzzzy Ink';

  @override
  String get acceptInvitation => 'Accept Invitation';

  @override
  String get back => 'Back';

  @override
  String get create => 'Create';

  @override
  String get failedToCreateChat => 'Failed to create chat.';

  @override
  String get accept => 'Accept';

  @override
  String get failedToReadAcceptance => 'Failed to read acceptance.';

  @override
  String get deleteChat => 'Delete Chat';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get copiedToTheClipboard => 'Copied to the clipboard.';

  @override
  String get copy => 'Copy';

  @override
  String get share => 'Share';

  @override
  String areYouSureYouWantToDeleteChatWith(Object personName) {
    return 'Are you sure you want to delete chat with $personName';
  }

  @override
  String get failedToGetAcceptance => 'Failed to get acceptance';

  @override
  String get errorPickingFiles => 'Error picking files.';

  @override
  String get loading => 'Loading';

  @override
  String get fuzz => 'Fuzz';

  @override
  String get failedToProcessFiles => 'Failed to process files';

  @override
  String get chatWithIndicatedNameAlreadyExists =>
      'Chat with indicated name already exists';

  @override
  String get show => 'Show';

  @override
  String get open => 'Open';

  @override
  String get dropFilesHere => 'Drop files here';

  @override
  String get basicEncryption => 'Basic Encryption';

  @override
  String get customKey => 'Custom Key';

  @override
  String get enterYourSecretKey => 'Enter your secret key';

  @override
  String get textToEncryptDecrypt => 'Text to Encrypt Decrypt';

  @override
  String get encryptText => 'Encrypt Text';

  @override
  String get decryptText => 'Decrypt Text';

  @override
  String get result => 'Result';

  @override
  String get processSelectedFiles => 'Process Selected Files';

  @override
  String get pleaseEnterAKey => 'Please enter a key';

  @override
  String get pleaseSelectFilesToProcess => 'Please select files to process';

  @override
  String get anUnknownErrorOccurred => 'An unknown error occurred';

  @override
  String get textAndKeyCannotBeEmpty => 'Text and key cannot be empty';

  @override
  String get encryptionFailed => 'Encryption failed';

  @override
  String get encryptedTextAndKeyCannotBeEmpty =>
      'Encrypted text and key cannot be empty';

  @override
  String get decryptionFailedCheckYourKeyOrEncryptedText =>
      'Decryption failed check your key or encrypted text';

  @override
  String get next => 'Next';

  @override
  String get settings => 'Settings';

  @override
  String get invalidLink => 'This link is invalid or corrupted.';

  @override
  String get alreadyConnected => 'Already connected!';

  @override
  String get cantAcceptOwnInvitation =>
      'You can\'t accept your own invitation.';

  @override
  String get chatNotFoundForAcceptance =>
      'Chat not found for this acceptance link.';

  @override
  String get failedToProcessAcceptance => 'Failed to process acceptance link.';

  @override
  String get shareFile => 'Share File';

  @override
  String get vaultUntitled => 'Untitled';

  @override
  String get vaultSave => 'Save';

  @override
  String get vaultPasswords => 'Passwords';

  @override
  String get vaultNotes => 'Notes';

  @override
  String get vaultFiles => 'Files';

  @override
  String get vaultFileLabel => 'File';

  @override
  String get vaultAll => 'All';

  @override
  String get vaultPasswordLabel => 'Password';

  @override
  String get vaultNoteLabel => 'Note';

  @override
  String get vaultPassword => 'Vault Password';

  @override
  String get vaultIncorrectPassword => 'Incorrect password';

  @override
  String get vaultUnlock => 'Unlock';

  @override
  String get vaultForgotPassword =>
      'Forgot password? Your data is encrypted and cannot be recovered.';

  @override
  String get menu => 'Menu';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get keyStrengthWeak => 'Weak (Too short)';

  @override
  String get keyStrengthModerate =>
      'Moderate (Consider adding numbers or letters)';

  @override
  String get keyStrengthStrong => 'Strong';

  @override
  String get keyStrengthGood => 'Good';

  @override
  String processingFile(Object fileName, Object progress) {
    return 'Processing: $fileName -> $progress%';
  }

  @override
  String get processingFailed => 'Processing Failed';

  @override
  String get chatUnlockTitle => 'Unlock Fuzzzy Ink';

  @override
  String get chatAuthIncorrectPassword => 'Incorrect password';

  @override
  String get chatAuthUnlock => 'Unlock';

  @override
  String get chatAuthResecuringKeys => 'Re-securing your keys…';

  @override
  String get benchmarkFileEncryption => 'Benchmark file encryption (dev)';

  @override
  String get benchmarkFileEncryptionDescription =>
      'Fuzzes and unfuzzes a 64 MiB temp file and reports MB/s';

  @override
  String get benchmarkResult => 'Benchmark result';

  @override
  String benchmarkResultSummary(Object encrypt, Object decrypt, Object sizeMiB,
      Object encryptKdf, Object decryptKdf, Object device, Object buildMode) {
    return 'Encrypt: $encrypt MB/s · Decrypt: $decrypt MB/s ($sizeMiB MiB)\nArgon2id: $encryptKdf s / $decryptKdf s (not in the MB/s)\n$device · $buildMode build';
  }

  @override
  String get close => 'Close';

  @override
  String get chatAuthPasswordTooWeak =>
      'Password is too weak. Use a longer one with letters, numbers and symbols.';

  @override
  String get biometricNotStrongEnough =>
      'This device\'s biometrics aren\'t strong enough to protect your password. Keep unlocking with your password.';

  @override
  String get biometricNotTurnedOn => 'Biometric unlock was not turned on.';

  @override
  String get vaultBiometricInvalidated =>
      'Your biometrics have changed. Biometric unlock has been disabled. Please re-enable it from settings.';

  @override
  String get invitationAlreadyUsed => 'This invitation was already used.';

  @override
  String get invalidInvitation => 'This invitation is invalid or damaged.';

  @override
  String get invalidAcceptance => 'This acceptance is invalid or damaged.';

  @override
  String get wrongChatBlob => 'This code belongs to a different chat.';

  @override
  String get alreadyUnfuzzed =>
      'This message was already unfuzzed on this device, or its one-time key is no longer kept.';

  @override
  String get corruptBlob => 'This is not a valid fuzzed message.';

  @override
  String get safetyNumberTitle => 'Safety number';

  @override
  String safetyNumberVersion(int version) {
    return 'Version $version. If your partner sees another version, or none, update both apps before comparing.';
  }

  @override
  String get wrongPasswordFile =>
      'Wrong password — this file cannot be unfuzzed with it.';

  @override
  String get fileStillArriving =>
      'This file is still being written — wait until it has fully arrived, then try again.';

  @override
  String get fileCannotBeOpenedAskToResend =>
      'This file cannot be opened; ask the sender to send it again.';

  @override
  String get basicsWrongPassword =>
      'Incorrect key — this text cannot be unfuzzed with it.';

  @override
  String get forwardSecrecyTitle => 'Unfuzzed once, on this device';

  @override
  String get forwardSecrecyNotice =>
      'Each fuzzed message can be unfuzzed once, on this device only. Your history stays in the app — export an archive to back it up. A new device cannot re-read old blobs.';

  @override
  String get aboutEncryptionTitle => 'About encryption';

  @override
  String get aboutEncryptionHistoryTitle => 'Your history on this device';

  @override
  String get aboutEncryptionBodyHistory =>
      'Every text you send or unfuzz is kept in the app, sealed per chat under a key only this device holds. If you set an app-lock password, that key is protected by it — without the password, the stored text history cannot be opened. Files are kept the same way: the app keeps only the sealed file, and unfuzzes it for the moment you open, save or share it. A file you save or share is yours — it leaves the app as an ordinary file, so protect it like any other file. Once unlocked, your chats stay open until you close the app; the app does not lock itself after a while. If you turn on biometric unlock, your password is stored securely on this device so a fingerprint or face can release it.';

  @override
  String get aboutEncryptionWindowTitle => 'Unfuzz in order';

  @override
  String get aboutEncryptionBodyWindow =>
      'The app keeps keys for skipped messages, but not without limit. A blob more than 63 messages behind the newest one you already read in that chat can no longer be unfuzzed — the app says it is too old — and no more than 40 skipped messages are kept at once. Your own sent blobs cannot be unfuzzed by you either; that is why the app keeps what you sent.';

  @override
  String get aboutEncryptionLinksTitle => 'Message links';

  @override
  String get aboutEncryptionBodyLinks =>
      'A message copied or shared as a link carries the chat’s id next to the blob, so tapping the link opens the right chat. The id is not part of the secret, but anyone who sees the link can tell which chat it belongs to. The blob itself carries no chat id.';

  @override
  String get aboutEncryptionErrorsTitle => 'What the errors mean';

  @override
  String get aboutEncryptionBodyErrors =>
      '“Already unfuzzed”: this blob was unfuzzed on this device before, or its one-time key is gone — more than 40 messages before it were skipped, or the chat has moved on several rounds since — so it can never be read here. “Not a valid fuzzed message”: the blob is damaged, incomplete, or belongs to a different chat — the app cannot tell these apart. “Too old”: it is more than 63 messages behind the newest one you already unfuzzed from that person. “Incorrect key” / “Wrong password” (Basics): the key or password does not match, or the text or file is damaged — the app cannot tell these apart either. For files, a receive that fails or is cancelled after it started has already used the file’s one-time key: ask the sender to send the file again.';

  @override
  String get aboutEncryptionBodySafetyNumber =>
      'Every chat has a 60-digit safety number, computed from both devices’ identity keys. Compare it with your partner by voice or in person: if the digits match, nobody sat in the middle when you paired. “Verified” is your own note that you did this — the app cannot check it for you.';

  @override
  String get aboutEncryptionUnderTheHoodTitle => 'Under the hood';

  @override
  String get aboutEncryptionBodyUnderTheHood =>
      'Messages use the Olm double ratchet (vodozemac, independently audited) — a fresh key per message, which is what makes a blob single-use. Files are sealed with XChaCha20-Poly1305 in chunks; a damaged file is refused and nothing is left on disk. Passwords go through Argon2id. Your secret keys live in the app’s native core and are never sent anywhere. There is no web version: the core is native code.';

  @override
  String get alreadyReceived =>
      'This file was already received on this device — it cannot be unfuzzed a second time.';

  @override
  String get fileTooOld =>
      'This file is too old to unfuzz — too many newer messages were unfuzzed first.';

  @override
  String get fileCorrupt =>
      'This is not a valid fuzzed file — it is damaged, incomplete, or from a different chat.';

  @override
  String get fileCancelled =>
      'Receiving was cancelled — this file cannot be unfuzzed on this device now; ask the sender to send it again.';

  @override
  String get exportChatArchiveFailed => 'Failed to export the chat archive.';

  @override
  String get exportChatArchiveNothingToExport =>
      'This chat has no messages to export.';

  @override
  String get exportChatArchiveStoreLocked =>
      'Unlock Fuzzzy Ink first — your history cannot be read while it is locked.';

  @override
  String get export => 'Export';

  @override
  String get couldNotOpenFile => 'Could not open file.';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get termsOfUse => 'Terms of use';

  @override
  String get support => 'Support';

  @override
  String get dataDeletion => 'Deleting your data';

  @override
  String get couldNotOpenLink => 'Could not open the link.';

  @override
  String get biometricUnlockChats => 'Authenticate to unlock chats';

  @override
  String get biometricUnlockVault => 'Authenticate to unlock vault';

  @override
  String get biometricUnlockVaultTitle => 'Unlock Fuzzy Vault';

  @override
  String get biometricSavePassword => 'Authenticate to save password';

  @override
  String get vaultMoveUnfinishedTitle => 'Vault not moved';

  @override
  String get vaultMoveUnfinishedMessage =>
      'Your vault couldn\'t be moved to its safe place in the app. Nothing was deleted. Close and reopen the app to try again.';

  @override
  String get copyRefused => 'Only sealed text can be copied.';

  @override
  String get vaultCopyPassword => 'Copy password';

  @override
  String get saveFile => 'Save';

  @override
  String get fileSaved => 'Saved.';

  @override
  String get couldNotSaveFile => 'Could not save the file.';

  @override
  String get unfuzzingFile => 'Unfuzzing…';

  @override
  String get fileNoPreview =>
      'This file cannot be shown in the app. Save it to open it with another app.';

  @override
  String get basicsFuzzedFilesTitle => 'Fuzzed files kept in the app';

  @override
  String get masterPassword => 'Master password';

  @override
  String get masterPasswordPreviousData =>
      'This version uses a master password. Chats and the vault from the earlier test version can\'t be opened with it, so they will be removed. Files you unfuzzed stay where they are.';

  @override
  String get masterPasswordFailed =>
      'Your keys could not be created. Try again.';

  @override
  String get recoveryKeyTitle => 'Recovery key';

  @override
  String get recoveryKeySaveFailed => 'The recovery key was not saved.';

  @override
  String recoveryKeyFileText(String key) {
    return 'Fuzzzy Ink recovery key\n\n$key\n\nIf you forget your master password, this key lets you set a new one. Keep it somewhere safe, away from the device. Without your password or this recovery key, nobody — not even us — can get your data back.\n';
  }

  @override
  String get recoveryKeyField => 'Recovery key';

  @override
  String get recoveryKeyTypo =>
      'This recovery key has a typo. Check each group of four.';

  @override
  String get recoveryKeyWrong => 'This recovery key does not open this app.';

  @override
  String get chatUnlockErase => 'Erase everything and start over';

  @override
  String get eraseTitle => 'Erase everything?';

  @override
  String get eraseMessage =>
      'Your chats, history, vault and settings are deleted from this device and cannot be brought back. Files you unfuzzed stay where they are.';

  @override
  String get eraseConfirm => 'Erase everything';

  @override
  String get storageUnavailable =>
      'Fuzzzy Ink can\'t read this device\'s secure key storage, so it stays locked. Try again; if it keeps happening, restart the device.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get appLockNow => 'Lock Fuzzzy Ink';

  @override
  String autoLockMinutes(int count) {
    return '$count min';
  }

  @override
  String get autoLockSaveFailed => 'The setting was not saved.';

  @override
  String get vaultUsesOwnPassword => 'The vault has its own password.';

  @override
  String get vaultUseOwnPassword => 'Use a different password for the vault';

  @override
  String get vaultUseMasterPassword =>
      'Open the vault with the master password';

  @override
  String get vaultOwnPasswordRecoveryNote =>
      'Your recovery key can still open My safe.';

  @override
  String get vaultRecoveryUseMasterPassword =>
      'Open My safe with my master password';

  @override
  String get vaultRecoverySubmit => 'Open My safe';

  @override
  String get tabHome => 'Home';

  @override
  String get tabMySafe => 'My safe';

  @override
  String get tabSettings => 'Settings';

  @override
  String get homeLockTitle => 'Lock';

  @override
  String get homeLockSubtitle => 'For one person';

  @override
  String get homeOpenTitle => 'Open';

  @override
  String get homeOpenSubtitle => 'What you got';

  @override
  String get homePeople => 'People';

  @override
  String homePeopleCount(int count) {
    return 'People · $count';
  }

  @override
  String get homeAdd => 'Add';

  @override
  String get homeAddPerson => 'Add a person';

  @override
  String get homeNoOneYet => 'No one yet';

  @override
  String get homeLoadError =>
      'Couldn\'t load your people. Close and open the app again.';

  @override
  String get stepYouSendInvite => 'You send an invite';

  @override
  String get stepTheyReply => 'They reply';

  @override
  String get stepInviteSent => 'Invite sent';

  @override
  String stepNameReplies(String name) {
    return '$name replies';
  }

  @override
  String get stepLockForEachOther => 'Lock for each other';

  @override
  String stepsProgress(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String stepsProgressWithLabel(int step, int total, String label) {
    return 'Step $step of $total · $label';
  }

  @override
  String stepDone(String step) {
    return 'Done: $step';
  }

  @override
  String stepNext(String step) {
    return 'Next: $step';
  }

  @override
  String get addSendInvite => 'Send an invite';

  @override
  String get addYouStart => 'You start';

  @override
  String get addGotInvite => 'I got an invite';

  @override
  String get addTheyStarted => 'They started';

  @override
  String get chipWaitingForReply => 'Waiting for reply';

  @override
  String get chipChecked => 'Checked';

  @override
  String get chipNotChecked => 'Not checked';

  @override
  String get personRowWaitingLine => 'Then you can lock for each other';

  @override
  String waitNoteReply(String name) {
    return 'Once $name replies, you can lock messages for each other.';
  }

  @override
  String get waitNoteAnyWay =>
      'Send the invite any way, even publicly. It stays safe.';

  @override
  String get linkWhy => 'Why?';

  @override
  String get linkHow => 'How?';

  @override
  String get linkMore => 'More';

  @override
  String get linkOpensExplanation => 'Opens an explanation';

  @override
  String get gotIt => 'Got it';

  @override
  String get infoNoResetTitle => 'Why no reset?';

  @override
  String get infoNoResetLine1 => 'Your password never leaves this phone.';

  @override
  String get infoNoResetLine2 => 'We can\'t see it, so no one can reset it.';

  @override
  String get infoNoResetLine3 => 'Your recovery key is the only spare.';

  @override
  String get infoRecoveryKeyTitle => 'Your recovery key';

  @override
  String get infoRecoveryKeyLine1 => 'Your spare if you forget the password.';

  @override
  String get infoRecoveryKeyLine2 => 'It opens Fuzzzy Ink, and My safe too.';

  @override
  String get infoRecoveryKeyLine3 =>
      'Print it or save it off this phone. Anyone with it and your phone can open everything.';

  @override
  String get infoOpensOnceTitle => 'Why only once?';

  @override
  String get infoOpensOnceLine1 => 'Each locked thing has its own key.';

  @override
  String get infoOpensOnceLine2 => 'Opening it uses the key up, on any phone.';

  @override
  String get infoOpensOnceLine3 => 'A copy stays in your history, locked.';

  @override
  String get infoSafeAnywhereTitle => 'Safe to send anywhere';

  @override
  String get infoSafeAnywhereLine1 => 'An invite can\'t open anything.';

  @override
  String get infoSafeAnywhereLine2 => 'Only their reply connects you two.';

  @override
  String get infoSafeAnywhereLine3 =>
      'Then you check numbers together, so you know it\'s them.';

  @override
  String get infoCheckNumbersTitle => 'Why check numbers?';

  @override
  String get infoCheckNumbersLine1 =>
      'Anyone who saw your invite could answer it.';

  @override
  String get infoCheckNumbersLine2 =>
      'Same numbers on both phones: nobody got in between.';

  @override
  String get infoFilesTitle => 'Where do files go?';

  @override
  String get infoFilesLine1 => 'Fuzzzy Ink keeps only the locked copy.';

  @override
  String get infoFilesLine2 => 'Open shows it here. Nothing is saved.';

  @override
  String get infoFilesLine3 =>
      'Save gives you a normal copy. From then on it\'s yours to protect.';

  @override
  String get infoNoCopyingTitle => 'Why no copying?';

  @override
  String get infoNoCopyingLine1 => 'What you open stays inside Fuzzzy Ink.';

  @override
  String get infoNoCopyingLine2 =>
      'Only locked text can be copied. It is safe anywhere.';

  @override
  String get infoPasswordLockingTitle => 'Locking with a password';

  @override
  String get infoPasswordLockingLine1 =>
      'Anyone with the password can open it.';

  @override
  String get infoPasswordLockingLine2 =>
      'Say the password. Never send it with the locked thing.';

  @override
  String get infoSafePasswordTitle => 'My safe\'s own password';

  @override
  String get infoSafePasswordLine1 => 'One more password to remember.';

  @override
  String get infoSafePasswordLine2 =>
      'Forgot it? Your recovery key opens My safe too.';

  @override
  String get tagNoCopyNoScreenshots => 'No copy · no screenshots';

  @override
  String get tagNoCopy => 'No copy';

  @override
  String get lockWhoTitle => 'Who\'s it for?';

  @override
  String get lockWithPassword => 'Lock with a password';

  @override
  String get lockNoInviteNeeded => 'No invite needed';

  @override
  String get lockAddPersonFirst => 'Add a person first';

  @override
  String get orDivider => 'or';

  @override
  String get openWhatYouGot => 'Open what you got';

  @override
  String get openPasteIt => 'Paste it';

  @override
  String get openPasteItHint => 'Locked text, invite or reply';

  @override
  String get openLinksTip => 'Links and QR codes open here by themselves.';

  @override
  String get openNothingToPaste =>
      'Nothing to paste. Copy the locked text first.';

  @override
  String get openLockedWithPassword => 'Locked with a password';

  @override
  String get lockStepWho => 'Who';

  @override
  String get lockStepWhat => 'What';

  @override
  String lockForName(String name) {
    return 'Lock for $name';
  }

  @override
  String get lockKindMessage => 'Message';

  @override
  String get lockKindFile => 'File';

  @override
  String get lockWriteMessageHint => 'Write your message…';

  @override
  String lockOnlyNameOnce(String name) {
    return 'Only $name can open it, once.';
  }

  @override
  String get lockChooseFile => 'Choose a file';

  @override
  String get lockDropHint => 'Or drop it here on a computer';

  @override
  String get lockChangeFile => 'Change';

  @override
  String get lockPasswordLabel => 'Password for this';

  @override
  String get lockSayPassword => 'Say the password. Don\'t send it.';

  @override
  String get lockAction => 'Lock';

  @override
  String get lockWriteSomethingFirst => 'Write something first.';

  @override
  String get lockChooseFileFirst => 'Choose a file first.';

  @override
  String get lockPasswordNotGood => 'It needs to reach Good.';

  @override
  String get lockFailed => 'Couldn\'t lock it. Try again.';

  @override
  String get lockStoppedNothingKept => 'Stopped. Nothing was kept.';

  @override
  String get workingLocking => 'Locking';

  @override
  String get workingOpening => 'Opening';

  @override
  String get workingStarting => 'Starting…';

  @override
  String get workingPause => 'Pause';

  @override
  String get workingGoOn => 'Go on';

  @override
  String get workingPaused => 'Paused';

  @override
  String lockedForName(String name) {
    return 'Locked for $name';
  }

  @override
  String get lockedWithPassword => 'Locked with a password';

  @override
  String get lockedNowSendIt => 'Now send it.';

  @override
  String get lockedSentToShareMenu => 'Sent to your share menu.';

  @override
  String get lockedShareAgain => 'Share again';

  @override
  String get lockedCopyText => 'Copy locked text';

  @override
  String get lockedSaveFile => 'Save locked file';

  @override
  String get flowDone => 'Done';

  @override
  String get openChooseFile => 'Choose a file';

  @override
  String get openChooseFileHint => 'A .fuzz file';

  @override
  String get openReading => 'Reading…';

  @override
  String openedFromName(String name) {
    return 'From $name';
  }

  @override
  String openedKeptInHistory(String name) {
    return 'Just now · kept in $name\'s history';
  }

  @override
  String get openedWithPassword => 'Opened with a password';

  @override
  String get openedNotKept => 'Just now · not kept';

  @override
  String openedInHistoryNow(String name) {
    return 'In $name\'s history now.';
  }

  @override
  String get openedSaveTip => 'Save gives you a normal copy. Then it\'s yours.';

  @override
  String get openPasswordTitle => 'What\'s the password?';

  @override
  String get openPasswordLabel => 'Password';

  @override
  String get openPasswordWrong =>
      'That doesn\'t open it. Check it and try again.';

  @override
  String get openErrorAlreadyTitle => 'Already opened';

  @override
  String openErrorAlreadyLine(String name) {
    return 'Each locked thing opens once. It\'s in $name\'s history.';
  }

  @override
  String get openErrorNotYoursTitle => 'Not from your people';

  @override
  String get openErrorNotYoursLine => 'Ask them for an invite first.';

  @override
  String get openErrorDamagedTitle => 'Can\'t open this';

  @override
  String get openErrorDamagedLine =>
      'It may be cut off or for someone else. Ask them to send it again.';

  @override
  String get openErrorOldTitle => 'Too old to open';

  @override
  String openErrorOldLine(String name) {
    return 'Ask $name to lock it again.';
  }

  @override
  String get openErrorNewerTitle => 'Needs a newer Fuzzzy Ink';

  @override
  String get openErrorNewerLine => 'Update the app, then try again.';

  @override
  String get openErrorOwnTitle => 'That\'s your own invite';

  @override
  String get openErrorOwnLine => 'Send it to the other person.';

  @override
  String get openErrorConnectedTitle => 'Already connected';

  @override
  String openErrorConnectedLine(String name) {
    return 'You and $name are connected already.';
  }

  @override
  String get openErrorNotFuzzzyTitle => 'This isn\'t from Fuzzzy Ink';

  @override
  String get openErrorNotFuzzzyLine =>
      'Open locked text, an invite or a reply.';

  @override
  String get openErrorArrivingTitle => 'Still arriving';

  @override
  String get openErrorArrivingLine =>
      'Wait until the file has fully arrived, then try again.';

  @override
  String get openErrorResendTitle => 'This file didn\'t open';

  @override
  String get openErrorResendLine =>
      'It can\'t open on this phone now. Ask them to send it again.';

  @override
  String openErrorGoToName(String name) {
    return 'Go to $name';
  }

  @override
  String get openErrorOk => 'OK';

  @override
  String get openFailed => 'Couldn\'t open it. Try again.';

  @override
  String get shareTitleInvite => 'Share invite';

  @override
  String get shareTitleReply => 'Share reply';

  @override
  String get shareTitleMessage => 'Share locked message';

  @override
  String get shareTitleFile => 'Share locked file';

  @override
  String get shareLineInvite => 'Any way. Even publicly.';

  @override
  String get shareLineReply => 'Any way you like.';

  @override
  String shareLineForName(String name) {
    return 'Only $name can open it.';
  }

  @override
  String get shareLinePassword => 'They need the password.';

  @override
  String get shareSendLink => 'Send a link';

  @override
  String get shareSendLinkHint => 'Opens in the app';

  @override
  String get shareShowQr => 'Show a QR code';

  @override
  String get shareShowQrHint => 'They scan it';

  @override
  String get shareSendFile => 'Send as a file';

  @override
  String get shareSendFileHint => 'A small file';

  @override
  String get shareCopyText => 'Copy as text';

  @override
  String get shareCopyTextHint => 'Stays locked anywhere';

  @override
  String get shareTooBig => 'Too big. Send it as a file.';

  @override
  String get shareCopiedStaysLocked => 'Copied. It stays locked.';

  @override
  String get qrLabelInvite => 'Your invite';

  @override
  String get qrLabelReply => 'Your reply';

  @override
  String get qrLabelMessage => 'Locked message';

  @override
  String qrLetNameScan(String name) {
    return 'Let $name scan this.';
  }

  @override
  String get qrLetThemScan => 'Let them scan this.';

  @override
  String get qrSafeToShowAnyone =>
      'Safe to show anyone. Only their reply connects you.';

  @override
  String get qrOnlyRightPerson => 'Only show it to the right person.';

  @override
  String get historyYouLockedMessage => 'You locked a message';

  @override
  String get historyYouOpenedMessage => 'You opened a message';

  @override
  String historyYouLockedFile(String file) {
    return 'You locked $file';
  }

  @override
  String historyYouOpenedFile(String file) {
    return 'You opened $file';
  }

  @override
  String get historyTapToRead => 'tap to read';

  @override
  String get historyTapToSee => 'tap to see';

  @override
  String get fileCardLocked => 'Locked';

  @override
  String get fileCardKeptInSafe => 'Kept locked in My safe';

  @override
  String get lockedPreviewLabel => 'Locked version · safe to send';

  @override
  String get confirmCopied => 'Copied';

  @override
  String get confirmHandedOver => 'Handed over';

  @override
  String get safetyGridLabel => 'Safety numbers';

  @override
  String lockoutWaitLeft(String time) {
    return 'Wait $time';
  }

  @override
  String get settingsLookAndLanguage => 'Look and language';

  @override
  String get settingsLook => 'Look';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get lookLikeMyPhone => 'Like my phone';

  @override
  String get lookLight => 'Light';

  @override
  String get lookDark => 'Dark';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGeorgian => 'ქართული';

  @override
  String get fuzzzyCast => 'Fuzzzy Cast';

  @override
  String get fuzzzyCastLine => 'Fuzzz reacts when you lock and open.';

  @override
  String get fuzzzyCastOn => 'Fuzzzy Cast is on.';

  @override
  String get softSounds => 'Soft sounds';

  @override
  String get safeLockedTitle => 'My safe is locked';

  @override
  String get safeLockButton => 'Lock My safe';

  @override
  String get safeOpensWithMaster => 'Opens with your master password.';

  @override
  String get safeOpensWithOwn => 'Opens with your safe password.';

  @override
  String get safeOpenWithFingerprint => 'Open with fingerprint';

  @override
  String get safeUseMasterPassword => 'Use master password';

  @override
  String get safeUseSafePassword => 'Use safe password';

  @override
  String get safePasswordField => 'Safe password';

  @override
  String get safeOpenButton => 'Open My safe';

  @override
  String get safeUseRecoveryKey => 'Use recovery key';

  @override
  String get safeWrongPassword => 'Not right. Try again.';

  @override
  String get safeTooManyTries => 'Too many tries.';

  @override
  String get safeCouldNotOpen => 'Couldn\'t open My safe. Try again.';

  @override
  String get safeRecoveryTitle => 'Type your recovery key';

  @override
  String get safeRecoveryLine => 'Spaces and capitals don\'t matter.';

  @override
  String get safeRecoveryNoKey => 'No key? Then nothing can open it.';

  @override
  String get safeRecoveryNewPassword => 'New safe password';

  @override
  String get safeSearch => 'Search';

  @override
  String get safeAllGroups => 'All groups';

  @override
  String get safeNewGroup => 'New group';

  @override
  String get safeEmptyTitle => 'Nothing here yet';

  @override
  String get safeEmptyLine => 'Tap Add.';

  @override
  String get safeNothingFound => 'Nothing found';

  @override
  String get safeTryAnotherWord => 'Try another word.';

  @override
  String get safeLoadError =>
      'Couldn\'t load My safe. Lock it and open it again.';

  @override
  String safeAutoLockTip(int minutes) {
    return 'Locks itself after $minutes minutes away';
  }

  @override
  String get safeAdd => 'Add';

  @override
  String get safeAddTitle => 'Add to My safe';

  @override
  String get safeUsername => 'Username or email';

  @override
  String get safeWebsite => 'Website';

  @override
  String get safeNotes => 'Notes';

  @override
  String get safeShowPassword => 'Show password';

  @override
  String get safeHidePassword => 'Hide password';

  @override
  String safeCopiedClearsIn(int seconds) {
    return 'Copied · clears in $seconds s';
  }

  @override
  String safeCopyRule(int seconds) {
    return 'Copied passwords clear after $seconds seconds.';
  }

  @override
  String get safeCleared => 'Cleared.';

  @override
  String get safeCopyOff => 'Copying is off in Settings.';

  @override
  String get safeGroup => 'Group';

  @override
  String get safeNoGroup => 'No group';

  @override
  String get safeMove => 'Move';

  @override
  String get safeEdit => 'Edit';

  @override
  String safeMoreFor(String title) {
    return 'More for $title';
  }

  @override
  String get safeSaveTip => 'Save gives you a normal copy. Then it\'s yours.';

  @override
  String get safeMoveToGroup => 'Move to a group';

  @override
  String safeDeleteTitle(String title) {
    return 'Delete $title?';
  }

  @override
  String get safeDeleteLine => 'It leaves My safe for good. No undo.';

  @override
  String get safeDeleted => 'Deleted from My safe.';

  @override
  String safeMovedTo(String group) {
    return 'Moved to $group.';
  }

  @override
  String get safeMovedOut => 'Removed from its group.';

  @override
  String get safeSaved => 'Saved in My safe.';

  @override
  String get safeItemLoadFailed => 'Couldn\'t open this. Try again.';

  @override
  String get safeSaveFailed => 'Couldn\'t save. Try again.';

  @override
  String get safeGroupName => 'Group name';

  @override
  String get safeGroupHint => 'e.g. Family';

  @override
  String get safeAddGroup => 'Add group';

  @override
  String get safeNewPasswordTitle => 'New password';

  @override
  String get safeNewNoteTitle => 'New note';

  @override
  String get safeNewFileTitle => 'New file';

  @override
  String get safeTitle => 'Title';

  @override
  String get safeTitleHintPassword => 'e.g. Bank app';

  @override
  String get safeTitleHintNote => 'e.g. Passport number';

  @override
  String get safeTitleHintFile => 'e.g. Home insurance';

  @override
  String get safeOptional => 'optional';

  @override
  String get safeNoteHint => 'Anything to keep safe';

  @override
  String get safeChooseFile => 'Choose a file';

  @override
  String get safeOriginalStays => 'Your original stays where it is.';

  @override
  String get safeChangeFile => 'Change';

  @override
  String get safeChooseFileFirst => 'Choose a file first.';

  @override
  String get accessWelcomeLine => 'Lock it. Only they can open it.';

  @override
  String get accessWelcomeTag => 'No accounts · nothing goes online';

  @override
  String get accessStart => 'Start';

  @override
  String get accessHowItWorks => 'How it works';

  @override
  String get accessHowAddPerson => 'Add a person';

  @override
  String get accessHowLockForThem => 'Lock for them';

  @override
  String get accessHowTheyOpenOnce => 'They open it, once';

  @override
  String get accessWhyOnce => 'Why once?';

  @override
  String get accessHowTip =>
      'One master password guards it all. You make it next.';

  @override
  String get accessContinue => 'Continue';

  @override
  String get accessStepPassword => 'Password';

  @override
  String get accessMakeMasterPassword => 'Make a master password';

  @override
  String get accessTypeItAgain => 'Type it again';

  @override
  String get accessNoResetBold => 'No reset.';

  @override
  String get accessNoResetLine =>
      'Lose it and your recovery key, and everything is gone.';

  @override
  String get accessUnderstandNoAccess =>
      'I understand: no password and no key means no access.';

  @override
  String get accessPasswordsDontMatch => 'They don\'t match yet.';

  @override
  String get accessStrengthWeak => 'Weak';

  @override
  String get accessStrengthFair => 'Fair';

  @override
  String get accessStrengthGood => 'Good';

  @override
  String get accessStrengthStrong => 'Strong';

  @override
  String get accessStrengthHintEmpty => 'Tip: a few random words.';

  @override
  String get accessStrengthHintWeak => 'Make it longer.';

  @override
  String get accessStrengthHintFair => 'Add a few more words.';

  @override
  String get accessStrengthHintGood => 'Hard to guess.';

  @override
  String get accessStrengthHintStrong => 'Very hard to guess.';

  @override
  String accessStrengthLabel(String level) {
    return 'Password strength: $level';
  }

  @override
  String get accessShowPassword => 'Show password';

  @override
  String get accessHidePassword => 'Hide password';

  @override
  String get accessYourRecoveryKey => 'Your recovery key';

  @override
  String get accessRecoverySpare => 'Your spare, if you forget the password.';

  @override
  String get accessPrint => 'Print';

  @override
  String get accessSaveAsFile => 'Save as file';

  @override
  String get accessSaved => 'Saved';

  @override
  String get accessKeepOffPhone =>
      'Keep it off this phone. Anyone with it can open everything.';

  @override
  String get accessKeptItSafe => 'I\'ve kept it safe';

  @override
  String get accessSkipForNow => 'Skip for now';

  @override
  String get accessSkipKeyTitle => 'Skip the recovery key?';

  @override
  String get accessSkipKeyMessage =>
      'Forget your password without it, and everything is lost. You can make one later in Settings.';

  @override
  String get accessSkipKeyKeep => 'Keep it now';

  @override
  String get accessSkipKeyAnyway => 'Skip anyway';

  @override
  String get accessPrintPreview => 'Print preview';

  @override
  String get accessPrintSheetTitle => 'Fuzzzy Ink · recovery key';

  @override
  String get accessPrintLine1 =>
      'Opens Fuzzzy Ink and My safe if you forget your password.';

  @override
  String get accessPrintLine2 =>
      'Anyone with this key and your phone can open everything. Keep it away from your phone.';

  @override
  String get accessPrintLine3 =>
      'Lose your password and this key, and nothing can be recovered.';

  @override
  String accessPrintMade(String date) {
    return 'Made $date. A new key from Settings stops this one.';
  }

  @override
  String get accessPrintHint =>
      'Your phone\'s share menu opens. Choose Print there.';

  @override
  String get accessPrintFailed =>
      'The print sheet could not be made. Try Save as file.';

  @override
  String get accessStepQuickUnlock => 'Quick unlock';

  @override
  String get accessBioTitle => 'Unlock with your fingerprint?';

  @override
  String get accessBioLine => 'Your password always works too.';

  @override
  String get accessBioTip => 'Locks itself after 5 minutes away';

  @override
  String get accessUseBio => 'Use fingerprint or face';

  @override
  String get accessNotNow => 'Not now';

  @override
  String get accessReadyTitle => 'You\'re ready';

  @override
  String get accessAddFirstPerson => 'Add your first person';

  @override
  String get accessLookAround => 'Look around first';

  @override
  String get accessLockedTitle => 'Fuzzzy Ink is locked';

  @override
  String get accessWrongPassword => 'Not right. Try again.';

  @override
  String get accessTooManyTries => 'Too many tries.';

  @override
  String get accessForgotPassword => 'Forgot your password?';

  @override
  String get accessLinkWaiting => 'A link is waiting. Unlock to open it.';

  @override
  String get accessBioChanged =>
      'Your fingerprint or face changed, so quick unlock is off. Turn it on again in Settings.';

  @override
  String get accessBioReset =>
      'An update turned quick unlock off to make it safer. Turn it on again in Settings.';

  @override
  String get accessRecoveryKeyHeader => 'Recovery key';

  @override
  String get accessTypeRecoveryKey => 'Type your recovery key';

  @override
  String get accessSpacesDontMatter => 'Spaces and capitals don\'t matter.';

  @override
  String get accessNoKeyNothing => 'No key? Then nothing can open it.';

  @override
  String get accessKeyTooShort => 'A recovery key has 8 groups of 4.';

  @override
  String get accessKeyDoesntMatch =>
      'That key doesn\'t match. Check each group.';

  @override
  String get accessNewMasterPassword => 'New master password';

  @override
  String get accessKeyCheckedOnSave => 'Your key is checked when you save.';

  @override
  String get accessSaveNewPassword => 'Save new password';

  @override
  String get accessNewPasswordSaved => 'New master password saved.';

  @override
  String get accessSettingsKeepingSafe => 'Keeping it safe';

  @override
  String get accessChangeIt => 'Change it';

  @override
  String get accessMakeNewOne => 'Make a new one';

  @override
  String get accessNoKeyYet => 'None yet';

  @override
  String get accessFingerprintOrFace => 'Fingerprint or face';

  @override
  String get accessNotOnThisDevice => 'Not on this device';

  @override
  String get accessLockTheApp => 'Lock the app';

  @override
  String accessLockAfter(String time) {
    return 'After $time';
  }

  @override
  String get accessLockNow => 'Lock now';

  @override
  String get accessLockAfterTitle => 'Lock the app after';

  @override
  String get accessRightAway => 'Right away';

  @override
  String get accessOneMinute => '1 minute';

  @override
  String get accessFiveMinutes => '5 minutes';

  @override
  String get accessFifteenMinutes => '15 minutes';

  @override
  String get accessOneHour => '1 hour';

  @override
  String get accessRecommended => 'recommended';

  @override
  String get accessOpensWith => 'Opens with';

  @override
  String get accessItsOwnPassword => 'Its own password';

  @override
  String get accessCopyPasswords => 'Copy passwords';

  @override
  String get accessClearsAfter30 => 'Clears after 30 seconds';

  @override
  String get accessOff => 'Off';

  @override
  String get accessSoftSoundsSoon => 'Coming in an update';

  @override
  String get accessHelp => 'Help';

  @override
  String get accessHowFuzzzyInkWorks => 'How Fuzzzy Ink works';

  @override
  String get accessPrivacyTermsSupport => 'Privacy, terms and support';

  @override
  String get accessOpensYourBrowser => 'Opens your browser';

  @override
  String get accessBrowserTip =>
      'Opens your browser. The app itself never goes online.';

  @override
  String get accessDeveloper => 'Developer';

  @override
  String accessVersionFooter(String version, String build) {
    return 'Fuzzzy Ink · version $version (build $build)';
  }

  @override
  String get accessTurnOnBioTitle => 'Turn on fingerprint or face';

  @override
  String get accessTurnOnBioLine => 'Type your master password once.';

  @override
  String get accessTurnOnSafeBioTitle => 'Fingerprint for My safe';

  @override
  String get accessTurnOnSafeBioLine => 'Type My safe\'s own password once.';

  @override
  String get accessTurnOn => 'Turn on';

  @override
  String get accessBioOn => 'Fingerprint or face is on.';

  @override
  String get accessMySafePassword => 'My safe\'s password';

  @override
  String get accessChangeMasterPassword => 'Change master password';

  @override
  String get accessCurrentPassword => 'Current password';

  @override
  String get accessNewPassword => 'New password';

  @override
  String get accessRecoveryKeepsWorking => 'Your recovery key keeps working.';

  @override
  String get accessChangePassword => 'Change password';

  @override
  String get accessMasterPasswordChanged => 'Master password changed.';

  @override
  String get accessMakeNewKey => 'Make a new key';

  @override
  String get accessOldKeyStops => 'The old key stops working.';

  @override
  String get accessSafePasswordToo =>
      'My safe has its own password. Type it too, so the new key opens My safe.';

  @override
  String get accessYourNewKey => 'Your new key';

  @override
  String get accessNoPasswordNoKey => 'No password and no key means no access.';

  @override
  String get accessNewKeyKept => 'Your new recovery key is set.';

  @override
  String get accessSafeOpensWith => 'My safe opens with';

  @override
  String get accessSimplestRecommended => 'Simplest. Recommended.';

  @override
  String get accessOneMoreToRemember => 'One more to remember';

  @override
  String get accessSafePassword => 'Safe password';

  @override
  String get accessSaveSafePassword => 'Save safe password';

  @override
  String get accessSafeHasOwnPassword => 'My safe now has its own password.';

  @override
  String get accessUseMasterPassword => 'Use master password';

  @override
  String get accessSafeUsesMaster =>
      'My safe opens with your master password again.';

  @override
  String get accessSafeNotMadeYet =>
      'My safe isn\'t made yet. Open it once from its tab.';

  @override
  String get accessMasterPasswordToConfirm =>
      'Your master password, to confirm';

  @override
  String get accessHowOnceTitle => 'Each thing opens once';

  @override
  String get accessHowOnceBody =>
      'Opening uses its key up. A copy stays in your history.';

  @override
  String get accessHowHistoryTitle => 'History stays on this phone';

  @override
  String get accessHowHistoryBody =>
      'Locked with your master password. A new phone can\'t read it. Save a person\'s history as a file to keep a copy.';

  @override
  String get accessHowOrderTitle => 'Open things in order';

  @override
  String get accessHowOrderBody =>
      'A very old message may be too old to open. Then ask them to lock it again.';

  @override
  String get accessHowCheckTitle => 'Checking a person';

  @override
  String get accessHowCheckBody =>
      'Same numbers on both phones: nobody got in between. \"Checked\" is your own note.';

  @override
  String get accessHowLinksTitle => 'Links';

  @override
  String get accessHowLinksBody =>
      'What comes after the # never reaches our website.';

  @override
  String get accessHowFilesTitle => 'Files you save';

  @override
  String get accessHowFilesBody =>
      'The app keeps only locked files. A saved copy is yours to protect.';

  @override
  String get accessHowHoodTitle => 'Under the hood';

  @override
  String get accessHowHoodBody =>
      'Messages use the Olm double ratchet (vodozemac, independently audited): a new key for every message. Files are sealed with XChaCha20-Poly1305 in pieces. Passwords go through Argon2id. Keys live in the app\'s native core and are never sent anywhere.';

  @override
  String get accessMoreAboutEncryption => 'More about encryption';

  @override
  String personMoreFor(String name) {
    return 'More for $name';
  }

  @override
  String get personNotCheckedLead => 'Not checked yet.';

  @override
  String get personNotCheckedAction => 'Check numbers.';

  @override
  String get historyFilterAll => 'All';

  @override
  String get historyFilterLocked => 'Locked';

  @override
  String get historyFilterOpened => 'Opened';

  @override
  String get historyToday => 'Today';

  @override
  String get historyYesterday => 'Yesterday';

  @override
  String get historyEmpty => 'Nothing here yet.';

  @override
  String get historyEmptyLocked => 'Nothing locked yet.';

  @override
  String get historyEmptyOpened => 'Nothing opened yet.';

  @override
  String get historyStaysLocked => 'History stays locked on this phone.';

  @override
  String get historyLoadError => 'Couldn\'t load the history.';

  @override
  String waitingCardTitle(String name) {
    return 'Waiting for $name\'s reply';
  }

  @override
  String get waitingShareInviteAgain => 'Share invite again';

  @override
  String get waitingGotReply => 'I got the reply';

  @override
  String get personMenuCheckNumbers => 'Check numbers';

  @override
  String get personMenuNotCheckedYet => 'Not checked yet';

  @override
  String get personMenuSendReplyAgain => 'Send my reply again';

  @override
  String get personMenuSaveHistory => 'Save history as a file';

  @override
  String get personMenuSaveHistoryHint => 'Locked with a password';

  @override
  String personMenuRemove(String name) {
    return 'Remove $name';
  }

  @override
  String removePersonTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get removePersonBody =>
      'Their history and files leave this phone. No undo.';

  @override
  String get removePersonConfirm => 'Remove';

  @override
  String removePersonDone(String name) {
    return '$name was removed.';
  }

  @override
  String removePersonFailed(String name) {
    return 'Couldn\'t remove $name. Try again.';
  }

  @override
  String exportHistoryTitle(String name) {
    return 'Save $name\'s history';
  }

  @override
  String get exportHistoryLine => 'One file, locked with this password.';

  @override
  String get exportHistoryPassword => 'Password for the file';

  @override
  String get exportHistorySave => 'Save file';

  @override
  String get exportHistorySaved => 'History saved as a file.';

  @override
  String itemForName(String name) {
    return 'For $name';
  }

  @override
  String itemYouLockedWhen(String day, String time) {
    return 'You locked this · $day · $time';
  }

  @override
  String itemOpenedWhen(String day, String time) {
    return 'Opened $day · $time';
  }

  @override
  String get itemShareAgain => 'Share again';

  @override
  String get itemCopyLocked => 'Copy locked';

  @override
  String get itemOnlyLockedKept => 'Only the locked copy is kept.';

  @override
  String get itemSave => 'Save';

  @override
  String get itemUnreadable => 'This message can\'t be read on this phone.';

  @override
  String get itemDone => 'Done';

  @override
  String get inviteStepName => 'Name';

  @override
  String get inviteStepSend => 'Send';

  @override
  String get inviteWhoFor => 'Who\'s it for?';

  @override
  String get inviteTheirName => 'Their name';

  @override
  String get inviteNameHint => 'e.g. Tamar';

  @override
  String get inviteOnlyYouSee => 'Only you see it.';

  @override
  String get inviteMake => 'Make the invite';

  @override
  String get inviteNameTaken => 'You already have someone with this name.';

  @override
  String get inviteMakeFailed => 'Couldn\'t make the invite. Try again.';

  @override
  String inviteSendTo(String name) {
    return 'Send it to $name';
  }

  @override
  String get inviteDoneForNow => 'Done for now';

  @override
  String inviteGotNameReply(String name) {
    return 'I got $name\'s reply';
  }

  @override
  String get inviteSharedLine => 'Sent to your share menu.';

  @override
  String get inviteConnecting => 'Connecting…';

  @override
  String get inviteLoadFailed =>
      'Couldn\'t read the invite. Close and open it again.';

  @override
  String get replyOpenTitle => 'Open the reply';

  @override
  String get pasteItHint => 'Copied text or link';

  @override
  String get chooseFile => 'Choose a file';

  @override
  String get chooseFileHint => 'The file they sent';

  @override
  String get replyNothingToPaste => 'Nothing to paste. Copy the reply first.';

  @override
  String get inviteNothingToPaste => 'Nothing to paste. Copy the invite first.';

  @override
  String get notAReply => 'That isn\'t a reply. Check what you pasted.';

  @override
  String get couldNotReadFile => 'Couldn\'t read that file.';

  @override
  String get replyNotConnected =>
      'That reply didn\'t connect you. Ask for it again.';

  @override
  String get gotStepOpen => 'Open it';

  @override
  String get gotStepReply => 'Reply';

  @override
  String get gotOpenTitle => 'Open the invite';

  @override
  String get gotInviteGood => 'The invite is good.';

  @override
  String get gotWhoSent => 'Who sent it?';

  @override
  String get gotAccept => 'Accept';

  @override
  String get gotOwnInviteTitle => 'That\'s your own invite';

  @override
  String get gotOwnInviteLine => 'Send it to the other person.';

  @override
  String get gotAlreadyTitle => 'You\'re already connected';

  @override
  String get gotAlreadyLine => 'This invite is already open on this phone.';

  @override
  String get gotDamagedTitle => 'Can\'t open this';

  @override
  String get gotDamagedLine =>
      'It may be cut off or for someone else. Ask them to send it again.';

  @override
  String get gotAcceptFailed => 'Couldn\'t accept the invite. Try again.';

  @override
  String replySendTo(String name) {
    return 'Send your reply to $name';
  }

  @override
  String get replySameWay => 'The same way the invite came.';

  @override
  String get replyCheckTip => 'Then check numbers together.';

  @override
  String get stepInviteOpened => 'Invite opened';

  @override
  String get stepYouReply => 'You reply';

  @override
  String connectedWith(String name) {
    return 'Connected with $name';
  }

  @override
  String isItReally(String name) {
    return 'Is it really $name?';
  }

  @override
  String get checkTogether => 'Check numbers together.';

  @override
  String get checkNow => 'Check now';

  @override
  String get checkLater => 'Later';

  @override
  String get twiceTitle => 'Someone else may have answered';

  @override
  String twiceLine(String name) {
    return 'Your invite to $name got two replies.';
  }

  @override
  String twiceNoteLead(String name) {
    return 'Don\'t lock anything for $name yet.';
  }

  @override
  String get twiceNoteRest => 'Check numbers first.';

  @override
  String twiceRemove(String name) {
    return 'Remove $name, invite again';
  }

  @override
  String get safetyCompare => 'Compare on a call, or side by side.';

  @override
  String get safetySame => 'Same numbers';

  @override
  String get safetyDifferent => 'Different numbers';

  @override
  String get safetyMarkNotChecked => 'Mark as not checked';

  @override
  String safetyCheckedBefore(String name) {
    return 'You checked $name before.';
  }

  @override
  String safetyNowNotChecked(String name) {
    return '$name is now Not checked.';
  }

  @override
  String get safetyLoadFailed =>
      'Couldn\'t read the numbers. Close and open them again.';

  @override
  String get safetySaveFailed => 'Couldn\'t save that. Try again.';

  @override
  String mismatchLead(String name) {
    return 'Don\'t send $name anything.';
  }

  @override
  String get mismatchRest =>
      'Someone may be in between. Remove and add them again, best in person.';

  @override
  String checkedTitle(String name) {
    return 'It\'s really $name';
  }

  @override
  String get incomingFileUnreadable =>
      'Couldn\'t read that file. Open it again from where it is.';
}
