part of 'lock_flow_cubit.dart';

/// Who a Lock is for: one connected person, or anyone with a password.
class LockTarget {
  const LockTarget.person(ChatGeneralData this.chat);

  const LockTarget.password() : chat = null;

  final ChatGeneralData? chat;

  bool get isPassword => chat == null;
}

enum LockKind { message, file }

/// What, then Locking (files only), then Locked.
enum LockPhase {
  what,
  working,
  locked;

  bool get isWorking => this == working;
}

/// Why Lock did not go on; each has one short line on the screen.
enum LockFailure {
  writeSomethingFirst,
  chooseFileFirst,
  passwordNotGood,

  /// A file was stopped: the core removed its partial output.
  stopped,
  failed,
}

/// A file picked or dropped for locking.
class LockFileChoice {
  const LockFileChoice({required this.filePath, required this.size});

  final String filePath;
  final int size;

  String get name => path.basename(filePath);
}

/// The locked result: the locked text (`Fuzz/…`) of a message, or the
/// locked `.fuzz` file the app keeps. [historyRowId] is the new row in the
/// person's history (none for a password lock).
class LockedItem {
  const LockedItem({
    this.lockedText,
    this.lockedFilePath,
    this.fileName,
    this.fileSize,
    this.historyRowId,
  });

  final String? lockedText;
  final String? lockedFilePath;
  final String? fileName;
  final int? fileSize;
  final int? historyRowId;

  bool get isFile => lockedFilePath != null;

  LockedItem withHistoryRow(int id) => LockedItem(
        lockedText: lockedText,
        lockedFilePath: lockedFilePath,
        fileName: fileName,
        fileSize: fileSize,
        historyRowId: id,
      );
}

class LockFlowState {
  const LockFlowState({
    this.phase = LockPhase.what,
    this.kind = LockKind.message,
    this.file,
    this.isBusy = false,
    this.progress = 0,
    this.isPaused = false,
    this.failure,
    this.item,
    this.isShared = false,
  });

  final LockPhase phase;
  final LockKind kind;
  final LockFileChoice? file;
  final bool isBusy;

  /// 0..1 while a file is locking.
  final double progress;
  final bool isPaused;
  final LockFailure? failure;
  final LockedItem? item;

  /// The system share reported it finished.
  final bool isShared;

  LockFlowState copyWith({
    LockPhase? phase,
    LockKind? kind,
    LockFileChoice? file,
    bool? isBusy,
    double? progress,
    bool? isPaused,
    LockFailure? failure,
    bool clearFailure = false,
    LockedItem? item,
    bool? isShared,
  }) {
    return LockFlowState(
      phase: phase ?? this.phase,
      kind: kind ?? this.kind,
      file: file ?? this.file,
      isBusy: isBusy ?? this.isBusy,
      progress: progress ?? this.progress,
      isPaused: isPaused ?? this.isPaused,
      failure: clearFailure ? null : failure ?? this.failure,
      item: item ?? this.item,
      isShared: isShared ?? this.isShared,
    );
  }

  @override
  String toString() =>
      'LockFlowState($phase, $kind, busy: $isBusy, progress: $progress, '
      'paused: $isPaused, failure: $failure, shared: $isShared)';
}
