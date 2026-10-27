import 'dart:io';

import 'package:fuzzzy_ink/lib.dart';
import 'package:isar_community/isar.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DependencyInjection {
  static Future<void> inject() async {
    late final Directory documentsDirectory;
    late final Directory supportDirectory;
    late final Directory temporaryDirectory;

    late final SharedPreferences prefs;
    late final PackageInfo packageInfo;

    await Future.wait<void>([
      (() async =>
          documentsDirectory = await getApplicationDocumentsDirectory())(),
      (() async => supportDirectory = await getApplicationSupportDirectory())(),
      (() async => temporaryDirectory = await getTemporaryDirectory())(),
      (() async => prefs = await SharedPreferences.getInstance())(),
      (() async => packageInfo = await PackageInfo.fromPlatform())(),
    ]);

    sl.safeRegisterSingleton<PackageInfo>(packageInfo);

    sl.safeRegisterSingleton<PreferencesService>(PreferencesService(prefs));
    // Settings → Copy passwords, as the person left it.
    vaultPasswordCopySetting.value =
        sl.get<PreferencesService>().vaultPasswordCopy;

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

    // After an erase, the database is copied compacted so the pages the
    // erase freed leave the file (security review 2026-10-26).
    final compactMarker =
        AppResetLocalDataSource.compactMarkerIn(supportDirectory.path);
    final compactNow = await compactMarker.exists();
    final isar = await Isar.open(
      [
        StoredChatGeneralDataSchema,
        StoredMessageDataSchema,
        StoredVaultItemSchema,
        StoredVaultGroupSchema,
        StoredVaultMetadataSchema,
      ],
      directory: supportDirectory.path,
      compactOnLaunch:
          compactNow ? const CompactCondition(minFileSize: 0) : null,
    );
    if (compactNow) await compactMarker.delete();

    sl.safeRegisterSingleton<Isar>(isar);

    sl.safeRegisterSingleton<FuzzyLinkService>(FuzzyLinkService());

    // Plain copies a previous run left behind are wiped before anything
    // can be unfuzzed again.
    final userFileStore = UserFileStore(
      supportDirectoryPath: supportDirectory.path,
      temporaryDirectoryPath: temporaryDirectory.path,
      documentsDirectoryPath: documentsDirectory.path,
    );
    await userFileStore.wipeTemporaryPlainCopies();
    sl.safeRegisterSingleton<UserFileStore>(userFileStore);

    sl.safeRegisterSingleton<CryptoCoreService>(
      CryptoCoreService(
        storeDirectoryPath: sl.get<AppSupportDirectory>().directory.path,
      ),
    );

    sl.safeRegisterSingleton<MasterKeyLocalDataSource>(
      MasterKeyLocalDataSource(),
    );

    sl.safeRegisterSingleton<ChatAuthRepository>(
      ChatAuthRepository(
        localDataSource: sl.get<MasterKeyLocalDataSource>(),
        cryptoCoreService: sl.get<CryptoCoreService>(),
        storeExists: () => Directory(
          '${sl.get<AppSupportDirectory>().directory.path}'
          '${Platform.pathSeparator}${AppResetLocalDataSource.storeFolderName}',
        ).exists(),
      ),
    );

    sl.safeRegisterSingleton<AutoLockSettingsRepository>(
      AutoLockSettingsRepository(
        localDataSource: AutoLockSettingsLocalDataSource(),
        cryptoCoreService: sl.get<CryptoCoreService>(),
      ),
    );

    sl.safeRegisterSingleton<BiometricAuthRepository>(
      BiometricAuthRepository(),
    );

    sl.safeRegisterSingleton<AppLockThrottleRepository>(
      AppLockThrottleRepository(
        localDataSource: AppLockThrottleLocalDataSource(),
      ),
    );
    sl.safeRegisterSingleton<VaultPasswordThrottleRepository>(
      VaultPasswordThrottleRepository(
        localDataSource: AppLockThrottleLocalDataSource(
          key: AppLockThrottleLocalDataSource.vaultPasswordKey,
        ),
      ),
    );

    sl.safeRegisterSingleton<AppResetRepository>(
      AppResetRepository(
        localDataSource: AppResetLocalDataSource(
          supportDirectoryPath: sl.get<AppSupportDirectory>().directory.path,
        ),
        masterKeyLocalDataSource: sl.get<MasterKeyLocalDataSource>(),
        biometricAuthRepository: sl.get<BiometricAuthRepository>(),
        cryptoCoreService: sl.get<CryptoCoreService>(),
      ),
    );

    sl.safeRegisterSingleton<FuzzyAuthStore>(
      FuzzyAuthStore(
        chatAuthRepository: sl.get<ChatAuthRepository>(),
        biometricAuthRepository: sl.get<BiometricAuthRepository>(),
        cryptoCoreService: sl.get<CryptoCoreService>(),
        appLockThrottleRepository: sl.get<AppLockThrottleRepository>(),
        appResetRepository: sl.get<AppResetRepository>(),
      ),
    );

    sl.safeRegisterSingleton<ChatGeneralDataListRepository>(
      ChatGeneralDataListRepository(
        localDataSource: ChatGeneralDataLocalDataSource(isar: sl.get()),
        pairedAcceptanceDataSource:
            PairedAcceptanceLocalDataSource(prefs: prefs),
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
        incomingFiles: IncomingFiles(
          userFileStore: sl.get<UserFileStore>(),
          documentsDirectoryPath:
              sl.get<AppDocumentsDirectory>().directory.path,
        ),
      ),
    );

    // Vault Dependencies
    sl.safeRegisterSingleton<PasswordStrengthService>(
      PasswordStrengthService(),
    );

    // The vault lives in its own app-private folder; a vault an older build
    // left in the documents directory is moved there before first use.
    // A move that failed before its marker was written keeps the vault
    // closed too (moveFailed), so no new vault is made in its place.
    final vaultDirectoryPath = VaultFileDataSource.directoryIn(
      sl.get<AppSupportDirectory>().directory.path,
    );
    final vaultMove = await VaultLocationMigration(
      legacyDirectoryPath: sl.get<AppDocumentsDirectory>().directory.path,
      vaultDataSource:
          VaultFileDataSource(vaultDirectoryPath: vaultDirectoryPath),
    ).run();
    sl.safeRegisterSingleton<VaultFileDataSource>(
      VaultFileDataSource(
        vaultDirectoryPath: vaultDirectoryPath,
        moveFailed: vaultMove == VaultLocationMigrationResult.failed,
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
        chatAuthRepository: sl.get<ChatAuthRepository>(),
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
        appLockThrottleRepository: sl.get<AppLockThrottleRepository>(),
        vaultPasswordThrottleRepository:
            sl.get<VaultPasswordThrottleRepository>(),
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
