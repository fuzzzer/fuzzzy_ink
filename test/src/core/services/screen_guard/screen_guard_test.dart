import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

void main() {
  const channel = MethodChannel('test/screen_guard');
  late List<bool> secureCalls;
  late List<Object?> coverCalls;

  setUp(() {
    secureCalls = [];
    coverCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'setSecure') secureCalls.add(call.arguments as bool);
      if (call.method == 'setCover') coverCalls.add(call.arguments);
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

  group('app-switcher cover', () {
    test('the cover paints the 3x mark of the look', () {
      expect(
        ScreenGuard.coverMarkAsset(Brightness.dark),
        'assets/logo/3.0x/ink_mark.png',
      );
      expect(
        ScreenGuard.coverMarkAsset(Brightness.light),
        'assets/logo/3.0x/ink_mark_paper.png',
      );
      for (final brightness in Brightness.values) {
        expect(
          File(ScreenGuard.coverMarkAsset(brightness)).existsSync(),
          isTrue,
        );
      }
    });

    testWidgets('iOS: the app tells the cover its look, once per change',
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        (tester) async {
      final night = FuzzzyTheme.build(inkPack, FuzzzySkin.night);
      final paper = FuzzzyTheme.build();
      Widget app(ThemeData theme, Brightness brightness) => AppSwitcherCover(
            ground: theme.extension<FuzzzyColors>()!.ground,
            brightness: brightness,
            child: const SizedBox.shrink(),
          );

      await tester.pumpWidget(app(night, Brightness.dark));
      await tester.pumpWidget(app(night, Brightness.dark));
      await tester.pumpWidget(app(paper, Brightness.light));

      expect(coverCalls, [
        {
          'ground': night.extension<FuzzzyColors>()!.ground.toARGB32(),
          'mark': 'assets/logo/3.0x/ink_mark.png',
        },
        {
          'ground': paper.extension<FuzzzyColors>()!.ground.toARGB32(),
          'mark': 'assets/logo/3.0x/ink_mark_paper.png',
        },
      ]);
    });

    testWidgets('no other platform has a native cover to tell',
        variant: const TargetPlatformVariant({
          TargetPlatform.android,
          TargetPlatform.macOS,
          TargetPlatform.windows,
          TargetPlatform.linux,
        }), (tester) async {
      await tester.pumpWidget(
        const AppSwitcherCover(
          ground: Color(0xFF121417),
          brightness: Brightness.dark,
          child: SizedBox.shrink(),
        ),
      );
      expect(coverCalls, isEmpty);
    });
  });
}
