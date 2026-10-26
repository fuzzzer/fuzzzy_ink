import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:mocktail/mocktail.dart';

import '../fuzz_anywhere_fakes.dart';

const _on = FuzzAnywhereSettings(isOn: true, locksAgainAfterUse: true);

T _done<T>(AnywhereResult<T> result) => switch (result) {
      AnywhereDone(:final value) => value,
      AnywhereRefused(:final failure) => fail('refused: $failure'),
    };

AnywhereFailure? _refusal(AnywhereResult<Object?> result) => switch (result) {
      AnywhereDone() => null,
      AnywhereRefused(:final failure) => failure,
    };

void main() {
  setUpAll(registerAnywhereFallbacks);

  late AnywhereHarness app;

  setUp(() => app = AnywhereHarness());
  tearDown(() => app.dispose());

  void verifyNothingOpened() {
    verifyNever(
      () => app.crypto.decryptText(
        chatId: any(named: 'chatId'),
        blob: any(named: 'blob'),
      ),
    );
  }

  group('the switch', () {
    test('off: every call is refused and nothing is locked or opened',
        () async {
      app.storeSettings(FuzzAnywhereSettings.standard);
      await app.boot();
      await app.unlockInApp();
      await app.settings.load();

      final service = app.service;
      expect(
        _refusal(await service.unlockWithPassword(rightPassword)),
        AnywhereFailure.disabled,
      );
      expect(_refusal(await service.people()), AnywhereFailure.disabled);
      expect(
        _refusal(await service.lock(personId: ninoId, text: secretText)),
        AnywhereFailure.disabled,
      );
      expect(
        _refusal(await service.peek(blobFromNino)),
        AnywhereFailure.disabled,
      );
      expect(
        _refusal(await service.open(blobFromNino)),
        AnywhereFailure.disabled,
      );
      expect((await service.status()).isOn, isFalse);
      verifyNever(
        () => app.crypto.encryptText(
          chatId: any(named: 'chatId'),
          text: any(named: 'text'),
        ),
      );
      verifyNothingOpened();
      verifyNever(
        () => app.crypto.peekPasted(
          text: any(named: 'text'),
          chatIds: any(named: 'chatIds'),
        ),
      );
      expect(app.rows, isEmpty);
    });

    test('not known before the first unlock: only unlocking is allowed',
        () async {
      app.storeSettings(_on);
      await app.boot();

      final status = await app.service.status();
      expect(status.isSettingKnown, isFalse);
      expect(status.isOn, isFalse);
      expect(status.isUnlocked, isFalse);
      expect(status.biometric, AnywhereBiometric.on);
      expect(_refusal(await app.service.people()), AnywhereFailure.locked);

      expect(
        _refusal(await app.service.unlockWithPassword(rightPassword)),
        isNull,
      );
      final after = await app.service.status();
      expect(after.isSettingKnown, isTrue);
      expect(after.isOn, isTrue);
      expect(after.isUnlocked, isTrue);
    });

    test('found off at an unlock from outside: the app locks again', () async {
      app.storeSettings(FuzzAnywhereSettings.standard);
      await app.boot();

      expect(
        _refusal(await app.service.unlockWithPassword(rightPassword)),
        AnywhereFailure.disabled,
      );
      expect(app.authStore.state.status, AuthStateStatus.locked);
    });
  });

  group('lock', () {
    setUp(() async {
      app.storeSettings(_on);
      await app.boot();
      await app.service.unlockWithPassword(rightPassword);
    });

    test('answers the sealed message link only, never the text', () async {
      final output = _done(
        await app.service.lock(personId: ninoId, text: secretText),
      );

      expect(output.isLink, isTrue);
      expect(output.output, 'https://ink.fuzzzycore.com/message#AwECc2VhbGVk');
      expect(output.output, isNot(contains(secretText)));
      expect(output.isCopied, isFalse);
      expect(app.copies, isEmpty);
    });

    test('keeps the sent message in the person history, as Lock does',
        () async {
      await app.service.lock(personId: ninoId, text: secretText);

      final row = app.rows.single;
      expect(row.chatId, ninoId);
      expect(row.isSent, isTrue);
      expect(row.type, MessageType.text);
      expect(row.decryptedMessage, secretText);
      expect(row.encryptedMessage, 'AwECc2VhbGVk');
      verify(() => app.crypto.encryptText(chatId: ninoId, text: secretText))
          .called(1);
      verifyNothingOpened();
    });

    test('too long for a link: the sealed text instead', () async {
      final long = 'Fuzz/${'A' * (FuzzyLinkParser.maxPayloadLength + 1)}';
      final longApp = AnywhereHarness(lockedOutput: long)..storeSettings(_on);
      addTearDown(longApp.dispose);
      await longApp.boot();
      await longApp.service.unlockWithPassword(rightPassword);

      final output = _done(
        await longApp.service.lock(personId: ninoId, text: secretText),
      );
      expect(output.isLink, isFalse);
      expect(output.output, long);
    });

    test('with copy: only the sealed output goes to the copy guard', () async {
      final output = _done(
        await app.service.lock(personId: ninoId, text: secretText, copy: true),
      );

      expect(output.isCopied, isTrue);
      expect(app.copies.single, (output.output, CopyContent.sealedLink));
    });

    test('refuses an empty text, someone not connected, a stranger', () async {
      expect(
        _refusal(await app.service.lock(personId: ninoId, text: '  ')),
        AnywhereFailure.emptyText,
      );
      expect(
        _refusal(await app.service.lock(personId: momId, text: secretText)),
        AnywhereFailure.unknownPerson,
      );
      expect(
        _refusal(await app.service.lock(personId: 'someone', text: secretText)),
        AnywhereFailure.unknownPerson,
      );
      expect(app.rows, isEmpty);
    });

    test('a core failure answers failed and keeps nothing', () async {
      when(
        () => app.crypto.encryptText(
          chatId: any(named: 'chatId'),
          text: any(named: 'text'),
        ),
      ).thenAnswer(
        (_) async => const CryptoCoreFailure(CryptoCoreFailureType.io),
      );
      expect(
        _refusal(await app.service.lock(personId: ninoId, text: secretText)),
        AnywhereFailure.failed,
      );
      expect(app.rows, isEmpty);
    });
  });

  group('the person last used in each app', () {
    setUp(() async {
      app.storeSettings(_on);
      await app.boot();
      await app.service.unlockWithPassword(rightPassword);
    });

    test('is remembered per app and marked in people', () async {
      await app.service.lock(
        personId: ninoId,
        text: secretText,
        sourceApp: 'org.telegram.messenger',
      );

      final here = _done(
        await app.service.people(sourceApp: 'org.telegram.messenger'),
      );
      expect(here.single.id, ninoId);
      expect(here.single.name, 'Nino');
      expect(here.single.isVerified, isTrue);
      expect(here.single.isLastUsedHere, isTrue);

      final elsewhere = _done(
        await app.service.people(sourceApp: 'com.whatsapp'),
      );
      expect(elsewhere.single.isLastUsedHere, isFalse);
    });

    test('is sealed: the stored blob holds no app id and no person id',
        () async {
      await app.service.lock(
        personId: ninoId,
        text: secretText,
        sourceApp: 'org.telegram.messenger',
      );

      final stored =
          app.storage.blobs[FuzzAnywhereLocalDataSource.appPeopleKey]!;
      final asText = latin1.decode(stored);
      expect(asText, isNot(contains('telegram')));
      expect(asText, isNot(contains(ninoId)));
      verify(
        () => app.crypto.sealSetting(
          name: FuzzAnywhereSettingsRepository.appPeopleName,
          bytes: any(named: 'bytes'),
        ),
      ).called(1);
    });

    test('is forgotten when the switch is turned off', () async {
      await app.service.lock(
        personId: ninoId,
        text: secretText,
        sourceApp: 'com.whatsapp',
      );
      expect(await app.settings.setOn(false), isTrue);

      expect(
        app.storage.blobs.containsKey(FuzzAnywhereLocalDataSource.appPeopleKey),
        isFalse,
      );
      expect(await app.repository.lastPersonFor('com.whatsapp'), isNull);
    });
  });

  group('peek and open', () {
    setUp(() async {
      app.storeSettings(_on);
      await app.boot();
      await app.service.unlockWithPassword(rightPassword);
    });

    test('peek names the person and opens nothing', () async {
      final peek = _done(await app.service.peek(blobFromNino));
      expect(peek.kind, AnywhereKind.message);
      expect(peek.personId, ninoId);
      expect(peek.personName, 'Nino');

      final link = _done(
        await app.service.peek('https://ink.fuzzzycore.com/message#AwECbmlubw'),
      );
      expect(link.personName, 'Nino');
      verifyNothingOpened();
      expect(app.rows, isEmpty);
    });

    test('nothing opens without an explicit open call', () async {
      await app.service.status();
      await app.service.people();
      await app.service.peek(blobFromNino);
      await app.service.lock(personId: ninoId, text: secretText);
      await app.service.relock();

      verifyNothingOpened();
      expect(app.rows.where((row) => !row.isSent), isEmpty);
    });

    test('open keeps the message in the history and answers no text', () async {
      final opened = _done(await app.service.open(blobFromNino));

      expect(opened.personId, ninoId);
      expect(opened.personName, 'Nino');
      expect(opened.displayId, isNot(contains(openedSecret)));
      verify(() => app.crypto.decryptText(chatId: ninoId, blob: blobFromNino))
          .called(1);
      final row = app.rows.single;
      expect(row.isSent, isFalse);
      expect(row.chatId, ninoId);
      expect(row.decryptedMessage, openedSecret);
      expect(app.shown, isEmpty);
    });

    test('show puts it on the private screen once', () async {
      final opened = _done(await app.service.open(blobFromNino));

      expect(
        _refusal(await app.service.show('not-it')),
        AnywhereFailure.unknownDisplay,
      );
      expect(_refusal(await app.service.show(opened.displayId)), isNull);
      expect(app.shown.single.message.decryptedMessage, openedSecret);
      expect(app.shown.single.message.isSent, isFalse);
      expect(app.shown.single.chat.chatId, ninoId);
      expect(
        _refusal(await app.service.show(opened.displayId)),
        AnywhereFailure.unknownDisplay,
      );
    });

    test('a lock drops a message waiting to be shown', () async {
      final opened = _done(await app.service.open(blobFromNino));
      await app.authStore.lock();
      await pumpEventQueue();

      expect(
        _refusal(await app.service.show(opened.displayId)),
        AnywhereFailure.unknownDisplay,
      );
      expect(app.shown, isEmpty);
    });

    test('an already opened message says so', () async {
      when(() => app.crypto.decryptText(chatId: ninoId, blob: blobFromNino))
          .thenAnswer(
        (_) async => const CryptoCoreFailure(CryptoCoreFailureType.replay),
      );
      expect(
        _refusal(await app.service.open(blobFromNino)),
        AnywhereFailure.alreadyOpened,
      );
      expect(app.rows, isEmpty);
    });

    test('not Fuzzzy Ink text opens nothing', () async {
      expect(
        _refusal(await app.service.open('hello there')),
        AnywhereFailure.notFuzzzy,
      );
      verifyNothingOpened();
    });
    test('a lock while it is shown closes it, and relock works after',
        () async {
      final events = <AnywhereEvent>[];
      app.service.events.listen(events.add);
      final opened = _done(await app.service.open(blobFromNino));
      await app.service.show(opened.displayId);

      // The lock replaces the private screen; its display never finishes.
      await app.authStore.lock();
      await pumpEventQueue();
      expect(events.whereType<AnywhereShownClosed>(), hasLength(1));

      await app.service.unlockWithPassword(rightPassword);
      expect(await app.service.relock(), isTrue);
      expect(app.authStore.state.status, AuthStateStatus.locked);
    });
  });

  group('open in the app', () {
    setUp(() async {
      app.storeSettings(_on);
      await app.boot();
      await app.service.unlockWithPassword(rightPassword);
    });

    test("an invite goes to the app's Open screen, as if pasted there",
        () async {
      expect(_refusal(await app.service.openInApp(' $inviteBlob\n')), isNull);

      expect(app.handedOff, hasLength(1));
      final request = app.handedOff.single;
      expect(request, isA<OpenPastedText>());
      expect((request as OpenPastedText).text, inviteBlob);
      verifyNothingOpened();
      expect(app.rows, isEmpty);
    });

    test('the use goes on in the app: closing the sheet does not lock it',
        () async {
      await app.service.openInApp(inviteBlob);

      expect(await app.service.relock(), isFalse);
      expect(app.authStore.state.status, AuthStateStatus.authenticated);
    });

    test('a message is refused: it opens only through open', () async {
      expect(
        _refusal(await app.service.openInApp(blobFromNino)),
        AnywhereFailure.badRequest,
      );
      expect(
        _refusal(await app.service.openInApp('just words')),
        AnywhereFailure.badRequest,
      );
      expect(
        _refusal(await app.service.openInApp('  ')),
        AnywhereFailure.emptyText,
      );
      expect(app.handedOff, isEmpty);
      verifyNothingOpened();
    });

    test('refused while locked or switched off', () async {
      await app.authStore.lock();
      expect(
        _refusal(await app.service.openInApp(inviteBlob)),
        AnywhereFailure.locked,
      );

      await app.unlockInApp();
      await pumpEventQueue(); // the settings are read again after an unlock
      await app.settings.setOn(false);
      expect(
        _refusal(await app.service.openInApp(inviteBlob)),
        AnywhereFailure.disabled,
      );
      expect(app.handedOff, isEmpty);
    });
  });

  group('unlocking', () {
    setUp(() => app.storeSettings(_on));

    test('a wrong password counts against the app limit and its waits', () {
      fakeAsync((async) {
        final clock = async.getClock(DateTime(2026, 10, 26, 22));
        final timed = AnywhereHarness(now: clock.now)..storeSettings(_on);
        timed.boot();
        async.flushMicrotasks();

        final answers = <AnywhereResult<void>>[];
        for (var i = 0; i < AppLockThrottleData.freeAttempts; i++) {
          timed.service.unlockWithPassword('wrong').then(answers.add);
          async.flushMicrotasks();
        }
        expect(
          answers.map(_refusal),
          everyElement(AnywhereFailure.wrongPassword),
        );
        expect(timed.throttleData.failedAttempts, 5);
        final last = answers.last as AnywhereRefused<void>;
        expect(last.wait, const Duration(seconds: 30));

        // During the wait even the right password is not tried.
        timed.service.unlockWithPassword(rightPassword).then(answers.add);
        async.flushMicrotasks();
        expect(_refusal(answers.last), AnywhereFailure.lockedOut);
        verify(() => timed.chatAuth.unlock(any())).called(5);

        async.elapse(const Duration(seconds: 31));
        timed.service.unlockWithPassword(rightPassword).then(answers.add);
        async.flushMicrotasks();
        expect(_refusal(answers.last), isNull);
        expect(timed.throttleData, AppLockThrottleData.none);

        timed.dispose();
        async.flushMicrotasks();
      });
    });

    test('fingerprint or face unlocks through the app prompt', () async {
      await app.boot();
      expect(_refusal(await app.service.unlockWithBiometrics()), isNull);
      expect(app.authStore.state.status, AuthStateStatus.authenticated);
      verify(() => app.biometrics.readPassword(BiometricScope.chat)).called(1);
    });

    test('a cancelled prompt leaves the app locked', () async {
      when(() => app.biometrics.readPassword(BiometricScope.chat))
          .thenAnswer((_) async => const BiometricNotRead());
      await app.boot();
      expect(
        _refusal(await app.service.unlockWithBiometrics()),
        AnywhereFailure.notUnlocked,
      );
      expect(app.authStore.state.status, AuthStateStatus.locked);
    });
  });

  group('lock again after each use', () {
    setUp(() => app.storeSettings(_on));

    test('locks the app this entry point unlocked', () {
      fakeAsync((async) {
        final app = AnywhereHarness()..storeSettings(_on);
        app.boot();
        async.flushMicrotasks();
        app.service.unlockWithPassword(rightPassword);
        async.flushMicrotasks();
        app.service.lock(personId: ninoId, text: secretText);
        async.flushMicrotasks();

        bool? relocked;
        app.service.relock().then((value) => relocked = value);
        async.flushMicrotasks();
        expect(relocked, isTrue);
        expect(app.authStore.state.status, AuthStateStatus.locked);
        verify(app.crypto.close).called(1);
        app.dispose();
        async.flushMicrotasks();
      });
    });

    test('leaves the app open when it was already open', () async {
      await app.boot();
      await app.unlockInApp();
      await app.service.lock(personId: ninoId, text: secretText);

      expect(await app.service.relock(), isFalse);
      expect(app.authStore.state.status, AuthStateStatus.authenticated);
    });

    test('off: the app stays open', () async {
      app.storeSettings(
        const FuzzAnywhereSettings(isOn: true, locksAgainAfterUse: false),
      );
      await app.boot();
      await app.service.unlockWithPassword(rightPassword);

      expect(await app.service.relock(), isFalse);
      expect(app.authStore.state.status, AuthStateStatus.authenticated);
    });

    test('after show, when the private screen closes', () {
      fakeAsync((async) {
        final app = AnywhereHarness()..storeSettings(_on);
        final events = <AnywhereEvent>[];
        app.service.events.listen(events.add);
        app.boot();
        async.flushMicrotasks();
        app.service.unlockWithPassword(rightPassword);
        async.flushMicrotasks();
        late AnywhereResult<AnywhereOpened> opened;
        app.service.open(blobFromNino).then((value) => opened = value);
        async.flushMicrotasks();
        app.service.show(_done(opened).displayId);
        async.flushMicrotasks();

        // The caller's sheet closed: not while the message is on screen.
        bool? relocked;
        app.service.relock().then((value) => relocked = value);
        async.flushMicrotasks();
        expect(relocked, isFalse);
        expect(app.authStore.state.status, AuthStateStatus.authenticated);

        app.displayClosed!.complete();
        async.flushMicrotasks();
        expect(app.authStore.state.status, AuthStateStatus.locked);
        expect(events.whereType<AnywhereShownClosed>(), hasLength(1));
        expect(
          events.whereType<AnywhereLockChanged>().map((e) => e.isUnlocked),
          [true, false],
        );
        app.dispose();
        async.flushMicrotasks();
      });
    });
  });
}
