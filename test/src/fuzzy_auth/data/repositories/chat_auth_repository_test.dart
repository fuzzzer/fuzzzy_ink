import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:mocktail/mocktail.dart';

class MockMasterKeyLocalDataSource extends Mock
    implements MasterKeyLocalDataSource {}

class MockCryptoCoreService extends Mock implements CryptoCoreService {}

/// The keychain outlives a deleted app on iPhone and Mac: key blobs whose
/// store is gone are leftovers of an earlier install, so the device reads as
/// not set up and the first run starts (seen live on a reinstall, 2026-10-26).
void main() {
  late MockMasterKeyLocalDataSource localDataSource;

  final blobs = MasterKeyBlobs(
    passwordWrap: Uint8List.fromList([1]),
    storeWrap: Uint8List.fromList([2]),
  );

  setUp(() {
    localDataSource = MockMasterKeyLocalDataSource();
  });

  ChatAuthRepository repository({Future<bool> Function()? storeExists}) =>
      ChatAuthRepository(
        localDataSource: localDataSource,
        cryptoCoreService: MockCryptoCoreService(),
        storeExists: storeExists,
      );

  MasterKeyStatus? statusOf(CryptoCoreResponse<MasterKeyStatus> res) =>
      res is CryptoCoreSuccess<MasterKeyStatus> ? res.data : null;

  test('no blobs: not set up', () async {
    when(() => localDataSource.read()).thenAnswer((_) async => null);
    final res = await repository(storeExists: () async => true).status();
    expect(statusOf(res), MasterKeyStatus.notSetUp);
  });

  test('blobs and their store: ready', () async {
    when(() => localDataSource.read()).thenAnswer((_) async => blobs);
    final res = await repository(storeExists: () async => true).status();
    expect(statusOf(res), MasterKeyStatus.ready);
  });

  test('blobs without their store (a reinstall): not set up', () async {
    when(() => localDataSource.read()).thenAnswer((_) async => blobs);
    final res = await repository(storeExists: () async => false).status();
    expect(statusOf(res), MasterKeyStatus.notSetUp);
  });

  test('a store that cannot be checked counts as there', () async {
    when(() => localDataSource.read()).thenAnswer((_) async => blobs);
    final res = await repository(
      storeExists: () async => throw Exception('no access'),
    ).status();
    expect(statusOf(res), MasterKeyStatus.ready);
  });

  test('no check given (tests): blobs are ready', () async {
    when(() => localDataSource.read()).thenAnswer((_) async => blobs);
    expect(statusOf(await repository().status()), MasterKeyStatus.ready);
  });
}
