import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockChatGeneralDataLocalDataSource extends Mock
    implements ChatGeneralDataLocalDataSource {}

class MockCryptoCoreService extends Mock implements CryptoCoreService {}

class MockMessageDataRepository extends Mock implements MessageDataRepository {}

class MockUserFileStore extends Mock implements UserFileStore {}

class MockAppResetLocalDataSource extends Mock
    implements AppResetLocalDataSource {}

class MockMasterKeyLocalDataSource extends Mock
    implements MasterKeyLocalDataSource {}

class MockBiometricAuthRepository extends Mock
    implements BiometricAuthRepository {}

StoredChatGeneralData _waitingPerson() => StoredChatGeneralData()
  ..chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d'
  ..chatName = 'Tamar'
  ..setupStatus = ChatSetupStatus.invited
  ..didAcceptInvitation = false;

/// Erase everything from the lock screen, then a new first run: Home must
/// not list the erased person until the app restarts (Georgian pass, shot
/// 27). The people list is held in memory by this cubit for the whole run.
void main() {
  late MockChatGeneralDataLocalDataSource chatStorage;
  late MockCryptoCoreService cryptoCoreService;
  late ChatGeneralDataListCubit cubit;
  late AppResetRepository appResetRepository;
  late List<StoredChatGeneralData> stored;
  late MockAppResetLocalDataSource resetStorage;

  setUpAll(() {
    registerFallbackValue(BiometricScope.chat);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    stored = [_waitingPerson()];
    chatStorage = MockChatGeneralDataLocalDataSource();
    when(() => chatStorage.getAllChats()).thenAnswer((_) async => stored);
    cryptoCoreService = MockCryptoCoreService();
    when(() => cryptoCoreService.close())
        .thenAnswer((_) async => const CryptoCoreSuccess(null));

    cubit = ChatGeneralDataListCubit(
      chatRepository: ChatGeneralDataListRepository(
        localDataSource: chatStorage,
        pairedAcceptanceDataSource: PairedAcceptanceLocalDataSource(
          prefs: await SharedPreferences.getInstance(),
        ),
      ),
      cryptoCoreService: cryptoCoreService,
      messageDataRepository: MockMessageDataRepository(),
      userFileStore: MockUserFileStore(),
    );

    resetStorage = MockAppResetLocalDataSource();
    when(resetStorage.clearDatabase).thenAnswer((_) async => stored = []);
    when(resetStorage.deleteChatStates).thenAnswer((_) async {});
    when(resetStorage.deleteVault).thenAnswer((_) async {});
    when(resetStorage.deleteSealedFiles).thenAnswer((_) async {});
    when(resetStorage.wipePlainCopies).thenAnswer((_) async {});
    when(
      () => resetStorage.clearPreferences(
        keepFirstRunChoices: any(named: 'keepFirstRunChoices'),
      ),
    ).thenAnswer((_) async {});
    final masterKeys = MockMasterKeyLocalDataSource();
    when(masterKeys.deleteAll).thenAnswer((_) async {});
    final biometrics = MockBiometricAuthRepository();
    when(() => biometrics.disable(any())).thenAnswer((_) async {});
    appResetRepository = AppResetRepository(
      localDataSource: resetStorage,
      masterKeyLocalDataSource: masterKeys,
      biometricAuthRepository: biometrics,
      cryptoCoreService: cryptoCoreService,
    );
  });

  tearDown(() => cubit.close());

  test('after Erase everything the people list is empty at once', () async {
    await cubit.fetchChats();
    expect(cubit.state.chatList, hasLength(1));

    final eraseRes = await appResetRepository.eraseEverything();
    expect(eraseRes, isA<CryptoCoreSuccess<void>>());
    await pumpEventQueue();

    expect(cubit.state.status, StateStatus.success);
    expect(cubit.state.chatList, isEmpty);
    expect(cubit.state.unverifiedChatIds, isEmpty);
    expect(cubit.state.actionStatus, StateStatus.initial);
  });

  test('an erase that fails part way still empties the list it cleared',
      () async {
    await cubit.fetchChats();
    when(resetStorage.deleteVault).thenThrow(const FileSystemException('x'));

    final eraseRes = await appResetRepository.eraseEverything();
    expect(eraseRes, isA<CryptoCoreFailure<void>>());
    await pumpEventQueue();

    expect(cubit.state.chatList, isEmpty);
  });
}
