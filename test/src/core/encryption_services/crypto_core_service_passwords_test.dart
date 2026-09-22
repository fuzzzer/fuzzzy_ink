import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';

import '../../../helpers/crypto_core_test_init.dart';

// ---------------------------------------------------------------------------
// Password-sealed text (0x05) through CryptoCoreService (real library): the
// fuzzy_basics text path, on a service whose store is never opened.
// ---------------------------------------------------------------------------

const _password = 'correct horse';
const _text = "grandma's cookies — ბებიას ნამცხვარი 🍪";

T _dataOf<T>(CryptoCoreResponse<T> res) => (res as CryptoCoreSuccess<T>).data;

CryptoCoreFailureType _failureOf(CryptoCoreResponse<dynamic> res) =>
    (res as CryptoCoreFailure).type;

void main() {
  setUpAll(initCryptoCoreForTests);

  late Directory dir;
  late CryptoCoreService service;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('crypto_core_pw_text_');
    // Never opened: password mode must not need the store.
    service = CryptoCoreService(storeDirectoryPath: dir.path);
  });

  tearDown(() async {
    await service.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('seal → Fuzz/ 0x05 blob → open restores the text', () async {
    expect(service.isOpen, isFalse);
    final blob = _dataOf(
      await service.passwordSealText(password: _password, text: _text),
    );
    expect(blob, startsWith(fuzzIdentificator));
    final raw = base64Url.decode(base64Url.normalize(blob.substring(5)));
    expect(raw.sublist(0, 6), [0x46, 0x55, 0x5A, 0x5A, 0x01, 0x05]);
    expect(blob, isNot(contains('cookies')), reason: 'no plaintext leaks');

    expect(
      _dataOf(await service.passwordOpenText(password: _password, blob: blob)),
      _text,
    );

    final again = _dataOf(
      await service.passwordSealText(password: _password, text: _text),
    );
    expect(again, isNot(blob), reason: 'fresh salt and nonce every seal');
  });

  test('wrong password and a tampered blob are wrongPassword', () async {
    final blob = _dataOf(
      await service.passwordSealText(password: _password, text: _text),
    );
    expect(
      _failureOf(await service.passwordOpenText(password: 'wrong', blob: blob)),
      CryptoCoreFailureType.wrongPassword,
    );
    expect(
      _failureOf(await service.passwordOpenText(password: '', blob: blob)),
      CryptoCoreFailureType.wrongPassword,
    );

    // Flip one ciphertext character: the AEAD tag fails like a wrong password.
    final at = blob.length - 10;
    final tampered = blob.replaceRange(at, at + 1, blob[at] == 'A' ? 'B' : 'A');
    expect(
      _failureOf(
        await service.passwordOpenText(password: _password, blob: tampered),
      ),
      CryptoCoreFailureType.wrongPassword,
    );
  });

  test('garbage is unsupportedFormat, a truncated blob corrupt', () async {
    for (final garbage in ['', 'not a blob', 'Fuzz/', fuzzIdentificator]) {
      expect(
        _failureOf(
          await service.passwordOpenText(password: _password, blob: garbage),
        ),
        CryptoCoreFailureType.unsupportedFormat,
        reason: '"$garbage"',
      );
    }

    final blob = _dataOf(
      await service.passwordSealText(password: _password, text: _text),
    );
    // Envelope intact, the Argon2 parameters cut off.
    final truncated = blob.substring(0, 5 + 12);
    expect(
      _failureOf(
        await service.passwordOpenText(password: _password, blob: truncated),
      ),
      CryptoCoreFailureType.corrupt,
    );
  });
}
