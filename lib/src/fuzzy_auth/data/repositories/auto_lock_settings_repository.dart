import 'dart:convert';
import 'dart:typed_data';

import 'package:fuzzzy_ink/src/src.dart';

/// The auto-lock settings, sealed under the store key (`app-setting` ‖
/// `auto-lock`) so they cannot be loosened by editing a file: a missing,
/// tampered or unreadable blob reads as [AutoLockSettings.standard].
class AutoLockSettingsRepository {
  AutoLockSettingsRepository({
    required AutoLockSettingsLocalDataSource localDataSource,
    required CryptoCoreService cryptoCoreService,
  })  : _localDataSource = localDataSource,
        _cryptoCoreService = cryptoCoreService;

  static const settingName = 'auto-lock';

  final AutoLockSettingsLocalDataSource _localDataSource;
  final CryptoCoreService _cryptoCoreService;

  /// Needs the open store; before it, or on any failure, the standard
  /// settings apply.
  Future<AutoLockSettings> read() async {
    final Uint8List? sealed;
    try {
      sealed = await _localDataSource.read();
    } catch (ex) {
      logger.w('Auto-lock settings unreadable: ${ex.runtimeType}');
      return AutoLockSettings.standard;
    }
    if (sealed == null) return AutoLockSettings.standard;
    final openRes = await _cryptoCoreService.openSetting(
      name: settingName,
      blob: sealed,
    );
    if (openRes is CryptoCoreFailure<Uint8List>) {
      logger.w('Auto-lock settings do not open: ${openRes.type}');
      return AutoLockSettings.standard;
    }
    final bytes = (openRes as CryptoCoreSuccess<Uint8List>).data;
    try {
      return AutoLockSettings.fromJson(jsonDecode(utf8.decode(bytes))) ??
          AutoLockSettings.standard;
    } on FormatException {
      return AutoLockSettings.standard;
    }
  }

  Future<CryptoCoreResponse<void>> write(AutoLockSettings settings) async {
    final sealRes = await _cryptoCoreService.sealSetting(
      name: settingName,
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(settings.toJson()))),
    );
    if (sealRes is CryptoCoreFailure<Uint8List>) {
      return CryptoCoreFailure(sealRes.type);
    }
    try {
      await _localDataSource
          .write((sealRes as CryptoCoreSuccess<Uint8List>).data);
      return const CryptoCoreSuccess(null);
    } catch (ex) {
      logger.e('Auto-lock settings not saved: ${ex.runtimeType}');
      return const CryptoCoreFailure(CryptoCoreFailureType.io);
    }
  }
}
