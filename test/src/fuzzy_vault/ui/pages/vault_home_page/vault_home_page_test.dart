import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockVaultRepository extends Mock implements VaultRepository {}

/// T-0331 / T-0336: at 411 dp the "Passwords" tab first overflowed its Row,
/// then ellipsized to "Passwo…". The tab content now scales down instead, so
/// the label is laid out at its natural width and stays readable.
void main() {
  late MockVaultRepository mockRepo;
  late StreamController<VaultDataUpdated> updatesController;

  setUp(() async {
    mockRepo = MockVaultRepository();
    updatesController = StreamController<VaultDataUpdated>.broadcast();
    when(() => mockRepo.vaultDataUpdates)
        .thenAnswer((_) => updatesController.stream);
    when(() => mockRepo.getAllItems())
        .thenAnswer((_) async => const VaultSuccess([]));
    when(() => mockRepo.getAllGroups())
        .thenAnswer((_) async => const VaultSuccess([]));

    SharedPreferences.setMockInitialValues({});
    sl.safeRegisterSingleton<PreferencesService>(
      PreferencesService(await SharedPreferences.getInstance()),
    );
  });

  tearDown(() async {
    await updatesController.close();
    await sl.unregister<PreferencesService>();
  });

  testWidgets('every tab label is laid out at its natural width at 411 dp',
      (tester) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<VaultItemsCubit>(
            create: (_) => VaultItemsCubit(vaultRepository: mockRepo),
          ),
          BlocProvider<VaultGroupsCubit>(
            create: (_) => VaultGroupsCubit(vaultRepository: mockRepo),
          ),
          BlocProvider<VaultSearchCubit>(
            create: (_) => VaultSearchCubit(vaultRepository: mockRepo),
          ),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          theme: FuzzzyTheme.build(inkPack, FuzzzySkin.night),
          localizationsDelegates: FuzzzyInkLocalizations.localizationsDelegates,
          supportedLocales: FuzzzyInkLocalizations.supportedLocales,
          home: const VaultHomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final l10n = FuzzzyInkLocalizations.of(navigatorKey.currentContext!)!;
    for (final label in [
      l10n.vaultPasswords,
      l10n.vaultNotes,
      l10n.vaultFiles,
    ]) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.overflow, isNull);
      final natural = TextPainter(
        text: TextSpan(
          text: label,
          style: DefaultTextStyle.of(tester.element(find.text(label))).style,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      expect(
        tester.getSize(find.text(label)).width,
        greaterThanOrEqualTo(natural.width),
        reason: label,
      );
    }
  });
}
