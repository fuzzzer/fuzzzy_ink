import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// Records what the guard writes and answers clears like the native side.
class _FakeSecureClipboard extends SecureClipboard {
  final List<({String text, bool sensitive, Duration clearAfter})> writes = [];
  int clears = 0;
  ClipboardClearResult clearAnswer = ClipboardClearResult.cleared;

  @override
  Future<void> write(
    String text, {
    required bool sensitive,
    required Duration clearAfter,
  }) async {
    writes.add((text: text, sensitive: sensitive, clearAfter: clearAfter));
  }

  @override
  Future<ClipboardClearResult> clearIfStillOurs() async {
    clears++;
    return clearAnswer;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CopyPolicy', () {
    const policy = CopyPolicy();

    test('sealed output the user sends may be copied', () {
      for (final content in [
        CopyContent.sealedMessage,
        CopyContent.sealedInvitation,
        CopyContent.sealedAcceptance,
        CopyContent.sealedLink,
        CopyContent.sealedText,
      ]) {
        expect(policy.allows(content), isTrue, reason: content.name);
        expect(policy.isSensitive(content), isFalse, reason: content.name);
        expect(policy.clearAfter(content), CopyPolicy.sealedClearAfter);
      }
    });

    test('plaintext is never copied', () {
      expect(policy.allows(CopyContent.plaintext), isFalse);
      expect(
        const CopyPolicy(allowsVaultPasswordCopy: false)
            .allows(CopyContent.plaintext),
        isFalse,
      );
    });

    test('with no rule given the policy follows Copy passwords live', () {
      addTearDown(() => vaultPasswordCopySetting.value = true);
      vaultPasswordCopySetting.value = false;
      expect(const CopyPolicy().allows(CopyContent.vaultPassword), isFalse);
      vaultPasswordCopySetting.value = true;
      expect(const CopyPolicy().allows(CopyContent.vaultPassword), isTrue);
    });

    test('a vault password follows the switch, sensitive, 30 seconds', () {
      expect(
        const CopyPolicy().allows(CopyContent.vaultPassword),
        allowVaultPasswordCopy,
      );
      expect(
        const CopyPolicy(allowsVaultPasswordCopy: false)
            .allows(CopyContent.vaultPassword),
        isFalse,
      );
      expect(policy.isSensitive(CopyContent.vaultPassword), isTrue);
      expect(
        policy.clearAfter(CopyContent.vaultPassword),
        const Duration(seconds: 30),
      );
    });
  });

  group('ClipboardGuard', () {
    test('refuses plaintext without touching the clipboard', () {
      fakeAsync((async) {
        final clipboard = _FakeSecureClipboard();
        final guard = ClipboardGuard(clipboard: clipboard);
        bool? isCopied;
        unawaited(
          guard
              .copy('hello in the clear', CopyContent.plaintext)
              .then((value) => isCopied = value),
        );
        async.flushMicrotasks();

        expect(isCopied, isFalse);
        expect(clipboard.writes, isEmpty);
        async.elapse(const Duration(minutes: 10));
        expect(clipboard.clears, 0);
        guard.dispose();
      });
    });

    test('refuses a vault password while the switch is off', () {
      fakeAsync((async) {
        final clipboard = _FakeSecureClipboard();
        final guard = ClipboardGuard(
          clipboard: clipboard,
          policy: const CopyPolicy(allowsVaultPasswordCopy: false),
        );
        unawaited(guard.copy('hunter2', CopyContent.vaultPassword));
        async.flushMicrotasks();

        expect(clipboard.writes, isEmpty);
        guard.dispose();
      });
    });

    test('copies sealed output and clears it after two minutes', () {
      fakeAsync((async) {
        final clipboard = _FakeSecureClipboard();
        final guard = ClipboardGuard(clipboard: clipboard);
        unawaited(guard.copy('FUZZ:abc', CopyContent.sealedMessage));
        async.flushMicrotasks();

        expect(clipboard.writes.single.text, 'FUZZ:abc');
        expect(clipboard.writes.single.sensitive, isFalse);
        async.elapse(const Duration(minutes: 1, seconds: 59));
        expect(clipboard.clears, 0);
        async.elapse(const Duration(seconds: 1));
        expect(clipboard.clears, 1);
        expect(guard.isClearPending, isFalse);
        guard.dispose();
      });
    });

    test('a vault password is sensitive and clears after 30 seconds', () {
      fakeAsync((async) {
        final clipboard = _FakeSecureClipboard();
        final guard = ClipboardGuard(
          clipboard: clipboard,
          // ignore: avoid_redundant_argument_values, the switch may change
          policy: const CopyPolicy(allowsVaultPasswordCopy: true),
        );
        unawaited(guard.copy('hunter2', CopyContent.vaultPassword));
        async.flushMicrotasks();

        expect(clipboard.writes.single.sensitive, isTrue);
        expect(
          clipboard.writes.single.clearAfter,
          const Duration(seconds: 30),
        );
        async.elapse(const Duration(seconds: 29));
        expect(clipboard.clears, 0);
        async.elapse(const Duration(seconds: 1));
        expect(clipboard.clears, 1);
        guard.dispose();
      });
    });

    test('a new copy restarts the clock; one clear for the latest copy', () {
      fakeAsync((async) {
        final clipboard = _FakeSecureClipboard();
        final guard = ClipboardGuard(
          clipboard: clipboard,
          // ignore: avoid_redundant_argument_values, the switch may change
          policy: const CopyPolicy(allowsVaultPasswordCopy: true),
        );
        unawaited(guard.copy('FUZZ:abc', CopyContent.sealedMessage));
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 90));
        unawaited(guard.copy('hunter2', CopyContent.vaultPassword));
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 29));
        expect(clipboard.clears, 0);
        async.elapse(const Duration(seconds: 1));
        expect(clipboard.clears, 1);
        async.elapse(const Duration(minutes: 5));
        expect(clipboard.clears, 1);
        guard.dispose();
      });
    });

    test('a clear the system refuses stays pending for the next resume', () {
      fakeAsync((async) {
        final clipboard = _FakeSecureClipboard()
          ..clearAnswer = ClipboardClearResult.unavailable;
        final guard = ClipboardGuard(clipboard: clipboard);
        unawaited(guard.copy('FUZZ:abc', CopyContent.sealedMessage));
        async
          ..flushMicrotasks()
          ..elapse(CopyPolicy.sealedClearAfter);

        expect(clipboard.clears, 1);
        expect(guard.isClearPending, isTrue);
        guard.dispose();
      });
    });
  });

  group('ClipboardGuard cleared event', () {
    test('tells when a vault password has really been cleared', () {
      fakeAsync((async) {
        final clipboard = _FakeSecureClipboard();
        final guard = ClipboardGuard(clipboard: clipboard);
        final events = <ClipboardCopyCleared>[];
        guard.cleared.listen(events.add);
        unawaited(guard.copy('hunter2', CopyContent.vaultPassword));
        async.flushMicrotasks();
        final id = guard.lastCopyId;

        async.elapse(const Duration(seconds: 29));
        expect(events, isEmpty);
        async.elapse(const Duration(seconds: 1));
        expect(events.single.copyId, id);
        expect(events.single.content, CopyContent.vaultPassword);
        guard.dispose();
      });
    });

    test('a replaced copy gets no event; the newer one does', () {
      fakeAsync((async) {
        final clipboard = _FakeSecureClipboard();
        final guard = ClipboardGuard(clipboard: clipboard);
        final events = <ClipboardCopyCleared>[];
        guard.cleared.listen(events.add);
        unawaited(guard.copy('first', CopyContent.vaultPassword));
        async.flushMicrotasks();
        final first = guard.lastCopyId;
        async.elapse(const Duration(seconds: 10));
        unawaited(guard.copy('second', CopyContent.vaultPassword));
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 30));

        expect(events.single.copyId, isNot(first));
        expect(events.single.copyId, guard.lastCopyId);
        guard.dispose();
      });
    });

    test('a clear the system refuses sends nothing until it really runs', () {
      fakeAsync((async) {
        final clipboard = _FakeSecureClipboard()
          ..clearAnswer = ClipboardClearResult.unavailable;
        final guard = ClipboardGuard(clipboard: clipboard);
        final events = <ClipboardCopyCleared>[];
        guard.cleared.listen(events.add);
        unawaited(guard.copy('hunter2', CopyContent.vaultPassword));
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 30));
        expect(events, isEmpty);

        clipboard.clearAnswer = ClipboardClearResult.notOurs;
        unawaited(guard.clearNow());
        async.flushMicrotasks();
        expect(events, hasLength(1), reason: 'gone from the clipboard');
        guard.dispose();
      });
    });
  });

  group('SecureClipboard', () {
    const channel = MethodChannel('test/guard');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final nativeCalls = <MethodCall>[];
    String? systemClipboard;

    setUp(() {
      nativeCalls.clear();
      systemClipboard = null;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            systemClipboard =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
            return null;
          case 'Clipboard.getData':
            return {'text': systemClipboard};
        }
        return null;
      });
    });

    tearDown(() {
      messenger
        ..setMockMethodCallHandler(SystemChannels.platform, null)
        ..setMockMethodCallHandler(channel, null);
    });

    test('the native side writes and judges a clear by its own mark', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        nativeCalls.add(call);
        return call.method == 'copy' ? true : 'notOurs';
      });
      final clipboard = SecureClipboard(channel: channel);

      await clipboard.write(
        'hunter2',
        sensitive: true,
        clearAfter: const Duration(seconds: 30),
      );
      expect(nativeCalls.single.arguments, {
        'text': 'hunter2',
        'sensitive': true,
        'expiresInMs': 30000,
      });
      expect(systemClipboard, isNull, reason: 'no second, unmarked copy');

      expect(await clipboard.clearIfStillOurs(), ClipboardClearResult.notOurs);
      expect(nativeCalls.last.method, 'clearIfOurs');
    });

    test('without a native side it clears only while it still holds ours',
        () async {
      final clipboard = SecureClipboard(channel: channel);

      await clipboard.write(
        'FUZZ:abc',
        sensitive: false,
        clearAfter: CopyPolicy.sealedClearAfter,
      );
      expect(systemClipboard, 'FUZZ:abc');
      expect(await clipboard.clearIfStillOurs(), ClipboardClearResult.cleared);
      expect(systemClipboard, '');

      await clipboard.write(
        'FUZZ:def',
        sensitive: false,
        clearAfter: CopyPolicy.sealedClearAfter,
      );
      systemClipboard = 'something the user copied elsewhere';
      expect(await clipboard.clearIfStillOurs(), ClipboardClearResult.notOurs);
      expect(systemClipboard, 'something the user copied elsewhere');
    });
  });

  group('plaintext fields', () {
    test('the context menu keeps paste and select all, drops the rest', () {
      void noop() {}
      final kept = CopyGuard.plaintextMenuItems([
        for (final type in ContextMenuButtonType.values)
          ContextMenuButtonItem(type: type, onPressed: noop),
      ]).map((item) => item.type);

      expect(
        kept,
        isNot(
          anyOf(
            contains(ContextMenuButtonType.copy),
            contains(ContextMenuButtonType.cut),
            contains(ContextMenuButtonType.share),
            contains(ContextMenuButtonType.lookUp),
            contains(ContextMenuButtonType.searchWeb),
          ),
        ),
      );
      expect(kept, contains(ContextMenuButtonType.paste));
      expect(kept, contains(ContextMenuButtonType.selectAll));
    });

    testWidgets('NoPlaintextCopy refuses the copy and cut shortcuts',
        (tester) async {
      String? systemClipboard;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          systemClipboard =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final controller = TextEditingController(text: 'decrypted secret');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoPlaintextCopy(
              child: TextField(controller: controller, autofocus: true),
            ),
          ),
        ),
      );
      await tester.pump();
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 9);
      await tester.pump();

      for (final modifier in [
        LogicalKeyboardKey.control,
        LogicalKeyboardKey.meta,
      ]) {
        await tester.sendKeyDownEvent(modifier);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
        await tester.sendKeyUpEvent(modifier);
        await tester.pump();
      }

      expect(systemClipboard, isNull);
      expect(controller.text, 'decrypted secret', reason: 'cut refused too');
    });
  });
}
