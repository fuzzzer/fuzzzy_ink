import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:path/path.dart' as path;

part 'open_flow_state.dart';

/// Open (DESIGN.md section 4.8): whatever arrives — a paste, a chosen file,
/// a tapped message link — is first recognised by the core's peek, which
/// spends nothing (`PROTOCOL.md` §7.4), then goes where it belongs. A message
/// that came by link waits for the person's Open before anything is spent
/// (security review 2026-10-26):
///
/// - an invite or a reply leaves for the adding-a-person flow ([OpenRoute]);
/// - a message is opened on its person's session and sealed into their
///   history, as the chat did; a chat file joins the app's one receive queue
///   ([FileProcessingCubit] for receiving), which keeps the locked container
///   and its key and never the plain file;
/// - a password item asks for its password (Basics);
/// - everything else is one "can't open" problem with one fact and one way on.
class OpenFlowCubit extends Cubit<OpenFlowState> {
  OpenFlowCubit({
    required this.cryptoCoreService,
    required this.chatRepository,
    required this.messageDataRepository,
    required this.userFileStore,
    required this.receiveQueue,
  }) : super(const OpenFlowState());

  final CryptoCoreService cryptoCoreService;
  final ChatGeneralDataListRepository chatRepository;
  final MessageDataRepository messageDataRepository;
  final UserFileStore userFileStore;

  /// The app's file queue for receiving from people (provided app-wide).
  final FileProcessingCubit<FileDecryptionOption> receiveQueue;

  StreamSubscription<FileProcessingState>? _queueSubscription;
  StreamSubscription<NewMessageAdded>? _rowSubscription;
  StreamSubscription<FileProcessingProgress>? _passwordFileSubscription;
  FileProcessingHandler? _passwordFileHandler;
  String? _plainCopy;

  /// A `.fuzz` text file another app handed over, already read: kept until
  /// Open used or left it, so a lock in between keeps it for the unlock
  /// ([FuzzyLinkHandler.keepWaitingFileAtLock]).
  String? _arrivedCopy;

  /// Opens [request]. Anything already shown is left first.
  Future<void> open(OpenRequest request) async {
    if (state.phase.isBusy) return;
    await _dropPlainCopy();
    await _dropArrivedCopy();
    emit(const OpenFlowState(phase: OpenPhase.reading));

    switch (request) {
      case OpenPastedText(:final text):
        await _openText(text.trim());
      case OpenChosenFile(:final filePath):
        await _openFile(filePath);
      case OpenArrivedFile(:final filePath):
        await _openFile(filePath, arrived: true);
      case OpenMessageLink(:final encryptedMessage):
        await _recogniseLinkedMessage('$fuzzIdentificator$encryptedMessage');
    }
  }

  /// A message link: recognised by the peek (nothing spent, nothing kept),
  /// then "Open the message from {name}?" — the message is opened only by
  /// [confirmOpen]. A link that holds anything but a message for one of the
  /// person's people opens nothing.
  Future<void> _recogniseLinkedMessage(String blob) async {
    final res = await cryptoCoreService.peekPasted(
      text: blob,
      chatIds: await _connectedChatIds(),
    );
    if (res is CryptoCoreFailure<CryptoCorePeek>) {
      return _problem(OpenProblem.failed);
    }
    final peek = (res as CryptoCoreSuccess<CryptoCorePeek>).data;
    final chatId = peek.chatId;
    if (peek.kind == CryptoCorePeekKind.newerVersion) {
      return _problem(OpenProblem.newerApp);
    }
    if (peek.kind != CryptoCorePeekKind.message) {
      return _problem(OpenProblem.damaged);
    }
    if (chatId == null) return _problem(OpenProblem.notFromYourPeople);
    final chat = await chatRepository.getChatById(chatId);
    if (chat == null || chat.setupStatus != ChatSetupStatus.connected) {
      return _problem(OpenProblem.notFromYourPeople);
    }
    if (isClosed) return;
    emit(
      OpenFlowState(
        phase: OpenPhase.confirmMessage,
        chat: chat,
        pendingMessage: blob,
      ),
    );
  }

