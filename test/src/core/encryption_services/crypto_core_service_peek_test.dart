import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:path/path.dart' as path;

import '../../../helpers/crypto_core_test_init.dart';

// ---------------------------------------------------------------------------
// Open's recognition through CryptoCoreService (real library): what a paste
// or a file is, and whose it is, without spending anything.
// ---------------------------------------------------------------------------

const _chatX = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';
const _chatY = '0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d';

Matcher _failsWith(CryptoCoreFailureType type) =>
    isA<CryptoCoreFailure<dynamic>>().having((f) => f.type, 'type', type);

T _dataOf<T>(CryptoCoreResponse<T> res) => (res as CryptoCoreSuccess<T>).data;

class _Device {
  _Device._(this.dir, this.service);

  final Directory dir;
  final CryptoCoreService service;

  static Future<_Device> open() async {
    final dir = Directory.systemTemp.createTempSync('crypto_core_peek_');
    final service = CryptoCoreService(storeDirectoryPath: dir.path);
    expect(
      await service.createMasterKey('test password'),
      isA<CryptoCoreSuccess<CryptoCoreMasterKeySetup>>(),
    );
    return _Device._(dir, service);
  }

  String write(String name, String text) {
    final file = File(path.join(dir.path, name))..writeAsStringSync(text);
    return file.path;
  }

  Future<void> close() async {
    await service.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

Future<void> _pair(_Device a, _Device b, String chatId) async {
  final invitation = _dataOf(await a.service.createInvitation(chatId)).content;
  final acceptance = _dataOf(
    await b.service.acceptInvitation(chatId: chatId, invitation: invitation),
  ).content;
  expect(
    await a.service.completeHandshake(chatId: chatId, acceptance: acceptance),
    isA<CryptoCoreSuccess<void>>(),
  );
}

void main() {
  setUpAll(initCryptoCoreForTests);

  late _Device a;
  late _Device b;
  late _Device c;

  setUp(() async {
    a = await _Device.open();
    b = await _Device.open();
    c = await _Device.open();
    await _pair(a, b, _chatX);
    await _pair(a, c, _chatY);
  });

  tearDown(() async {
    await a.close();
    await b.close();
    await c.close();
  });

  test('a pasted message routes to its person and still opens once', () async {
    final fromC =
        _dataOf(await c.service.encryptText(chatId: _chatY, text: 'hi'));

    final peek = _dataOf(
      await a.service.peekPasted(text: fromC, chatIds: [_chatX, _chatY]),
    );
    expect(
      peek,
      const CryptoCorePeek(kind: CryptoCorePeekKind.message, chatId: _chatY),
    );
    expect(
      _dataOf(await a.service.decryptText(chatId: _chatY, blob: fromC)),
      'hi',
    );

    // Opened already: still Y's, so Open can say where it is.
    final again = _dataOf(
      await a.service.peekPasted(text: fromC, chatIds: [_chatX, _chatY]),
    );
    expect(again.chatId, _chatY);
    expect(
      await a.service.decryptText(chatId: _chatY, blob: fromC),
      _failsWith(CryptoCoreFailureType.replay),
    );
  });

  test('pairing blobs, password text and strangers', () async {
    final stranger = await _Device.open();
    addTearDown(stranger.close);
    final invitation = _dataOf(
      await stranger.service
          .createInvitation('11111111-2222-4333-8444-555555555555'),
    ).content;
    expect(
      _dataOf(await a.service.peekPasted(text: invitation, chatIds: [])),
      const CryptoCorePeek(
        kind: CryptoCorePeekKind.invitation,
        chatId: '11111111-2222-4333-8444-555555555555',
      ),
    );

    final sealed = _dataOf(
      await a.service.passwordSealText(password: 'pw pw pw', text: 'x'),
    );
    expect(
      _dataOf(await a.service.peekPasted(text: sealed, chatIds: [])).kind,
      CryptoCorePeekKind.passwordText,
    );

    final fromB =
        _dataOf(await b.service.encryptText(chatId: _chatX, text: 'hi'));
    expect(
      _dataOf(await a.service.peekPasted(text: fromB, chatIds: [_chatY])),
      const CryptoCorePeek(kind: CryptoCorePeekKind.message),
    );
    expect(
      _dataOf(await a.service.peekPasted(text: 'hello', chatIds: [])).kind,
      CryptoCorePeekKind.notFuzzzy,
    );
  });

  test('a .fuzz file of locked text peeks as that text', () async {
    final fromB =
        _dataOf(await b.service.encryptText(chatId: _chatX, text: 'hi'));
    final file = a.write('fuzzzy-ink-message.fuzz', fromB);
    expect(
      _dataOf(
        await a.service.peekFile(inputPath: file, chatIds: [_chatY, _chatX]),
      ),
      const CryptoCorePeek(
        kind: CryptoCorePeekKind.message,
        chatId: _chatX,
        isTextFile: true,
      ),
    );
    expect(
      await a.service.peekFile(
        inputPath: path.join(a.dir.path, 'missing'),
        chatIds: [],
      ),
      _failsWith(CryptoCoreFailureType.io),
    );
  });

  test('a locked store answers storeLocked', () async {
    await a.service.close();
    expect(
      await a.service.peekPasted(text: 'Fuzz/x', chatIds: []),
      _failsWith(CryptoCoreFailureType.storeLocked),
    );
  });
}
