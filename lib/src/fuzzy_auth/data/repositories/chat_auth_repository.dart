import 'dart:typed_data';

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

  /// First run: the core draws every key and opens the store; the password
  /// and store wraps are written here. The recovery wrap comes back unsaved
  /// with the recovery key: [saveRecoveryWrap] keeps it once the user has
  /// saved the key. A failed write closes the store again.
  Future<CryptoCoreResponse<CryptoCoreMasterKeySetup>> setUp(
    String password,
  ) async {
    final createRes = await _cryptoCoreService.createMasterKey(password);
    if (createRes is CryptoCoreFailure<CryptoCoreMasterKeySetup>) {
      return CryptoCoreFailure(createRes.type);
    }
    final setup =
        (createRes as CryptoCoreSuccess<CryptoCoreMasterKeySetup>).data;
    final writeRes = await _guard(
      () => _localDataSource.writeSetup(
        MasterKeyBlobs(
          passwordWrap: setup.passwordWrap,
          storeWrap: setup.storeWrap,
        ),
      ),
    );
    if (writeRes is CryptoCoreFailure<void>) {
      await _cryptoCoreService.close();
      return CryptoCoreFailure(writeRes.type);
    }
    return CryptoCoreSuccess(setup);
  }

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

  /// A new recovery key, once [password] is right. The old recovery key
  /// stops working here, before the new one is shown: the new wrap is kept
  /// only when the user confirms saving it ([saveRecoveryWrap]).
  Future<CryptoCoreResponse<CryptoCoreRecoveryKey>> newRecoveryKey(
    String password,
  ) async {
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
    final dropRes = await _guard(_localDataSource.deleteRecoveryWrap);
    if (dropRes is CryptoCoreFailure<void>) {
      return CryptoCoreFailure(dropRes.type);
    }
    return createRes;
  }

  Future<CryptoCoreResponse<void>> saveRecoveryWrap(Uint8List recoveryWrap) =>
      _guard(() => _localDataSource.writeRecoveryWrap(recoveryWrap));

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
      logger.e('Secure storage failed: ${ex.runtimeType}');
      return const CryptoCoreFailure(CryptoCoreFailureType.io);
    }
  }
}
