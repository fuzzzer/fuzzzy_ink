import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Keeps sensitive screens out of screenshots, screen recordings and the app
/// switcher while at least one of them is visible:
///
/// - Android: `FLAG_SECURE` on the window (screenshots, recordings and the
///   recents thumbnail come out blank).
/// - iOS: the content is drawn in a secure layer (screenshots and recordings
///   come out blank), and a blur covers it while the screen is recorded or
///   mirrored.
/// - macOS: the window's sharing type is none (left out of screenshots and
///   screen recordings that respect it).
/// - Windows: the window is excluded from capture
///   (`SetWindowDisplayAffinity`).
/// - Linux: nothing the system offers; only the in-app cover.
///
/// Screens opt in with one line: wrap the page in [SensitiveScreen].
///
/// The app switcher never shows the content of any screen (DESIGN.md section
/// 4.2): on iOS a native cover (the look's ground and the Ink mark,
/// [setCoverLook]) hides the window whenever the app is inactive; Android 13+
/// leaves every recents thumbnail blank (`MainActivity.kt`). macOS and
/// Windows show no app-switcher thumbnails of the content.
class ScreenGuard {
  ScreenGuard({MethodChannel channel = guardChannel}) : _channel = channel;

  static ScreenGuard instance = ScreenGuard();

  final MethodChannel _channel;
  int _visibleSensitiveScreens = 0;

  bool get isProtecting => _visibleSensitiveScreens > 0;

  void sensitiveScreenShown() {
    _visibleSensitiveScreens++;
    if (_visibleSensitiveScreens == 1) unawaited(_setSecure(true));
  }

  void sensitiveScreenHidden() {
    if (_visibleSensitiveScreens == 0) return;
    _visibleSensitiveScreens--;
    if (_visibleSensitiveScreens == 0) unawaited(_setSecure(false));
  }

  ({int ground, String mark})? _coverLook;

  /// Tells the iOS app-switcher cover the look's [ground] and the Ink mark
  /// to paint on it ([InkMark.assetFor] at 3x). Sent only when it changes;
  /// nothing to do on the other platforms.
  Future<void> setCoverLook({
    required Color ground,
    required Brightness brightness,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    final look = (
      ground: ground.toARGB32(),
      mark: coverMarkAsset(brightness),
    );
    if (look == _coverLook) return;
    _coverLook = look;
    try {
      await _channel.invokeMethod<bool>(
        'setCover',
        {'ground': look.ground, 'mark': look.mark},
      );
    } on MissingPluginException {
      // Nothing native to tell.
    } on PlatformException catch (exception) {
      logger.w('SCREEN GUARD: setCover failed: ${exception.code}');
    }
  }

  /// The 3x file of the mark for a look (the cover draws it at 64 points).
  static String coverMarkAsset(Brightness brightness) {
    final asset = InkMark.assetFor(brightness);
    final slash = asset.lastIndexOf('/');
    return '${asset.substring(0, slash)}/3.0x${asset.substring(slash)}';
  }

  Future<void> _setSecure(bool isSecure) async {
    try {
      await _channel.invokeMethod<bool>('setSecure', isSecure);
    } on MissingPluginException {
      // Linux: no system protection; the in-app cover still applies.
    } on PlatformException catch (exception) {
      logger.w('SCREEN GUARD: setSecure($isSecure) failed: ${exception.code}');
    }
  }
}

/// Marks the page below as sensitive: while it is visible (its route is on
/// top or only covered by a dialog or sheet), [ScreenGuard] protects the
/// window; on a phone it is also covered whenever the app is not in front.
/// Its text fields refuse the copy and cut shortcuts ([NoPlaintextCopy]).
class SensitiveScreen extends StatefulWidget {
  const SensitiveScreen({required this.child, super.key});

  final Widget child;

  /// Whether [context] sits below a [SensitiveScreen]. Shared widgets keep to
  /// in-place changes there: no travel, glow or Fuzzzy Cast (DESIGN.md
  /// section 10, "Private screens").
  static bool isIn(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_SensitiveScope>() != null;

  @override
  State<SensitiveScreen> createState() => _SensitiveScreenState();
}

class _SensitiveScope extends InheritedWidget {
  const _SensitiveScope({required super.child});

  @override
  bool updateShouldNotify(_SensitiveScope oldWidget) => false;
}

class _SensitiveScreenState extends State<SensitiveScreen> {
  ValueListenable<TickerModeData>? _visibility;
  bool _isCounted = false;
  late final AppLifecycleListener _lifecycleListener;
  late bool _isCovered;

  /// Desktop windows lose focus all the time (another window, a dialog);
  /// covering them then would get in the way. The system protection holds.
  static bool get _coversWhenInactive =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _isCovered = _shouldCover(WidgetsBinding.instance.lifecycleState);
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        final isCovered = _shouldCover(state);
        if (isCovered != _isCovered) setState(() => _isCovered = isCovered);
      },
    );
  }

  bool _shouldCover(AppLifecycleState? state) =>
      _coversWhenInactive &&
      state != null &&
      state != AppLifecycleState.resumed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visibility = TickerMode.getValuesNotifier(context);
    if (visibility == _visibility) return;
    _visibility?.removeListener(_onVisibilityChanged);
    _visibility = visibility..addListener(_onVisibilityChanged);
    _onVisibilityChanged();
  }

  void _onVisibilityChanged() {
    final isVisible = _visibility?.value.enabled ?? false;
    if (isVisible == _isCounted) return;
    _isCounted = isVisible;
    if (isVisible) {
      ScreenGuard.instance.sensitiveScreenShown();
    } else {
      ScreenGuard.instance.sensitiveScreenHidden();
    }
  }

  @override
  void dispose() {
    _visibility?.removeListener(_onVisibilityChanged);
    if (_isCounted) ScreenGuard.instance.sensitiveScreenHidden();
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        _SensitiveScope(child: NoPlaintextCopy(child: widget.child)),
        if (_isCovered)
          Positioned.fill(
            child: ColoredBox(
              key: const Key('sensitive_screen.cover'),
              color: context.fuzzzyColors.ground,
              child: Center(
                child: Icon(
                  Icons.lock_outline,
                  color: context.fuzzzyColors.inkMute,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Keeps the app-switcher cover in the app's look ([ScreenGuard.setCoverLook]):
/// sits once at the app's root and tells the native side the look the app
/// settles on ([ground], [brightness]) whenever it changes.
class AppSwitcherCover extends StatefulWidget {
  const AppSwitcherCover({
    required this.ground,
    required this.brightness,
    required this.child,
    super.key,
  });

  final Color ground;
  final Brightness brightness;
  final Widget child;

  @override
  State<AppSwitcherCover> createState() => _AppSwitcherCoverState();
}

class _AppSwitcherCoverState extends State<AppSwitcherCover> {
  @override
  void initState() {
    super.initState();
    _tell();
  }

  @override
  void didUpdateWidget(AppSwitcherCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    _tell();
  }

  void _tell() => unawaited(
        ScreenGuard.instance.setCoverLook(
          ground: widget.ground,
          brightness: widget.brightness,
        ),
      );

  @override
  Widget build(BuildContext context) => widget.child;
}
