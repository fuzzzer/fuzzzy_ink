import 'dart:io';

import 'package:fuzzzy_seal/lib.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DependencyInjection {
  static Future<void> inject() async {
    late final Directory documentsDirectory;
    late final Directory supportDirectory;

    late final SharedPreferences prefs;

    await Future.wait<void>([
      (() async =>
          documentsDirectory = await getApplicationDocumentsDirectory())(),
      (() async => supportDirectory = await getApplicationSupportDirectory())(),
      (() async => prefs = await SharedPreferences.getInstance())(),
    ]);

    sl.safeRegisterSingleton<PreferencesService>(PreferencesService(prefs));

    sl.safeRegisterSingleton<AppDocumentsDirectory>(
      AppDocumentsDirectory(
        directory: documentsDirectory,
      ),
    );

    sl.safeRegisterSingleton<AppSupportDirectory>(
      AppSupportDirectory(
        directory: supportDirectory,
      ),
    );

    final isar = await Isar.open(
      [
        StoredChatGeneralDataSchema,
        StoredChatPreferencesSchema,
        StoredMessageDataSchema,
        StoredUserAuthPreferencesSchema,
        StoredVaultItemSchema,
        StoredVaultGroupSchema,
        StoredVaultMetadataSchema,
      ],
      directory: supportDirectory.path,
    );

    sl.safeRegisterSingleton<Isar>(isar);

    sl.safeRegisterSingleton<FuzzyLinkService>(FuzzyLinkService());

    sl.safeRegisterSingleton<UserFileStore>(UserFileStore());

    sl.safeRegisterSingleton<UserAuthPreferencesRepository>(
      UserAuthPreferencesRepository(
        localDataSource: UserAuthPreferencesLocalDataSource(isar: sl.get()),
      ),
    );

    sl.safeRegisterSingleton<CryptoCoreService>(
      CryptoCoreService(
        storeDirectoryPath: sl.get<AppSupportDirectory>().directory.path,
      ),
    );

    sl.safeRegisterSingleton<CryptoStoreKeyRepository>(
      CryptoStoreKeyRepository(
        cryptoCoreService: sl.get<CryptoCoreService>(),
      ),
    );

    sl.safeRegisterSingleton<ChatAuthRepository>(
      ChatAuthRepository(
        userAuthPreferencesRepository: sl.get<UserAuthPreferencesRepository>(),
        cryptoStoreKeyRepository: sl.get<CryptoStoreKeyRepository>(),
        cryptoCoreService: sl.get<CryptoCoreService>(),
      ),
    );

    sl.safeRegisterSingleton<BiometricAuthRepository>(
      BiometricAuthRepository(),
    );

    sl.safeRegisterSingleton<FuzzyAuthStore>(
      FuzzyAuthStore(
        chatAuthRepository: sl.get<ChatAuthRepository>(),
        biometricAuthRepository: sl.get<BiometricAuthRepository>(),
        cryptoStoreKeyRepository: sl.get<CryptoStoreKeyRepository>(),
        cryptoCoreService: sl.get<CryptoCoreService>(),
      ),
    );

    sl.safeRegisterSingleton<ChatGeneralDataListRepository>(
      ChatGeneralDataListRepository(
        localDataSource: ChatGeneralDataLocalDataSource(isar: sl.get()),
      ),
    );

    sl.safeRegisterSingleton<MessageDataRepository>(
      MessageDataRepository(
        localDataSource: MessageDataLocalDataSource(isar: sl.get()),
        cryptoCoreService: sl.get<CryptoCoreService>(),
      ),
    );

    sl.safeRegisterSingleton<ChatArchiveRepository>(
      ChatArchiveRepository(
        messageDataRepository: sl.get<MessageDataRepository>(),
        cryptoCoreService: sl.get<CryptoCoreService>(),
        workingDirectoryPath: sl.get<AppSupportDirectory>().directory.path,
      ),
    );

    sl.safeRegisterSingleton<FuzzyLinkHandler>(
      FuzzyLinkHandler(
        linkService: sl.get<FuzzyLinkService>(),
        chatRepository: sl.get<ChatGeneralDataListRepository>(),
        authStore: sl.get<FuzzyAuthStore>(),
        cryptoCoreService: sl.get<CryptoCoreService>(),
      ),
    );

    // Vault Dependencies
    sl.safeRegisterSingleton<PasswordStrengthService>(
      PasswordStrengthService(),
    );

    sl.safeRegisterSingleton<VaultFileDataSource>(
      VaultFileDataSource(
        vaultDirectoryPath: sl.get<AppDocumentsDirectory>().directory.path,
      ),
    );

    sl.safeRegisterSingleton<VaultItemLocalDataSource>(
      VaultItemLocalDataSource(isar: sl.get<Isar>()),
    );

    sl.safeRegisterSingleton<VaultGroupLocalDataSource>(
      VaultGroupLocalDataSource(isar: sl.get<Isar>()),
    );

    sl.safeRegisterSingleton<VaultCryptoRepository>(
      VaultCryptoRepository(
        passwordStrengthService: sl.get<PasswordStrengthService>(),
        cryptoCoreService: sl.get<CryptoCoreService>(),
      ),
    );

    sl.safeRegisterSingleton<VaultRepository>(
      VaultRepository(
        itemDataSource: sl.get<VaultItemLocalDataSource>(),
        groupDataSource: sl.get<VaultGroupLocalDataSource>(),
        fileDataSource: sl.get<VaultFileDataSource>(),
        cryptoRepository: sl.get<VaultCryptoRepository>(),
      ),
    );

    sl.safeRegisterSingleton<VaultExportRepository>(
      VaultExportRepository(
        fileDataSource: sl.get<VaultFileDataSource>(),
        itemDataSource: sl.get<VaultItemLocalDataSource>(),
        groupDataSource: sl.get<VaultGroupLocalDataSource>(),
      ),
    );

    // Vault Cubits
    sl.safeRegisterSingleton<VaultAuthCubit>(
      VaultAuthCubit(
        vaultRepository: sl.get<VaultRepository>(),
        cryptoRepository: sl.get<VaultCryptoRepository>(),
        biometricAuthRepository: sl.get<BiometricAuthRepository>(),
      ),
    );

    sl.registerFactory<VaultItemsCubit>(
      () => VaultItemsCubit(
        vaultRepository: sl.get<VaultRepository>(),
      ),
    );

    sl.registerFactory<VaultGroupsCubit>(
      () => VaultGroupsCubit(
        vaultRepository: sl.get<VaultRepository>(),
      ),
    );

    sl.registerFactory<VaultSearchCubit>(
      () => VaultSearchCubit(
        vaultRepository: sl.get<VaultRepository>(),
      ),
    );

    sl.registerFactory<VaultExportCubit>(
      () => VaultExportCubit(
        exportRepository: sl.get<VaultExportRepository>(),
      ),
    );
  }
}
