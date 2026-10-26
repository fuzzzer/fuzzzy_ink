import 'dart:async';

import 'package:fuzzzy_ink/src/src.dart';

/// "Lock from other apps": what another app's entry point (the Android
/// selection menu, the Mac Services menu and panel, the iPhone quick sheet)
/// may ask of the running app. The platform code calls it over
/// [FuzzAnywhereChannel]; the contract is `documents/fuzz_anywhere/
/// CHANNEL.md`.
///
/// It adds no cryptography and no second way to lock or open: unlocking is
/// the app's own ([FuzzyAuthStore], the same wrong-password count and
/// waits), locking is the Lock flow ([LockFlowCubit], which keeps the sent
/// message in the person's history) and opening is the Open flow
/// ([OpenFlowCubit], which keeps the opened message there).
///
/// Rules it keeps (THREAT_MODEL "Locking from other apps"):
/// - Nothing is opened unless [open] is called: the caller calls it only on
///   the person's own Open press, never on a selection, a paste or a
///   clipboard change.
/// - [lock] answers sealed output only. [open] never answers the opened
///   text: it answers a display id, and [show] puts the text on the app's
///   own private screen ([HistoryItemPage] in a [SensitiveScreen]).
/// - Every call is refused while Settings → Lock from other apps is off.
class FuzzAnywhereService {
  FuzzAnywhereService({
    required this.authStore,
    required this.settings,
    required this.settingsRepository,
    required this.biometricAuthRepository,
    required this.cryptoCoreService,
    required this.chatRepository,
    required this.lockFlow,
    required this.openFlow,
    required this.display,
    required this.handOff,
    Future<bool> Function(String text, CopyContent content)? copySealed,
    void Function()? keepSealedCopyAtLock,
    DateTime Function()? now,
  })  : _copySealed = copySealed ?? _copyThroughGuard,
        _keepSealedCopyAtLock =
            keepSealedCopyAtLock ?? CopyGuard.keepSealedCopyAtNextLock,
        _now = now ?? DateTime.now {
    _wasUnlocked = authStore.state.status.hasAccess;
    _lastSettings = settings.state;
    _authSubscription = authStore.stream.listen(_onAuthChanged);
    _settingsSubscription = settings.stream.listen(_onSettingsChanged);
    if (_wasUnlocked) unawaited(_loadSettings());
  }

  final FuzzyAuthStore authStore;
  final FuzzAnywhereSettingsCubit settings;
  final FuzzAnywhereSettingsRepository settingsRepository;
  final BiometricAuthRepository biometricAuthRepository;
  final CryptoCoreService cryptoCoreService;
  final ChatGeneralDataListRepository chatRepository;

  /// The Lock flow for one person (the app's own, with its file queue).
  final LockFlowCubit Function(ChatGeneralData chat) lockFlow;

  /// The Open flow (the app's own, with its file queue).
  final OpenFlowCubit Function() openFlow;

  /// Shows an opened message on the app's private history screen; done
  /// when the person closes it (or the app locks).
  final Future<void> Function(HistoryItemPagePayload payload) display;

  /// Brings up the app's Open screen with `request` (an invite, a reply or
  /// a password-locked text), where the person goes on as after Paste it.
  final void Function(OpenRequest request) handOff;

  final Future<bool> Function(String text, CopyContent content) _copySealed;
  final void Function() _keepSealedCopyAtLock;
  final DateTime Function() _now;

  final _events = StreamController<AnywhereEvent>.broadcast();
  late final StreamSubscription<FuzzyAuthState> _authSubscription;
  late final StreamSubscription<FuzzAnywhereSettingsState>
      _settingsSubscription;
  late bool _wasUnlocked;
  late FuzzAnywhereSettingsState _lastSettings;
  Future<void>? _settingsLoad;

  /// This entry point unlocked the app: "Lock again after each use" may
  /// lock it when the use is done.
  bool _unlockedHere = false;

  /// This use copied sealed output: the lock after it keeps that copy, so
  /// the person can still paste it.
  bool _copiedHere = false;

  /// The one opened message waiting for [show]. Dropped at a lock.
  _PendingDisplay? _pending;
  int _displayCount = 0;

  /// The display id on screen now, between [show] and its close.
  String? _shownId;

  /// Locked or unlocked, Settings changed, a shown message closed.
  Stream<AnywhereEvent> get events => _events.stream;

  static Future<bool> _copyThroughGuard(String text, CopyContent content) =>
      CopyGuard.copyQuietly(text: text, content: content);

