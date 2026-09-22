import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockCryptoCoreService extends Mock implements CryptoCoreService {}

const _result = FileBenchmarkResult(
  sizeBytes: 64 * 1024 * 1024,
  encryptMbPerSecond: 123.4,
  decryptMbPerSecond: 130.1,
  encryptKeyDerivation: Duration(milliseconds: 900),
  decryptKeyDerivation: Duration(milliseconds: 880),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCryptoCoreService mockService;
  late Directory temp;

  setUp(() {
    mockService = MockCryptoCoreService();
    temp = Directory.systemTemp.createTempSync('file_benchmark_cubit_');
    // path_provider's method channel, as the plugin is not registered here.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => temp.path,
    );
    when(
      () => mockService.benchmarkFiles(
        directoryPath: any(named: 'directoryPath'),
        sizeMiB: any(named: 'sizeMiB'),
      ),
    ).thenAnswer((_) async => const CryptoCoreSuccess(_result));
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  FileBenchmarkCubit build() =>
      FileBenchmarkCubit(cryptoCoreService: mockService);

  final loading = isA<FileBenchmarkState>()
      .having((s) => s.status, 'status', StateStatus.loading);

  blocTest<FileBenchmarkCubit, FileBenchmarkState>(
    'runs the benchmark in the temporary directory and keeps the result',
    build: build,
    act: (cubit) => cubit.run(),
    expect: () => [
      loading,
      isA<FileBenchmarkState>()
          .having((s) => s.status, 'status', StateStatus.success)
          .having((s) => s.result, 'result', _result)
          .having((s) => s.failure, 'failure', isNull),
    ],
    verify: (_) {
      verify(
        () => mockService.benchmarkFiles(directoryPath: temp.path),
      ).called(1);
    },
  );

  blocTest<FileBenchmarkCubit, FileBenchmarkState>(
    'a service failure is failed with a failure attached',
    setUp: () {
      when(
        () => mockService.benchmarkFiles(
          directoryPath: any(named: 'directoryPath'),
          sizeMiB: any(named: 'sizeMiB'),
        ),
      ).thenAnswer(
        (_) async => const CryptoCoreFailure(CryptoCoreFailureType.internal),
      );
    },
    build: build,
    act: (cubit) => cubit.run(),
    expect: () => [
      loading,
      isA<FileBenchmarkState>()
          .having((s) => s.status, 'status', StateStatus.failed)
          .having((s) => s.result, 'result', isNull)
          .having((s) => s.failure, 'failure', isNotNull),
    ],
  );

  blocTest<FileBenchmarkCubit, FileBenchmarkState>(
    'a second tap while running is ignored',
    build: build,
    act: (cubit) async {
      final first = cubit.run();
      await cubit.run();
      await first;
    },
    expect: () => [loading, isA<FileBenchmarkState>()],
    verify: (_) {
      verify(
        () => mockService.benchmarkFiles(
          directoryPath: any(named: 'directoryPath'),
        ),
      ).called(1);
    },
  );
}
