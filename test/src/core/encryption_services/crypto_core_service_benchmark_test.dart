import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:path/path.dart' as path;

import '../../../helpers/crypto_core_test_init.dart';

// ---------------------------------------------------------------------------
// The development-flavor file benchmark through CryptoCoreService (real
// library): a small round trip on a service whose store is never opened.
// ---------------------------------------------------------------------------

T _dataOf<T>(CryptoCoreResponse<T> res) => (res as CryptoCoreSuccess<T>).data;

CryptoCoreFailureType _failureOf(CryptoCoreResponse<dynamic> res) =>
    (res as CryptoCoreFailure).type;

void main() {
  setUpAll(initCryptoCoreForTests);

  late Directory dir;
  late CryptoCoreService service;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('crypto_core_bench_');
    // Never opened: password mode must not need the store.
    service = CryptoCoreService(storeDirectoryPath: dir.path);
  });

  tearDown(() async {
    await service.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('a 2 MiB round trip reports both rates, both KDF times and cleans up',
      () async {
    expect(service.isOpen, isFalse);
    final result = _dataOf(
      await service.benchmarkFiles(directoryPath: dir.path, sizeMiB: 2),
    );

    expect(result.sizeBytes, 2 * 1024 * 1024);
    expect(result.encryptMbPerSecond, greaterThan(0));
    expect(result.decryptMbPerSecond, greaterThan(0));
    // Argon2id at 64 MiB / t=4 is never instantaneous.
    expect(result.encryptKeyDerivation, greaterThan(Duration.zero));
    expect(result.decryptKeyDerivation, greaterThan(Duration.zero));
    expect(dir.listSync(), isEmpty, reason: 'temp files deleted');
  });

  test('an unwritable directory is internal and leaves nothing behind',
      () async {
    final missing = path.join(dir.path, 'missing');
    final res = await service.benchmarkFiles(directoryPath: missing);
    expect(_failureOf(res), CryptoCoreFailureType.internal);
    expect(Directory(missing).existsSync(), isFalse);
    expect(dir.listSync(), isEmpty);
  });
}
