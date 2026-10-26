import 'package:flutter/services.dart';
import 'package:fuzzzy_ink/lib.dart';

/// The master password: one password above every key on the device. It
/// opens the master key, the master key opens the store key (chats) and, by
/// default, the vault key. All key work runs in the core; this repository
/// keeps the wrapped blobs in the secure storage and turns every storage
/// error into a [CryptoCoreFailure] (`io`), so a caller can fail closed.
class ChatAuthRepository {
  ChatAuthRepository({
    required MasterKeyLocalDataSource localDataSource,
    required CryptoCoreService cryptoCoreService,
  })  : _localDataSource = localDataSource,
        _cryptoCoreService = cryptoCoreService;

  final MasterKeyLocalDataSource _localDataSource;
  final CryptoCoreService _cryptoCoreService;

  /// `notSetUp` until the first run has written its blobs; an unreadable
  /// secure storage is `io`, never "not set up".
  Future<CryptoCoreResponse<MasterKeyStatus>> status() async {
    final readRes = await _read();
    if (readRes is CryptoCoreFailure<MasterKeyBlobs?>) {
      return CryptoCoreFailure(readRes.type);
    }
    final blobs = (readRes as CryptoCoreSuccess<MasterKeyBlobs?>).data;
    return CryptoCoreSuccess(
      blobs == null ? MasterKeyStatus.notSetUp : MasterKeyStatus.ready,
    );
  }

  /// Whether an earlier build left its own key here (the app-lock store key
  /// that the master password replaces). Its chats and vault cannot be
  /// opened by this build.
  Future<CryptoCoreResponse<bool>> hasLegacyData() =>
      _guard(_localDataSource.hasLegacyKey);

  /// Whether a recovery key is set (the user confirmed saving one).
  Future<CryptoCoreResponse<bool>> hasRecoveryKey() async {
    final readRes = await _read();
    if (readRes is CryptoCoreFailure<MasterKeyBlobs?>) {
      return CryptoCoreFailure(readRes.type);
    }
    final blobs = (readRes as CryptoCoreSuccess<MasterKeyBlobs?>).data;
    return CryptoCoreSuccess(blobs?.recoveryWrap != null);
  }

  /// First run in one go, without a recovery key: the core draws every key
  /// and opens the store, and the password and store wraps are written. The
  /// recovery wrap and lock come back unsaved with the recovery key:
  /// [saveRecovery] keeps them. A failed write closes the store again.
  Future<CryptoCoreResponse<CryptoCoreMasterKeySetup>> setUp(
    String password,
  ) async {
    final createRes = await prepareSetUp(password);
    if (createRes is CryptoCoreFailure<CryptoCoreMasterKeySetup>) {
      return createRes;
    }
    final setup =
        (createRes as CryptoCoreSuccess<CryptoCoreMasterKeySetup>).data;
    final writeRes = await completeSetUp(setup, keepRecovery: false);
    if (writeRes is CryptoCoreFailure<void>) {
      await _cryptoCoreService.close();
      return CryptoCoreFailure(writeRes.type);
    }
    return CryptoCoreSuccess(setup);
  }

  /// The first run's first half: the core draws every key and opens the
  /// store, and nothing is written yet. Until [completeSetUp] the device
  /// still reads as "not set up", so a first run closed on the recovery-key
  /// step starts again from the beginning instead of leaving a password
  /// whose shown recovery key never works (QA 2026-10-26).
  Future<CryptoCoreResponse<CryptoCoreMasterKeySetup>> prepareSetUp(
    String password,
  ) async {
    final createRes = await _cryptoCoreService.createMasterKey(password);
    if (createRes is CryptoCoreFailure<CryptoCoreMasterKeySetup>) {
      return CryptoCoreFailure(createRes.type);
    }
    return createRes;
  }

  /// The first run's second half, once the recovery key was kept
  /// ([keepRecovery]) or skipped: the recovery wrap and lock (when kept),
  /// then the store wrap, then the password wrap — the mark that the first
  /// run is complete. A failed write leaves the store open, so it can be
  /// tried again.
  Future<CryptoCoreResponse<void>> completeSetUp(
    CryptoCoreMasterKeySetup setup, {
    required bool keepRecovery,
  }) =>
      _guard(() async {
        if (keepRecovery) {
          await _localDataSource.writeRecovery(
            recoveryWrap: setup.recoveryWrap,
            recoveryLock: setup.recoveryLock,
          );
        }
        await _localDataSource.writeSetup(
          MasterKeyBlobs(
            passwordWrap: setup.passwordWrap,
            storeWrap: setup.storeWrap,
          ),
        );
      });

