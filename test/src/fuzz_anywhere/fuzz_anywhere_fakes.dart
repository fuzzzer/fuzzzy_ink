import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:mocktail/mocktail.dart';

/// Fakes shared by the "Lock from other apps" tests: the real lock store,
/// Lock flow, Open flow, settings cubit and repository, over mocked storage
/// and a mocked core.

class MockCrypto extends Mock implements CryptoCoreService {}

class MockChats extends Mock implements ChatGeneralDataListRepository {}

class MockMessages extends Mock implements MessageDataRepository {}

class MockUserFiles extends Mock implements UserFileStore {}

class MockChatAuth extends Mock implements ChatAuthRepository {}

class MockBiometrics extends Mock implements BiometricAuthRepository {}

class MockThrottle extends Mock implements AppLockThrottleRepository {}

class MockReset extends Mock implements AppResetRepository {}

class MockSendQueue extends MockCubit<FileProcessingState>
    implements FileProcessingCubit<FileEncryptionOption> {}

class MockReceiveQueue extends MockCubit<FileProcessingState>
    implements FileProcessingCubit<FileDecryptionOption> {}

/// The secure storage, in memory: holds only what the repository wrote.
class MemoryAnywhereStorage implements FuzzAnywhereLocalDataSource {
  final blobs = <String, Uint8List>{};

  @override
  Future<Uint8List?> read(String key) async => blobs[key];

  @override
  Future<void> write(String key, Uint8List sealed) async => blobs[key] = sealed;

  @override
  Future<void> delete(String key) async => blobs.remove(key);
}

const ninoId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';
const momId = '0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d';
const rightPassword = 'violet-harbor-lantern-91';

/// What the person wrote, and what an opened message says: never to be
/// seen in anything answered to another app.
const secretText = 'meet me at the bridge at six';
const openedSecret = 'the key is under the blue pot';

/// A message for this phone from Nino (a stand-in blob; the core is a mock).
const blobFromNino = 'Fuzz/AwECbmlubw';
const lockedBlob = 'Fuzz/AwECc2VhbGVk';

final nino = ChatGeneralData(
  chatId: ninoId,
  chatName: 'Nino',
  setupStatus: ChatSetupStatus.connected,
  didAcceptInvitation: false,
);
final mom = ChatGeneralData(
  chatId: momId,
  chatName: 'Mom',
  setupStatus: ChatSetupStatus.invited,
  didAcceptInvitation: false,
);

MessageData fallbackRow() => MessageData(
      id: 0,
      chatId: ninoId,
      type: MessageType.text,
      encryptedMessage: '',
      decryptedMessage: '',
      sentAt: DateTime(2026),
      isSent: false,
    );

void registerAnywhereFallbacks() {
  registerFallbackValue(fallbackRow());
  registerFallbackValue(AppLockThrottleData.none);
  registerFallbackValue(BiometricScope.chat);
  registerFallbackValue(Uint8List(0));
}

/// The stand-in seal: a name tag, then the bytes scrambled. Only the mocked
/// core opens it, and only under the same name.
Uint8List fakeSeal(String name, Uint8List bytes) => Uint8List.fromList([
      ...utf8.encode('sealed:$name:'),
      for (final byte in bytes) byte ^ 0x5A,
    ]);

Uint8List? fakeOpen(String name, Uint8List blob) {
  final tag = utf8.encode('sealed:$name:');
  if (blob.length < tag.length) return null;
  for (var i = 0; i < tag.length; i++) {
    if (blob[i] != tag[i]) return null;
  }
  return Uint8List.fromList([
    for (final byte in blob.skip(tag.length)) byte ^ 0x5A,
  ]);
}

