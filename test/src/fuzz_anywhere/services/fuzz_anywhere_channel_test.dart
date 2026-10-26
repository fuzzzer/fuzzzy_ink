import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:mocktail/mocktail.dart';

import '../fuzz_anywhere_fakes.dart';

const _codec = StandardMethodCodec();

/// What the platform code receives for a call: the answer, or the
/// refusal's code and details. [raw] is every byte it got, as text.
class _Reply {
  _Reply(this.value, this.code, this.details, this.raw);

  final Object? value;
  final String? code;
  final Object? details;
  final String raw;
}

Future<_Reply?> _call(String method, [Map<String, Object?>? arguments]) async {
  ByteData? answer;
  var answered = false;
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    fuzzAnywhereMethodChannel.name,
    _codec.encodeMethodCall(MethodCall(method, arguments)),
    (data) {
      answered = true;
      answer = data;
    },
  );
  final bytes = answer;
  if (!answered || bytes == null) return null;
  final raw = String.fromCharCodes(bytes.buffer.asUint8List());
  try {
    return _Reply(_codec.decodeEnvelope(bytes), null, null, raw);
  } on PlatformException catch (exception) {
    return _Reply(null, exception.code, exception.details, raw);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAnywhereFallbacks);

  late AnywhereHarness app;
  late FuzzAnywhereChannel channel;
  late List<MethodCall> sentToPlatform;

  setUp(() async {
    app = AnywhereHarness()
      ..storeSettings(
        const FuzzAnywhereSettings(isOn: true, locksAgainAfterUse: true),
      );
    sentToPlatform = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fuzzAnywhereMethodChannel, (call) async {
      sentToPlatform.add(call);
      return null;
    });
    channel = FuzzAnywhereChannel(service: app.service)..attach();
    await app.boot();
  });

  tearDown(() async {
    await channel.detach();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(fuzzAnywhereMethodChannel, null);
    await app.dispose();
  });

  test('status answers the contract version and where the app stands',
      () async {
    final reply = await _call('status');
    expect(reply!.value, {
      'version': 1,
      'enabled': false,
      'settingKnown': false,
      'lockAgainAfterUse': true,
      'unlocked': false,
      'setUp': true,
      'biometric': 'on',
    });
  });

  test('a newer contract, a bad argument and an unknown method are refused',
      () async {
    expect((await _call('status', {'v': 2}))!.code, 'unsupportedVersion');
    expect(
      (await _call('unlockWithPassword', {'password': 7}))!.code,
      'badRequest',
    );
    expect((await _call('lock', {'personId': ninoId}))!.code, 'badRequest');
    // No handler for it: the platform side gets "not implemented".
    expect(await _call('readClipboard'), isNull);
  });

  test('a wrong password answers its code and the wait, never the password',
      () async {
    const typed = 'tulip-harbor-17';
    final replies = <_Reply>[];
    for (var i = 0; i <= AppLockThrottleData.freeAttempts; i++) {
      replies.add((await _call('unlockWithPassword', {'password': typed}))!);
    }
    expect(replies.first.code, 'wrongPassword');
    expect(replies.first.details, isNull);
    expect(replies[4].code, 'wrongPassword');
    expect(replies[4].details, {'waitSeconds': 30});
    expect(replies.last.code, 'lockedOut');
    expect(replies.last.details, {'waitSeconds': 30});
    for (final reply in replies) {
      expect(reply.raw, isNot(contains(typed)));
    }
  });

  group('unlocked', () {
    setUp(() async {
      final reply = await _call(
        'unlockWithPassword',
        {'v': 1, 'password': rightPassword},
      );
      expect(reply!.value, {'status': 'unlocked'});
    });

    test('people, then lock: sealed output only', () async {
      final people = await _call('people', {'sourceApp': 'com.whatsapp'});
      expect(people!.value, {
        'people': [
          {
            'id': ninoId,
            'name': 'Nino',
            'verified': true,
            'lastUsedHere': false,
          },
        ],
      });

      final locked = await _call('lock', {
        'personId': ninoId,
        'text': secretText,
        'sourceApp': 'com.whatsapp',
        'copy': true,
      });
      expect(locked!.value, {
        'output': 'https://ink.fuzzzycore.com/message#AwECc2VhbGVk',
        'kind': 'link',
        'copied': true,
      });
      expect(locked.raw, isNot(contains(secretText)));
    });

    test('open answers a display id, never the opened text', () async {
      final peek = await _call('peek', {'text': blobFromNino});
      expect(peek!.value, {
        'kind': 'message',
        'personId': ninoId,
        'personName': 'Nino',
      });

      final opened = await _call('open', {'text': blobFromNino});
      final answer = opened!.value! as Map<Object?, Object?>;
      expect(
        answer.keys,
        unorderedEquals(['status', 'displayId', 'personId', 'personName']),
      );
      expect(answer['status'], 'opened');
      expect(opened.raw, isNot(contains(openedSecret)));
      expect(app.rows.single.decryptedMessage, openedSecret);

      final shown = await _call('show', {'displayId': answer['displayId']});
      expect(shown!.value, {'status': 'shown'});
      expect(shown.raw, isNot(contains(openedSecret)));
      expect(app.shown.single.message.decryptedMessage, openedSecret);

      app.displayClosed!.complete();
      await pumpEventQueue();
      expect(
        sentToPlatform.map((call) => call.method),
        containsAllInOrder(['lockChanged', 'shownClosed', 'lockChanged']),
      );
      for (final call in sentToPlatform) {
        expect('${call.arguments}', isNot(contains(openedSecret)));
      }
    });

    test('open in the app hands a sealed text over, never opens it', () async {
      const invite = 'Fuzz/AwEBaW52aXRl';
      when(
        () =>
            app.crypto.peekPasted(text: invite, chatIds: any(named: 'chatIds')),
      ).thenAnswer(
        (_) async => const CryptoCoreSuccess(
          CryptoCorePeek(kind: CryptoCorePeekKind.invitation),
        ),
      );
      final reply = await _call('openInApp', {'text': invite});
      expect(reply!.value, {'status': 'shown'});
      expect(app.presented, hasLength(1));
      expect((await _call('openInApp', {'text': blobFromNino}))!.code,
          'badRequest');
      expect((await _call('openInApp'))!.code, 'badRequest');
    });

    test('relock answers whether it locked, and the platform hears it',
        () async {
      expect((await _call('relock'))!.value, {'relocked': true});
      await pumpEventQueue();
      expect(sentToPlatform.last.method, 'lockChanged');
      expect(sentToPlatform.last.arguments, {'v': 1, 'unlocked': false});
      expect((await _call('people'))!.code, 'locked');
    });
  });
}