  /// The person tapped Open on a message (or a person's file) that came by
  /// link or from another app: only now is it opened (its key spent).
  Future<void> confirmOpen() async {
    final chat = state.chat;
    final blob = state.pendingMessage;
    final filePath = state.pendingFilePath;
    if (state.phase != OpenPhase.confirmMessage || chat == null) return;
    if (blob != null) {
      emit(const OpenFlowState(phase: OpenPhase.reading));
      await _dropArrivedCopy();
      await _openMessage(chatId: chat.chatId, blob: blob, isFromLink: true);
    } else if (filePath != null) {
      emit(const OpenFlowState(phase: OpenPhase.reading));
      _openChatFile(chat, filePath);
    }
  }

  /// Something that arrived from outside and belongs to [chat]: "Open the
  /// message (or file) from {name}?" first.
  void _askToOpen(ChatGeneralData chat, {String? text, String? filePath}) {
    if (isClosed) return;
    emit(
      OpenFlowState(
        phase: OpenPhase.confirmMessage,
        chat: chat,
        pendingMessage: text,
        pendingFilePath: filePath,
      ),
    );
  }

  Future<void> _openText(String pasted) async {
    if (pasted.isEmpty) return _problem(OpenProblem.notFuzzzy);
    // A whole message pasted: only its locked part is read.
    final found = FuzzyLinkParser.findIn(pasted) ?? pasted;
    var text = found;

    // A pasted link: its blob is what the peek reads. The paste is the
    // person's own action, so a message opens straight away.
    final link = FuzzyLinkParser.parseText(found);
    switch (link) {
      case FuzzMessageLinkPayload(:final encryptedMessage):
        text = '$fuzzIdentificator$encryptedMessage';
      case InvitationLinkPayload(:final rawInvitationContent):
        text = rawInvitationContent;
      case AcceptanceLinkPayload(:final rawAcceptanceContent):
        text = rawAcceptanceContent;
      case null:
        break;
    }

    final res = await cryptoCoreService.peekPasted(
      text: text,
      chatIds: await _connectedChatIds(),
    );
    if (res is CryptoCoreFailure<CryptoCorePeek>) {
      return _problem(OpenProblem.failed);
    }
    await _route((res as CryptoCoreSuccess<CryptoCorePeek>).data, text: text);
  }

  Future<void> _openFile(String filePath, {bool arrived = false}) async {
    final res = await cryptoCoreService.peekFile(
      inputPath: filePath,
      chatIds: await _connectedChatIds(),
    );
    if (res is CryptoCoreFailure<CryptoCorePeek>) {
      return _problem(OpenProblem.failed);
    }
    final peek = (res as CryptoCoreSuccess<CryptoCorePeek>).data;
    if (peek.isTextFile) {
      String text;
      try {
        text = (await File(filePath).readAsString()).trim();
      } on FileSystemException {
        return _problem(OpenProblem.failed);
      }
      if (arrived) {
        _arrivedCopy = filePath;
      } else {
        await userFileStore.discardPickedCopy(filePath);
      }
      return _route(peek, text: text, arrived: arrived);
    }
    await _route(peek, filePath: filePath, arrived: arrived);
  }

