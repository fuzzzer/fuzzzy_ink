import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// The desktop keys (DESIGN.md section 6): ⌘ on a Mac, Ctrl on Windows and
/// Linux; nothing on a phone.
void main() {
  late List<String> done;

  Future<void> pump(WidgetTester tester) async {
    done = [];
    await tester.pumpWidget(
      MaterialApp(
        home: DesktopShortcuts(
          onLock: () => done.add('lock'),
          onOpen: () => done.add('open'),
          onSettings: () => done.add('settings'),
          onLockApp: () => done.add('lock the app'),
          child: const Text('tabs'),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey modifier,
    LogicalKeyboardKey key, {
    bool shift = false,
  }) async {
    await tester.sendKeyDownEvent(modifier);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(key);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(modifier);
    await tester.pump();
  }

  testWidgets('a Mac uses ⌘',
      variant: TargetPlatformVariant.only(
        TargetPlatform.macOS,
      ), (tester) async {
    await pump(tester);
    const meta = LogicalKeyboardKey.metaLeft;
    await press(tester, meta, LogicalKeyboardKey.keyL);
    await press(tester, meta, LogicalKeyboardKey.keyO);
    await press(tester, meta, LogicalKeyboardKey.comma);
    await press(tester, meta, LogicalKeyboardKey.keyL, shift: true);
    expect(done, ['lock', 'open', 'settings', 'lock the app']);

    // Ctrl is not the Mac's key.
    await press(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.keyL,
    );
    expect(done, hasLength(4));
  });

  testWidgets('Windows and Linux use Ctrl',
      variant: const TargetPlatformVariant({
        TargetPlatform.windows,
        TargetPlatform.linux,
      }), (tester) async {
    await pump(tester);
    const control = LogicalKeyboardKey.controlLeft;
    await press(tester, control, LogicalKeyboardKey.keyL);
    await press(tester, control, LogicalKeyboardKey.keyO);
    await press(tester, control, LogicalKeyboardKey.comma);
    await press(tester, control, LogicalKeyboardKey.keyL, shift: true);
    expect(done, ['lock', 'open', 'settings', 'lock the app']);

    await press(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.keyO);
    expect(done, hasLength(4));
  });

  testWidgets('a key without ⌘ or Ctrl is just typing',
      variant: TargetPlatformVariant.desktop(), (tester) async {
    await pump(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.pump();
    expect(done, isEmpty);
  });

  testWidgets('a phone has no shortcuts and no extra focus',
      variant: TargetPlatformVariant.mobile(), (tester) async {
    await pump(tester);
    expect(find.byType(CallbackShortcuts), findsNothing);
    await press(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.keyL,
    );
    expect(done, isEmpty);
  });
}