  Future<AnywhereStatus> status() async {
    final auth = authStore.state;
    final canUseBiometrics = await biometricAuthRepository.canUseBiometrics();
    final known = settings.state;
    return AnywhereStatus(
      isSettingKnown: known.isLoaded,
      isOn: known.isOn,
      locksAgainAfterUse: known.settings.locksAgainAfterUse,
      isUnlocked: auth.status.hasAccess,
      isSetUp: !auth.status.isSetupRequired && !auth.status.isInitial,
      biometric: !canUseBiometrics
          ? AnywhereBiometric.none
          : auth.biometricEnabled
              ? AnywhereBiometric.on
              : AnywhereBiometric.off,
    );
  }

  /// The fingerprint or face prompt, as the lock screen's.
  Future<AnywhereResult<void>> unlockWithBiometrics() async {
    final refusal = _unlockRefusal();
    if (refusal != null) return refusal;
    if (authStore.state.status.hasAccess) return _alreadyUnlocked();
    if (!authStore.state.biometricEnabled) {
      return const AnywhereRefused(AnywhereFailure.biometricOff);
    }
    await authStore.unlockWithBiometrics();
    final after = authStore.state;
    if (after.status.hasAccess) return _unlockedNow();
    if (after.status.isStorageUnavailable) {
      return const AnywhereRefused(AnywhereFailure.notReady);
    }
    if (after.biometricInvalidated) {
      return const AnywhereRefused(AnywhereFailure.biometricGone);
    }
    return const AnywhereRefused(AnywhereFailure.notUnlocked);
  }

  /// The master password, sent once and never kept. A wrong one counts
  /// against the app's own limit; during a wait it is not even tried.
  Future<AnywhereResult<void>> unlockWithPassword(String password) async {
    final refusal = _unlockRefusal();
    if (refusal != null) return refusal;
    if (authStore.state.status.hasAccess) return _alreadyUnlocked();
    if (password.isEmpty) {
      return const AnywhereRefused(AnywhereFailure.badRequest);
    }
    await authStore.unlock(password);
    final after = authStore.state;
    if (after.status.hasAccess) return _unlockedNow();
    if (after.status.isStorageUnavailable) {
      return const AnywhereRefused(AnywhereFailure.notReady);
    }
    if (after.verificationFailed) {
      return AnywhereRefused(
        AnywhereFailure.wrongPassword,
        wait: after.lockoutRemaining,
      );
    }
    if (after.isLockedOut) {
      return AnywhereRefused(
        AnywhereFailure.lockedOut,
        wait: after.lockoutRemaining,
      );
    }
    return const AnywhereRefused(AnywhereFailure.notUnlocked);
  }

  /// The connected people, each with their checked mark, and the one last
  /// locked for from [sourceApp] marked.
  Future<AnywhereResult<List<AnywherePerson>>> people({
    String? sourceApp,
  }) async {
    final refusal = await _gate();
    if (refusal != null) return AnywhereRefused(refusal);
    final List<ChatGeneralData> chats;
    try {
      chats = await chatRepository.getAllChats();
    } catch (error) {
      logger.w('ANYWHERE: could not read the people: ${error.runtimeType}');
      return const AnywhereRefused(AnywhereFailure.failed);
    }
    final lastPerson = sourceApp == null
        ? null
        : await settingsRepository.lastPersonFor(sourceApp);
    final people = <AnywherePerson>[];
    for (final chat in chats) {
      if (chat.setupStatus != ChatSetupStatus.connected) continue;
      final verifiedRes = await cryptoCoreService.isVerified(chat.chatId);
      people.add(
        AnywherePerson(
          id: chat.chatId,
          name: chat.chatName,
          isVerified:
              verifiedRes is CryptoCoreSuccess<bool> && verifiedRes.data,
          isLastUsedHere: chat.chatId == lastPerson,
        ),
      );
    }
    return AnywhereDone(people);
  }