/// One app with "Lock from other apps" around it: the real
/// [FuzzyAuthStore], [FuzzAnywhereSettingsCubit], repository, Lock and Open
/// flows, over mocks.
class AnywhereHarness {
  AnywhereHarness({DateTime Function()? now, String lockedOutput = lockedBlob})
      : _now = now ?? (() => DateTime(2026, 10, 26, 22)) {
    _stubCore(lockedOutput);
    _stubLock();
    _stubPeople();
    _stubHistory();
    authStore = FuzzyAuthStore(
      chatAuthRepository: chatAuth,
      biometricAuthRepository: biometrics,
      cryptoCoreService: crypto,
      appLockThrottleRepository: throttle,
      appResetRepository: MockReset(),
      now: _now,
    );
    repository = FuzzAnywhereSettingsRepository(
      localDataSource: storage,
      cryptoCoreService: crypto,
    );
    settings = FuzzAnywhereSettingsCubit(repository: repository);
    service = FuzzAnywhereService(
      authStore: authStore,
      settings: settings,
      settingsRepository: repository,
      biometricAuthRepository: biometrics,
      cryptoCoreService: crypto,
      chatRepository: chats,
      lockFlow: (chat) => LockFlowCubit(
        target: LockTarget.person(chat),
        cryptoCoreService: crypto,
        messageDataRepository: messages,
        userFileStore: userFiles,
        passwordStrengthService: PasswordStrengthService(),
        chatFileQueue: sendQueue,
      ),
      openFlow: () => OpenFlowCubit(
        cryptoCoreService: crypto,
        chatRepository: chats,
        messageDataRepository: messages,
        userFileStore: userFiles,
        receiveQueue: receiveQueue,
      ),
      display: (payload) {
        shown.add(payload);
        return (displayClosed = Completer<void>()).future;
      },
      presentOpen: (payload) async => presented.add(payload),
      keepSealedCopyAtLock: () => keptAtLock++,
      copySealed: (text, content) async {
        copies.add((text, content));
        return true;
      },
      now: _now,
    );
  }

  final DateTime Function() _now;
  final crypto = MockCrypto();
  final chats = MockChats();
  final messages = MockMessages();
  final userFiles = MockUserFiles();
  final chatAuth = MockChatAuth();
  final biometrics = MockBiometrics();
  final throttle = MockThrottle();
  final sendQueue = MockSendQueue();
  final receiveQueue = MockReceiveQueue();
  final storage = MemoryAnywhereStorage();
  final _added = StreamController<NewMessageAdded>.broadcast();

  late final FuzzyAuthStore authStore;
  late final FuzzAnywhereSettingsRepository repository;
  late final FuzzAnywhereSettingsCubit settings;
  late final FuzzAnywhereService service;

  /// History rows written, in order.
  final rows = <MessageData>[];

  /// What [FuzzAnywhereService.show] put on the private screen.
  final shown = <HistoryItemPagePayload>[];
  Completer<void>? displayClosed;

  /// What [FuzzAnywhereService.openInApp] handed to the Open screen.
  final presented = <OpenPagePayload>[];

  /// What went to the copy guard.
  final copies = <(String, CopyContent)>[];

  /// How often a relock asked the copy guard to keep the sealed copy.
  int keptAtLock = 0;

  AppLockThrottleData throttleData = AppLockThrottleData.none;

  /// The switch as it would be sealed in the store, before the app reads
  /// it.
  void storeSettings(FuzzAnywhereSettings value) {
    storage.blobs[FuzzAnywhereLocalDataSource.settingsKey] = fakeSeal(
      FuzzAnywhereSettingsRepository.settingsName,
      Uint8List.fromList(utf8.encode(jsonEncode(value.toJson()))),
    );
  }

  /// Boots the lock store (locked: a master password exists).
  Future<void> boot() => authStore.checkAuthStatus();

  /// The person unlocks inside the app (not through another app).
  Future<void> unlockInApp() => authStore.unlock(rightPassword);

  Future<void> dispose() async {
    await service.dispose();
    await settings.close();
    await authStore.close();
    await _added.close();
  }

