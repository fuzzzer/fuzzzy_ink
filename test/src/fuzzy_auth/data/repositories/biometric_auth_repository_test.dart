import 'package:biometric_storage/biometric_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';

class _FakeStorageFile extends Fake implements BiometricStorageFile {
  _FakeStorageFile(this.name, {this.failDelete = false});

  @override
  final String name;
  bool failDelete;
  final List<String> calls = [];
  String? value;
  Exception? readError;
  Exception? writeError;

  @override
  Future<String?> read({PromptInfo? promptInfo}) async {
    calls.add('read');
    if (readError != null) throw readError!;
    return value;
  }

  @override
  Future<void> write(String content, {PromptInfo? promptInfo}) async {
    calls.add('write');
    if (writeError != null) throw writeError!;
    value = content;
  }

  @override
  Future<void> delete({PromptInfo? promptInfo}) async {
    calls.add('delete');
    if (failDelete) throw Exception('keystore busy');
  }
}

class _FakeBiometricStorage extends Fake implements BiometricStorage {
  _FakeBiometricStorage({this.failDelete = false});

  final bool failDelete;
  final Map<String, _FakeStorageFile> files = {};
  final List<StorageFileInitOptions?> options = [];

  @override
  Future<BiometricStorageFile> getStorage(
    String name, {
    StorageFileInitOptions? options,
    bool forceInit = false,
    PromptInfo promptInfo = PromptInfo.defaultValues,
  }) async {
    this.options.add(options);
    return files.putIfAbsent(
      name,
      () => _FakeStorageFile(name, failDelete: failDelete),
    );
  }
}

