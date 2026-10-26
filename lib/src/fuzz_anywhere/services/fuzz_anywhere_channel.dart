import 'dart:async';

import 'package:flutter/services.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// The method channel the platform code of "Lock from other apps" calls.
const fuzzAnywhereMethodChannel = MethodChannel('com.fuzzzycore.ink/anywhere');

/// The Dart end of `com.fuzzzycore.ink/anywhere`, contract version
/// [contractVersion] (`documents/fuzz_anywhere/CHANNEL.md`). It reads the
/// arguments, asks [FuzzAnywhereService] and answers maps of plain values.
/// A refusal is a `PlatformException` whose code is an [AnywhereFailure]
/// code, with no message; its details carry only `waitSeconds`. Nothing it
/// answers or sends holds opened text, a password or a key.
///
/// Registered only when the build has the feature ([fuzzAnywhereEnabled]).
class FuzzAnywhereChannel {
  FuzzAnywhereChannel({
    required this.service,
    MethodChannel channel = fuzzAnywhereMethodChannel,
  }) : _channel = channel;

  static const contractVersion = 1;

  final FuzzAnywhereService service;
  final MethodChannel _channel;
  StreamSubscription<AnywhereEvent>? _eventSubscription;

  void attach() {
    _channel.setMethodCallHandler(_handle);
    _eventSubscription = service.events.listen(_sendEvent);
  }

  Future<void> detach() async {
    _channel.setMethodCallHandler(null);
    await _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  Future<Object?> _handle(MethodCall call) async {
    final args = call.arguments;
    final arguments = args is Map ? args : const <Object?, Object?>{};
    final version = arguments['v'];
    if (version != null && (version is! int || version > contractVersion)) {
      throw _refusal(AnywhereFailure.unsupportedVersion);
    }

    switch (call.method) {
      case 'status':
        return _statusMap(await service.status());
      case 'unlock':
        return _unlocked(await service.unlockWithBiometrics());
      case 'unlockWithPassword':
        return _unlocked(
          await service.unlockWithPassword(_string(arguments, 'password')),
        );
      case 'people':
        final result = await service.people(
          sourceApp: _optionalString(arguments, 'sourceApp'),
        );
        return {
          'people': [
            for (final person in _valueOf(result))
              {
                'id': person.id,
                'name': person.name,
                'verified': person.isVerified,
                'lastUsedHere': person.isLastUsedHere,
              },
          ],
        };
      case 'lock':
        final output = _valueOf(
          await service.lock(
            personId: _string(arguments, 'personId'),
            text: _string(arguments, 'text'),
            sourceApp: _optionalString(arguments, 'sourceApp'),
            copy: arguments['copy'] == true,
          ),
        );
        return {
          'output': output.output,
          'kind': output.isLink ? 'link' : 'text',
          'copied': output.isCopied,
        };
      case 'peek':
        final peek = _valueOf(await service.peek(_string(arguments, 'text')));
        return {
          'kind': peek.kind.code,
          if (peek.personId case final id?) 'personId': id,
          if (peek.personName case final name?) 'personName': name,
        };
      case 'open':
        final opened = _valueOf(await service.open(_string(arguments, 'text')));
        return {
          'status': 'opened',
          'displayId': opened.displayId,
          'personId': opened.personId,
          'personName': opened.personName,
        };
      case 'show':
        _valueOf(await service.show(_string(arguments, 'displayId')));
        return const {'status': 'shown'};
      case 'relock':
        return {'relocked': await service.relock()};
      default:
        throw MissingPluginException('No method ${call.method}');
    }
  }

  Map<String, Object?> _statusMap(AnywhereStatus status) => {
        'version': contractVersion,
        'enabled': status.isOn,
        'settingKnown': status.isSettingKnown,
        'lockAgainAfterUse': status.locksAgainAfterUse,
        'unlocked': status.isUnlocked,
        'setUp': status.isSetUp,
        'biometric': status.biometric.code,
      };

  Map<String, Object?> _unlocked(AnywhereResult<void> result) {
    _valueOf(result);
    return const {'status': 'unlocked'};
  }

  static T _valueOf<T>(AnywhereResult<T> result) => switch (result) {
        AnywhereDone(:final value) => value,
        AnywhereRefused(:final failure, :final wait) =>
          throw _refusal(failure, wait: wait),
      };

  static PlatformException _refusal(
    AnywhereFailure failure, {
    Duration wait = Duration.zero,
  }) =>
      PlatformException(
        code: failure.code,
        details: wait > Duration.zero
            ? {'waitSeconds': (wait.inMilliseconds / 1000).ceil()}
            : null,
      );

  static String _string(Map<Object?, Object?> arguments, String key) {
    final value = arguments[key];
    if (value is! String) throw _refusal(AnywhereFailure.badRequest);
    return value;
  }

  static String? _optionalString(Map<Object?, Object?> arguments, String key) {
    final value = arguments[key];
    if (value == null) return null;
    if (value is! String) throw _refusal(AnywhereFailure.badRequest);
    return value;
  }

  Future<void> _sendEvent(AnywhereEvent event) async {
    final (method, arguments) = switch (event) {
      AnywhereLockChanged(:final isUnlocked) => (
          'lockChanged',
          <String, Object?>{'unlocked': isUnlocked},
        ),
      AnywhereSettingsChanged(:final isOn, :final locksAgainAfterUse) => (
          'settingsChanged',
          <String, Object?>{
            'enabled': isOn,
            'lockAgainAfterUse': locksAgainAfterUse,
          },
        ),
      AnywhereShownClosed(:final displayId) => (
          'shownClosed',
          <String, Object?>{'displayId': displayId},
        ),
    };
    try {
      await _channel.invokeMethod<void>(method, {
        'v': contractVersion,
        ...arguments,
      });
    } on MissingPluginException {
      // No platform side listening yet (it is built separately).
    } on PlatformException catch (exception) {
      logger.w('ANYWHERE: event not taken: ${exception.code}');
    }
  }
}
