import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/lib.dart';

export 'fuzzy_snackbar_content.dart';
export 'fuzzy_snackbar_data.dart';

const Duration _snackBarDisplayDuration = Duration(milliseconds: 2500);

class FuzzySnackbar {
  static final List<FuzzySnackbarData> _snackbarQueue = [];

  static void show({
    String? label,
    TextStyle? labelStyle,
    Color? backgroundColor,
    double? width,
    double? elevation,
    Widget? leading,
    Widget? content = const SizedBox.shrink(),
    Duration? duration = _snackBarDisplayDuration,
  }) {
    _snackbarQueue.add(
      FuzzySnackbarData(
        label: label,
        labelStyle: labelStyle,
        backgroundColor: backgroundColor,
        width: width,
        elevation: elevation,
        leading: leading,
        content: content,
        duration: duration,
      ),
    );

    if (_snackbarQueue.length == 1) {
      showNextSnackbar();
    }
  }

  static void showNextSnackbar() {
    if (navigatorKey.currentState == null) return;

    if (_snackbarQueue.isNotEmpty) {
      final snackbarData = _snackbarQueue[0];
      final overlayState = navigatorKey.currentState?.overlay;

      if (overlayState == null) {
        return;
      }

      OverlayEntry? overlayEntry;

      overlayEntry = OverlayEntry(
        builder: (BuildContext context) => FuzzySnackBarContent(
          overlayEntry: overlayEntry,
          snackbarData: snackbarData,
          snackbarQueue: _snackbarQueue,
        ),
      );

      overlayState.insert(overlayEntry);

      Future.delayed(snackbarData.duration ?? _snackBarDisplayDuration, () {
        overlayEntry?.remove();
        _snackbarQueue.removeAt(0);
        showNextSnackbar();
      });
    }
  }
}
