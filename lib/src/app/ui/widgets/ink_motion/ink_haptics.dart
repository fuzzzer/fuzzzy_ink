import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Haptics for the redesign's responses, through Flutter's own
/// [HapticFeedback] only (no package). Phones only: nothing on desktop or the
/// web. The phone's own haptics setting still applies, and a buzz is never
/// the only signal (DESIGN.md section 10).
abstract final class InkHaptics {
  /// Lets tests run the phone path on any host.
  @visibleForTesting
  static bool? debugIsPhone;

  static bool get _isPhone =>
      debugIsPhone ??
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS));

  /// Copied, shared, invite made, unlocked, handed over, a file opened.
  static Future<void> light() =>
      _isPhone ? HapticFeedback.lightImpact() : Future<void>.value();

  /// Locked, connected, checked.
  static Future<void> medium() =>
      _isPhone ? HapticFeedback.mediumImpact() : Future<void>.value();

  /// A wrong password, once per wrong try.
  static Future<void> heavy() =>
      _isPhone ? HapticFeedback.heavyImpact() : Future<void>.value();

  /// Switches only.
  static Future<void> selection() =>
      _isPhone ? HapticFeedback.selectionClick() : Future<void>.value();
}
