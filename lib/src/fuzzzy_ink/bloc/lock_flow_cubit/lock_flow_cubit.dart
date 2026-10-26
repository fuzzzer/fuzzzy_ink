import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:path/path.dart' as path;

part 'lock_flow_state.dart';

/// Lock → What → Locking → Locked (DESIGN.md sections 4.5–4.7), on the
/// existing logic underneath:
///
/// - a message for a person: the core locks it on the chat's session and the
///   row is sealed into their history ([MessageDataRepository.addMessage]),
///   exactly as the chat did;
/// - a file for a person: it joins the app's one file queue
///   ([FileProcessingCubit] for sending), which writes the `.fuzz` into the
///   person's sealed folder and the history row; this cubit follows it for
///   the progress, Pause and Cancel;
/// - with a password (Basics): text or a file locked under a password that
///   must reach "good"; the file lands in the sealed Basics folder. Nothing
///   goes into anyone's history.
///
/// The original file stays where it was; on a phone the picker's copy is
/// deleted once used, when the lock fails or is stopped, when another file is
/// chosen, and when the flow closes (security review 2026-10-26).
class LockFlowCubit extends Cubit<LockFlowState> {
  LockFlowCubit({
    required this.target,
    required this.cryptoCoreService,
    required this.messageDataRepository,
    required this.userFileStore,
    required this.passwordStrengthService,
    required this.chatFileQueue,
  }) : super(const LockFlowState());

  final LockTarget target;
  final CryptoCoreService cryptoCoreService;
  final MessageDataRepository messageDataRepository;
  final UserFileStore userFileStore;
  final PasswordStrengthService passwordStrengthService;

  /// The app's file queue for sending to people (provided app-wide).
  final FileProcessingCubit<FileEncryptionOption> chatFileQueue;

  StreamSubscription<FileProcessingState>? _queueSubscription;
  StreamSubscription<NewMessageAdded>? _rowSubscription;
  StreamSubscription<FileProcessingProgress>? _passwordFileSubscription;
  FileProcessingHandler? _passwordFileHandler;

  void chooseKind(LockKind kind) {
    if (state.phase != LockPhase.what) return;
    emit(state.copyWith(kind: kind, clearFailure: true));
  }

