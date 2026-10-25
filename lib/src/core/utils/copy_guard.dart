import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// The copy policy, in one place (owner, 2026-10-26: "not possible to copy
/// anything sensitive from app. unless its a raw message they send").
///
/// Only sealed output the user sends leaves the app through the clipboard.
/// Decrypted messages, decrypted Basics results, vault notes, file paths and
/// any other plaintext are never copied, and the widgets that show them are
/// not selectable. Everything that is copied clears itself after a short time,
/// but only while the clipboard still holds what this app put there.
///
/// Every copy in `lib/` goes through [CopyGuard.copy]; nothing else calls
/// `Clipboard.setData`.

/// The native side of the copy guard and the screen guard: `Guard.kt`
/// (Android), `AppDelegate.swift` (iOS), `MainFlutterWindow.swift` (macOS),
/// `flutter_window.cpp` (Windows, screen only). Linux has none.
const guardChannel = MethodChannel('com.fuzzzycore.ink/guard');

/// Owner question open since 2026-10-26: whether vault passwords keep their
/// copy button. On keeps the existing vault feature: the copy is marked
/// sensitive (kept out of clipboard previews and clipboard history where the
/// system allows it) and clears after [CopyPolicy.vaultPasswordClearAfter].
/// Off removes every vault password copy button.
const bool allowVaultPasswordCopy = true;

/// What a piece of text is. The policy decides on this, never on the text.
enum CopyContent {
  /// A sealed chat message the user sends (`fuzzIdentificator` + blob).
  sealedMessage,

  /// A sealed invitation the user sends.
  sealedInvitation,

  /// A sealed acceptance the user sends back.
  sealedAcceptance,

  /// A link that carries sealed output (message, invitation, acceptance).
  sealedLink,

  /// A sealed Basics text (password-sealed blob).
  sealedText,

  /// A vault password, only while [allowVaultPasswordCopy] is on.
  vaultPassword,

  /// The development-flavor file benchmark numbers: no user data.
  benchmarkReport,

  /// Anything in the clear: a decrypted message or Basics result, a vault
  /// note, a file path. Always refused.
  plaintext,
}

/// The rules: what may be copied, whether it is sensitive, when it clears.
@immutable
class CopyPolicy {
  const CopyPolicy({
    this.allowsVaultPasswordCopy = allowVaultPasswordCopy,
  });

  final bool allowsVaultPasswordCopy;

  static const vaultPasswordClearAfter = Duration(seconds: 30);
  static const sealedClearAfter = Duration(minutes: 2);

  bool allows(CopyContent content) => switch (content) {
        CopyContent.sealedMessage ||
        CopyContent.sealedInvitation ||
        CopyContent.sealedAcceptance ||
        CopyContent.sealedLink ||
        CopyContent.sealedText ||
        CopyContent.benchmarkReport =>
          true,
        CopyContent.vaultPassword => allowsVaultPasswordCopy,
        CopyContent.plaintext => false,
      };

  /// Sensitive copies are kept out of clipboard previews, clipboard history
  /// and other devices where the system allows it.
  bool isSensitive(CopyContent content) => content == CopyContent.vaultPassword;

  Duration clearAfter(CopyContent content) =>
      content == CopyContent.vaultPassword
          ? vaultPasswordClearAfter
          : sealedClearAfter;
}

/// What the clipboard answered when asked to clear the app's own copy.
enum ClipboardClearResult {
  /// The clipboard held the app's copy and is now empty.
  cleared,

  /// The clipboard holds something else (or nothing): left alone.
  notOurs,

  /// The system does not let the app look right now (Android in the
  /// background); asked again when the app comes back.
  unavailable,
}

/// Writes to the system clipboard through the guard channel, which marks a
/// sensitive copy and can tell whether the clipboard still holds the app's
/// copy without reading anyone else's text. Where the platform has no native
/// side (Linux, Windows clipboard) it falls back to Flutter's [Clipboard] and
/// compares the text itself.
class SecureClipboard {
  SecureClipboard({MethodChannel channel = guardChannel}) : _channel = channel;