  void _stubCore(String lockedOutput) {
    when(crypto.close).thenAnswer((_) async => const CryptoCoreSuccess(null));
    when(
      () => crypto.sealSetting(
        name: any(named: 'name'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer((call) async {
      final name = call.namedArguments[#name] as String;
      final bytes = call.namedArguments[#bytes] as Uint8List;
      return CryptoCoreSuccess(fakeSeal(name, bytes));
    });
    when(
      () => crypto.openSetting(
        name: any(named: 'name'),
        blob: any(named: 'blob'),
      ),
    ).thenAnswer((call) async {
      final opened = fakeOpen(
        call.namedArguments[#name] as String,
        call.namedArguments[#blob] as Uint8List,
      );
      return opened == null
          ? const CryptoCoreFailure(CryptoCoreFailureType.corrupt)
          : CryptoCoreSuccess(opened);
    });
    when(() => crypto.isVerified(ninoId))
        .thenAnswer((_) async => const CryptoCoreSuccess(true));
    when(
      () => crypto.encryptText(
        chatId: any(named: 'chatId'),
        text: any(named: 'text'),
      ),
    ).thenAnswer((_) async => CryptoCoreSuccess(lockedOutput));
    when(
      () => crypto.peekPasted(
        text: any(named: 'text'),
        chatIds: any(named: 'chatIds'),
      ),
    ).thenAnswer((call) async {
      final text = call.namedArguments[#text] as String;
      return CryptoCoreSuccess(
        text == blobFromNino
            ? const CryptoCorePeek(
                kind: CryptoCorePeekKind.message,
                chatId: ninoId,
              )
            : const CryptoCorePeek(kind: CryptoCorePeekKind.notFuzzzy),
      );
    });
    when(() => crypto.decryptText(chatId: ninoId, blob: blobFromNino))
        .thenAnswer((_) async => const CryptoCoreSuccess(openedSecret));
  }

  void _stubLock() {
    when(chatAuth.status).thenAnswer(
      (_) async => const CryptoCoreSuccess(MasterKeyStatus.ready),
    );
    when(() => chatAuth.unlock(any())).thenAnswer(
      (call) async => call.positionalArguments[0] == rightPassword
          ? const CryptoCoreSuccess(null)
          : const CryptoCoreFailure(CryptoCoreFailureType.wrongPassword),
    );
    when(() => biometrics.discardOutdatedCopy(any()))
        .thenAnswer((_) async => false);
    when(() => biometrics.isEnabled(any())).thenAnswer((_) async => true);
    when(biometrics.canUseBiometrics).thenAnswer((_) async => true);
    when(biometrics.biometricKind).thenAnswer((_) async => BiometricKind.other);
    when(() => biometrics.readPassword(BiometricScope.chat))
        .thenAnswer((_) async => const BiometricPassword(rightPassword));
    when(() => biometrics.disable(any())).thenAnswer((_) async {});
    when(throttle.read).thenAnswer((_) async => throttleData);
    when(() => throttle.save(any())).thenAnswer((call) async {
      throttleData = call.positionalArguments[0] as AppLockThrottleData;
    });
    when(throttle.clear).thenAnswer((_) async {
      throttleData = AppLockThrottleData.none;
    });
  }

  void _stubPeople() {
    when(chats.getAllChats).thenAnswer((_) async => [nino, mom]);
    when(() => chats.getChatById(ninoId)).thenAnswer((_) async => nino);
    when(() => chats.getChatById(momId)).thenAnswer((_) async => mom);
    when(() => chats.getChatById(any(that: isNot(anyOf(ninoId, momId)))))
        .thenAnswer((_) async => null);
  }

  void _stubHistory() {
    when(() => messages.newMessageUpdates).thenAnswer((_) => _added.stream);
    when(() => messages.addMessage(any(), notifyListeners: true))
        .thenAnswer((call) async {
      rows.add(call.positionalArguments[0] as MessageData);
      return 40 + rows.length;
    });
    when(() => sendQueue.state).thenReturn(const FileProcessingState());
    when(() => receiveQueue.state).thenReturn(const FileProcessingState());
    when(() => userFiles.discardPickedCopy(any())).thenAnswer((_) async {});
  }
}
