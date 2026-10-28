import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:mocktail/mocktail.dart';

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// The app's keychain items live under their own service; what earlier
/// builds left under the plugin's shared default service is only a
/// leftover: noticed, removed where the system allows, and never in the way
/// of a fresh start (QA 2026-10-26: "Your keys could not be created").
void main() {
  late MockSecureStorage own;
  late MockSecureStorage legacy;
  late MasterKeyLocalDataSource dataSource;

  setUp(() {
    own = MockSecureStorage();
    legacy = MockSecureStorage();
    dataSource =
        MasterKeyLocalDataSource(secureStorage: own, legacyStorage: legacy);
    when(() => own.deleteAll()).thenAnswer((_) async {});
    when(() => own.containsKey(key: any(named: 'key')))
        .thenAnswer((_) async => false);
    when(() => legacy.containsKey(key: any(named: 'key')))
        .thenAnswer((_) async => false);
    when(() => legacy.delete(key: any(named: 'key'))).thenAnswer((_) async {});
    when(() => own.delete(key: any(named: 'key'))).thenAnswer((_) async {});
  });

  test('the app keeps its keys under its own keychain service', () {
    expect(secureStorageService, isNot(AppleOptions.defaultAccountName));
    expect(
      secureStorageIosOptions.toMap()['accountName'],
      secureStorageService,
    );
    expect(
      secureStorageMacOsOptions.toMap()['accountName'],
      secureStorageService,
    );
    expect(
      legacySecureStorageMacOsOptions.toMap()['accountName'],
      AppleOptions.defaultAccountName,
    );
  });

  test(
      'erase removes every own entry, then the old leftovers that are there '
      'one by one, never with a wildcard on the shared service', () async {
    when(
      () => legacy.containsKey(key: MasterKeyLocalDataSource.legacyStoreKeyKey),
    ).thenAnswer((_) async => true);
    await dataSource.deleteAll();
    verify(() => own.deleteAll()).called(1);
    verify(
      () => legacy.delete(key: MasterKeyLocalDataSource.legacyStoreKeyKey),
    ).called(1);
    verifyNever(
      () => legacy.delete(key: MasterKeyLocalDataSource.storeWrapKey),
    );
    verifyNever(() => legacy.deleteAll());
  });

  test('a leftover this build may not remove does not stop a fresh start',
      () async {
    when(
      () => legacy.containsKey(key: MasterKeyLocalDataSource.legacyStoreKeyKey),
    ).thenAnswer((_) async => true);
    when(() => legacy.delete(key: MasterKeyLocalDataSource.legacyStoreKeyKey))
        .thenThrow(
      PlatformException(code: 'Unexpected security result code'),
    );
    await expectLater(dataSource.deleteAll(), completes);
  });

  test(
      'a development Mac refuses the wildcard delete (no keychain '
      'entitlement, -34018): each entry that is there is deleted instead',
      () async {
    when(() => own.deleteAll()).thenThrow(
      PlatformException(
        code: 'Unexpected security result code',
        message: 'Code: -34018',
      ),
    );
    when(() => own.containsKey(key: MasterKeyLocalDataSource.passwordWrapKey))
        .thenAnswer((_) async => true);
    await expectLater(dataSource.deleteAll(), completes);
    verify(() => own.delete(key: MasterKeyLocalDataSource.passwordWrapKey))
        .called(1);
    verifyNever(() => own.delete(key: MasterKeyLocalDataSource.storeWrapKey));
  });

  test(
      'a refused wildcard delete still removes the sealed "Lock from other '
      'apps" settings', () async {
    when(() => own.deleteAll()).thenThrow(
      PlatformException(code: 'Unexpected security result code'),
    );
    for (final key in [
      FuzzAnywhereLocalDataSource.settingsKey,
      FuzzAnywhereLocalDataSource.appPeopleKey,
    ]) {
      when(() => own.containsKey(key: key)).thenAnswer((_) async => true);
    }
    await expectLater(dataSource.deleteAll(), completes);
    verify(() => own.delete(key: FuzzAnywhereLocalDataSource.settingsKey))
        .called(1);
    verify(() => own.delete(key: FuzzAnywhereLocalDataSource.appPeopleKey))
        .called(1);
  });

  test('an own entry that is there but cannot be removed fails the erase',
      () async {
    when(() => own.deleteAll()).thenThrow(
      PlatformException(code: 'Unexpected security result code'),
    );
    when(() => own.containsKey(key: MasterKeyLocalDataSource.passwordWrapKey))
        .thenAnswer((_) async => true);
    when(() => own.delete(key: MasterKeyLocalDataSource.passwordWrapKey))
        .thenThrow(PlatformException(code: 'Unexpected security result code'));
    await expectLater(
      dataSource.deleteAll(),
      throwsA(isA<PlatformException>()),
    );
  });

  test('a key an earlier build kept under the old service is a leftover',
      () async {
    expect(await dataSource.hasLegacyKey(), isFalse);
    when(
      () => legacy.containsKey(
        key: MasterKeyLocalDataSource.passwordWrapKey,
      ),
    ).thenAnswer((_) async => true);
    expect(await dataSource.hasLegacyKey(), isTrue);
  });
}
