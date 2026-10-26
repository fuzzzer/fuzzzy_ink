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

  testWidgets(
      'the device clock set back while away locks on return (security '
      'review 2026-10-26)', (tester) async {
    final real = AppAutoLock.wallClock;
    addTearDown(() => AppAutoLock.wallClock = real);
    var wall = DateTime(2026, 10, 26, 12);
    AppAutoLock.wallClock = () => wall;
    await pump(tester, unlocked);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    wall = wall.subtract(const Duration(hours: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    verify(() => store.lock()).called(1);
  });

  test('the longer of the two clocks counts; a negative wall clock locks', () {
    const minute = Duration(minutes: 1);
    expect(
      AppAutoLock.isAwayTooLong(
        wall: const Duration(seconds: -5),
        monotonic: Duration.zero,
        background: minute,
      ),
      isTrue,
    );
    expect(
      AppAutoLock.isAwayTooLong(
        wall: const Duration(seconds: 10),
        monotonic: const Duration(minutes: 2),
        background: minute,
      ),
      isTrue,
      reason: 'the clock was set forward… or back by less than the time away',
    );
    expect(
      AppAutoLock.isAwayTooLong(
        wall: const Duration(minutes: 3),
        monotonic: const Duration(seconds: 10),
        background: minute,
      ),
      isTrue,
      reason: 'a phone asleep: the monotonic clock paused',
    );
    expect(
      AppAutoLock.isAwayTooLong(
        wall: const Duration(seconds: 10),
        monotonic: const Duration(seconds: 10),
        background: minute,
      ),
      isFalse,
    );
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