  /// Opens the store with the master password and leaves it open — the
  /// wrapped master key is the only verifier.
  Future<CryptoCoreResponse<void>> unlock(String password) async {
    final blobsRes = await _readReady();
    if (blobsRes is CryptoCoreFailure<MasterKeyBlobs>) {
      return CryptoCoreFailure(blobsRes.type);
    }
    final blobs = (blobsRes as CryptoCoreSuccess<MasterKeyBlobs>).data;
    return _cryptoCoreService.openStore(
      passwordWrap: blobs.passwordWrap,
      storeWrap: blobs.storeWrap,
      password: password,
    );
  }

  /// Re-wraps the master key under [newPassword]: one blob, one write;
  /// every key below the master key stays as it is.
  Future<CryptoCoreResponse<void>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final blobsRes = await _readReady();
    if (blobsRes is CryptoCoreFailure<MasterKeyBlobs>) {
      return CryptoCoreFailure(blobsRes.type);
    }
    final blobs = (blobsRes as CryptoCoreSuccess<MasterKeyBlobs>).data;
    final rewrapRes = await _cryptoCoreService.changeMasterPassword(
      passwordWrap: blobs.passwordWrap,
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
    if (rewrapRes is CryptoCoreFailure<Uint8List>) {
      return CryptoCoreFailure(rewrapRes.type);
    }
    return _guard(
      () => _localDataSource.writePasswordWrap(
        (rewrapRes as CryptoCoreSuccess<Uint8List>).data,
      ),
    );
  }

  /// The forgotten-password path: the recovery key sets [newPassword] and
  /// opens the store. Without a saved recovery key nothing opens
  /// (`wrongPassword`); a typo is `corrupt`.
  Future<CryptoCoreResponse<void>> recover({
    required String recoveryKey,
    required String newPassword,
  }) async {
    final blobsRes = await _readReady();
    if (blobsRes is CryptoCoreFailure<MasterKeyBlobs>) {
      return CryptoCoreFailure(blobsRes.type);
    }
    final blobs = (blobsRes as CryptoCoreSuccess<MasterKeyBlobs>).data;
    final recoveryWrap = blobs.recoveryWrap;
    if (recoveryWrap == null) {
      return const CryptoCoreFailure(CryptoCoreFailureType.wrongPassword);
    }
    final recoverRes = await _cryptoCoreService.recoverMasterPassword(
      recoveryWrap: recoveryWrap,
      storeWrap: blobs.storeWrap,
      recoveryKey: recoveryKey,
      newPassword: newPassword,
    );
    if (recoverRes is CryptoCoreFailure<Uint8List>) {
      return CryptoCoreFailure(recoverRes.type);
    }
    final writeRes = await _guard(
      () => _localDataSource.writePasswordWrap(
        (recoverRes as CryptoCoreSuccess<Uint8List>).data,
      ),
    );
    if (writeRes is CryptoCoreFailure<void>) {
      await _cryptoCoreService.close();
    }
    return writeRes;
  }

  /// Whether a typed [recoveryKey] has a recovery key's form, check byte
  /// included: `corrupt` for a typo. Says nothing about this device.
  Future<CryptoCoreResponse<void>> checkRecoveryKey(String recoveryKey) =>
      _cryptoCoreService.checkRecoveryKey(recoveryKey);