  /// Locks [text] for [personId] through the Lock flow, which keeps the
  /// sent message in their history. Answers the sealed output only: the
  /// message link when it fits one, else the `Fuzz/` text. With [copy], the
  /// app's copy guard copies it (sealed, cleared after 2 minutes).
  Future<AnywhereResult<AnywhereLockOutput>> lock({
    required String personId,
    required String text,
    String? sourceApp,
    bool copy = false,
  }) async {
    final refusal = await _gate();
    if (refusal != null) return AnywhereRefused(refusal);
    if (text.trim().isEmpty) {
      return const AnywhereRefused(AnywhereFailure.emptyText);
    }
    final chat = await _connectedChat(personId);
    if (chat == null) {
      return const AnywhereRefused(AnywhereFailure.unknownPerson);
    }

    final flow = lockFlow(chat);
    final String? lockedText;
    try {
      await flow.lock(text: text);
      lockedText = flow.state.phase == LockPhase.locked
          ? flow.state.item?.lockedText
          : null;
    } finally {
      await flow.close();
    }
    if (lockedText == null) {
      return const AnywhereRefused(AnywhereFailure.failed);
    }

    if (sourceApp != null &&
        FuzzAnywhereSettingsRepository.isAppId(sourceApp)) {
      final rememberRes = await settingsRepository.rememberPerson(
        appId: sourceApp,
        personId: personId,
      );
      if (rememberRes is CryptoCoreFailure<void>) {
        logger.w('ANYWHERE: last person not kept: ${rememberRes.type}');
      }
    }

    final link = FuzzyLinkGenerator.generateFuzzLink(lockedText);
    final output = link ?? lockedText;
    final isCopied = copy &&
        await _copySealed(
          output,
          link != null ? CopyContent.sealedLink : CopyContent.sealedMessage,
        );
    if (isCopied) _copiedHere = true;
    return AnywhereDone(
      AnywhereLockOutput(
        output: output,
        isLink: link != null,
        isCopied: isCopied,
      ),
    );
  }

