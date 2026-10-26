import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// Where a My safe password copy is: nothing copied, copied and counting
/// down, or really cleared.
enum SafeCopyPhase { idle, copied, cleared }

/// The truthful "Copied · clears in 30 s" line (DESIGN.md section 10, item
/// 11): counts down once a second from the guard's clear time, and says
/// "Cleared." only when the copy guard reports that the copy really left the
/// clipboard ([CopyGuard.cleared]). While the clear is still pending (the
/// system refused it in the background) the count stays at one second.
/// A newer copy made anywhere in the app ends this one quietly.
class SafeCopyCountdown extends ChangeNotifier {
  SafeCopyCountdown({
    Stream<ClipboardCopyCleared>? cleared,
    int Function()? lastCopyId,
  }) : _lastCopyId = lastCopyId ?? (() => CopyGuard.lastCopyId) {
    _subscription = (cleared ?? CopyGuard.cleared).listen(_onCleared);
  }

  final int Function() _lastCopyId;
  late final StreamSubscription<ClipboardCopyCleared> _subscription;
  Timer? _ticker;
  int? _copyId;

  SafeCopyPhase _phase = SafeCopyPhase.idle;
  SafeCopyPhase get phase => _phase;

  int _secondsLeft = 0;

  /// Whole seconds until the planned clear; at least 1 while copied.
  int get secondsLeft => _secondsLeft;

  /// A copy was made: [copyId] is the guard's id for it.
  void start({required int copyId, required Duration clearAfter}) {
    _ticker?.cancel();
    _copyId = copyId;
    _phase = SafeCopyPhase.copied;
    _secondsLeft = clearAfter.inSeconds < 1 ? 1 : clearAfter.inSeconds;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();
  }

  void _tick() {
    if (_lastCopyId() != _copyId) {
      // Another copy replaced this one: nothing of ours is left to count.
      _ticker?.cancel();
      _phase = SafeCopyPhase.idle;
      notifyListeners();
      return;
    }
    if (_secondsLeft > 1) {
      _secondsLeft--;
      notifyListeners();
    }
  }

  void _onCleared(ClipboardCopyCleared event) {
    if (_phase != SafeCopyPhase.copied || event.copyId != _copyId) return;
    _ticker?.cancel();
    _phase = SafeCopyPhase.cleared;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