  Future<void> _route(
    CryptoCorePeek peek, {
    String? text,
    String? filePath,
    bool arrived = false,
  }) async {
    final chatId = peek.chatId;
    switch (peek.kind) {
      case CryptoCorePeekKind.invitation:
        if (chatId == null || text == null) {
          return _problem(OpenProblem.damaged);
        }
        final chat = await chatRepository.getChatById(chatId);
        if (chat == null) return _leave(OpenRouteInvite(text));
        // This phone made it, or already answered it.
        return chat.setupStatus == ChatSetupStatus.invited
            ? _problem(OpenProblem.ownInvite)
            : _problem(OpenProblem.alreadyConnected, chat: chat);
      case CryptoCorePeekKind.acceptance:
        if (chatId == null || text == null) {
          return _problem(OpenProblem.damaged);
        }
        final chat = await chatRepository.getChatById(chatId);
        if (chat == null) return _problem(OpenProblem.notFromYourPeople);
        if (chat.setupStatus != ChatSetupStatus.connected) {
          return _leave(
            OpenRouteReply(chat: chat, acceptance: text, arrived: arrived),
          );
        }
        // The same reply again is harmless. Another one means someone else
        // answered the invite too — but only if the core finds it really
        // answers this chat's invite; anything else is just damaged
        // (security review 2026-10-26).
        final isSame = await chatRepository.isPairedAcceptance(chatId, text);
        if (isSame) return _problem(OpenProblem.alreadyConnected, chat: chat);
        final checkRes = await cryptoCoreService.checkAcceptance(
          chatId: chatId,
          acceptance: text,
        );
        return checkRes is CryptoCoreSuccess<void>
            ? _leave(OpenRouteSecondReply(chat))
            : _problem(OpenProblem.damaged);
      case CryptoCorePeekKind.message:
        if (chatId == null || text == null) {
          return _problem(OpenProblem.damaged);
        }
        if (arrived) {
          final chat = await chatRepository.getChatById(chatId);
          if (chat == null || chat.setupStatus != ChatSetupStatus.connected) {
            return _problem(OpenProblem.notFromYourPeople);
          }
          return _askToOpen(chat, text: text);
        }
        return _openMessage(chatId: chatId, blob: text, isFromLink: false);
      case CryptoCorePeekKind.chatFile:
        if (chatId == null || filePath == null) {
          return _problem(OpenProblem.damaged);
        }
        final chat = await chatRepository.getChatById(chatId);
        if (chat == null) return _problem(OpenProblem.notFromYourPeople);
        if (arrived) return _askToOpen(chat, filePath: filePath);
        return _openChatFile(chat, filePath);
      case CryptoCorePeekKind.passwordText:
        if (text == null) return _problem(OpenProblem.damaged);
        return _askPassword(PendingPasswordItem.text(text));
      case CryptoCorePeekKind.passwordFile:
        if (filePath == null) return _problem(OpenProblem.damaged);
        return _askPassword(PendingPasswordItem.file(filePath));
      case CryptoCorePeekKind.newerVersion:
        return _problem(OpenProblem.newerApp);
      case CryptoCorePeekKind.notFuzzzy:
        return _problem(OpenProblem.notFuzzzy);
      case CryptoCorePeekKind.damaged:
        return _problem(OpenProblem.damaged);
    }
  }

  /// A message for a known chat: opened on its session (the ratchet moves on
  /// and the core saves it), then sealed into the person's history before it
  /// is shown, so a crash in between cannot lose it.
  Future<void> _openMessage({
    required String chatId,
    required String blob,
    required bool isFromLink,
  }) async {
    final chat = await chatRepository.getChatById(chatId);
    if (chat == null || chat.setupStatus != ChatSetupStatus.connected) {
      return _problem(OpenProblem.notFromYourPeople);
    }

    final res = await cryptoCoreService.decryptText(chatId: chatId, blob: blob);
    if (res is CryptoCoreFailure<String>) {
      return _problem(
        switch (res.type) {
          CryptoCoreFailureType.replay => OpenProblem.alreadyOpened,
          CryptoCoreFailureType.tooOld => OpenProblem.tooOld,
          CryptoCoreFailureType.newerVersion => OpenProblem.newerApp,
          CryptoCoreFailureType.storeLocked ||
          CryptoCoreFailureType.io ||
          CryptoCoreFailureType.internal =>
            OpenProblem.failed,
          _ => OpenProblem.damaged,
        },
        chat: chat,
      );
    }
    final text = (res as CryptoCoreSuccess<String>).data;

    try {
      final id = await messageDataRepository.addMessage(
        MessageData(
          id: 0,
          chatId: chatId,
          type: MessageType.text,
          encryptedMessage: blob.replaceAll(RegExp(r'\s'), '').substring(
                fuzzIdentificator.length,
              ),
          decryptedMessage: text,
          sentAt: DateTime.now(),
          isSent: false,
        ),
        notifyListeners: true,
      );
      if (isClosed) return;
      emit(
        OpenFlowState(
          phase: OpenPhase.openedText,
          chat: chat,
          openedText: text,
          historyRowId: id,
        ),
      );
    } catch (error) {
      logger.e('OPEN: could not keep the opened message: $error');
      _problem(OpenProblem.failed, chat: chat);
    }
  }

