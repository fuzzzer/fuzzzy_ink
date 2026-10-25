import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

export 'widgets/widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final FileBenchmarkCubit? _fileBenchmarkCubit;
  final PackageInfo _packageInfo = sl.get<PackageInfo>();

  @override
  void initState() {
    super.initState();
    _fileBenchmarkCubit = isFileBenchmarkEnabled
        ? FileBenchmarkCubit(cryptoCoreService: sl.get<CryptoCoreService>())
        : null;
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
              child: Text(
                localizations.copy,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: context.fuzzzyColors.focus,
              ),
              child: Text(
                localizations.close,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openExternalLink(Uri uri) async {
    final isOpened = await ExternalLinks.open(uri);
    if (isOpened || !mounted) return;
    FuzzzyToast.show(
      context,
      message: context.fuzzzyInkLocalizations.couldNotOpenLink,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fuzzzyColors = context.fuzzzyColors;
    final fuzzzyTextStyles = context.fuzzzyTextStyles;
    final localizations = context.fuzzzyInkLocalizations;

    final fileBenchmarkCubit = _fileBenchmarkCubit;

    return FuzzyScaffold(
      // A tab now: the bottom bar is the way out.
      hasAutomaticBackButton: false,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: FuzzzyAppBar(
              title: localizations.settings,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.copyPolicyTitle,
                    style: fuzzzyTextStyles.titleM.copyWith(
                      color: fuzzzyColors.ink,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    localizations.copyPolicyDescription,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: fuzzzyColors.inkMute,
                    ),
                  ),
                  if (allowVaultPasswordCopy) ...[
                    const SizedBox(height: 4),
                    Text(
                      localizations.copyPolicyVaultPasswordNote(
                        CopyPolicy.vaultPasswordClearAfter.inSeconds,
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: fuzzzyColors.inkMute,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  _SettingsLinkTile(
                    icon: Icons.shield_outlined,
                    title: localizations.chatAuthentication,
                    subtitle: localizations.chatAuthenticationDescription,
                    onTap: () => context.push(AppRouter.auth),
                    fuzzzyColors: fuzzzyColors,
                    fuzzzyTextStyles: fuzzzyTextStyles,
                  ),
                  const SizedBox(height: 12),
                  _SettingsLinkTile(
                    icon: Icons.lock_clock,
                    title: localizations.aboutEncryptionTitle,
                    subtitle: localizations.aboutEncryptionDescription,
                    onTap: () => context.push(AppRouter.aboutEncryption),
                    fuzzzyColors: fuzzzyColors,
                    fuzzzyTextStyles: fuzzzyTextStyles,
                  ),
                  if (fileBenchmarkCubit != null) ...[
                    const SizedBox(height: 12),
                    BlocConsumer<FileBenchmarkCubit, FileBenchmarkState>(
                      bloc: fileBenchmarkCubit,
                      listenWhen: (previous, current) =>
                          previous.status != current.status,
                      listener: (context, state) {
                        if (state.status.isSuccess) {
                          _showBenchmarkResult(state.result!);
                        } else if (state.status.isFailed) {
                          FuzzzyToast.show(
                            context,
                            message: localizations.anUnknownErrorOccurred,
                          );
                        }
                      },
                      builder: (context, state) => _SettingsLinkTile(
                        icon: Icons.speed,
                        title: localizations.benchmarkFileEncryption,
                        subtitle: state.status.isLoading
                            ? localizations.loading
                            : localizations.benchmarkFileEncryptionDescription,
                        onTap: fileBenchmarkCubit.run,
                        fuzzzyColors: fuzzzyColors,
                        fuzzzyTextStyles: fuzzzyTextStyles,
                      ),
                    ),
                  ],
                  const SettingsFuzzzyCastSection(),
                  const SettingsLookAndLanguageSection(),
                  const SizedBox(height: 32),
                  Text(
                    localizations.legalAndSupport,
                    style: fuzzzyTextStyles.titleM.copyWith(
                      color: fuzzzyColors.ink,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    localizations.legalAndSupportDescription,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: fuzzzyColors.inkMute,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SettingsLinkTile(
                    icon: Icons.privacy_tip_outlined,
                    title: localizations.privacyPolicy,
                    subtitle: localizations.privacyPolicyDescription,
                    trailingIcon: Icons.open_in_new,
                    onTap: () => _openExternalLink(ExternalLinks.privacyPolicy),
                    fuzzzyColors: fuzzzyColors,
                    fuzzzyTextStyles: fuzzzyTextStyles,
                  ),
                  const SizedBox(height: 12),
                  _SettingsLinkTile(
                    icon: Icons.description_outlined,
                    title: localizations.termsOfUse,
                    subtitle: localizations.termsOfUseDescription,
                    trailingIcon: Icons.open_in_new,
                    onTap: () => _openExternalLink(ExternalLinks.terms),
                    fuzzzyColors: fuzzzyColors,
                    fuzzzyTextStyles: fuzzzyTextStyles,
                  ),
                  const SizedBox(height: 12),
                  _SettingsLinkTile(
                    icon: Icons.help_outline,
                    title: localizations.support,
                    subtitle: localizations.supportDescription,
                    trailingIcon: Icons.open_in_new,
                    onTap: () => _openExternalLink(ExternalLinks.support),
                    fuzzzyColors: fuzzzyColors,
                    fuzzzyTextStyles: fuzzzyTextStyles,
                  ),
                  const SizedBox(height: 12),
                  _SettingsLinkTile(
                    icon: Icons.delete_outline,
                    title: localizations.dataDeletion,
                    subtitle: localizations.dataDeletionDescription,
                    trailingIcon: Icons.open_in_new,
                    onTap: () => _openExternalLink(ExternalLinks.dataDeletion),
                    fuzzzyColors: fuzzzyColors,
                    fuzzzyTextStyles: fuzzzyTextStyles,
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      localizations.appVersion(
                        _packageInfo.version,
                        _packageInfo.buildNumber,
                      ),
                      style: fuzzzyTextStyles.bodyS.copyWith(
                        color: fuzzzyColors.inkMute,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsLinkTile extends StatelessWidget {
  const _SettingsLinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.fuzzzyColors,
    required this.fuzzzyTextStyles,
    this.trailingIcon = Icons.chevron_right,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final IconData trailingIcon;
  final FuzzzyColors fuzzzyColors;
  final FuzzzyTextStyles fuzzzyTextStyles;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: fuzzzyColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: fuzzzyColors.focus.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: fuzzzyColors.ink,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: fuzzzyTextStyles.body.copyWith(
                      color: fuzzzyColors.ink,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: fuzzzyTextStyles.bodyS.copyWith(
                      color: fuzzzyColors.inkMute,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              trailingIcon,
              color: fuzzzyColors.inkMute,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
