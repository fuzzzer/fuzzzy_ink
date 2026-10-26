import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// Puts "Lock from other apps" into the app when the build has it
/// ([fuzzAnywhereEnabled]): provides [FuzzAnywhereSettingsCubit] for
/// Settings and answers the platform code on `com.fuzzzycore.ink/anywhere`.
/// Without the flag it is only its [child]: no cubit, no channel handler.
///
/// Sits below the app's global providers (the lock, the file queues the
/// Lock and Open flows share) and above the router.
class FuzzAnywhereHost extends StatefulWidget {
  const FuzzAnywhereHost({
    super.key,
    required this.child,
    this.isEnabled = fuzzAnywhereEnabled,
  });

  final Widget child;

  /// The build flag; tests set it.
  final bool isEnabled;

  @override
  State<FuzzAnywhereHost> createState() => _FuzzAnywhereHostState();
}

class _FuzzAnywhereHostState extends State<FuzzAnywhereHost> {
  FuzzAnywhereSettingsCubit? _settings;
  FuzzAnywhereService? _service;
  FuzzAnywhereChannel? _channel;

  @override
  void initState() {
    super.initState();
    if (!widget.isEnabled) return;
    final settings = FuzzAnywhereSettingsCubit(
      repository: sl.get<FuzzAnywhereSettingsRepository>(),
    );
    final sendQueue = context.read<FileProcessingCubit<FileEncryptionOption>>();
    final receiveQueue =
        context.read<FileProcessingCubit<FileDecryptionOption>>();
    final service = FuzzAnywhereService(
      authStore: context.read<FuzzyAuthStore>(),
      settings: settings,
      settingsRepository: sl.get<FuzzAnywhereSettingsRepository>(),
      biometricAuthRepository: sl.get<BiometricAuthRepository>(),
      cryptoCoreService: sl.get<CryptoCoreService>(),
      chatRepository: sl.get<ChatGeneralDataListRepository>(),
      lockFlow: (chat) => LockFlowCubit(
        target: LockTarget.person(chat),
        cryptoCoreService: sl.get<CryptoCoreService>(),
        messageDataRepository: sl.get<MessageDataRepository>(),
        userFileStore: sl.get<UserFileStore>(),
        passwordStrengthService: sl.get<PasswordStrengthService>(),
        chatFileQueue: sendQueue,
      ),
      openFlow: () => OpenFlowCubit(
        cryptoCoreService: sl.get<CryptoCoreService>(),
        chatRepository: sl.get<ChatGeneralDataListRepository>(),
        messageDataRepository: sl.get<MessageDataRepository>(),
        userFileStore: sl.get<UserFileStore>(),
        receiveQueue: receiveQueue,
      ),
      display: _showOpened,
      presentOpen: _presentOpen,
    );
    _settings = settings;
    _service = service;
    _channel = FuzzAnywhereChannel(service: service)..attach();
  }

  /// The opened message on the history item screen (private, behind the
  /// lock); done when it is closed, or dropped by a lock.
  static Future<void> _showOpened(HistoryItemPagePayload payload) async {
    final router = AppRouter.routerInstance;
    if (router == null) return;
    await router.push<void>(AppRouter.personItem, extra: payload);
  }

  /// The app's Open screen with a sealed text filled in ("Open in Fuzzzy
  /// Ink" from another app).
  static Future<void> _presentOpen(OpenPagePayload payload) async {
    final router = AppRouter.routerInstance;
    if (router == null) return;
    await router.push<void>(AppRouter.open, extra: payload);
  }

  @override
  void dispose() {
    final channel = _channel;
    final service = _service;
    final settings = _settings;
    unawaited(() async {
      await channel?.detach();
      await service?.dispose();
      await settings?.close();
    }());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (settings == null) return widget.child;
    return BlocProvider<FuzzAnywhereSettingsCubit>.value(
      value: settings,
      child: widget.child,
    );
  }
}