  /// Joins the receive queue and follows this one file through it. The
  /// queue copies the container into the person's sealed folder, opens it
  /// once to prove every chunk, wipes that plain proof and writes the row
  /// with the container's sealed key; Open and Save here open it again.
  void _openChatFile(ChatGeneralData chat, String filePath) {
    emit(
      OpenFlowState(
        phase: OpenPhase.working,
        chat: chat,
        workingName: path.basename(filePath),
      ),
    );

    String? storedPath;
    _rowSubscription = messageDataRepository.newMessageUpdates.listen((added) {
      final row = added.message;
      if (row.chatId != chat.chatId || row.isSent) return;
      if (row.type != MessageType.file) return;
      if (storedPath == null || row.encryptedMessage != storedPath) return;
      if (isClosed || state.openedFile == null) return;
      emit(
        state.copyWith(
          historyRowId: row.id,
          openedFile: state.openedFile!.withKeptRow(row),
        ),
      );
    });

    _queueSubscription = receiveQueue.stream.listen((queue) {
      if (isClosed) return;
      if (queue.currentProcessingFile?.inputFilePath == filePath &&
          state.phase == OpenPhase.working) {
        emit(state.copyWith(progress: queue.progress));
      }
      final finished = queue.processedFiles
          .where((done) => done.inputFilePath == filePath)
          .firstOrNull;
      if (finished == null) return;

      unawaited(_queueSubscription?.cancel());
      if (finished.status == FileProcessingStatus.completed &&
          finished.outputFilePath != null) {
        storedPath = finished.outputFilePath;
        final row = MessageData(
          id: 0,
          chatId: chat.chatId,
          type: MessageType.file,
          encryptedMessage: finished.outputFilePath!,
          decryptedMessage: '',
          sentAt: DateTime.now(),
          isSent: false,
          keptFileKey: finished.keptFileKey,
        );
        emit(
          OpenFlowState(
            phase: OpenPhase.openedFile,
            chat: chat,
            historyRowId: state.historyRowId,
            openedFile: OpenedFile(
              name: ChatFileCubit.fileNameOf(row),
              keptRow: row,
            ),
          ),
        );
        return;
      }
      _problem(_problemOfFile(finished), chat: chat);
    });

    receiveQueue.addFilesToProcess(
      chatId: chat.chatId,
      chatName: chat.chatName,
      filePaths: [filePath],
    );
  }

  static OpenProblem _problemOfFile(FileProcessingData finished) {
    if (finished.status == FileProcessingStatus.canceled) {
      return OpenProblem.askResend;
    }
    return switch (finished.failure?.type) {
      FileProcessingFailureType.alreadyUnfuzzed => OpenProblem.alreadyOpened,
      FileProcessingFailureType.tooOld => OpenProblem.tooOld,
      FileProcessingFailureType.stillArriving => OpenProblem.stillArriving,
      FileProcessingFailureType.newerApp => OpenProblem.newerApp,
      FileProcessingFailureType.cannotOpenAskResend ||
      FileProcessingFailureType.cancelled =>
        OpenProblem.askResend,
      FileProcessingFailureType.corrupt ||
      FileProcessingFailureType.wrongChat =>
        OpenProblem.damaged,
      _ => OpenProblem.failed,
    };
  }

  void _askPassword(PendingPasswordItem item) {
    emit(OpenFlowState(phase: OpenPhase.password, pendingPassword: item));
  }

  /// Opens the waiting password item with [password]. A wrong one keeps the
  /// screen and says so; nothing is kept in any history.
  Future<void> openWithPassword(String password) async {
    final item = state.pendingPassword;
    if (state.phase != OpenPhase.password || item == null || state.isBusy) {
      return;
    }
    if (password.isEmpty) {
      emit(state.copyWith(isPasswordWrong: true));
      return;
    }
    emit(state.copyWith(isBusy: true, isPasswordWrong: false));

    final text = item.text;
    if (text != null) {
      final res = await cryptoCoreService.passwordOpenText(
        password: password,
        blob: text,
      );
      if (isClosed) return;
      if (res is CryptoCoreFailure<String>) {
        if (res.type == CryptoCoreFailureType.wrongPassword) {
          emit(state.copyWith(isBusy: false, isPasswordWrong: true));
          return;
        }
        return _problem(
          res.type == CryptoCoreFailureType.newerVersion
              ? OpenProblem.newerApp
              : OpenProblem.damaged,
        );
      }
      emit(
        OpenFlowState(
          phase: OpenPhase.openedText,
          openedText: (res as CryptoCoreSuccess<String>).data,
        ),
      );
      return;
    }

    await _openPasswordFile(item.filePath!, password);
  }

