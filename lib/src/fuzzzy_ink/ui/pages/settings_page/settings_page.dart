import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late CopySecurityLevel _securityLevel;
  late final FileBenchmarkCubit? _fileBenchmarkCubit;

  @override
  void initState() {
    super.initState();
    _securityLevel = sl.get<PreferencesService>().copySecurityLevel;
    _fileBenchmarkCubit = isFileBenchmarkEnabled
        ? FileBenchmarkCubit(cryptoCoreService: sl.get<CryptoCoreService>())
        : null;
  }

  @override
  void dispose() {
    _fileBenchmarkCubit?.close();
    super.dispose();
  }

  void _onSecurityLevelChanged(CopySecurityLevel level) {
    sl.get<PreferencesService>().setCopySecurityLevel(level);
    setState(() {
      _securityLevel = level;
    });
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
                Clipboard.setData(ClipboardData(text: summary)).then((_) {
                  if (!context.mounted) return;
                  FuzzzyToast.show(
                    context,
                    message: localizations.copiedToTheClipboard,
                  );
                });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fuzzzyColors = context.fuzzzyColors;
    final fuzzzyTextStyles = context.fuzzzyTextStyles;
    final localizations = context.fuzzzyInkLocalizations;

    final isStrict = _securityLevel == CopySecurityLevel.strict;
    final fileBenchmarkCubit = _fileBenchmarkCubit;

    return FuzzyScaffold(
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
                    localizations.securityLevel,
                    style: fuzzzyTextStyles.titleM.copyWith(
                      color: fuzzzyColors.ink,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isStrict
                        ? localizations.strictSecurityDescription
                        : localizations.moderateSecurityDescription,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: fuzzzyColors.inkMute,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SecurityLevelTile(
                    label: localizations.strict,
                    icon: Icons.lock,
                    isSelected: isStrict,
                    color: fuzzzyColors.destructiveText,
                    onTap: () =>
                        _onSecurityLevelChanged(CopySecurityLevel.strict),
                    fuzzzyColors: fuzzzyColors,
                    fuzzzyTextStyles: fuzzzyTextStyles,
                  ),
                  const SizedBox(height: 12),
                  _SecurityLevelTile(
                    label: localizations.moderate,
                    icon: Icons.lock_open,
                    isSelected: !isStrict,
                    color: fuzzzyColors.focus,
                    onTap: () =>
                        _onSecurityLevelChanged(CopySecurityLevel.moderate),
                    fuzzzyColors: fuzzzyColors,
                    fuzzzyTextStyles: fuzzzyTextStyles,
                  ),
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
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
              Icons.chevron_right,
              color: fuzzzyColors.inkMute,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityLevelTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;
  final FuzzzyColors fuzzzyColors;
  final FuzzzyTextStyles fuzzzyTextStyles;

  const _SecurityLevelTile({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
    required this.fuzzzyColors,
    required this.fuzzzyTextStyles,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withValues(alpha: 0.12) : fuzzzyColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                isSelected ? color : fuzzzyColors.focus.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? color : fuzzzyColors.inkMute,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: fuzzzyTextStyles.body.copyWith(
                  color: isSelected ? color : fuzzzyColors.ink,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
