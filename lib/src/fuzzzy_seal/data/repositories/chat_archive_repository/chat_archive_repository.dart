import 'dart:convert';
import 'dart:io';

import 'package:fuzzzy_seal/lib.dart';
import 'package:path/path.dart' as path;

/// Takes a chat's history out of the app as a password-sealed file: under
/// the ratchet every blob is single-use, so the sealed local history is the
/// only readable copy there is.
class ChatArchiveRepository {
  final MessageDataRepository messageDataRepository;
  final CryptoCoreService cryptoCoreService;

  /// App-private directory for the plaintext lines while they are sealed.
  final String workingDirectoryPath;

  ChatArchiveRepository({
    required this.messageDataRepository,
    required this.cryptoCoreService,
    required this.workingDirectoryPath,
  });

  /// Writes the chat's history as JSON lines (one object per message:
  /// `chatId`, `chatName`, `direction`, `sentAt`, `type`, then `text`,
  /// `fileName` or `"unreadable": true` for a text row whose seal would not
  /// open) to a temp file, seals it with [password] into the password-mode
  /// file container at [outputPath] — the one Basics file decryption opens —
  /// and deletes the plaintext whatever happens.
  ///
  /// The store must be open: `getMessagesForChat` reads a locked store as
  /// empty rows, which would export silently blank messages.
  Future<ChatArchiveResponse<void>> exportChat({
    required String chatId,
    required String chatName,
    required String password,
    required String outputPath,
  }) async {
    if (!cryptoCoreService.isOpen) {
      return const ChatArchiveFailure(ChatArchiveExportFailureType.storeLocked);
    }

    final plaintextFile = File(
      path.join(workingDirectoryPath, 'chat_archive_$chatId.jsonl'),
    );

    try {
      final messages = await messageDataRepository.getMessagesForChat(chatId);

      if (messages.isEmpty) {
        return const ChatArchiveFailure(
          ChatArchiveExportFailureType.nothingToExport,
        );
      }

      await plaintextFile.writeAsString(
        messages
            .map((message) => '${jsonEncode(_lineOf(message, chatName))}\n')
            .join(),
        flush: true,
      );

      final sealRes = await cryptoCoreService.encryptFileWithPassword(
        password: password,
        inputPath: plaintextFile.path,
        outputPath: outputPath,
      );

      if (sealRes is CryptoCoreFailure<FileProcessingHandler>) {
        logger.w('Failed to start the chat archive seal: ${sealRes.type}');
        return const ChatArchiveFailure(ChatArchiveExportFailureType.unknown);
      }

      final failure = await _runToCompletion(
        (sealRes as CryptoCoreSuccess<FileProcessingHandler>).data,
      );

      if (failure != null) {
        logger.w('Chat archive seal failed: $failure');
        return const ChatArchiveFailure(ChatArchiveExportFailureType.unknown);
      }

      return const ChatArchiveSuccess(null);
    } catch (e) {
      logger.e('Failed to export chat archive: $e');
      return const ChatArchiveFailure(ChatArchiveExportFailureType.unknown);
    } finally {
      if (plaintextFile.existsSync()) plaintextFile.deleteSync();
    }
  }

  Map<String, Object> _lineOf(MessageData message, String chatName) {
    return {
      'chatId': message.chatId,
      'chatName': chatName,
      'direction': message.isSent ? 'sent' : 'received',
      'sentAt': message.sentAt.toUtc().toIso8601String(),
      'type': message.type.name,
      if (message.type.isFile)
        'fileName': path.basename(message.encryptedMessage)
      else if (message.isUnreadable)
        'unreadable': true
      else
        'text': message.decryptedMessage,
    };
  }

  /// The job's terminal event: `errorMessage` before `isComplete`
  /// (a failure event carries both). `null` means the container was written.
  Future<String?> _runToCompletion(FileProcessingHandler handler) async {
    await for (final event in handler.progressStream) {
      if (event.errorMessage != null) return event.errorMessage;
      if (event.isCancelled) return CryptoCoreFailureType.cancelled.name;
      if (event.isComplete) return null;
    }
    return CryptoCoreFailureType.internal.name;
  }
}
