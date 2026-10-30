/// One connected person, as another app's entry point lists them.
class AnywherePerson {
  const AnywherePerson({
    required this.id,
    required this.name,
    required this.isVerified,
    required this.isLastUsedHere,
  });

  /// The chat id.
  final String id;
  final String name;

  /// The safety numbers were checked; otherwise the sheet shows "Not
  /// verified" before Lock.
  final bool isVerified;

  /// The person last locked for from the calling app (a hint only).
  final bool isLastUsedHere;
}

/// What locking gave: the message link when it fits one (at most
/// `FuzzyLinkParser.maxPayloadLength` characters), else the `Fuzz/` text.
/// Sealed output only.
class AnywhereLockOutput {
  const AnywhereLockOutput({
    required this.output,
    required this.isLink,
    required this.isCopied,
  });

  final String output;
  final bool isLink;

  /// Copied through the app's copy guard (sealed, cleared after 2 minutes).
  final bool isCopied;
}

/// What a pasted or selected text is, without opening it.
enum AnywhereKind {
  message('message'),
  invite('invite'),
  reply('reply'),
  passwordText('passwordText'),
  newerApp('newerApp'),
  damaged('damaged'),
  notFuzzzy('notFuzzzy');

  const AnywhereKind(this.code);

  final String code;
}

/// [AnywhereKind], and for a message from one of the person's people,
/// whose it is.
class AnywherePeek {
  const AnywherePeek({required this.kind, this.personId, this.personName});

  final AnywhereKind kind;
  final String? personId;
  final String? personName;
}

/// A message opened from outside: it is in [personName]'s history now. The
/// text itself stays in the app; [displayId] lets the caller ask the app to
/// show it once, on its own private screen.
class AnywhereOpened {
  const AnywhereOpened({
    required this.displayId,
    required this.personId,
    required this.personName,
  });

  final String displayId;
  final String personId;
  final String personName;
}

/// Where the app stands, for another app's entry point.
class AnywhereStatus {
  const AnywhereStatus({
    required this.isSettingKnown,
    required this.isOn,
    required this.locksAgainAfterUse,
    required this.isUnlocked,
    required this.isSetUp,
    required this.biometric,
  });

  /// The setting is sealed: until the first unlock of this run it is not
  /// known, and [isOn] is false.
  final bool isSettingKnown;
  final bool isOn;
  final bool locksAgainAfterUse;
  final bool isUnlocked;

  /// A master password exists.
  final bool isSetUp;
  final AnywhereBiometric biometric;
}

/// Whether fingerprint or face can unlock. Which one the device has is the
/// platform's to say.
enum AnywhereBiometric {
  /// Turned on in Fuzzzy Ink.
  on('on'),

  /// The device can, but it is off in Fuzzzy Ink.
  off('off'),

  /// Not on this device.
  none('none');

  const AnywhereBiometric(this.code);

  final String code;
}

/// What the app tells the caller without being asked.
sealed class AnywhereEvent {
  const AnywhereEvent();
}

/// The app locked or unlocked (any way: Lock now, auto-lock, an unlock).
final class AnywhereLockChanged extends AnywhereEvent {
  const AnywhereLockChanged({required this.isUnlocked});

  final bool isUnlocked;
}

/// Settings → Other apps changed (or were read after an unlock).
final class AnywhereSettingsChanged extends AnywhereEvent {
  const AnywhereSettingsChanged({
    required this.isOn,
    required this.locksAgainAfterUse,
  });

  final bool isOn;
  final bool locksAgainAfterUse;
}

/// No master password (a new install, "Erase everything"): the sheet
/// forgets the flags it keeps ("Copy automatically next time", the draft
/// note seen), as the erase promises for every setting.
final class AnywhereSheetForget extends AnywhereEvent {
  const AnywhereSheetForget();
}

/// The private screen `show` opened was closed.
final class AnywhereShownClosed extends AnywhereEvent {
  const AnywhereShownClosed(this.displayId);

  final String displayId;
}
