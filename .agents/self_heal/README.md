# Flutter Self-Heal Protocol

When requested to test, "Self-Heal", or fix a bug, activate autonomous bug-fixing mode for the Flutter application.

## 1. The Healing Loop
When presented with a build error, crash log, or test failure:
1.  **Analyze:** Read the stack trace. Identify the exact file, line number, and error type (e.g., `Null check operator used on a null value`, `LateInitializationError`).
2.  **Hypothesize:** State the probable cause in one sentence. (e.g., "The `user` object is null in the state when the `build` method is called.").
3.  **Fix:** Apply the minimal required code change. This could be adding a null check, initializing a variable, or handling a specific state in the UI.
4.  **Verify:** Formulate the exact command to re-run to confirm the fix (`fvm flutter test path/to/failing_test.dart` or `fvm flutter analyze`).
5.  **Loop:** If the verification fails, analyze the new error. Do not repeat the same failed fix. Stop after 3 failed attempts on the same conceptual issue and ask the user for architectural guidance.

## 2. Test Generation Templates
Structure all tests using Arrange, Act, Assert (AAA) and the `bloc_test` or `flutter_test` libraries.

### Cubit Testing Template (using `bloc_test` and `mocktail`)
```dart
// test/features/my_feature/bloc/my_cubit_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
// ... other imports

// Mock your repository
class MockMyRepository extends Mock implements MyRepository {}

void main() {
  late MyRepository mockRepo;
  late MyCubit myCubit;

  setUp(() {
    mockRepo = MockMyRepository();
    myCubit = MyCubit(repository: mockRepo);
  });

  blocTest<MyCubit, MyState>(
    'emits [loading, success] when repository returns a successful response',
    // Arrange: Set up the mock repository's behavior
    build: () {
      when(() => mockRepo.fetchData()).thenAnswer((_) async => FetchDataSuccess(data: 'mock_data'));
      return myCubit;
    },
    // Act: Call the method on the cubit
    act: (cubit) => cubit.fetch(),
    // Assert: Check the sequence of emitted states
    expect: () => [
      const MyState(status: StateStatus.loading),
      const MyState(status: StateStatus.success, data: 'mock_data'),
    ],
    // Verify: Ensure the mock was called as expected
    verify: (_) {
      verify(() => mockRepo.fetchData()).called(1);
    },
  );
}
```
