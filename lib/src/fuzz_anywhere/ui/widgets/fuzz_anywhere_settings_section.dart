import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Settings → Other apps (experimental, only in a build with
/// [fuzzAnywhereEnabled]): "Lock from other apps", off by default, and under
/// it while it is on "Lock again after each use", on by default, and "Copy
/// automatically" whenever the Android sheet's "Copy automatically next
/// time" is on, so it can be turned off here (Fuzzzy Tester, 2026-10-30);
/// then a "Why?" that says what it does and that another app may keep what
/// was typed there. Each switch ticks once; the first two are kept only
/// when sealed.
class FuzzAnywhereSettingsSection extends StatefulWidget {
  const FuzzAnywhereSettingsSection({
    super.key,
    this.isEnabled = fuzzAnywhereEnabled,
  });

  /// The build flag; tests set it.
  final bool isEnabled;

  @override
  State<FuzzAnywhereSettingsSection> createState() =>
      _FuzzAnywhereSettingsSectionState();
}

class _FuzzAnywhereSettingsSectionState
    extends State<FuzzAnywhereSettingsSection> {
  AppLifecycleListener? _lifecycleListener;

  /// "Copy automatically" was on while this screen was up: its row stays
  /// after it is turned off here, so it can be turned on again.
  bool _showsCopyAutomatically = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isEnabled) return;
    final cubit = context.read<FuzzAnywhereSettingsCubit>();
    unawaited(cubit.readSheetFlags());
    // The sheet may turn it on or off while the app is away.
    _lifecycleListener = AppLifecycleListener(onResume: cubit.readSheetFlags);
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) return const SizedBox.shrink();
    final localizations = context.fuzzzyInkLocalizations;
    final motion = context.fuzzzyMotion;

    return BlocBuilder<FuzzAnywhereSettingsCubit, FuzzAnywhereSettingsState>(
      builder: (context, state) {
        final cubit = context.read<FuzzAnywhereSettingsCubit>();
        final settings = state.settings;
        if (state.copiesAutomatically) _showsCopyAutomatically = true;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsSectionLabel(localizations.anywhereSection),
            FuzzzyListTile(
              qaId: 'settings.otherApps',
              leading: const SettingsRowIcon(Icons.apps_outlined),
              title: SettingsRowText(
                title: localizations.anywhereLockFromOtherApps,
                subtitle: localizations.anywhereExperimental,
              ),
              trailing: FuzzzyToggle(
                value: settings.isOn,
                qaId: 'settings.otherApps',
                onChanged: state.isLoaded
                    ? (isOn) {
                        unawaited(InkHaptics.selection());
                        unawaited(_saved(context, cubit.setOn(isOn)));
                      }
                    : null,
              ),
              divider: settings.isOn,
            ),
            AnimatedSize(
              duration: InkMotion.isReduced(context)
                  ? Duration.zero
                  : motion.standard,
              curve: motion.standardCurve,
              alignment: Alignment.topCenter,
              child: settings.isOn
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FuzzzyListTile(
                          qaId: 'settings.otherAppsLockAgain',
                          leading:
                              const SettingsRowIcon(Icons.lock_clock_outlined),
                          title: SettingsRowText(
                            title: localizations.anywhereLockAgain,
                          ),
                          trailing: FuzzzyToggle(
                            value: settings.locksAgainAfterUse,
                            qaId: 'settings.otherAppsLockAgain',
                            onChanged: (locksAgain) {
                              unawaited(InkHaptics.selection());
                              unawaited(
                                _saved(
                                  context,
                                  cubit.setLocksAgainAfterUse(locksAgain),
                                ),
                              );
                            },
                          ),
                          divider: _showsCopyAutomatically,
                        ),
                        if (_showsCopyAutomatically)
                          FuzzzyListTile(
                            qaId: 'settings.otherAppsCopyAutomatically',
                            leading: const SettingsRowIcon(Icons.copy_outlined),
                            title: SettingsRowText(
                              title: localizations.anywhereCopyAutomatically,
                              subtitle:
                                  localizations.anywhereCopyAutomaticallyLine,
                            ),
                            trailing: FuzzzyToggle(
                              value: state.copiesAutomatically,
                              qaId: 'settings.otherAppsCopyAutomatically',
                              onChanged: (isOn) {
                                unawaited(InkHaptics.selection());
                                unawaited(cubit.setCopiesAutomatically(isOn));
                              },
                            ),
                            divider: false,
                          ),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: WhyLink(
                topic: InkInfoTopic.otherApps,
                qaId: 'settings.otherApps',
              ),
            ),
          ],
        );
      },
    );
  }

  /// A switch that could not be sealed and stored stays as it was, and
  /// says so.
  static Future<void> _saved(BuildContext context, Future<bool> save) async {
    final isSaved = await save;
    if (isSaved || !context.mounted) return;
    showInkToast(
      context,
      message: context.fuzzzyInkLocalizations.autoLockSaveFailed,
      kind: FuzzzyToastKind.error,
    );
  }
}
