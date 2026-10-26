import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The desktop keys of DESIGN.md section 6 ("Tablet and desktop"), on a
/// computer only (macOS with ⌘, Windows and Linux with Ctrl):
///
/// - ⌘/Ctrl + L: Lock
/// - ⌘/Ctrl + O: Open
/// - ⌘/Ctrl + ,: Settings
/// - ⌘/Ctrl + Shift + L: lock the app
///
/// It sits around the unlocked app's tabs, so the keys work wherever the
/// focus is on them; a flow or a sheet on top keeps its own keys.
class DesktopShortcuts extends StatelessWidget {
  const DesktopShortcuts({
    super.key,
    required this.onLock,
    required this.onOpen,
    required this.onSettings,
    required this.onLockApp,
    required this.child,
  });

  final VoidCallback onLock;
  final VoidCallback onOpen;
  final VoidCallback onSettings;
  final VoidCallback onLockApp;
  final Widget child;

  /// Whether the keys apply on [platform] (a computer).
  static bool isDesktop(TargetPlatform platform) => switch (platform) {
        TargetPlatform.macOS ||
        TargetPlatform.windows ||
        TargetPlatform.linux =>
          true,
        TargetPlatform.android ||
        TargetPlatform.iOS ||
        TargetPlatform.fuchsia =>
          false,
      };

  /// The keys for [platform]: ⌘ on a Mac, Ctrl elsewhere.
  static Map<ShortcutActivator, VoidCallback> bindingsFor(
    TargetPlatform platform, {
    required VoidCallback onLock,
    required VoidCallback onOpen,
    required VoidCallback onSettings,
    required VoidCallback onLockApp,
  }) {
    final isMac = platform == TargetPlatform.macOS;
    SingleActivator key(LogicalKeyboardKey key, {bool shift = false}) =>
        SingleActivator(key, meta: isMac, control: !isMac, shift: shift);
    return {
      key(LogicalKeyboardKey.keyL): onLock,
      key(LogicalKeyboardKey.keyO): onOpen,
      key(LogicalKeyboardKey.comma): onSettings,
      key(LogicalKeyboardKey.keyL, shift: true): onLockApp,
    };
  }

  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform;
    if (!isDesktop(platform)) return child;
    return CallbackShortcuts(
      bindings: bindingsFor(
        platform,
        onLock: onLock,
        onOpen: onOpen,
        onSettings: onSettings,
        onLockApp: onLockApp,
      ),
      // Keeps a focus inside, so the keys arrive before anything is clicked.
      child: Focus(autofocus: true, child: child),
    );
  }
}
