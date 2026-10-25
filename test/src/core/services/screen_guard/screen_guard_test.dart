import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

void main() {
  const channel = MethodChannel('test/screen_guard');
  late List<bool> secureCalls;

  setUp(() {
    secureCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'setSecure') secureCalls.add(call.arguments as bool);
      return true;
    });
    ScreenGuard.instance = ScreenGuard(channel: channel);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    ScreenGuard.instance = ScreenGuard();
  });

  final navigatorKey = GlobalKey<NavigatorState>();

  Widget host(Widget home) => MaterialApp(
        navigatorKey: navigatorKey,
        theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
        home: home,
      );

  test('protects once for any number of visible sensitive screens', () async {
    ScreenGuard.instance
      ..sensitiveScreenShown()
      ..sensitiveScreenShown()
      ..sensitiveScreenHidden();
    expect(ScreenGuard.instance.isProtecting, isTrue);
    ScreenGuard.instance
      ..sensitiveScreenHidden()
      ..sensitiveScreenHidden();
    await Future<void>.delayed(Duration.zero);

    expect(ScreenGuard.instance.isProtecting, isFalse);
    expect(secureCalls, [true, false]);
  });

  testWidgets('a sensitive page protects the window while it is visible',
      (tester) async {
    await tester.pumpWidget(
      host(const SensitiveScreen(child: Text('vault'))),
    );
    expect(secureCalls, [true]);

    // A dialog leaves the page visible: still protected.
    unawaited(
      showDialog<void>(
        context: navigatorKey.currentContext!,
        builder: (_) => const AlertDialog(content: Text('sure?')),
      ),
    );
    await tester.pumpAndSettle();
    expect(secureCalls, [true]);
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    // A plain page on top hides it: protection off until it comes back.
    unawaited(
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('settings')),
      ),
    );
    await tester.pumpAndSettle();
    expect(secureCalls, [true, false]);

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(secureCalls, [true, false, true]);

    await tester.pumpWidget(host(const Text('chat list')));
    expect(secureCalls, [true, false, true, false]);
  });

  testWidgets('on a phone the page is covered whenever the app is not in front',
      variant: const TargetPlatformVariant(
        {TargetPlatform.android, TargetPlatform.iOS},
      ), (tester) async {
    await tester.pumpWidget(
      host(const SensitiveScreen(child: Text('decrypted note'))),
    );
    const cover = Key('sensitive_screen.cover');
    expect(find.byKey(cover), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.byKey(cover), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.byKey(cover), findsNothing);
  });

  testWidgets('a desktop window losing focus is not covered',
      variant: TargetPlatformVariant.desktop(), (tester) async {
    await tester.pumpWidget(
      host(const SensitiveScreen(child: Text('decrypted note'))),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(find.byKey(const Key('sensitive_screen.cover')), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}
