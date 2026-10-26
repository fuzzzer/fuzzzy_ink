import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';

import '../../fuzz_anywhere_fakes.dart';

const _codec = StandardMethodCodec();

/// Whether anything in Dart answers the platform's `status` call.
Future<bool> _answersStatus(WidgetTester tester) async {
  var answered = false;
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    fuzzAnywhereMethodChannel.name,
    _codec.encodeMethodCall(const MethodCall('status')),
    (data) => answered = data != null,
  );
  return answered;
}

void main() {
  setUpAll(registerAnywhereFallbacks);

  late AnywhereHarness app;

  setUp(() => app = AnywhereHarness());
  tearDown(() => app.dispose());

  Future<void> pumpHost(WidgetTester tester, {required bool flag}) =>
      tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<FuzzyAuthStore>.value(value: app.authStore),
            BlocProvider<FileProcessingCubit<FileEncryptionOption>>.value(
              value: app.sendQueue,
            ),
            BlocProvider<FileProcessingCubit<FileDecryptionOption>>.value(
              value: app.receiveQueue,
            ),
          ],
          child: FuzzAnywhereHost(
            isEnabled: flag,
            child: Builder(
              builder: (context) => Text(
                context.read<FuzzAnywhereSettingsCubit?>() == null
                    ? 'no settings'
                    : 'settings',
                textDirection: TextDirection.ltr,
              ),
            ),
          ),
        ),
      );

  testWidgets('without the build flag: no handler and no settings',
      (tester) async {
    await pumpHost(tester, flag: false);

    expect(find.text('no settings'), findsOneWidget);
    expect(await _answersStatus(tester), isFalse);
  });

  group('with the build flag', () {
    setUp(() {
      sl
        ..safeRegisterSingleton<FuzzAnywhereSettingsRepository>(app.repository)
        ..safeRegisterSingleton<BiometricAuthRepository>(app.biometrics)
        ..safeRegisterSingleton<CryptoCoreService>(app.crypto)
        ..safeRegisterSingleton<ChatGeneralDataListRepository>(app.chats)
        ..safeRegisterSingleton<MessageDataRepository>(app.messages)
        ..safeRegisterSingleton<UserFileStore>(app.userFiles)
        ..safeRegisterSingleton<PasswordStrengthService>(
          PasswordStrengthService(),
        );
    });

    tearDown(() async {
      await sl.unregister<FuzzAnywhereSettingsRepository>();
      await sl.unregister<BiometricAuthRepository>();
      await sl.unregister<CryptoCoreService>();
      await sl.unregister<ChatGeneralDataListRepository>();
      await sl.unregister<MessageDataRepository>();
      await sl.unregister<UserFileStore>();
      await sl.unregister<PasswordStrengthService>();
    });

    testWidgets('the handler answers, and goes with the host', (tester) async {
      await pumpHost(tester, flag: true);

      expect(find.text('settings'), findsOneWidget);
      expect(await _answersStatus(tester), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(await _answersStatus(tester), isFalse);
    });
  });
}
