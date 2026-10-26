import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/lib.dart';

/// Opens what arrives from outside the app: Fuzzzy Ink links, and `.fuzz`
/// files other apps opened in this one ([IncomingFiles], straight to Open).
/// While the app is locked, the one that came last waits for the unlock.
class FuzzyLinkHandler {
  FuzzyLinkHandler({
    required FuzzyLinkService linkService,
    required ChatGeneralDataListRepository chatRepository,
    required FuzzyAuthStore authStore,
    required CryptoCoreService cryptoCoreService,
    IncomingFiles? incomingFiles,
    void Function(String path, Object? extra)? navigate,
  })  : _linkService = linkService,
        _chatRepository = chatRepository,
        _authStore = authStore,
        _cryptoCoreService = cryptoCoreService,
        _incomingFiles = incomingFiles,
        _navigate = navigate;

  final FuzzyLinkService _linkService;
  final ChatGeneralDataListRepository _chatRepository;
  final FuzzyAuthStore _authStore;
  final CryptoCoreService _cryptoCoreService;
  final IncomingFiles? _incomingFiles;

  /// Tests watch where things go; the app goes Home, then pushes `path`.
  final void Function(String path, Object? extra)? _navigate;

  StreamSubscription<Uri>? _subscription;
  StreamSubscription<Uri>? _fileSubscription;
  FuzzyLinkPayload? _pendingPayload;

  /// A `.fuzz` file's hand-off copy waiting for the unlock.
  String? _pendingFilePath;
  bool _isInitialized = false;

  bool get hasPendingPayload =>
      _pendingPayload != null || _pendingFilePath != null;

  /// Whether a link waits for the unlock: the lock screen says so ("A link
  /// is waiting. Unlock to open it.").
  ValueListenable<bool> get pendingLink => _pendingLink;
  final _pendingLink = ValueNotifier<bool>(false);

  FuzzzyInkLocalizations get _l10n =>
      FuzzzyInkLocalizations.of(navigatorKey.currentContext!)!;

  /// Feedback from outside the widget tree goes through the app's
  /// `ScaffoldMessenger`, as `GlobalBlocListeners` does: `FuzzzyToast.show`
  /// needs a context *inside* the navigator's `Overlay`, which no global key
  /// provides (`navigatorKey.currentContext` is the navigator itself — T-0328).
  void _showMessage(String message) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    final initialUri = await _linkService.getInitialLink();
    if (initialUri != null) {
      _handleUri(initialUri);
    }

    _subscription = _linkService.onLinkReceived.listen(_handleUri);

