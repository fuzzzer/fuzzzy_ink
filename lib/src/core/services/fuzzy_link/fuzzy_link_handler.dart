import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/lib.dart';

class FuzzyLinkHandler {
  FuzzyLinkHandler({
    required FuzzyLinkService linkService,
    required ChatGeneralDataListRepository chatRepository,
    required FuzzyAuthStore authStore,
    required CryptoCoreService cryptoCoreService,
  })  : _linkService = linkService,
        _chatRepository = chatRepository,
        _authStore = authStore,
        _cryptoCoreService = cryptoCoreService;

  final FuzzyLinkService _linkService;
  final ChatGeneralDataListRepository _chatRepository;
  final FuzzyAuthStore _authStore;
  final CryptoCoreService _cryptoCoreService;

  StreamSubscription<Uri>? _subscription;
  FuzzyLinkPayload? _pendingPayload;
  bool _isInitialized = false;

  bool get hasPendingPayload => _pendingPayload != null;

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
  }

  void processPendingPayload() {
    if (_pendingPayload != null) {
      _processPayload(_pendingPayload!);
      _pendingPayload = null;
    }
  }

  /// Home's Open → "Paste it": when [text] is a whole Fuzzzy Ink link it
  /// takes the same way as a tapped link (same checks, waits while locked)
  /// and this answers true; anything else answers false and does nothing.
  bool openPastedText(String text) {
    final payload = FuzzyLinkParser.parseText(text);
    if (payload == null) return false;
    _routePayload(payload);
    return true;
  }

  void _handleUri(Uri uri) {
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
      return;
    }

    _processPayload(payload);
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

  Future<void> _handleFuzzMessage(FuzzMessageLinkPayload payload) async {
    try {
      final chat = await _chatRepository.getChatById(payload.chatId);

      if (chat == null) {
        _showMessage(_l10n.chatNotFoundForMessage);
        return;
      }

      _navigateCleanly(
        AppRouter.chatConnected,
        extra: ConnectedChatPagePayload(
          chatGeneralData: chat,
          prefillEncryptedMessage: payload.encryptedMessage,
        ),
      );
    } catch (_) {
      _showMessage(_l10n.failedToProcessMessage);
    }
  }

  /// "Someone else may have answered": its own screen, with Check numbers
  /// and Remove (DESIGN.md section 4.3).
  void _showPairingWarning(ChatGeneralData chat) {
    _navigateCleanly(AppRouter.personAnsweredTwice, extra: chat);
  }

  void _navigateCleanly(String path, {Object? extra}) {
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
  }
}