  /// What [text] is and, for a message from one of the person's people,
  /// whose: the core's peek, which opens and spends nothing
  /// (`PROTOCOL.md` §7.4).
  Future<AnywhereResult<AnywherePeek>> peek(String text) async {
    final refusal = await _gate();
    if (refusal != null) return AnywhereRefused(refusal);
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const AnywhereRefused(AnywhereFailure.emptyText);
    }
    final res = await cryptoCoreService.peekPasted(
      text: _blobOf(trimmed),
      chatIds: await _connectedChatIds(),
    );
    if (res is CryptoCoreFailure<CryptoCorePeek>) {
      return const AnywhereRefused(AnywhereFailure.failed);
    }
    final peek = (res as CryptoCoreSuccess<CryptoCorePeek>).data;
    final kind = switch (peek.kind) {
      CryptoCorePeekKind.message => AnywhereKind.message,
      CryptoCorePeekKind.invitation => AnywhereKind.invite,
      CryptoCorePeekKind.acceptance => AnywhereKind.reply,
      CryptoCorePeekKind.passwordText => AnywhereKind.passwordText,
      CryptoCorePeekKind.newerVersion => AnywhereKind.newerApp,
      CryptoCorePeekKind.notFuzzzy => AnywhereKind.notFuzzzy,
      CryptoCorePeekKind.chatFile ||
      CryptoCorePeekKind.passwordFile ||
      CryptoCorePeekKind.damaged =>
        AnywhereKind.damaged,
    };
    final chatId = peek.chatId;
    final chat = kind == AnywhereKind.message && chatId != null
        ? await _connectedChat(chatId)
        : null;
    return AnywhereDone(
      AnywherePeek(
        kind: kind,
        personId: chat?.chatId,
        personName: chat?.chatName,
      ),
    );
  }

  /// Opens a message from one of the person's people through the Open flow
  /// (its key is spent and the text kept in their history), on the person's
  /// own Open press. The text is not answered: [show] puts it on the app's
  /// private screen.
  Future<AnywhereResult<AnywhereOpened>> open(String text) async {
    final refusal = await _gate();
    if (refusal != null) return AnywhereRefused(refusal);
    if (text.trim().isEmpty) {
      return const AnywhereRefused(AnywhereFailure.emptyText);
    }

    final flow = openFlow();
    final OpenFlowState opened;
    try {
      await flow.open(OpenPastedText(text));
      opened = flow.state;
    } finally {
      await flow.close();
    }

    final chat = opened.chat;
    final rowId = opened.historyRowId;
    final openedText = opened.openedText;
    if (opened.phase == OpenPhase.openedText &&
        chat != null &&
        rowId != null &&
        openedText != null) {
      final displayId = '${++_displayCount}';
      _pending = _PendingDisplay(
        id: displayId,
        payload: HistoryItemPagePayload(
          chat: chat,
          message: MessageData(
            id: rowId,
            chatId: chat.chatId,
            type: MessageType.text,
            encryptedMessage: '',
            decryptedMessage: openedText,
            sentAt: _now(),
            isSent: false,
          ),
        ),
      );
      return AnywhereDone(
        AnywhereOpened(
          displayId: displayId,
          personId: chat.chatId,
          personName: chat.chatName,
        ),
      );
    }
    if (opened.route != null || opened.phase == OpenPhase.password) {
      return const AnywhereRefused(AnywhereFailure.notForAPerson);
    }
    return AnywhereRefused(_failureOf(opened.problem));
  }

  /// The person pressed "Open in Fuzzzy Ink" on something [open] answered
  /// [AnywhereFailure.notForAPerson] for: an invite, a reply or a
  /// password-locked text. The app's Open screen takes it as if it had been
  /// pasted there, and every next step (Connect, the password) is the
  /// person's own press in the app. Anything else is refused: a message
  /// opens only through [open].
  ///
  /// The use goes on inside the app, so "Lock again after each use" no
  /// longer applies to it: the app's own auto-lock does.
  Future<AnywhereResult<void>> openInApp(String text) async {
    final refusal = await _gate();
    if (refusal != null) return AnywhereRefused(refusal);
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const AnywhereRefused(AnywhereFailure.emptyText);
    }
    final AnywhereKind kind;
    switch (await peek(trimmed)) {
      case AnywhereRefused(:final failure):
        return AnywhereRefused(failure);
      case AnywhereDone(:final value):
        kind = value.kind;
    }
    const handedOver = {
      AnywhereKind.invite,
      AnywhereKind.reply,
      AnywhereKind.passwordText,
    };
    if (!handedOver.contains(kind)) {
      return const AnywhereRefused(AnywhereFailure.badRequest);
    }
    _unlockedHere = false;
    handOff(OpenPastedText(trimmed));
    return const AnywhereDone(null);
  }

  /// Shows the message [open] just opened on the app's private screen,
  /// once. "Lock again after each use" runs when that screen closes.
  Future<AnywhereResult<void>> show(String displayId) async {
    final pending = _pending;
    if (pending == null || pending.id != displayId) {
      return const AnywhereRefused(AnywhereFailure.unknownDisplay);
    }
    final refusal = await _gate();
    if (refusal != null) return AnywhereRefused(refusal);
    _pending = null;
    _shownId = displayId;
    unawaited(_showUntilClosed(pending));
    return const AnywhereDone(null);
  }

  /// The caller's use is done (its sheet or panel closed, whatever the
  /// outcome). Locks the app again when this entry point unlocked it and
  /// "Lock again after each use" is on; answers whether it locked. While a
  /// message [show] opened is on screen, that screen's close does it.
  Future<bool> relock() async {
    if (_shownId != null) return false;
    return _relockAfterUse();
  }

  Future<void> dispose() async {
    await _authSubscription.cancel();
    await _settingsSubscription.cancel();
    await _events.close();
  }

  Future<void> _showUntilClosed(_PendingDisplay pending) async {
    try {
      await display(pending.payload);
    } catch (error) {
      logger.w('ANYWHERE: could not show: ${error.runtimeType}');
    }
    // A lock already took the screen away (its route is replaced, not
    // popped, so the display may never finish): nothing more to do.
    if (_shownId != pending.id) return;
    _shownId = null;
    _send(AnywhereShownClosed(pending.id));
    await _relockAfterUse();
  }

  Future<bool> _relockAfterUse() async {
    final copied = _copiedHere;
    _copiedHere = false;
    if (!_unlockedHere) return false;
    _unlockedHere = false;
    if (!settings.state.settings.locksAgainAfterUse) return false;
    if (!authStore.state.status.hasAccess) return false;
    if (copied) _keepSealedCopyAtLock();
    await authStore.lock();
    return true;
  }

  /// Every call but [status] and the unlocks: the switch on, the app open.
  Future<AnywhereFailure?> _gate() async {
    if (settings.state.isLoaded && !settings.state.settings.isOn) {
      return AnywhereFailure.disabled;
    }
    final access = _accessFailure();
    if (access != null) return access;
    if (!settings.state.isLoaded) await _loadSettings();
    return settings.state.isOn ? null : AnywhereFailure.disabled;
  }

  /// Unlocking is allowed while the switch is on or not known yet (it is
  /// sealed: the first unlock of a run reads it).
  AnywhereRefused<void>? _unlockRefusal() {
    if (settings.state.isLoaded && !settings.state.settings.isOn) {
      return const AnywhereRefused(AnywhereFailure.disabled);
    }
    final status = authStore.state.status;
    if (status.isSetupRequired) {
      return const AnywhereRefused(AnywhereFailure.notSetUp);
    }
    if (status.isInitial || status.isStorageUnavailable) {
      return const AnywhereRefused(AnywhereFailure.notReady);
    }
    return null;
  }

  AnywhereFailure? _accessFailure() => switch (authStore.state.status) {
        AuthStateStatus.authenticated => null,
        AuthStateStatus.setupRequired => AnywhereFailure.notSetUp,
        AuthStateStatus.initial ||
        AuthStateStatus.storageUnavailable =>
          AnywhereFailure.notReady,
        AuthStateStatus.locked ||
        AuthStateStatus.unlocking =>
          AnywhereFailure.locked,
      };

  Future<AnywhereResult<void>> _alreadyUnlocked() async {
    final refusal = await _gate();
    return refusal == null
        ? const AnywhereDone(null)
        : AnywhereRefused(refusal);
  }

  /// This entry point just unlocked the app. If the sealed switch turns out
  /// to be off, the app locks again at once: nothing stays open for an entry
  /// point that should not be there.
  Future<AnywhereResult<void>> _unlockedNow() async {
    _unlockedHere = true;
    await _loadSettings();
    if (settings.state.isOn) return const AnywhereDone(null);
    _unlockedHere = false;
    await authStore.lock();
    return const AnywhereRefused(AnywhereFailure.disabled);
  }

  Future<void> _loadSettings() {
    return _settingsLoad ??= settings.load().whenComplete(
          () => _settingsLoad = null,
        );
  }

  void _onAuthChanged(FuzzyAuthState state) {
    final isUnlocked = state.status.hasAccess;
    if (isUnlocked == _wasUnlocked) return;
    _wasUnlocked = isUnlocked;
    if (isUnlocked) {
      unawaited(_loadSettings());
    } else {
      // Whatever locked the app, nothing this entry point opened is kept,
      // and a message on screen is gone with the private screens.
      _unlockedHere = false;
      _pending = null;
    }
    _send(AnywhereLockChanged(isUnlocked: isUnlocked));
    final shownId = _shownId;
    if (!isUnlocked && shownId != null) {
      _shownId = null;
      _send(AnywhereShownClosed(shownId));
    }
  }

  void _onSettingsChanged(FuzzAnywhereSettingsState state) {
    final before = _lastSettings;
    _lastSettings = state;
    if (before.isOn == state.isOn &&
        before.settings.locksAgainAfterUse ==
            state.settings.locksAgainAfterUse) {
      return;
    }
    _send(
      AnywhereSettingsChanged(
        isOn: state.isOn,
        locksAgainAfterUse: state.settings.locksAgainAfterUse,
      ),
    );
  }

  void _send(AnywhereEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  Future<ChatGeneralData?> _connectedChat(String chatId) async {
    try {
      final chat = await chatRepository.getChatById(chatId);
      return chat?.setupStatus == ChatSetupStatus.connected ? chat : null;
    } catch (error) {
      logger.w('ANYWHERE: could not read a person: ${error.runtimeType}');
      return null;
    }
  }

  Future<List<String>> _connectedChatIds() async {
    try {
      return [
        for (final chat in await chatRepository.getAllChats())
          if (chat.setupStatus == ChatSetupStatus.connected) chat.chatId,
      ];
    } catch (error) {
      logger.w('ANYWHERE: could not read the people: ${error.runtimeType}');
      return const [];
    }
  }

  /// A pasted link's blob is what the peek reads, as on Open.
  static String _blobOf(String text) =>
      switch (FuzzyLinkParser.parseText(text)) {
        FuzzMessageLinkPayload(:final encryptedMessage) =>
          '$fuzzIdentificator$encryptedMessage',
        InvitationLinkPayload(:final rawInvitationContent) =>
          rawInvitationContent,
        AcceptanceLinkPayload(:final rawAcceptanceContent) =>
          rawAcceptanceContent,
        null => text,
      };

  static AnywhereFailure _failureOf(OpenProblem? problem) => switch (problem) {
        OpenProblem.alreadyOpened => AnywhereFailure.alreadyOpened,
        OpenProblem.notFromYourPeople => AnywhereFailure.notFromYourPeople,
        OpenProblem.damaged => AnywhereFailure.damaged,
        OpenProblem.tooOld => AnywhereFailure.tooOld,
        OpenProblem.newerApp => AnywhereFailure.newerApp,
        OpenProblem.notFuzzzy => AnywhereFailure.notFuzzzy,
        OpenProblem.ownInvite ||
        OpenProblem.alreadyConnected =>
          AnywhereFailure.notForAPerson,
        OpenProblem.stillArriving ||
        OpenProblem.askResend ||
        OpenProblem.failed ||
        null =>
          AnywhereFailure.failed,
      };
}

class _PendingDisplay {
  const _PendingDisplay({required this.id, required this.payload});

  final String id;
  final HistoryItemPagePayload payload;
}
