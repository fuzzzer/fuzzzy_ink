import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class MockSafetyNumberCubit extends MockCubit<SafetyNumberState>
    implements SafetyNumberCubit {}

/// Two builds that compute the safety number differently must never show
/// silently different digits: the page always shows the computation's
/// version beside them.
void main() {
  testWidgets('shows the digits together with the version that made them',
      (tester) async {
    final cubit = MockSafetyNumberCubit();
    whenListen(
      cubit,
      const Stream<SafetyNumberState>.empty(),
      initialState: const SafetyNumberState(
        status: StateStatus.success,
        safetyNumber: SafetyNumber(
          version: 7,
          digits: '12345 67890 11111 22222 33333 44444 '
              '55555 66666 77777 88888 99999 00000',
        ),
      ),
    );

    await tester.pumpWidget(
      BlocProvider<SafetyNumberCubit>.value(
        value: cubit,
        child: MaterialApp(
          theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
          localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
          supportedLocales: FuzzzyInkLocalizations.supportedLocales,
          home: ProvidedSafetyNumberPage(
            chatGeneralData: ChatGeneralData(
              chatId: '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d',
              chatName: 'Alice',
              setupStatus: ChatSetupStatus.connected,
              didAcceptInvitation: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final en = FuzzzyInkLocalizationsEn();
    expect(
      find.text(
        '12345 67890 11111\n22222 33333 44444\n'
        '55555 66666 77777\n88888 99999 00000',
      ),
      findsOneWidget,
    );
    expect(find.text(en.safetyNumberVersion(7)), findsOneWidget);
  });
}
