import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

export 'widgets/widgets.dart';

/// The Settings tab (DESIGN.md sections 2 and 4.12, prototype `settings`):
/// Keeping it safe · My safe · Fuzzzy Cast · Look and language · Help ·
/// Developer (development builds only) · the app version. Rows: an icon, a
/// title, at most a short subtitle, a chevron or a switch. With Fuzzzy Cast
/// on, the Sun Keeper keeps the screen ([CastKeeper]): in the header or
/// beside the Fuzzzy Cast label.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FuzzyUserAuthPreferencesCubit>(
      create: (_) => FuzzyUserAuthPreferencesCubit(
        chatAuthRepository: sl.get<ChatAuthRepository>(),
        fuzzyAuthStore: context.read<FuzzyAuthStore>(),
        biometricAuthRepository: sl.get<BiometricAuthRepository>(),
        passwordStrengthService: sl.get<PasswordStrengthService>(),
        appLockThrottleRepository: sl.get<AppLockThrottleRepository>(),
        vaultPasswordThrottleRepository:
            sl.get<VaultPasswordThrottleRepository>(),
        vaultRepository: sl.get<VaultRepository>(),
      )..loadRecoveryKeyStatus(),
      child: const SettingsView(),
    );
  }
}

/// The tab's content, below a [FuzzyUserAuthPreferencesCubit].
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final FileBenchmarkCubit? _fileBenchmarkCubit;
  final PackageInfo _packageInfo = sl.get<PackageInfo>();
  bool? _canUseBiometrics;

  @override
  void initState() {
    super.initState();
    _fileBenchmarkCubit = isFileBenchmarkEnabled
        ? FileBenchmarkCubit(cryptoCoreService: sl.get<CryptoCoreService>())
        : null;
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final canUse = await sl.get<BiometricAuthRepository>().canUseBiometrics();
    if (mounted) setState(() => _canUseBiometrics = canUse);
  }

  @override
  void dispose() {
    _fileBenchmarkCubit?.close();
    super.dispose();
  }

  String _benchmarkSummary(
    FuzzzyInkLocalizations localizations,
    FileBenchmarkResult result,
  ) {
    String seconds(Duration duration) =>
        (duration.inMilliseconds / 1000).toStringAsFixed(2);

    return localizations.benchmarkResultSummary(
      result.encryptMbPerSecond.toStringAsFixed(1),
      result.decryptMbPerSecond.toStringAsFixed(1),
      result.sizeBytes ~/ (1024 * 1024),
      seconds(result.encryptKeyDerivation),
      seconds(result.decryptKeyDerivation),
      '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      kDebugMode ? 'debug' : (kProfileMode ? 'profile' : 'release'),
    );
  }

  Future<void> _showBenchmarkResult(FileBenchmarkResult result) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final localizations = context.fuzzzyInkLocalizations;
        final summary = _benchmarkSummary(localizations, result);

        return AlertDialog(
          title: Text(localizations.benchmarkResult),
          content: Text(summary),
          actions: [
            TextButton(
              onPressed: () {
                CopyGuard.copy(
                  context,
                  text: summary,
                  content: CopyContent.benchmarkReport,
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: context.fuzzzyColors.focus,
              ),
              child: Text(localizations.copy),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: context.fuzzzyColors.focus,
              ),
              child: Text(localizations.close),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;
    final fileBenchmarkCubit = _fileBenchmarkCubit;

    return CastKeeper(
      role: CastKeepers.settings,
      tabPath: AppRouter.settings,
      qaId: 'settings',
      child: ColoredBox(
        color: colors.ground,
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            key: const Key('settings.scroll'),
            slivers: [
              SliverToBoxAdapter(
                child: FuzzzyAppBar(
                  qaId: 'settings',
                  title: localizations.settings,
                  actions: const [CastKeeperSpot(0)],
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: space.l),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AccessPage.maxContentWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SettingsKeepingSafeSection(
                            canUseBiometrics: _canUseBiometrics,
                          ),
                          SettingsMySafeSection(
                            canUseBiometrics: _canUseBiometrics,
                          ),
                          const SettingsFuzzzyCastSection(),
                          const SettingsLookAndLanguageSection(),
                          SettingsSectionLabel(localizations.accessHelp),
                          FuzzzyListTile(
                            qaId: 'settings.howItWorks',
                            leading: const SettingsRowIcon(Icons.help_outline),
                            title: SettingsRowText(
                              title: localizations.accessHowFuzzzyInkWorks,
                            ),
                            chevron: true,
                            onTap: () =>
                                context.push(AppRouter.settingsHowItWorks),
                          ),
                          FuzzzyListTile(
                            qaId: 'settings.legal',
                            leading: const SettingsRowIcon(Icons.public),
                            title: SettingsRowText(
                              title: localizations.accessPrivacyTermsSupport,
                              subtitle: localizations.accessOpensYourBrowser,
                            ),
                            chevron: true,
                            divider: fileBenchmarkCubit != null,
                            onTap: () => context.push(AppRouter.settingsLegal),
                          ),
                          if (fileBenchmarkCubit != null) ...[
                            SettingsSectionLabel(localizations.accessDeveloper),
                            BlocConsumer<FileBenchmarkCubit,
                                FileBenchmarkState>(
                              bloc: fileBenchmarkCubit,
                              listenWhen: (previous, current) =>
                                  previous.status != current.status,
                              listener: (context, state) {
                                if (state.status.isSuccess) {
                                  _showBenchmarkResult(state.result!);
                                } else if (state.status.isFailed) {
                                  showInkToast(
                                    context,
                                    message:
                                        localizations.anUnknownErrorOccurred,
                                    kind: FuzzzyToastKind.error,
                                  );
                                }
                              },
                              builder: (context, state) => FuzzzyListTile(
                                qaId: 'settings.benchmark',
                                leading: const SettingsRowIcon(Icons.speed),
                                title: SettingsRowText(
                                  title: localizations.benchmarkFileEncryption,
                                  subtitle: state.status.isLoading
                                      ? localizations.loading
                                      : localizations
                                          .benchmarkFileEncryptionDescription,
                                ),
                                divider: false,
                                onTap: state.status.isLoading
                                    ? null
                                    : fileBenchmarkCubit.run,
                              ),
                            ),
                          ],
                          SizedBox(height: space.xl),
                          Text(
                            localizations.accessVersionFooter(
                              _packageInfo.version,
                              _packageInfo.buildNumber,
                            ),
                            key: const Key('settings.version'),
                            textAlign: TextAlign.center,
                            style: context.fuzzzyTextStyles.bodyS
                                .copyWith(color: colors.inkMute),
                          ),
                          SizedBox(height: space.xl),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
