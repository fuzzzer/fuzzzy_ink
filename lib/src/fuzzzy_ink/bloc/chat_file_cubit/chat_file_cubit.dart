import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:path/path.dart' as path;

part 'chat_file_state.dart';

/// A chat's file rows, for the moment the user uses one: a received file is
/// unfuzzed from the container the app kept (`PROTOCOL.md` §9.6) into a
/// hand-off copy, which the caller shows, saves or shares and then wipes
/// ([wipe], [wipeWhenBack]); every copy still held is wiped when the chat
/// closes. A sent row's container is handed out as it is — it is sealed.
class ChatFileCubit extends Cubit<ChatFileState> {
  ChatFileCubit({
    required this.cryptoCoreService,
    required this.userFileStore,
  }) : super(const ChatFileState());

  final CryptoCoreService cryptoCoreService;
  final UserFileStore userFileStore;

  final Set<String> _copies = {};
  FileProcessingHandler? _activeHandler;

  /// The file a row names, as the user knows it: the stored container's
  /// name without `.fuzz`.
  static String fileNameOf(MessageData message) {
    final name = path.basename(message.encryptedMessage);
    const suffix = '.$fuzzedFileIdentificator';
    return name.endsWith(suffix) && name.length > suffix.length
        ? name.substring(0, name.length - suffix.length)
        : name;
  }

  /// The sealed file a row keeps.
  String sealedPathOf(MessageData message) =>
      userFileStore.resolve(message.encryptedMessage);

  /// Unfuzzes the received file row [message] into a fresh hand-off copy and
  /// answers its path, or `null` when it failed (the state says why) or was
  /// cancelled. One at a time.
  Future<String?> unfuzz(MessageData message) async {
    if (state.status.isLoading) return null;
    emit(const ChatFileState(status: StateStatus.loading));

    final keptKey = _decodeKeptKey(message.keptFileKey);
    if (keptKey == null) {
      _fail(FileProcessingFailureType.corrupt);
      return null;
    }

    final outputPath = await userFileStore.newHandoffPath(fileNameOf(message));
    final res = await cryptoCoreService.openKeptFileForChat(
      chatId: message.chatId,
      inputPath: sealedPathOf(message),
      keptKey: keptKey,
      outputPath: outputPath,
    );
    if (res is CryptoCoreFailure<FileProcessingHandler>) {
      await userFileStore.wipe(outputPath);
      _fail(
        res.type == CryptoCoreFailureType.corrupt
            ? FileProcessingFailureType.corrupt
            : FileProcessingFailureType.unknown,
      );
      return null;
    }

    final handler = (res as CryptoCoreSuccess<FileProcessingHandler>).data;
    _activeHandler = handler;
    try {
      await for (final event in handler.progressStream) {
        if (event.isCancelled) {
          await userFileStore.wipe(outputPath);
          if (!isClosed) emit(const ChatFileState());
          return null;
        }
        if (event.errorMessage != null) {
          await userFileStore.wipe(outputPath);
          _fail(FileProcessingFailureType.corrupt);
          return null;
        }
        if (event.isComplete) {
          _copies.add(outputPath);
          if (!isClosed) {
            emit(const ChatFileState(status: StateStatus.success, progress: 1));
          }
          return outputPath;
        }
        if (!isClosed) {
          emit(state.copyWith(progress: event.progress));
        }
      }
    } finally {
      _activeHandler = null;
    }
    await userFileStore.wipe(outputPath);
    _fail(FileProcessingFailureType.unknown);
    return null;
  }

  void cancel() => _activeHandler?.cancel();

  /// Wipes a copy [unfuzz] made, now.
  Future<void> wipe(String copyPath) async {
    _copies.remove(copyPath);
    await userFileStore.wipe(copyPath);
  }

  /// For a copy the share sheet may still be reading: wiped when the app is
  /// back in front, or when the chat closes.
  void wipeWhenBack(String copyPath) => userFileStore.wipeWhenBack(copyPath);

  static Uint8List? _decodeKeptKey(String? keptFileKey) {
    if (keptFileKey == null || keptFileKey.isEmpty) return null;
    try {
      return base64Decode(keptFileKey);
    } on FormatException {
      return null;
    }
  }

  void _fail(FileProcessingFailureType type) {
    if (isClosed) return;
    emit(
      ChatFileState(
        status: StateStatus.failed,
        failure: FileProcessingFailure(type: type),
      ),
    );
  }

  @override
  Future<void> close() async {
    _activeHandler?.cancel();
    for (final copy in _copies.toList()) {
      await userFileStore.wipe(copy);
    }
    _copies.clear();
    return super.close();
  }
}
