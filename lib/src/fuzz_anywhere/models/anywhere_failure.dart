/// Why a call from another app's entry point was refused. [code] is the
/// channel's error code (`documents/fuzz_anywhere/CHANNEL.md`); it never
/// carries text, a name or a password.
enum AnywhereFailure {
  /// The build has the feature, but Settings → Lock from other apps is off.
  disabled('disabled'),

  /// The app is locked: unlock first.
  locked('locked'),

  /// No master password yet: the person sets one up in the app first.
  notSetUp('notSetUp'),

  /// The app is still starting, or its secure storage cannot be read.
  notReady('notReady'),

  /// A missing or wrongly typed argument.
  badRequest('badRequest'),

  /// The caller speaks a newer contract than this app.
  unsupportedVersion('unsupportedVersion'),

  /// No connected person with that id.
  unknownPerson('unknownPerson'),

  /// Nothing to lock or open.
  emptyText('emptyText'),

  /// The master password was wrong; it counts like a wrong try in the app.
  wrongPassword('wrongPassword'),

  /// Too many wrong passwords: wait (`waitSeconds`), as in the app.
  lockedOut('lockedOut'),

  /// Fingerprint or face is not turned on in Fuzzzy Ink.
  biometricOff('biometricOff'),

  /// The phone's fingerprints or face changed: the master password again.
  biometricGone('biometricGone'),

  /// The prompt was cancelled or another unlock was already running.
  notUnlocked('notUnlocked'),

  /// An invite, a reply or a password-locked text: open it in Fuzzzy Ink.
  notForAPerson('notForAPerson'),

  /// Already opened (it opens once); it is in that person's history.
  alreadyOpened('alreadyOpened'),
  tooOld('tooOld'),
  newerApp('newerApp'),
  damaged('damaged'),
  notFuzzzy('notFuzzzy'),

  /// Locked for someone, but not from one of the person's people.
  notFromYourPeople('notFromYourPeople'),

  /// `show` with an id `open` did not just give, or already shown.
  unknownDisplay('unknownDisplay'),

  /// `copy` with no Lock in this use to copy (or the app locked since).
  nothingToCopy('nothingToCopy'),
  failed('failed');

  const AnywhereFailure(this.code);

  final String code;
}
