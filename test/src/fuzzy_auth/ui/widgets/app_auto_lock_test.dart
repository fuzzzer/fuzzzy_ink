import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:mocktail/mocktail.dart';

class MockFuzzyAuthStore extends MockCubit<FuzzyAuthState>
    implements FuzzyAuthStore {}

class MockAutoLockCubit extends MockCubit<AutoLockSettings>
    implements AutoLockCubit {}

/// The whole-app auto-lock: idle time without a touch, time in the
/// background, and nothing while the app is locked.
void main() {
  late MockFuzzyAuthStore store;
  late MockAutoLockCubit autoLock;

  final unlocked = const FuzzyAuthState.initial()
      .copyWith(status: AuthStateStatus.authenticated);

  setUp(() {
    store = MockFuzzyAuthStore();
    autoLock = MockAutoLockCubit();
    when(() => store.lock()).thenAnswer((_) async {});
    when(() => autoLock.load()).thenAnswer((_) async {});
    whenListen(
      autoLock,
      const Stream<AutoLockSettings>.empty(),
      initialState: AutoLockSettings.standard,
    );
  });

  Future<void> pump(WidgetTester tester, FuzzyAuthState state) async {
    whenListen(
      store,
      Stream.value(state),
      initialState: const FuzzyAuthState.initial(),
    );
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<FuzzyAuthStore>.value(value: store),
          BlocProvider<AutoLockCubit>.value(value: autoLock),
        ],
        child: const AppAutoLock(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox.expand(key: ValueKey('content')),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('locks after the idle time without a touch', (tester) async {
    await pump(tester, unlocked);
    verify(() => autoLock.load()).called(1);

    await tester.pump(const Duration(minutes: 4));
    verifyNever(() => store.lock());
    await tester.pump(const Duration(minutes: 1, seconds: 1));
    verify(() => store.lock()).called(1);
  });

  testWidgets('a touch starts the idle time again', (tester) async {
    await pump(tester, unlocked);

    await tester.pump(const Duration(minutes: 4));
    await tester.tap(find.byKey(const ValueKey('content')));
    await tester.pump(const Duration(minutes: 4));
    verifyNever(() => store.lock());
    await tester.pump(const Duration(minutes: 1, seconds: 1));
    verify(() => store.lock()).called(1);
  });

  testWidgets('locks once the app has been in the background for a minute',
      (tester) async {
    await pump(tester, unlocked);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 59));
    verifyNever(() => store.lock());
    await tester.pump(const Duration(seconds: 2));
    verify(() => store.lock()).called(1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('"at once" locks as the app leaves', (tester) async {
    whenListen(
      autoLock,
      const Stream<AutoLockSettings>.empty(),
      initialState:
          AutoLockSettings.standard.copyWith(background: Duration.zero),
    );
    await pump(tester, unlocked);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    verifyNever(() => store.lock());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    verify(() => store.lock()).called(1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('a locked app runs no timer', (tester) async {
    await pump(
      tester,
      const FuzzyAuthState.initial().copyWith(status: AuthStateStatus.locked),
    );
    await tester.pump(const Duration(minutes: 40));
    verifyNever(() => store.lock());
  });
}
