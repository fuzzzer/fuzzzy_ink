import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:path/path.dart' as path;

import '../../../../helpers/crypto_core_test_init.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// In-memory stand-in for the Isar-backed data source (as in
/// `message_data_repository_test.dart`); rows are what the export reads.
class FakeMessageDataLocalDataSource extends Fake
    implements MessageDataLocalDataSource {
  final List<StoredMessageData> rows = [];

  @override
  Future<int> addMessage(StoredMessageData messageData) async {
    messageData.id = rows.length + 1;
    rows.add(messageData);
    return messageData.id;
  }

  @override
  Future<List<StoredMessageData>> getMessagesForChat(String chatId) async {
    return rows.where((row) => row.chatId == chatId).toList()
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }
}

Uint8List? _blobOf(CryptoCoreResponse<Uint8List?> readRes) =>
    (readRes as CryptoCoreSuccess<Uint8List?>).data;

const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';
const _chatName = 'Alice';
const _password = 'correct horse battery staple';

MessageData _message(
  String plaintext, {
  required bool isSent,
  MessageType type = MessageType.text,
}) =>
    MessageData(
      id: 0,
      chatId: _chatId,
      type: type,
      encryptedMessage: type.isText ? 'blob-of-$plaintext' : plaintext,
      decryptedMessage: plaintext,
      sentAt: DateTime.now(),
      isSent: isSent,
    );

