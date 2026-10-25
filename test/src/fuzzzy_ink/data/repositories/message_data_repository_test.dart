import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';

import '../../../../helpers/crypto_core_test_init.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

/// In-memory stand-in for the Isar-backed data source: rows survive a
/// "relaunch" of the repository exactly as Isar rows would.
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

  @override
  Future<List<StoredMessageData>> getMessagesForChatPaginated(
    String chatId, {
    required int pageSize,
    required int pageIndex,
  }) async {
    final sorted = rows.where((row) => row.chatId == chatId).toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
    return sorted.skip(pageIndex * pageSize).take(pageSize).toList();
  }
}

/// A row's binding as the repository forms it: direction byte ‖ blob text.
Uint8List _row({required bool isSent, required String blob}) =>
    Uint8List.fromList([if (isSent) 1 else 0, ...utf8.encode(blob)]);

const _masterPassword = 'Test-Master-Pass-1';

const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';
const _otherChatId = '0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d';

MessageData _text(
  String plaintext, {
  required bool isSent,
  String chatId = _chatId,
}) =>
    MessageData(
      id: 0,
      chatId: chatId,
      type: MessageType.text,
      encryptedMessage: 'blob-of-$plaintext',
      decryptedMessage: plaintext,
      sentAt: DateTime.now(),
      isSent: isSent,
    );

