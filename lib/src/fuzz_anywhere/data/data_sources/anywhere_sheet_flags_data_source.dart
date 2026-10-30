// ignore_for_file: avoid_positional_boolean_parameters

import 'package:flutter/services.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// The flags the Android sheet keeps for itself, never text: "Copy
/// automatically next time" (Settings shows and changes it) and the draft
/// note seen. Read and changed over [fuzzAnywhereMethodChannel]
/// (`sheetFlags`, `setCopyAutomatically`, CHANNEL.md section 3). Where no
/// sheet answers (every other platform) the flag reads as off and nothing
/// changes.
class AnywhereSheetFlagsDataSource {
  AnywhereSheetFlagsDataSource({
    MethodChannel channel = fuzzAnywhereMethodChannel,
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<bool> copiesAutomatically() async {
    final flags = await _call<Map<Object?, Object?>>('sheetFlags');
    return flags?['copyAutomatically'] == true;
  }

  Future<void> setCopiesAutomatically(bool isOn) =>
      _call<void>('setCopyAutomatically', {'enabled': isOn});

  Future<T?> _call<T>(String method, [Map<String, Object?>? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, {
        'v': FuzzAnywhereChannel.contractVersion,
        ...?arguments,
      });
    } on MissingPluginException {
      return null;
    } on PlatformException catch (exception) {
      logger.w('ANYWHERE: sheet flags not reached: ${exception.code}');
      return null;
    }
  }
}