  /// A new recovery key, once [password] is right. [sealVault] — given when
  /// the vault has its own password — seals that vault to the new key's lock
  /// and answers the copy; if it fails, nothing changes and the old key keeps
  /// working. Otherwise the old recovery key (its wrap, lock and vault copy)
  /// stops working here, before the new one is shown: the new blobs are kept
  /// only when the user confirms saving it ([saveRecovery]).
  Future<CryptoCoreResponse<PendingRecoveryKey>> newRecoveryKey(
    String password, {
    Future<CryptoCoreResponse<Uint8List>> Function(Uint8List recoveryLock)?
        sealVault,
  }) async {
    final blobsRes = await _readReady();
    if (blobsRes is CryptoCoreFailure<MasterKeyBlobs>) {
      return CryptoCoreFailure(blobsRes.type);
    }
    final blobs = (blobsRes as CryptoCoreSuccess<MasterKeyBlobs>).data;
    final createRes = await _cryptoCoreService.newRecoveryKey(
      passwordWrap: blobs.passwordWrap,
      password: password,
    );
    if (createRes is CryptoCoreFailure<CryptoCoreRecoveryKey>) {
      return CryptoCoreFailure(createRes.type);
    }
    final created =
        (createRes as CryptoCoreSuccess<CryptoCoreRecoveryKey>).data;
    Uint8List? vaultRecovery;
    if (sealVault != null) {
      final sealRes = await sealVault(created.recoveryLock);
      if (sealRes is CryptoCoreFailure<Uint8List>) {
        return CryptoCoreFailure(sealRes.type);
      }
      vaultRecovery = (sealRes as CryptoCoreSuccess<Uint8List>).data;
    }
    final dropRes = await _guard(_localDataSource.deleteRecovery);
    if (dropRes is CryptoCoreFailure<void>) {
      return CryptoCoreFailure(dropRes.type);
    }
    return CryptoCoreSuccess(
      PendingRecoveryKey(
        recoveryKey: created.recoveryKey,
        recoveryWrap: created.recoveryWrap,
        recoveryLock: created.recoveryLock,
        vaultRecovery: vaultRecovery,
      ),
    );
  }

  /// Keeps a recovery key the user saved: its wrap, its lock and, for a
  /// vault with its own password, the vault's copy.
  Future<CryptoCoreResponse<void>> saveRecovery(PendingRecoveryKey pending) =>
      _guard(
        () => _localDataSource.writeRecovery(
          recoveryWrap: pending.recoveryWrap,
          recoveryLock: pending.recoveryLock,
          vaultRecovery: pending.vaultRecovery,
        ),
      );

  /// The recovery key's blobs the vault needs: the lock to seal a vault with
  /// its own password to, the vault's copy and the master key's recovery
  /// wrap (all `null` without a recovery key).
  Future<CryptoCoreResponse<MasterKeyBlobs>> keyBlobs() => _readReady();

  /// Keeps (or, with `null`, removes) the vault key sealed to the recovery
  /// lock.
  Future<CryptoCoreResponse<void>> saveVaultRecovery(Uint8List? recovery) =>
      _guard(
        () => recovery == null
            ? _localDataSource.deleteVaultRecovery()
            : _localDataSource.writeVaultRecovery(recovery),
      );

  /// The master key's password wrap, for the vault calls that need the
  /// master password.
  Future<CryptoCoreResponse<Uint8List>> passwordWrap() async {
    final blobsRes = await _readReady();
    if (blobsRes is CryptoCoreFailure<MasterKeyBlobs>) {
      return CryptoCoreFailure(blobsRes.type);
    }
    return CryptoCoreSuccess(
      (blobsRes as CryptoCoreSuccess<MasterKeyBlobs>).data.passwordWrap,
    );
  }

  /// The blobs of a finished first run; none is `internal` (the app gates
  /// every caller behind the first run).
  Future<CryptoCoreResponse<MasterKeyBlobs>> _readReady() async {
    final readRes = await _read();
    if (readRes is CryptoCoreFailure<MasterKeyBlobs?>) {
      return CryptoCoreFailure(readRes.type);
    }
    final blobs = (readRes as CryptoCoreSuccess<MasterKeyBlobs?>).data;
    if (blobs == null) {
      return const CryptoCoreFailure(CryptoCoreFailureType.internal);
    }
    return CryptoCoreSuccess(blobs);
  }

  Future<CryptoCoreResponse<MasterKeyBlobs?>> _read() =>
      _guard(_localDataSource.read);

  Future<CryptoCoreResponse<T>> _guard<T>(Future<T> Function() call) async {
    try {
      return CryptoCoreSuccess(await call());
    } catch (ex) {
      logger.e(
        ex is PlatformException
            ? 'Secure storage failed: PlatformException(${ex.code}, '
                '${ex.message})'
            : 'Secure storage failed: ${ex.runtimeType}',
      );
      return const CryptoCoreFailure(CryptoCoreFailureType.io);
    }
  }
}
