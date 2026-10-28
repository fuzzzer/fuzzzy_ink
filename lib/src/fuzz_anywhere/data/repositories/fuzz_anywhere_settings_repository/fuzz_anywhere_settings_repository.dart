import 'dart:convert';
import 'dart:typed_data';

import 'package:fuzzzy_ink/src/src.dart';

/// Settings → Other apps, and the person last locked for from each other
/// app. Both are sealed under the store key (`app-setting` ‖ name,
/// `PROTOCOL.md` §10.7): which apps the person uses with whom is metadata,
/// and the switch must not be turned on by editing a file. A missing,
/// tampered or unreadable blob reads as [FuzzAnywhereSettings.standard]
/// (off) or as no memory. Both need the open store.
class FuzzAnywhereSettingsRepository {
  FuzzAnywhereSettingsRepository({
    required FuzzAnywhereLocalDataSource localDataSource,
    required CryptoCoreService cryptoCoreService,
  })  : _localDataSource = localDataSource,
        _cryptoCoreService = cryptoCoreService;

  static const settingsName = 'anywhere';
  static const appPeopleName = 'anywhere-apps';

  /// The most other apps remembered; the least recent goes first.
  static const maxApps = 32;

  /// An app id is the caller's: a package name or a bundle id.
  static const maxAppIdLength = 200;

  final FuzzAnywhereLocalDataSource _localDataSource;
  final CryptoCoreService _cryptoCoreService;

  static bool isAppId(String appId) =>
      appId.isNotEmpty &&
      appId.length <= maxAppIdLength &&
      !appId.contains(RegExp(r'[\x00-\x1F\x7F]'));

  Future<FuzzAnywhereSettings> readSettings() async {
    final json = await _readSealed(
      FuzzAnywhereLocalDataSource.settingsKey,
      settingsName,
    );
    return FuzzAnywhereSettings.fromJson(json) ?? FuzzAnywhereSettings.standard;
  }

  Future<CryptoCoreResponse<void>> writeSettings(
    FuzzAnywhereSettings settings,
  ) =>
      _writeSealed(
        FuzzAnywhereLocalDataSource.settingsKey,
        settingsName,
        settings.toJson(),
      );

  /// The person last locked for from [appId], if any.
  Future<String?> lastPersonFor(String appId) async {
    if (!isAppId(appId)) return null;
    for (final (app, person) in await _readAppPeople()) {
      if (app == appId) return person;
    }
    return null;
  }

  /// [personId] becomes [appId]'s last person.
  Future<CryptoCoreResponse<void>> rememberPerson({
    required String appId,
    required String personId,
  }) async {
    if (!isAppId(appId)) {
      return const CryptoCoreFailure(CryptoCoreFailureType.internal);
    }
    final entries = [
      (appId, personId),
      for (final entry in await _readAppPeople())
        if (entry.$1 != appId) entry,
    ].take(maxApps);
    return _writeSealed(
      FuzzAnywhereLocalDataSource.appPeopleKey,
      appPeopleName,
      [
        for (final (app, person) in entries) [app, person],
      ],
    );
  }

  /// Forgets every app's person (the switch was turned off).
  Future<CryptoCoreResponse<void>> forgetApps() async {
    try {
      await _localDataSource.delete(FuzzAnywhereLocalDataSource.appPeopleKey);
      return const CryptoCoreSuccess(null);
    } catch (ex) {
      logger.e('Other apps memory not removed: ${ex.runtimeType}');
      return const CryptoCoreFailure(CryptoCoreFailureType.io);
    }
  }

  Future<List<(String, String)>> _readAppPeople() async {
    final json = await _readSealed(
      FuzzAnywhereLocalDataSource.appPeopleKey,
      appPeopleName,
    );
    if (json is! List) return const [];
    return [
      for (final entry in json)
        if (entry is List &&
            entry.length == 2 &&
            entry[0] is String &&
            entry[1] is String)
          (entry[0] as String, entry[1] as String),
    ];
  }

  /// The opened JSON, or `null` when missing or unreadable.
  Future<Object?> _readSealed(String key, String name) async {
    final Uint8List? sealed;
    try {
      sealed = await _localDataSource.read(key);
    } catch (ex) {
      logger.w('Other apps setting unreadable: ${ex.runtimeType}');
      return null;
    }
    if (sealed == null) return null;
    final openRes = await _cryptoCoreService.openSetting(
      name: name,
      blob: sealed,
    );
    if (openRes is CryptoCoreFailure<Uint8List>) {
      logger.w('Other apps setting does not open: ${openRes.type}');
      return null;
    }
    try {
      return jsonDecode(
        utf8.decode((openRes as CryptoCoreSuccess<Uint8List>).data),
      );
    } on FormatException {
      return null;
    }
  }

  Future<CryptoCoreResponse<void>> _writeSealed(
    String key,
    String name,
    Object json,
  ) async {
    final sealRes = await _cryptoCoreService.sealSetting(
      name: name,
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(json))),
    );
    if (sealRes is CryptoCoreFailure<Uint8List>) {
      return CryptoCoreFailure(sealRes.type);
    }
    try {
      await _localDataSource.write(
        key,
        (sealRes as CryptoCoreSuccess<Uint8List>).data,
      );
      return const CryptoCoreSuccess(null);
    } catch (ex) {
      logger.e('Other apps setting not saved: ${ex.runtimeType}');
      return const CryptoCoreFailure(CryptoCoreFailureType.io);
    }
  }
}
