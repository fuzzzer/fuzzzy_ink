import 'package:flutter/services.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// "Erase everything and start over": the way back for someone who has
/// neither the master password nor the recovery key, and the clean start an
/// install from before the master password needs. The keys go first, so the
/// data is unreadable even if a later step fails; then the data itself.
class AppResetRepository {
  AppResetRepository({
    required AppResetLocalDataSource localDataSource,
    required MasterKeyLocalDataSource masterKeyLocalDataSource,
    required BiometricAuthRepository biometricAuthRepository,
    required CryptoCoreService cryptoCoreService,
  })  : _localDataSource = localDataSource,
        _masterKeyLocalDataSource = masterKeyLocalDataSource,
        _biometricAuthRepository = biometricAuthRepository,
        _cryptoCoreService = cryptoCoreService;

  final AppResetLocalDataSource _localDataSource;
  final MasterKeyLocalDataSource _masterKeyLocalDataSource;
  final BiometricAuthRepository _biometricAuthRepository;
  final CryptoCoreService _cryptoCoreService;

  /// Erases everything this app keeps on the device.
  ///
  /// The first run erases what an earlier install left before it makes keys;
  /// it passes [keepFirstRunChoices] so the welcome, language and look the
  /// person just chose stay.
  ///
  /// Afterwards, whatever the outcome, [AppDataErased] tells every list held
  /// in memory to read the (now empty) storage again.
  Future<CryptoCoreResponse<void>> eraseEverything({
    bool keepFirstRunChoices = false,
  }) async {
    final eraseRes = await _erase(keepFirstRunChoices: keepFirstRunChoices);
    fuzzyHub.sendSignal(const AppDataErased());
    return eraseRes;
  }

  Future<CryptoCoreResponse<void>> _erase({
    required bool keepFirstRunChoices,
  }) async {
    await _cryptoCoreService.close();
    try {
      await _masterKeyLocalDataSource.deleteAll();
      for (final scope in BiometricScope.values) {
        await _biometricAuthRepository.disable(scope);
      }
      await _localDataSource.clearDatabase();
      await _localDataSource.deleteChatStates();
      await _localDataSource.deleteVault();
      await _localDataSource.deleteSealedFiles();
      await _localDataSource.wipePlainCopies();
      await _localDataSource.clearPreferences(
        keepFirstRunChoices: keepFirstRunChoices,
      );
      _localDataSource.discardPendingLink();
      return const CryptoCoreSuccess(null);
    } catch (ex) {
      // The system's code says why (a keychain entry this build may not
      // touch, a locked keychain); never a value.
      logger.e(
        ex is PlatformException
            ? 'Erase failed: PlatformException(${ex.code}, ${ex.message})'
            : 'Erase failed: ${ex.runtimeType}',
      );
      return const CryptoCoreFailure(CryptoCoreFailureType.io);
    }
  }
}