  /// A password file opens into one hand-off copy, kept only while it is on
  /// screen (wiped when Open is left or closed, and at every launch).
  Future<void> _openPasswordFile(String filePath, String password) async {
    final base = path.basename(filePath);
    const suffix = '.$fuzzedFileIdentificator';
    final name = base.endsWith(suffix) && base.length > suffix.length
        ? base.substring(0, base.length - suffix.length)
        : base;
    final outputPath = await userFileStore.newHandoffPath(name);
    final res = await cryptoCoreService.decryptFileWithPassword(
      password: password,
      inputPath: filePath,
      outputPath: outputPath,
    );
    if (isClosed) return;
    if (res is CryptoCoreFailure<FileProcessingHandler>) {
      await userFileStore.wipe(outputPath);
      return _problem(OpenProblem.failed);
    }
    final pending = state.pendingPassword;
    emit(
      OpenFlowState(
        phase: OpenPhase.working,
        workingName: name,
        pendingPassword: pending,
      ),
    );
    final handler = (res as CryptoCoreSuccess<FileProcessingHandler>).data;
    _passwordFileHandler = handler;
    _passwordFileSubscription = handler.progressStream.listen((event) async {
      if (isClosed) return;
      if (event.isCancelled) {
        _passwordFileHandler = null;
        await userFileStore.wipe(outputPath);
        _askPassword(pending!);
        return;
      }
      final error = event.errorMessage;
      if (error != null) {
        _passwordFileHandler = null;
        await userFileStore.wipe(outputPath);
        if (isClosed) return;
        if (error == CryptoCoreFailureType.wrongPassword.name) {
          emit(
            OpenFlowState(
              phase: OpenPhase.password,
              pendingPassword: pending,
              isPasswordWrong: true,
            ),
          );
          return;
        }
        return _problem(
          error == CryptoCoreFailureType.newerVersion.name
              ? OpenProblem.newerApp
              : OpenProblem.damaged,
        );
      }
      if (event.isComplete) {
        _passwordFileHandler = null;
        _plainCopy = outputPath;
        await userFileStore.discardPickedCopy(filePath);
        if (isClosed) return;
        emit(
          OpenFlowState(
            phase: OpenPhase.openedFile,
            openedFile: OpenedFile(name: name, plainPath: outputPath),
          ),
        );
        return;
      }
      emit(state.copyWith(progress: event.progress));
    });
  }

  /// Stops a file that is opening.
  void cancel() {
    if (state.phase != OpenPhase.working) return;
    final handler = _passwordFileHandler;
    if (handler != null) {
      handler.cancel();
    } else {
      receiveQueue.cancelFile();
    }
  }

  /// Back to "Open what you got".
  Future<void> startOver() async {
    if (state.phase == OpenPhase.working) return;
    await _dropPlainCopy();
    await _dropArrivedCopy();
    await _queueSubscription?.cancel();
    await _rowSubscription?.cancel();
    if (!isClosed) emit(const OpenFlowState());
  }

  /// The page has followed [OpenFlowState.route].
  void routeTaken() {
    if (state.route != null) emit(const OpenFlowState());
  }

  Future<List<String>> _connectedChatIds() async {
    try {
      final chats = await chatRepository.getAllChats();
      return [
        for (final chat in chats)
          if (chat.setupStatus == ChatSetupStatus.connected) chat.chatId,
      ];
    } catch (error) {
      logger.w('OPEN: could not read the people: $error');
      return const [];
    }
  }

  void _leave(OpenRoute route) {
    if (isClosed) return;
    emit(OpenFlowState(route: route));
  }

  void _problem(OpenProblem problem, {ChatGeneralData? chat}) {
    if (isClosed) return;
    emit(OpenFlowState(phase: OpenPhase.problem, problem: problem, chat: chat));
  }

  Future<void> _dropPlainCopy() async {
    final copy = _plainCopy;
    _plainCopy = null;
    if (copy != null) await userFileStore.wipe(copy);
  }

  Future<void> _dropArrivedCopy() async {
    final copy = _arrivedCopy;
    _arrivedCopy = null;
    if (copy != null) await userFileStore.discardPickedCopy(copy);
  }

  @override
  Future<void> close() async {
    _passwordFileHandler?.cancel();
    await _queueSubscription?.cancel();
    await _rowSubscription?.cancel();
    await _passwordFileSubscription?.cancel();
    await _dropPlainCopy();
    await _dropArrivedCopy();
    // A person's file another app handed over and still waiting for Open
    // ("Not now", or Open closed): its hand-off copy goes.
    final waitingFile =
        state.phase == OpenPhase.confirmMessage ? state.pendingFilePath : null;
    if (waitingFile != null) {
      await userFileStore.discardPickedCopy(waitingFile);
    }
    return super.close();
  }
}