void main() {
  setUpAll(initCryptoCoreForTests);

  late Directory storeDir;
  late Directory workDir;
  late Directory outDir;
  late CryptoCoreService service;
  late CryptoStoreKeyRepository storeKeyRepository;
  late FakeMessageDataLocalDataSource dataSource;
  late MessageDataRepository messageDataRepository;
  late ChatArchiveRepository repository;
  late String archivePath;

  String plaintextTempPath() =>
      path.join(workDir.path, 'chat_archive_$_chatId.jsonl');

  Future<void> openStore() async {
    await storeKeyRepository.ensureStoreKey('');
    expect(
      await service.openStore(
        wrapped: _blobOf(await storeKeyRepository.read())!,
        password: '',
      ),
      isA<CryptoCoreSuccess<void>>(),
    );
  }

  /// Opens the archive the way Basics file decryption does and parses its
  /// JSON lines; a failure returns the job's `errorMessage` instead.
  Future<({List<Map<String, dynamic>>? lines, String? error})> openArchive(
    String password,
  ) async {
    final openedPath = path.join(outDir.path, 'opened.jsonl');
    final res = await service.decryptFileWithPassword(
      password: password,
      inputPath: archivePath,
      outputPath: openedPath,
    );
    final events = await (res as CryptoCoreSuccess<FileProcessingHandler>)
        .data
        .progressStream
        .toList();
    if (events.last.errorMessage != null) {
      return (lines: null, error: events.last.errorMessage);
    }
    final text = File(openedPath).readAsStringSync();
    expect(text, endsWith('\n'));
    final lines = const LineSplitter()
        .convert(text)
        .map((line) => jsonDecode(line) as Map<String, dynamic>)
        .toList();
    return (lines: lines, error: null);
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    storeDir = Directory.systemTemp.createTempSync('fuzzy_archive_store_');
    workDir = Directory.systemTemp.createTempSync('fuzzy_archive_work_');
    outDir = Directory.systemTemp.createTempSync('fuzzy_archive_out_');
    service = CryptoCoreService(storeDirectoryPath: storeDir.path);
    storeKeyRepository = CryptoStoreKeyRepository(cryptoCoreService: service);
    dataSource = FakeMessageDataLocalDataSource();
    messageDataRepository = MessageDataRepository(
      localDataSource: dataSource,
      cryptoCoreService: service,
    );
    repository = ChatArchiveRepository(
      messageDataRepository: messageDataRepository,
      cryptoCoreService: service,
      workingDirectoryPath: workDir.path,
    );
    archivePath = path.join(outDir.path, 'fuzzzy_ink_archive_2026-09-13.fuzz');
    await openStore();
    expect(
      await service.createInvitation(_chatId),
      isA<CryptoCoreSuccess<CryptoCoreInvitation>>(),
    );
  });

  tearDown(() async {
    await service.close();
    for (final dir in [storeDir, workDir, outDir]) {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
  });

  group('ChatArchiveRepository (real library)', () {
    test(
        'export → 0x04 password-mode container → opens with the password → '
        'JSON lines match the history (sent, received, file, unreadable) → '
        'plaintext temp gone, wrong password refused', () async {
      await messageDataRepository.addMessage(
        _message('hello from A', isSent: true),
      );
      await messageDataRepository.addMessage(
        _message('გამარჯობა 👋', isSent: false),
      );
      await messageDataRepository.addMessage(
        _message(
          '/tmp/Alice/report.pdf.fuzz',
          isSent: true,
          type: MessageType.file,
        ),
      );
      await messageDataRepository.addMessage(_message('lost', isSent: false));
      // The stored row stamps its own `sentAt`; pin them a minute apart.
      final t0 = DateTime.utc(2026, 9, 13, 10);
      for (final (i, row) in dataSource.rows.indexed) {
        row.sentAt = t0.add(Duration(minutes: i));
      }
      // The last row's seal is damaged: it must be marked, not blanked.
      final damaged = base64Decode(dataSource.rows.last.sealedPlaintext!);
      damaged[damaged.length - 1] ^= 0x01;
      dataSource.rows.last.sealedPlaintext = base64Encode(damaged);

      final res = await repository.exportChat(
        chatId: _chatId,
        chatName: _chatName,
        password: _password,
        outputPath: archivePath,
      );

      expect(res, isA<ChatArchiveSuccess<void>>());
      expect(File(plaintextTempPath()).existsSync(), isFalse);
      expect(workDir.listSync(), isEmpty, reason: 'no plaintext left behind');
      expect(File('$archivePath.part').existsSync(), isFalse);
      final header = File(archivePath).openSync().readSync(7);
      expect(
        header,
        [0x46, 0x55, 0x5A, 0x5A, 0x01, 0x04, 0x02],
        reason: 'FUZZ · v1 · file container · password mode',
      );
      final sealedText = utf8.decode(
        File(archivePath).readAsBytesSync(),
        allowMalformed: true,
      );
      expect(sealedText, isNot(contains('hello from A')));
      expect(sealedText, isNot(contains('report.pdf')));

      final opened = await openArchive(_password);
      expect(opened.error, isNull);
      expect(opened.lines, [
        {
          'chatId': _chatId,
          'chatName': _chatName,
          'direction': 'sent',
          'sentAt': '2026-09-13T10:00:00.000Z',
          'type': 'text',
          'text': 'hello from A',
        },
        {
          'chatId': _chatId,
          'chatName': _chatName,
          'direction': 'received',
          'sentAt': '2026-09-13T10:01:00.000Z',
          'type': 'text',
          'text': 'გამარჯობა 👋',
        },
        {
          'chatId': _chatId,
          'chatName': _chatName,
          'direction': 'sent',
          'sentAt': '2026-09-13T10:02:00.000Z',
          'type': 'file',
          'fileName': 'report.pdf.fuzz',
        },
        {
          'chatId': _chatId,
          'chatName': _chatName,
          'direction': 'received',
          'sentAt': '2026-09-13T10:03:00.000Z',
          'type': 'text',
          'unreadable': true,
        },
      ]);

      final wrong = await openArchive('wrong horse');
      expect(wrong.lines, isNull);
      expect(wrong.error, CryptoCoreFailureType.wrongPassword.name);
    });

    test('a locked store is storeLocked before anything is read or written',
        () async {
      await messageDataRepository.addMessage(_message('hello', isSent: true));
      await service.close();

      final res = await repository.exportChat(
        chatId: _chatId,
        chatName: _chatName,
        password: _password,
        outputPath: archivePath,
      );

      expect(
        res,
        isA<ChatArchiveFailure<void>>().having(
          (failure) => failure.type,
          'type',
          ChatArchiveExportFailureType.storeLocked,
        ),
      );
      expect(File(archivePath).existsSync(), isFalse);
      expect(workDir.listSync(), isEmpty);
    });

    test('an empty chat is nothingToExport and writes nothing', () async {
      final res = await repository.exportChat(
        chatId: _chatId,
        chatName: _chatName,
        password: _password,
        outputPath: archivePath,
      );

      expect(
        res,
        isA<ChatArchiveFailure<void>>().having(
          (failure) => failure.type,
          'type',
          ChatArchiveExportFailureType.nothingToExport,
        ),
      );
      expect(File(archivePath).existsSync(), isFalse);
      expect(workDir.listSync(), isEmpty);
    });

    test(
        'a seal that cannot be written is unknown — the plaintext temp is '
        'still deleted', () async {
      await messageDataRepository.addMessage(_message('hello', isSent: true));
      final unwritable = path.join(outDir.path, 'missing', 'archive.fuzz');

      final res = await repository.exportChat(
        chatId: _chatId,
        chatName: _chatName,
        password: _password,
        outputPath: unwritable,
      );

      expect(
        res,
        isA<ChatArchiveFailure<void>>().having(
          (failure) => failure.type,
          'type',
          ChatArchiveExportFailureType.unknown,
        ),
      );
      expect(File(unwritable).existsSync(), isFalse);
      expect(File(plaintextTempPath()).existsSync(), isFalse);
      expect(workDir.listSync(), isEmpty);
    });
  });
}
