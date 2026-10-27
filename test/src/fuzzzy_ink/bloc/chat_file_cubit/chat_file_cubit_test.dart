import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:path/path.dart' as path;

import '../../../../helpers/crypto_core_test_init.dart';

const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';

T _dataOf<T>(CryptoCoreResponse<T> res) => (res as CryptoCoreSuccess<T>).data;

/// A device: its own open store and its own file folders.
class _Device {
  _Device._(this.dir, this.service, this.files);

  final Directory dir;
  final CryptoCoreService service;
  final UserFileStore files;

  static Future<_Device> open() async {
    final dir = Directory.systemTemp.createTempSync('chat_file_cubit_');
    final service = CryptoCoreService(storeDirectoryPath: dir.path);
    // The first run opens the store; the master password only gates it.
    _dataOf(await service.createMasterKey('test password'));
    final files = UserFileStore(
      supportDirectoryPath: dir.path,
      temporaryDirectoryPath: path.join(dir.path, 'tmp'),
      documentsDirectoryPath: path.join(dir.path, 'documents'),
    );
    return _Device._(dir, service, files);
  }

  Future<void> close() async {
    await service.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

/// A received file the way the chat keeps it: the container copied into the
/// chat's sealed folder, unfuzzed once, its key sealed in the row.
Future<MessageData> _receive(_Device a, _Device b, Uint8List plaintext) async {
  final input = File(path.join(a.dir.path, 'photo.jpg'))
    ..writeAsBytesSync(plaintext);
  final sent = path.join(a.dir.path, 'photo.jpg.fuzz');
  final send = _dataOf(
    await a.service.encryptFileForChat(
      chatId: _chatId,
      inputPath: input.path,
      outputPath: sent,
    ),
  );
  await send.progressStream.drain<void>();

  final folder = await b.files.chatFolder(chatName: 'Alice', chatId: _chatId);
  final kept = File(sent).copySync(path.join(folder, 'photo.jpg.fuzz'));
  final received = _dataOf(
    await b.service.decryptFileForChat(
      chatId: _chatId,
      inputPath: kept.path,
      outputDirectoryPath: await b.files.newHandoffFolder(),
    ),
  );
  await received.handler.progressStream.drain<void>();
  await b.files.wipe(received.outputPath);

  return MessageData(
    id: 1,
    chatId: _chatId,
    type: MessageType.file,
    encryptedMessage: b.files.storedPathOf(kept.path),
    decryptedMessage: '',
    sentAt: DateTime(2026, 10, 26),
    isSent: false,
    keptFileKey: base64Encode(received.keptKey),
  );
}

void main() {
  setUpAll(initCryptoCoreForTests);

  late _Device a;
  late _Device b;
  late ChatFileCubit cubit;
  final plaintext = Uint8List.fromList(List<int>.generate(70000, (i) => i));

  setUp(() async {
    a = await _Device.open();
    b = await _Device.open();
    final invitation = _dataOf(await a.service.createInvitation(_chatId));
    final acceptance = _dataOf(
      await b.service.acceptInvitation(
        chatId: _chatId,
        invitation: invitation.content,
      ),
    );
    await a.service.completeHandshake(
      chatId: _chatId,
      acceptance: acceptance.content,
    );
    cubit = ChatFileCubit(cryptoCoreService: b.service, userFileStore: b.files);
  });

  tearDown(() async {
    if (!cubit.isClosed) await cubit.close();
    await a.close();
    await b.close();
  });

  test(
      'a kept file unfuzzes into a short-lived copy as often as asked; each '
      'copy is wiped when used and the rest when the chat closes', () async {
    final row = await _receive(a, b, plaintext);
    expect(ChatFileCubit.fileNameOf(row), 'photo.jpg');

    final first = await cubit.unfuzz(row);
    expect(first, isNotNull);
    expect(path.basename(first!), 'photo.jpg');
    expect(b.files.isHandoff(first), isTrue);
    expect(File(first).readAsBytesSync(), plaintext);
    expect(cubit.state.status, StateStatus.success);

    await cubit.wipe(first);
    expect(File(first).existsSync(), isFalse);

    final second = await cubit.unfuzz(row);
    expect(File(second!).readAsBytesSync(), plaintext);

    await cubit.close();
    expect(File(second).existsSync(), isFalse);
    expect(Directory(b.files.handoffRootPath).listSync(), isEmpty);
  });

  test('a row without its kept key, or another chat, opens nothing', () async {
    final row = await _receive(a, b, plaintext);

    expect(await cubit.unfuzz(row.copyWith(keptFileKey: '')), isNull);
    expect(cubit.state.status, StateStatus.failed);
    expect(cubit.state.failure?.type, FileProcessingFailureType.corrupt);

    await b.service.deleteChat(_chatId);
    expect(await cubit.unfuzz(row), isNull);
    expect(cubit.state.status, StateStatus.failed);
    expect(
      Directory(b.files.handoffRootPath).listSync(recursive: true),
      everyElement(isA<Directory>()),
      reason: 'no plain file is left',
    );
  });
}