  /// A picked or dropped file. Only its name and size are read here.
  Future<void> chooseFile(String filePath) async {
    if (state.phase != LockPhase.what) return;
    final previous = state.file?.filePath;
    if (previous != null && previous != filePath) {
      await userFileStore.discardPickedCopy(previous);
    }
    var size = 0;
    try {
      size = await File(filePath).length();
    } on FileSystemException {
      size = 0;
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        kind: LockKind.file,
        file: LockFileChoice(filePath: filePath, size: size),
        clearFailure: true,
      ),
    );
  }

  /// Locks what was written or chosen. [password] is used only when the
  /// target is [LockTarget.password].
  Future<void> lock({String text = '', String password = ''}) async {
    if (state.phase != LockPhase.what || state.isBusy) return;

    final isFile = state.kind == LockKind.file;
    final file = state.file;
    if (!isFile && text.trim().isEmpty) {
      return _fail(LockFailure.writeSomethingFirst);
    }
    if (isFile && file == null) return _fail(LockFailure.chooseFileFirst);
    if (target.isPassword &&
        !passwordStrengthService.isStrongEnough(password)) {
      return _fail(LockFailure.passwordNotGood);
    }

    emit(state.copyWith(isBusy: true, clearFailure: true));
    final chat = target.chat;
    if (chat == null) {
      if (isFile) return _lockFileWithPassword(file!, password);
      return _lockTextWithPassword(text, password);
    }
    if (isFile) return _lockFileFor(chat, file!);
    return _lockTextFor(chat, text);
  }

  Future<void> _lockTextFor(ChatGeneralData chat, String text) async {
    final res = await cryptoCoreService.encryptText(
      chatId: chat.chatId,
      text: text,
    );
    if (res is CryptoCoreFailure<String>) return _fail(LockFailure.failed);
    final blob = (res as CryptoCoreSuccess<String>).data;

    try {
      // The ratchet has moved on: this sealed row is the only copy of the
      // text the sender can ever read back (as in the chat before).
      final id = await messageDataRepository.addMessage(
        MessageData(
          id: 0,
          type: MessageType.text,
          chatId: chat.chatId,
          encryptedMessage: blob.substring(fuzzIdentificator.length),
          decryptedMessage: text,
          sentAt: DateTime.now(),
          isSent: true,
        ),
        notifyListeners: true,
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          phase: LockPhase.locked,
          isBusy: false,
          item: LockedItem(lockedText: blob, historyRowId: id),
        ),
      );
    } catch (error) {
      logger.e('LOCK: could not keep the locked message: $error');
      _fail(LockFailure.failed);
    }
  }

  Future<void> _lockTextWithPassword(String text, String password) async {
    final res = await cryptoCoreService.passwordSealText(
      password: password,
      text: text,
    );
    if (isClosed) return;
    if (res is CryptoCoreFailure<String>) return _fail(LockFailure.failed);
    emit(
      state.copyWith(
        phase: LockPhase.locked,
        isBusy: false,
        item: LockedItem(lockedText: (res as CryptoCoreSuccess<String>).data),
      ),
    );
  }

  /// Joins the app's file queue and follows this one file through it: its
  /// progress while it runs, then its finished entry (done, stopped or
  /// failed). The history row the queue writes is caught for the glow.
  void _lockFileFor(ChatGeneralData chat, LockFileChoice file) {
    emit(state.copyWith(phase: LockPhase.working, progress: 0));

    String? storedPath;
    _rowSubscription = messageDataRepository.newMessageUpdates.listen((added) {
      final row = added.message;
      if (row.chatId != chat.chatId || !row.isSent) return;
      if (row.type != MessageType.file) return;
      if (storedPath == null || row.encryptedMessage != storedPath) return;
      final item = state.item;
      if (item != null && !isClosed) {
        emit(state.copyWith(item: item.withHistoryRow(row.id)));
      }
    });

    _queueSubscription = chatFileQueue.stream.listen((queue) {
      if (isClosed) return;
      final current = queue.currentProcessingFile;
      if (current?.inputFilePath == file.filePath && state.phase.isWorking) {
        emit(state.copyWith(progress: queue.progress));
      }
      final finished = queue.processedFiles
          .where((done) => done.inputFilePath == file.filePath)
          .firstOrNull;
      if (finished == null) return;

      unawaited(_queueSubscription?.cancel());
      switch (finished.status) {
        case FileProcessingStatus.completed:
          storedPath = finished.outputFilePath;
          emit(
            state.copyWith(
              phase: LockPhase.locked,
              isBusy: false,
              isPaused: false,
              progress: 1,
              item: LockedItem(
                lockedFilePath: userFileStore.resolve(finished.outputFilePath!),
                fileName: file.name,
                fileSize: file.size,
              ),
            ),
          );
        case FileProcessingStatus.canceled:
          unawaited(_droppedFile(file, LockFailure.stopped));
        case FileProcessingStatus.failed:
        case FileProcessingStatus.pending:
        case FileProcessingStatus.inProgress:
          unawaited(_droppedFile(file, LockFailure.failed));
      }
    });

    chatFileQueue.addFilesToProcess(
      chatId: chat.chatId,
      chatName: chat.chatName,
      filePaths: [file.filePath],
    );
  }

  Future<void> _lockFileWithPassword(
    LockFileChoice file,
    String password,
  ) async {
    emit(state.copyWith(phase: LockPhase.working, progress: 0));
    final folder = await userFileStore.basicsFolder();
    final outputPath = await UserFileNames.uniqueOutputPath(
      path.join(
        folder,
        '${UserFileNames.cleanPickedFileName(file.name)}.$fuzzedFileIdentificator',
      ),
    );
    final res = await cryptoCoreService.encryptFileWithPassword(
      password: password,
      inputPath: file.filePath,
      outputPath: outputPath,
    );
    if (isClosed) return;
    if (res is CryptoCoreFailure<FileProcessingHandler>) {
      return _droppedFile(file, LockFailure.failed);
    }
    final handler = (res as CryptoCoreSuccess<FileProcessingHandler>).data;
    _passwordFileHandler = handler;
    _passwordFileSubscription = handler.progressStream.listen((event) async {
      if (isClosed) return;
      if (event.isCancelled) {
        _passwordFileHandler = null;
        return _droppedFile(file, LockFailure.stopped);
      }
      // A failure ends with isComplete set too: it must win.
      if (event.errorMessage != null) {
        _passwordFileHandler = null;
        return _droppedFile(file, LockFailure.failed);
      }
      if (event.isComplete) {
        _passwordFileHandler = null;
        await userFileStore.discardPickedCopy(file.filePath);
        if (isClosed) return;
        emit(
          state.copyWith(
            phase: LockPhase.locked,
            isBusy: false,
            isPaused: false,
            progress: 1,
            item: LockedItem(
              lockedFilePath: outputPath,
              fileName: file.name,
              fileSize: file.size,
            ),
          ),
        );
        return;
      }
      emit(state.copyWith(progress: event.progress));
    });
  }

  void pause() {
    if (!state.phase.isWorking || state.isPaused) return;
    _pauseTarget();
    emit(state.copyWith(isPaused: true));
  }

  void resume() {
    if (!state.phase.isWorking || !state.isPaused) return;
    final handler = _passwordFileHandler;
    if (handler != null) {
      handler.resume();
    } else {
      chatFileQueue.resumeFile();
    }
    emit(state.copyWith(isPaused: false));
  }

  /// Stops the running file; the core removes its partial output, so
  /// nothing is kept ("Stopped. Nothing was kept.").
  void cancel() {
    if (!state.phase.isWorking) return;
    final handler = _passwordFileHandler;
    if (handler != null) {
      handler.cancel();
    } else {
      chatFileQueue.cancelFile();
    }
  }

  /// After a share the system reported as finished: Share steps back to
  /// "Share again" and Done becomes the main button.
  void markShared() {
    if (state.phase != LockPhase.locked) return;
    emit(state.copyWith(isShared: true));
  }

  void _pauseTarget() {
    final handler = _passwordFileHandler;
    if (handler != null) {
      handler.pause();
    } else {
      chatFileQueue.pauseFile();
    }
  }

  void _backToWhat(LockFailure failure, {bool dropFile = false}) {
    if (isClosed) return;
    emit(
      LockFlowState(
        kind: state.kind,
        file: dropFile ? null : state.file,
        failure: failure,
        item: state.item,
        isShared: state.isShared,
      ),
    );
  }

  /// A file lock that failed or was stopped: the picker's plain copy goes at
  /// once (the file queue deletes its own), and on a phone the person picks
  /// the file again; a computer's own file stays chosen.
  Future<void> _droppedFile(LockFileChoice file, LockFailure failure) async {
    await userFileStore.discardPickedCopy(file.filePath);
    _backToWhat(failure, dropFile: userFileStore.isPickedCopy(file.filePath));
  }

  void _fail(LockFailure failure) {
    if (isClosed) return;
    emit(state.copyWith(isBusy: false, failure: failure));
  }

  @override
  Future<void> close() async {
    await _queueSubscription?.cancel();
    await _rowSubscription?.cancel();
    await _passwordFileSubscription?.cancel();
    // A picked copy nothing will use any more: never handed over, or its
    // password lock is stopped here. One the file queue is working on is the
    // queue's to delete.
    final picked = state.file?.filePath;
    final queueOwnsIt = state.phase.isWorking && _passwordFileHandler == null;
    if (picked != null && state.phase != LockPhase.locked && !queueOwnsIt) {
      _passwordFileHandler?.cancel();
      await userFileStore.discardPickedCopy(picked);
    }
    return super.close();
  }
}
