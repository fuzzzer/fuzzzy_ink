import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Settings → Other apps (experimental, only in a build with
/// [fuzzAnywhereEnabled]): "Lock from other apps", off by default, and under
/// it while it is on "Lock again after each use", on by default; then a
/// "Why?" that says what it does and that another app may keep what was
/// typed there. Each switch ticks once and is kept only when sealed.
class FuzzAnywhereSettingsSection extends StatelessWidget {
  const FuzzAnywhereSettingsSection({
    super.key,
    this.isEnabled = fuzzAnywhereEnabled,
  });

  /// The build flag; tests set it.
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    if (!isEnabled) return const SizedBox.shrink();
    final localizations = context.fuzzzyInkLocalizations;
    final motion = context.fuzzzyMotion;

    return BlocBuilder<FuzzAnywhereSettingsCubit, FuzzAnywhereSettingsState>(
      builder: (context, state) {
        final cubit = context.read<FuzzAnywhereSettingsCubit>();
        final settings = state.settings;
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
                  ? FuzzzyListTile(
                      qaId: 'settings.otherAppsLockAgain',
                      leading: const SettingsRowIcon(Icons.lock_clock_outlined),
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
                      divider: false,
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
