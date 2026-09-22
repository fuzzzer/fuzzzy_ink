import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:mocktail/mocktail.dart';

class MockCryptoCoreService extends Mock implements CryptoCoreService {}

const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';
const _longName = 'Chat1-with-a-deliberately-very-long-name-for-the-header';

void main() {
  // T-0331: a 55-char chat name overflowed the header Row by ~238 px on a
  // phone; the title now ellipsizes and the shield stays next to it.
  testWidgets('a long chat name ellipsizes instead of overflowing the header',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final chat = ChatGeneralData(
      chatId: _chatId,
      chatName: _longName,
      setupStatus: ChatSetupStatus.connected,
      didAcceptInvitation: false,
    );
    await tester.pumpWidget(
      BlocProvider<SafetyNumberCubit>(
        create: (_) => SafetyNumberCubit(
          chatId: _chatId,
          cryptoCoreService: MockCryptoCoreService(),
        ),
        child: MaterialApp(
          theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
          localizationsDelegates: FuzzzySealLocalizations.localizationsDelegates,
          supportedLocales: FuzzzySealLocalizations.supportedLocales,
          home: Scaffold(
            body: ChatHeader(chatGeneralData: chat, onBackPressed: () {}),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final title = tester.widget<Text>(find.text(_longName));
    expect(title.overflow, TextOverflow.ellipsis);
    expect(title.maxLines, 1);
    expect(find.byKey(const ValueKey('verify_shield_button')), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });
}
