import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:go_router/go_router.dart';

/// Centralized navigation helpers for Fuzzzy Ink.
///
/// Use `context.goBack()` instead of raw `context.pop()` everywhere.
/// This guarantees the chat list (home) is always reachable — even when
/// the current page was opened via deep link and has no parent on the stack.
extension FuzzyNavigator on BuildContext {
  /// Pops to the previous page, or navigates to the chat list if
  /// there is nothing to pop (e.g. page was opened via deep link).
  void goBack() {
    if (canPop()) {
      pop();
    } else {
      go(AppRouter.home);
    }
  }
}
