import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

Widget _host({required bool isVerified}) => MaterialApp(
      theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
      localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
      supportedLocales: FuzzzyInkLocalizations.supportedLocales,
      home: Scaffold(
        body: ConnectedChatTile(
          name: 'Bob',
          isVerified: isVerified,
          onTap: () {},
          onLongPress: () {},
        ),
      ),
    );

void main() {
  testWidgets('an unverified chat carries a "not verified" mark',
      (tester) async {
    await tester.pumpWidget(_host(isVerified: false));

    expect(find.byKey(const ValueKey('chat_tile_not_verified')), findsOne);
    expect(find.text('Tap to view chat.'), findsNothing);
  });

  testWidgets('a verified chat carries no mark', (tester) async {
    await tester.pumpWidget(_host(isVerified: true));

    expect(find.byKey(const ValueKey('chat_tile_not_verified')), findsNothing);
  });
}
