import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Secret and plaintext fields keep their text in the app (security review
/// 2026-10-26): no Copy, Cut, Share, Look Up or other app's text action in
/// the menu, no copy shortcut, and no keyboard suggestions or learning.
void main() {
  Future<TextField> pump(WidgetTester tester, Widget field) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
        localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
        supportedLocales: FuzzzyInkLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: field)),
      ),
    );
    return tester.widget<TextField>(find.byType(TextField));
  }

  void expectGuarded(TextField field) {
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.enableIMEPersonalizedLearning, isFalse);
    expect(field.contextMenuBuilder, CopyGuard.plaintextContextMenuBuilder);
  }

  testWidgets('a guarded field: no learning, the allow-list menu',
      (tester) async {
    final controller = TextEditingController(text: 'secret');
    addTearDown(controller.dispose);
    final field = await pump(
      tester,
      GuardedTextField(controller: controller, label: 'Text', qaId: 'g'),
    );
    expectGuarded(field);
    expect(find.byKey(const Key('field.g')), findsOneWidget);
  });

  testWidgets('a password field, shown or hidden, is guarded', (tester) async {
    final controller = TextEditingController(text: 'hunter2-hunter2');
    addTearDown(controller.dispose);
    var field = await pump(
      tester,
      InkPasswordField(controller: controller, label: 'Password', qaId: 'p'),
    );
    expectGuarded(field);
    expect(field.obscureText, isTrue);
    await tester.tap(find.byKey(const Key('iconbtn.p.peek')));
    await tester.pump();
    field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isFalse);
    expect(field.keyboardType, TextInputType.visiblePassword);
    expectGuarded(field);
  });

  testWidgets('the menu of a selected secret has no way out of the app',
      (tester) async {
    final controller = TextEditingController(text: 'decrypted secret');
    addTearDown(controller.dispose);
    await pump(tester, GuardedTextField(controller: controller, qaId: 'm'));
    final state = tester.state<EditableTextState>(find.byType(EditableText));
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 9);
    await tester.pump();
    final offered = CopyGuard.plaintextMenuItems(
      state.contextMenuButtonItems,
    ).map((item) => item.type);
    expect(offered, isNot(contains(ContextMenuButtonType.copy)));
    expect(offered, isNot(contains(ContextMenuButtonType.cut)));
    expect(offered, isNot(contains(ContextMenuButtonType.share)));
    expect(offered, isNot(contains(ContextMenuButtonType.custom)));
  });

  testWidgets('Ctrl/Cmd+C does not copy out of a guarded field',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final controller = TextEditingController(text: 'decrypted secret');
    addTearDown(controller.dispose);
    await pump(tester, GuardedTextField(controller: controller, qaId: 'k'));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 9);
    await tester.pump();
    for (final modifier in [
      LogicalKeyboardKey.control,
      LogicalKeyboardKey.meta,
    ]) {
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(modifier);
      await tester.pump();
    }
    expect(copied, isNull);
  });
}