    final incomingFiles = _incomingFiles;
    if (incomingFiles != null) {
      _fileSubscription = incomingFiles.opened.listen(_handleUri);
      await incomingFiles.start();
    }
  }

  void processPendingPayload() {
    final payload = _pendingPayload;
    final filePath = _pendingFilePath;
    _pendingPayload = null;
    _pendingFilePath = null;
    _pendingLink.value = false;
    if (payload != null) _processPayload(payload);
    if (filePath != null) _openFile(filePath);
  }

  void _handleUri(Uri uri) {
    if (IncomingFiles.isFileUri(uri)) {
      unawaited(_handleIncomingFile(uri));
      return;
    }
    final payload = FuzzyLinkParser.parse(uri);
    if (payload == null) {
      if (navigatorKey.currentContext == null) return;
      _showMessage(_l10n.invalidLink);
      return;
    }

    _routePayload(payload);
  }

  Future<void> _routePayload(FuzzyLinkPayload payload) async {
    if (await _isAppLocked()) {
      _pendingPayload = payload;
      _pendingFilePath = null;
      _pendingLink.value = true;
      return;
    }

    _processPayload(payload);
  }

  /// A `.fuzz` file from another app: read once into the hand-off folder,
  /// then Open (after the unlock when the app is locked).
  Future<void> _handleIncomingFile(Uri uri) async {
    final incomingFiles = _incomingFiles;
    if (incomingFiles == null) return;
    final filePath = await incomingFiles.take(uri);
    if (filePath == null) {
      if (navigatorKey.currentContext != null) {
        _showMessage(_l10n.incomingFileUnreadable);
      }
      return;
    }
    if (await _isAppLocked()) {
      _pendingFilePath = filePath;
      _pendingPayload = null;
      _pendingLink.value = true;
      return;
    }
    _openFile(filePath);
  }

  void _openFile(String filePath) {
    _navigateCleanly(
      AppRouter.open,
      extra: OpenPagePayload(request: OpenChosenFile(filePath)),
    );
  }

  void _processPayload(FuzzyLinkPayload payload) {
    switch (payload) {
      case InvitationLinkPayload():
        _handleInvitation(payload);
      case AcceptanceLinkPayload():
        _handleAcceptance(payload);
      case FuzzMessageLinkPayload():
        _handleFuzzMessage(payload);
    }
  }

  Future<void> _handleInvitation(InvitationLinkPayload payload) async {
    try {
      final chatIdRes =
          _cryptoCoreService.peekChatId(payload.rawInvitationContent);
      if (chatIdRes is CryptoCoreSuccess<String>) {
        final existingChat = await _chatRepository.getChatById(chatIdRes.data);

        if (existingChat != null) {
          _showMessage(_l10n.cantAcceptOwnInvitation);
          return;
        }
      }
    } catch (_) {
      // Let the acceptance page handle parsing errors downstream.
    }

    _navigateCleanly(
      AppRouter.chatAccept,
      extra: payload.rawInvitationContent,
    );
  }

  Future<void> _handleAcceptance(AcceptanceLinkPayload payload) async {
    try {
      final chatIdRes =
          _cryptoCoreService.peekChatId(payload.rawAcceptanceContent);
      if (chatIdRes is CryptoCoreFailure) {
        _showMessage(_l10n.failedToProcessAcceptance);
        return;
      }
      final chatId = (chatIdRes as CryptoCoreSuccess<String>).data;
      final chat = await _chatRepository.getChatById(chatId);

      if (chat == null) {
        _showMessage(_l10n.chatNotFoundForAcceptance);
        return;
      }

      if (chat.setupStatus == ChatSetupStatus.connected) {
        // The same acceptance again is harmless. A different one means a
        // second person accepted this invitation: say so, never "connected".
        final isSameAcceptance = await _chatRepository.isPairedAcceptance(
          chatId,
          payload.rawAcceptanceContent,
        );
        if (isSameAcceptance) {
          _showMessage(_l10n.alreadyConnected);
        } else {
          _showPairingWarning(chat);
        }
        return;
      }

      _navigateCleanly(
        AppRouter.chatInvitation,
        extra: ChatInvitationPagePayload(
          chatName: chat.chatName,
          chatId: chat.chatId,
          prefillAcceptanceContent: payload.rawAcceptanceContent,
        ),
      );
    } catch (_) {
      _showMessage(_l10n.failedToProcessAcceptance);
    }
  }

  /// A message link opens in Open, which checks the person and opens it
  /// once (a person not on this phone is "Not from your people").
  void _handleFuzzMessage(FuzzMessageLinkPayload payload) {
    _navigateCleanly(
      AppRouter.open,
      extra: OpenPagePayload(
        request: OpenMessageLink(
          chatId: payload.chatId,
          encryptedMessage: payload.encryptedMessage,
        ),
      ),
    );
  }

  /// "Someone else may have answered": its own screen, with Check numbers
  /// and Remove (DESIGN.md section 4.3).
  void _showPairingWarning(ChatGeneralData chat) {
    _navigateCleanly(AppRouter.personAnsweredTwice, extra: chat);
  }

  void _navigateCleanly(String path, {Object? extra}) {
    final navigate = _navigate;
    if (navigate != null) return navigate(path, extra);
    final router = AppRouter.routerInstance;
    if (router == null) return;
    router.go(AppRouter.home);
    router.push(path, extra: extra);
  }

  Future<bool> _isAppLocked() async {
    final status = _authStore.state.status;
    return !status.hasAccess;
  }

  void dispose() {
    _subscription?.cancel();
    _fileSubscription?.cancel();
  }
}