void main() {
  setUpAll(initCryptoCoreForTests);

  late Directory storeDir;
  late CryptoCoreService service;
  late ChatAuthRepository auth;
  late FakeMessageDataLocalDataSource dataSource;
  late MessageDataRepository repository;

  Future<void> openStore() async {
    expect(
      await auth.setUp(_masterPassword),
      isA<CryptoCoreSuccess<CryptoCoreMasterKeySetup>>(),
    );
  }

  Future<void> reopenStore() async {
    expect(await auth.unlock(_masterPassword), isA<CryptoCoreSuccess<void>>());
  }

  /// History is sealed under the chat's own key, which exists from the
  /// moment the chat's key material does — an invitation is enough.
  Future<void> invite(CryptoCoreService on, String chatId) async {
    expect(
      await on.createInvitation(chatId),
      isA<CryptoCoreSuccess<CryptoCoreInvitation>>(),
    );
  }

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    storeDir = Directory.systemTemp.createTempSync('fuzzy_message_repo_');
    service = CryptoCoreService(storeDirectoryPath: storeDir.path);
    auth = ChatAuthRepository(
      localDataSource: MasterKeyLocalDataSource(),
      cryptoCoreService: service,
    );
    dataSource = FakeMessageDataLocalDataSource();
    repository = MessageDataRepository(
      localDataSource: dataSource,
      cryptoCoreService: service,
    );
    await openStore();
    await invite(service, _chatId);
  });

  tearDown(() async {
    await service.close();
    if (storeDir.existsSync()) storeDir.deleteSync(recursive: true);
  });

  group('MessageDataRepository sealed history (real library)', () {
    test(
        'seal on add → stored row carries a 0x20 seal, not the plaintext → '
        'open on read → close and reopen the store → still readable', () async {
      final sentId = await repository.addMessage(_text('hello', isSent: true));
      final receivedId =
          await repository.addMessage(_text('reply', isSent: false));
      expect([sentId, receivedId], [1, 2]);

      final sentRow = dataSource.rows.first;
      expect(sentRow.encryptedMessage, 'blob-of-hello');
      expect(sentRow.messageType, MessageType.text.name);
      final seal = base64Decode(sentRow.sealedPlaintext!);
      expect(
        seal.sublist(0, 6),
        [0x46, 0x55, 0x5A, 0x5A, 0x01, 0x20],
        reason: 'FUZZ · v1 · local seal',
      );
      expect(sentRow.sealedPlaintext, isNot(contains('hello')));
      expect(
        utf8.decode(seal, allowMalformed: true),
        isNot(contains('hello')),
      );

      final messages = await repository.getMessagesForChat(_chatId);
      expect(messages.map((m) => m.decryptedMessage), ['hello', 'reply']);
      expect(messages.map((m) => m.isSent), [true, false]);
      expect(
        messages.map((m) => m.encryptedMessage),
        ['blob-of-hello', 'blob-of-reply'],
      );

      // "Relaunch": the store is closed and reopened from the same wrapped
      // key; the rows are what Isar kept.
      await service.close();
      expect(
        (await repository.getMessagesForChat(_chatId))
            .map((m) => m.decryptedMessage),
        ['', ''],
        reason: 'a locked store reads as empty, never throws',
      );
      await reopenStore();

      final page = await repository.getMessagesForChatPaginated(
        _chatId,
        pageSize: 8,
        pageIndex: 0,
      );
      expect(page.map((m) => m.decryptedMessage), ['reply', 'hello']);
    });

    test(
        'a seal from another store, a flipped byte, a missing seal and a '
        'non-base64 seal read as empty and are never thrown', () async {
      await repository.addMessage(_text('hello', isSent: true));
      final row = dataSource.rows.single;

      final tampered = base64Decode(row.sealedPlaintext!);
      tampered[tampered.length - 1] ^= 0x01;
      row.sealedPlaintext = base64Encode(tampered);
      expect(
        (await repository.getMessagesForChat(_chatId)).single.decryptedMessage,
        '',
      );

      final otherDir = Directory.systemTemp.createTempSync('fuzzy_other_');
      final other = CryptoCoreService(storeDirectoryPath: otherDir.path);
      addTearDown(() async {
        await other.close();
        otherDir.deleteSync(recursive: true);
      });
      await other.createMasterKey(_masterPassword);
      await invite(other, _chatId);
      final foreignSeal = await other.sealLocal(
        chatId: _chatId,
        row: _row(isSent: true, blob: row.encryptedMessage),
        bytes: Uint8List.fromList(utf8.encode('hello')),
      );
      row.sealedPlaintext =
          base64Encode((foreignSeal as CryptoCoreSuccess<Uint8List>).data);
      expect(
        (await repository.getMessagesForChat(_chatId)).single.decryptedMessage,
        '',
      );

      row.sealedPlaintext = null;
      expect(
        (await repository.getMessagesForChat(_chatId)).single.decryptedMessage,
        '',
      );

      // Not base64 at all: base64Decode would throw a FormatException.
      row.sealedPlaintext = 'not base64 at all!';
      expect(
        (await repository.getMessagesForChat(_chatId)).single.decryptedMessage,
        '',
      );
    });

    test(
        'the seal is per chat: sealed in chat A, opens in A, and reads as '
        'empty (corrupt) in chat B on the same device', () async {
      await invite(service, _otherChatId);
      await repository.addMessage(_text('only for A', isSent: false));
      final row = dataSource.rows.single;
      expect(
        (await repository.getMessagesForChat(_chatId)).single.decryptedMessage,
        'only for A',
      );

      final sealed = base64Decode(row.sealedPlaintext!);
      expect(
        await service.openLocal(
          chatId: _otherChatId,
          row: _row(isSent: false, blob: row.encryptedMessage),
          blob: sealed,
        ),
        isA<CryptoCoreFailure<Uint8List>>().having(
          (failure) => failure.type,
          'type',
          CryptoCoreFailureType.corrupt,
        ),
      );

      // The same seal filed under chat B's row reads as empty, never throws.
      row.chatId = _otherChatId;
      expect(
        (await repository.getMessagesForChat(_otherChatId))
            .single
            .decryptedMessage,
        '',
      );
      expect(await repository.getMessagesForChat(_chatId), isEmpty);

      // A chat the store does not know cannot open a seal either.
      row.chatId = 'ffffffff-0000-4000-8000-000000000000';
      expect(
        (await repository.getMessagesForChat(row.chatId))
            .single
            .decryptedMessage,
        '',
      );
    });

    test(
        'the seal is per row (security review 2026-10-22): moved onto another '
        'row, or with the row flipped between sent and received, it reads as '
        'empty', () async {
      await repository.addMessage(_text('first', isSent: true));
      await repository.addMessage(_text('second', isSent: false));
      final first = dataSource.rows.first;
      final second = dataSource.rows.last;
      expect(
        (await repository.getMessagesForChat(_chatId))
            .map((m) => m.decryptedMessage),
        ['first', 'second'],
      );

      final swapped = first.sealedPlaintext;
      first.sealedPlaintext = second.sealedPlaintext;
      second.sealedPlaintext = swapped;
      expect(
        (await repository.getMessagesForChat(_chatId))
            .map((m) => m.isUnreadable),
        [true, true],
      );

      second
        ..sealedPlaintext = first.sealedPlaintext
        ..isSent = true;
      expect(
        (await repository.getMessagesForChat(_chatId)).last.decryptedMessage,
        '',
        reason: 'the right seal on its row, but the direction flipped',
      );
    });

    test(
        'a row that opens is not flagged; a row whose seal fails is flagged '
        'isUnreadable, as is one read through a locked store', () async {
      await repository.addMessage(_text('hello', isSent: true));
      await repository.addMessage(_text('reply', isSent: false));
      final damaged = base64Decode(dataSource.rows.last.sealedPlaintext!);
      damaged[0] ^= 0x01;
      dataSource.rows.last.sealedPlaintext = base64Encode(damaged);

      final messages = await repository.getMessagesForChat(_chatId);
      expect(messages.map((m) => m.decryptedMessage), ['hello', '']);
      expect(messages.map((m) => m.isUnreadable), [false, true]);

      await service.close();
      expect(
        (await repository.getMessagesForChat(_chatId))
            .map((m) => m.isUnreadable),
        [true, true],
      );
    });

    test('a sent file row carries no seal and keeps its path in both fields',
        () async {
      await repository.addMessage(
        MessageData(
          id: 0,
          chatId: _chatId,
          type: MessageType.file,
          encryptedMessage: 'chats/Bob (6f1e9b2c)/photo.jpg.fuzz',
          decryptedMessage: '',
          sentAt: DateTime.now(),
          isSent: true,
        ),
      );
      expect(dataSource.rows.single.sealedPlaintext, isNull);

      final message = (await repository.getMessagesForChat(_chatId)).single;
      expect(message.type, MessageType.file);
      expect(message.encryptedMessage, 'chats/Bob (6f1e9b2c)/photo.jpg.fuzz');
      expect(message.decryptedMessage, 'chats/Bob (6f1e9b2c)/photo.jpg.fuzz');
      expect(message.keptFileKey, isNull);
      expect(
        await repository.getFilePathsForChat(_chatId),
        ['chats/Bob (6f1e9b2c)/photo.jpg.fuzz'],
      );
    });

    test(
        "a received file row keeps the container's sealed key as it is, "
        'and gives it back', () async {
      await repository.addMessage(
        MessageData(
          id: 0,
          chatId: _chatId,
          type: MessageType.file,
          encryptedMessage: 'chats/Bob (6f1e9b2c)/photo.jpg.fuzz',
          decryptedMessage: '',
          sentAt: DateTime.now(),
          isSent: false,
          keptFileKey: 'RlVaWgEg',
        ),
      );
      await repository.addMessage(_text('hello', isSent: true));
      expect(dataSource.rows.first.sealedPlaintext, 'RlVaWgEg');

      final file = (await repository.getMessagesForChat(_chatId)).first;
      expect(file.keptFileKey, 'RlVaWgEg');
      expect(
        await repository.getFilePathsForChat(_chatId),
        ['chats/Bob (6f1e9b2c)/photo.jpg.fuzz'],
      );
    });

    test('a locked store still stores the blob, without a seal', () async {
      await service.close();
      final id = await repository.addMessage(_text('hello', isSent: false));
      expect(id, 1);
      expect(dataSource.rows.single.encryptedMessage, 'blob-of-hello');
      expect(dataSource.rows.single.sealedPlaintext, isNull);
    });

    test('unicode plaintext round-trips through the seal', () async {
      const plaintext = 'გამარჯობა 👋 — «quotes»';
      await repository.addMessage(_text(plaintext, isSent: true));
      expect(
        (await repository.getMessagesForChat(_chatId)).single.decryptedMessage,
        plaintext,
      );
    });
  });
}
