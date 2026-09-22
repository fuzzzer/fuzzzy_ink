import 'dart:typed_data';

import 'package:fuzzzy_seal/lib.dart';

class ChatAuthRepository {
  ChatAuthRepository({
    required UserAuthPreferencesRepository userAuthPreferencesRepository,
    required CryptoStoreKeyRepository cryptoStoreKeyRepository,
    required CryptoCoreService cryptoCoreService,
  })  : _userAuthPreferencesRepository = userAuthPreferencesRepository,
        _cryptoStoreKeyRepository = cryptoStoreKeyRepository,
        _cryptoCoreService = cryptoCoreService;

  final UserAuthPreferencesRepository _userAuthPreferencesRepository;
  final CryptoStoreKeyRepository _cryptoStoreKeyRepository;
  final CryptoCoreService _cryptoCoreService;

  /// The wrapped store-key blob is the truth about the lock and the
  /// preference only a cache of it (F2-6 review R1): the store is tried under
  /// `''` and the preference repaired when the two disagree, so a kill between
  /// the two writes of [setupPassword] / [disableAuth] never locks anyone out.
  /// Leaves the store open when the lock is disabled.
  Future<bool> isChatAuthEnabled() async {
    final readRes = await _cryptoStoreKeyRepository.read();
    if (readRes is CryptoCoreFailure) return false;
    final wrapped = (readRes as CryptoCoreSuccess<Uint8List?>).data;
    if (wrapped == null) return false;

    final openRes = await _cryptoCoreService.openStore(
      wrapped: wrapped,
      password: '',
    );
    final enabled = openRes is CryptoCoreFailure;

    final prefs = await _userAuthPreferencesRepository.getUserAuthPreferences();
    if ((prefs?.isAuthenticationOnceEnabled ?? false) != enabled) {
      await _userAuthPreferencesRepository.updateUserAuthPreferences(
        UserAuthPreferences(isAuthenticationOnceEnabled: enabled),
      );
    }
    return enabled;
  }

  /// With the lock disabled the store key is wrapped under `''`; enabling it
  /// re-wraps that same key under [password].
  Future<bool> setupPassword(String password) async {
    final rewrapRes = await _cryptoStoreKeyRepository.rewrap(
      oldPassword: '',
      newPassword: password,
    );
    if (rewrapRes is CryptoCoreFailure) return false;

    await _userAuthPreferencesRepository.updateUserAuthPreferences(
      UserAuthPreferences(isAuthenticationOnceEnabled: true),
    );
    return true;
  }

  /// Opens the store under [password] and leaves it open — the wrapped store
  /// key is the verification token.
  Future<bool> verifyPassword(String password) async {
    final readRes = await _cryptoStoreKeyRepository.read();
    if (readRes is CryptoCoreFailure) return false;
    final wrapped = (readRes as CryptoCoreSuccess<Uint8List?>).data;
    if (wrapped == null) return false;

    final openRes = await _cryptoCoreService.openStore(
      wrapped: wrapped,
      password: password,
    );
    return openRes is CryptoCoreSuccess;
  }

  Future<bool> disableAuth(String currentPassword) async {
    final rewrapRes = await _cryptoStoreKeyRepository.rewrap(
      oldPassword: currentPassword,
      newPassword: '',
    );
    if (rewrapRes is CryptoCoreFailure) return false;

    await _userAuthPreferencesRepository.updateUserAuthPreferences(
      UserAuthPreferences(isAuthenticationOnceEnabled: false),
    );
    return true;
  }

  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final rewrapRes = await _cryptoStoreKeyRepository.rewrap(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
    return rewrapRes is! CryptoCoreFailure;
  }
}
