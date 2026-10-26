import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// The system Paste button sits inside a paste row that reads the clipboard
/// on its own tap. A tap on the button goes to the button (the platform view
/// wins at once, so the row's tap never runs and iOS never asks "Allow
/// Paste?"); a tap anywhere else on the row is the row's (security review
/// 2026-10-26).
void main() {
  late List<String> platformViewCalls;

  setUp(() {
    platformViewCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
      platformViewCalls.add(call.method);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  Future<List<String>> pumpRow(WidgetTester tester) async {
    final rowTaps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
        localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
        supportedLocales: FuzzzyInkLocalizations.supportedLocales,
        home: Scaffold(
          body: SheetDoorRow(
            qaId: 'open.paste',
            icon: Icons.content_paste,
            title: 'Paste it',
            hint: 'From the clipboard',
            onTap: () => rowTaps.add('row'),
            trailing: InkPasteButton(qaId: 'open', onPasted: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump();
    return rowTaps;
  }

  final iOS = TargetPlatformVariant.only(TargetPlatform.iOS);

  testWidgets('a tap on the Paste button is the button’s, never the row’s',
      variant: iOS, (tester) async {
    final rowTaps = await pumpRow(tester);

    await tester.tap(find.byKey(const Key('paste.open')));
    await tester.pumpAndSettle();

    expect(rowTaps, isEmpty);
    expect(platformViewCalls, contains('acceptGesture'));
    expect(platformViewCalls, isNot(contains('rejectGesture')));
  });

  testWidgets('a long press on the Paste button is the button’s too',
      variant: iOS, (tester) async {
    final rowTaps = await pumpRow(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('paste.open'))),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(rowTaps, isEmpty);
    expect(platformViewCalls, contains('acceptGesture'));
  });

  testWidgets('a tap on the rest of the row is the row’s', variant: iOS,
      (tester) async {
    final rowTaps = await pumpRow(tester);

    await tester.tap(find.text('Paste it'));
    await tester.pumpAndSettle();

    expect(rowTaps, ['row']);
    expect(platformViewCalls, isNot(contains('acceptGesture')));
  });

  testWidgets(
      'in a sheet that drags to close, a press that wanders on the button '
      'stays the button’s',
      variant: iOS, (tester) async {
    final rowTaps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
        localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
        supportedLocales: FuzzzyInkLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => SheetDoorRow(
                    qaId: 'open.paste',
                    icon: Icons.content_paste,
                    title: 'Paste it',
                    hint: 'From the clipboard',
                    onTap: () => rowTaps.add('row'),
                    trailing: InkPasteButton(qaId: 'open', onPasted: (_) {}),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('paste.open'))),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(rowTaps, isEmpty);
    expect(platformViewCalls, contains('acceptGesture'));
    expect(platformViewCalls, isNot(contains('rejectGesture')));
    expect(find.text('Paste it'), findsOneWidget, reason: 'the sheet stays');
  });
}