  final MethodChannel _channel;
  String? _lastWritten;

  Future<void> write(
    String text, {
    required bool sensitive,
    required Duration clearAfter,
  }) async {
    _lastWritten = text;
    try {
      final isWritten = await _channel.invokeMethod<bool>('copy', {
        'text': text,
        'sensitive': sensitive,
        'expiresInMs': clearAfter.inMilliseconds,
      });
      if (isWritten ?? false) return;
    } on MissingPluginException {
      // No native side on this platform: the Flutter clipboard below.
    } on PlatformException catch (exception) {
      logger.w('COPY GUARD: native copy failed: ${exception.code}');
    }
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<ClipboardClearResult> clearIfStillOurs() async {
    final text = _lastWritten;
    if (text == null) return ClipboardClearResult.notOurs;
    try {
      final answer = await _channel.invokeMethod<String>('clearIfOurs');
      final result = ClipboardClearResult.values.asNameMap()[answer];
      if (result != null) {
        if (result != ClipboardClearResult.unavailable) _lastWritten = null;
        return result;
      }
    } on MissingPluginException {
      // No native side on this platform: compare the text below.
    } on PlatformException catch (exception) {
      logger.w('COPY GUARD: native clear failed: ${exception.code}');
    }
    _lastWritten = null;
    final current = await Clipboard.getData(Clipboard.kTextPlain);
    if (current?.text != text) return ClipboardClearResult.notOurs;
    await Clipboard.setData(const ClipboardData(text: ''));
    return ClipboardClearResult.cleared;
  }
}

/// A copy the guard made has really left the clipboard: its clear ran, and
/// the clipboard either held it and is now empty or already held something
/// else. A copy replaced by a newer copy of the app gets no event of its own;
/// compare [copyId] with [ClipboardGuard.lastCopyId].
@immutable
class ClipboardCopyCleared {
  const ClipboardCopyCleared({required this.copyId, required this.content});

  final int copyId;
  final CopyContent content;
}

/// Applies [CopyPolicy] to every copy and runs the auto-clear timer. Holds no
/// UI: [CopyGuard] is the widget-facing side.
class ClipboardGuard {
  ClipboardGuard({
    SecureClipboard? clipboard,
    this.policy = const CopyPolicy(),
  }) : _clipboard = clipboard ?? SecureClipboard();

  final SecureClipboard _clipboard;
  final CopyPolicy policy;

  Timer? _clearTimer;
  bool _isClearPending = false;
  AppLifecycleListener? _lifecycleListener;
  final _cleared = StreamController<ClipboardCopyCleared>.broadcast();
  int _lastCopyId = 0;
  ({int id, CopyContent content})? _pendingCopy;

  /// Counts the copies made; the id of the latest one.
  int get lastCopyId => _lastCopyId;

  /// One event when a copy has really been cleared ("Cleared." on screen).
  Stream<ClipboardCopyCleared> get cleared => _cleared.stream;

  /// Copies [text] when the policy allows [content]; answers whether it did.
  Future<bool> copy(String text, CopyContent content) async {
    if (!policy.allows(content)) return false;

    final clearAfter = policy.clearAfter(content);
    _clearTimer?.cancel();
    await _clipboard.write(
      text,
      sensitive: policy.isSensitive(content),
      clearAfter: clearAfter,
    );
    _isClearPending = true;
    _lastCopyId++;
    _pendingCopy = (id: _lastCopyId, content: content);
    _clearTimer = Timer(clearAfter, () => unawaited(clearNow()));
    _lifecycleListener ??= AppLifecycleListener(onResume: _retryPendingClear);
    return true;
  }