/// Biometric copies are read with a prompt every time, strong biometrics
/// only; an Android copy made under the old settings is dropped once
/// (security review 2026-10-22, item 2).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const flag = 'biometric_enabled_chat';
  const version = 'biometric_key_version_chat';
  const legacyName = 'fuzzy_biometric_password_chat';

  late _FakeBiometricStorage biometricStorage;
  late BiometricAuthRepository repository;

  Future<String?> secure(String key) => const FlutterSecureStorage().read(
        key: key,
      );

  void build(Map<String, String> secureValues, {bool failDelete = false}) {
    FlutterSecureStorage.setMockInitialValues(secureValues);
    biometricStorage = _FakeBiometricStorage(failDelete: failDelete);
    repository = BiometricAuthRepository(biometricStorage: biometricStorage);
  }

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('the storage asks every time, for strong biometrics only', () {
    final options = BiometricAuthRepository.storageOptions;
    expect(options.authenticationValidityDurationSeconds, -1);
    expect(options.androidBiometricOnly, isTrue);
    expect(options.darwinBiometricOnly, isTrue);
    expect(options.authenticationRequired, isTrue);
  });

  group('on Android', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);

    test('an old copy is dropped once: off, file and key deleted', () async {
      build({flag: 'true'});

      expect(await repository.discardOutdatedCopy(BiometricScope.chat), isTrue);
      expect(await secure(flag), isNull);
      expect(biometricStorage.files[legacyName]!.calls, ['delete']);
      expect(
        biometricStorage.options.single,
        BiometricAuthRepository.storageOptions,
      );

      expect(
        await repository.discardOutdatedCopy(BiometricScope.chat),
        isFalse,
      );
      expect(await repository.isEnabled(BiometricScope.chat), isFalse);
    });

    test('isEnabled drops an old copy too (the vault reads only this)',
        () async {
      build({'biometric_enabled_vault': 'true'});

      expect(await repository.isEnabled(BiometricScope.vault), isFalse);
      expect(
        biometricStorage.files['fuzzy_biometric_password_vault']!.calls,
        ['delete'],
      );
    });

    test('the copy is dropped even when deleting the old file fails', () async {
      build({flag: 'true'}, failDelete: true);

      expect(await repository.discardOutdatedCopy(BiometricScope.chat), isTrue);
      expect(await repository.isEnabled(BiometricScope.chat), isFalse);
    });

    test(
        'a failed delete of the old copy is tried again at the next start '
        'until it succeeds; the notice still shows only once', () async {
      const cleanup = 'biometric_legacy_cleanup_chat';
      build({flag: 'true'}, failDelete: true);

      expect(await repository.discardOutdatedCopy(BiometricScope.chat), isTrue);
      expect(await secure(flag), isNull);
      expect(await secure(cleanup), 'true');
      final legacy = biometricStorage.files[legacyName]!;
      expect(legacy.calls, ['delete']);

      // Next start: the delete fails again and stays pending.
      expect(
        await repository.discardOutdatedCopy(BiometricScope.chat),
        isFalse,
      );
      expect(legacy.calls, ['delete', 'delete']);
      expect(await secure(cleanup), 'true');

      // The start after that: it succeeds, and nothing more is tried.
      legacy.failDelete = false;
      expect(await repository.isEnabled(BiometricScope.chat), isFalse);
      expect(legacy.calls, ['delete', 'delete', 'delete']);
      expect(await secure(cleanup), isNull);

      expect(
        await repository.discardOutdatedCopy(BiometricScope.chat),
        isFalse,
      );
      expect(legacy.calls, hasLength(3));
    });

    test('a copy made under the current settings is kept', () async {
      build({flag: 'true', version: biometricKeyVersion});

      expect(await repository.isEnabled(BiometricScope.chat), isTrue);
      expect(biometricStorage.files, isEmpty);
    });

    test('nothing happens while biometrics are off', () async {
      build({});

      expect(
        await repository.discardOutdatedCopy(BiometricScope.chat),
        isFalse,
      );
      expect(biometricStorage.files, isEmpty);
    });

    test('enabling writes under a new name, so no old key is ever reused',
        () async {
      build({});

      await repository.enable(BiometricScope.chat, 'pw');

      expect(
        biometricStorage.files.keys,
        ['fuzzy_biometric_password_v2_chat'],
      );
      expect(
        biometricStorage.files.values.single.calls,
        ['write'],
      );
      expect(await secure(flag), 'true');
      expect(await secure(version), biometricKeyVersion);
      expect(await repository.isEnabled(BiometricScope.chat), isTrue);
    });
  });

  group('on iOS and macOS', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
      test(
          '${platform.name}: an old copy was already biometric-only and is '
          'kept, under its old name', () async {
        debugDefaultTargetPlatformOverride = platform;
        build({flag: 'true'});

        expect(
          await repository.discardOutdatedCopy(BiometricScope.chat),
          isFalse,
        );
        expect(await secure(version), biometricKeyVersion);
        expect(await repository.isEnabled(BiometricScope.chat), isTrue);
        expect(biometricStorage.files, isEmpty);

        await repository.enable(BiometricScope.chat, 'pw');
        expect(biometricStorage.files.keys, [legacyName]);
      });
    }
  });

  group('reading the copy', () {
    const v2Name = 'fuzzy_biometric_password_v2_chat';

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      build({flag: 'true', version: biometricKeyVersion});
    });

    _FakeStorageFile file() => biometricStorage.files.putIfAbsent(
          v2Name,
          () => _FakeStorageFile(v2Name),
        );

    test('a stored password comes back', () async {
      file().value = 'pw';
      final read = await repository.readPassword(BiometricScope.chat);
      expect(read, isA<BiometricPassword>());
      expect((read as BiometricPassword).password, 'pw');
    });

    test('no copy (the plugin deleted an invalidated key) is "gone"', () async {
      file();
      expect(
        await repository.readPassword(BiometricScope.chat),
        isA<BiometricCopyGone>(),
      );
    });

    for (final error in <Exception>[
      AuthException(AuthExceptionCode.userCanceled, 'cancel'),
      AuthException(AuthExceptionCode.unknown, 'Too many attempts'),
      PlatformException(code: 'SecurityError'),
    ]) {
      test('$error is "not read" and keeps the setting', () async {
        file().readError = error;
        expect(
          await repository.readPassword(BiometricScope.chat),
          isA<BiometricNotRead>(),
        );
        expect(await secure(flag), 'true');
      });
    }
  });

  group('turning biometrics on fails plainly', () {
    const v2Name = 'fuzzy_biometric_password_v2_chat';

    Future<BiometricEnableResult> enableWith(
      Exception error,
      TargetPlatform platform,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      build({});
      final name = platform == TargetPlatform.android ? v2Name : legacyName;
      biometricStorage.files[name] = _FakeStorageFile(name)..writeError = error;
      return repository.enable(BiometricScope.chat, 'pw');
    }

    test('a cancelled prompt is "cancelled" and enables nothing', () async {
      expect(
        await enableWith(
          AuthException(AuthExceptionCode.userCanceled, 'cancel'),
          TargetPlatform.android,
        ),
        BiometricEnableResult.cancelled,
      );
      expect(await secure(flag), isNull);
    });

    test('Android cannot make a strong-biometric key: "not strong enough"',
        () async {
      expect(
        await enableWith(
          PlatformException(
            code: 'Unexpected Error',
            message: 'At least one biometric must be enrolled to create keys '
                'requiring user authentication for every use',
          ),
          TargetPlatform.android,
        ),
        BiometricEnableResult.notStrongEnough,
      );
      expect(await secure(flag), isNull);
    });

    test('a prompt error other than cancel is "failed"', () async {
      expect(
        await enableWith(
          AuthException(AuthExceptionCode.unknown, 'lockout'),
          TargetPlatform.android,
        ),
        BiometricEnableResult.failed,
      );
    });

    test('the same storage error on iOS is "failed"', () async {
      expect(
        await enableWith(
          PlatformException(code: 'SecurityError'),
          TargetPlatform.iOS,
        ),
        BiometricEnableResult.failed,
      );
    });
  });
}