  /// Clears the clipboard now if it still holds the app's last copy.
  Future<void> clearNow() async {
    _clearTimer?.cancel();
    _clearTimer = null;
    final result = await _clipboard.clearIfStillOurs();
    _isClearPending = result == ClipboardClearResult.unavailable;
    final pending = _pendingCopy;
    if (_isClearPending || pending == null) return;
    _pendingCopy = null;
    if (!_cleared.isClosed) {
      _cleared.add(
        ClipboardCopyCleared(copyId: pending.id, content: pending.content),
      );
    }
  }

  /// A clear the system refused while the app was in the background runs
  /// as soon as the app is back.
  void _retryPendingClear() {
    if (_isClearPending && _clearTimer == null) unawaited(clearNow());
  }

  @visibleForTesting
  bool get isClearPending => _isClearPending;

  void dispose() {
    _clearTimer?.cancel();
    _lifecycleListener?.dispose();
    unawaited(_cleared.close());
  }
}

/// The widget-facing copy guard: every copy in the app, and the context menu
/// and shortcut rules for fields that hold plaintext.
abstract final class CopyGuard {
  static ClipboardGuard _clipboardGuard = ClipboardGuard();

  @visibleForTesting
  static ClipboardGuard get clipboardGuard => _clipboardGuard;

  @visibleForTesting
  static set clipboardGuard(ClipboardGuard guard) => _clipboardGuard = guard;

  /// Copies [text] if [content] may leave the app, then toasts
  /// [copiedMessage] (or the generic "copied"). A refused copy toasts why.
  static Future<bool> copy(
    BuildContext context, {
    required String text,
    required CopyContent content,
    String? copiedMessage,
  }) async {
    final localizations = context.fuzzzyInkLocalizations;
    final isCopied = await _clipboardGuard.copy(text, content);
    if (!context.mounted) return isCopied;
    FuzzzyToast.show(
      context,
      message: isCopied
          ? copiedMessage ?? localizations.copiedToTheClipboard
          : localizations.copyRefused,
    );
    return isCopied;
  }

  /// Copies [text] if [content] may leave the app, with no toast: for a
  /// control that confirms in place ("Copied" on the button or row itself).
  /// Answers whether it copied.
  static Future<bool> copyQuietly({
    required String text,
    required CopyContent content,
  }) =>
      _clipboardGuard.copy(text, content);

  /// The id of the latest copy ([ClipboardGuard.lastCopyId]).
  static int get lastCopyId => _clipboardGuard.lastCopyId;

  /// When a copy has really left the clipboard ([ClipboardGuard.cleared]).
  static Stream<ClipboardCopyCleared> get cleared => _clipboardGuard.cleared;

  /// Context menu for a text field that holds plaintext: paste and select
  /// stay, everything that sends the selection out of the app goes.
  static Widget plaintextContextMenuBuilder(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: plaintextMenuItems(editableTextState.contextMenuButtonItems),
    );
  }

  static const _itemsThatLeaveTheApp = {
    ContextMenuButtonType.copy,
    ContextMenuButtonType.cut,
    ContextMenuButtonType.share,
    ContextMenuButtonType.lookUp,
    ContextMenuButtonType.searchWeb,
  };

  @visibleForTesting
  static List<ContextMenuButtonItem> plaintextMenuItems(
    List<ContextMenuButtonItem> items,
  ) =>
      items
          .where((item) => !_itemsThatLeaveTheApp.contains(item.type))
          .toList();
}

/// Refuses the copy and cut shortcuts (Ctrl/Cmd+C, Ctrl/Cmd+X) for every text
/// field below it: wrap a screen or a field that holds plaintext.
class NoPlaintextCopy extends StatelessWidget {
  const NoPlaintextCopy({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        CopySelectionTextIntent: _RefuseCopyAction(),
      },
      child: child,
    );
  }
}

class _RefuseCopyAction extends Action<CopySelectionTextIntent> {
  @override
  Object? invoke(CopySelectionTextIntent intent) => null;
}
