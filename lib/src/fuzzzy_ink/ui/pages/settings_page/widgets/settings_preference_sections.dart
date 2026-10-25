import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Settings → Fuzzzy Cast: the switch ("Fuzzz reacts when you lock and
/// open."), and Soft sounds under it while it is on. Turning it on greets
/// with Fuzzz in the toast.
class SettingsFuzzzyCastSection extends StatelessWidget {
  const SettingsFuzzzyCastSection({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;

    return BlocBuilder<FuzzzyCastSettingsCubit, FuzzzyCastSettingsState>(
      builder: (context, state) {
        final cubit = context.read<FuzzzyCastSettingsCubit>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionLabel(localizations.fuzzzyCast),
            FuzzzyListTile(
              qaId: 'settings.fuzzzyCast',
              leading: const _RowIcon(Icons.auto_awesome_outlined),
              title: _RowText(
                title: localizations.fuzzzyCast,
                subtitle: localizations.fuzzzyCastLine,
              ),
              trailing: FuzzzyToggle(
                value: state.isEnabled,
                qaId: 'settings.fuzzzyCast',
                onChanged: (isOn) async {
                  unawaited(InkHaptics.selection());
                  await cubit.setEnabled(isOn);
                  if (isOn && context.mounted) {
                    showInkToast(
                      context,
                      message: localizations.fuzzzyCastOn,
                      castMoment: FuzzzyCastMoment.turnedOn,
                    );
                  }
                },
              ),
              divider: state.isEnabled,
            ),
            if (state.isEnabled)
              FuzzzyListTile(
                qaId: 'settings.softSounds',
                leading: const _RowIcon(Icons.volume_down_outlined),
                title: _RowText(
                  title: localizations.softSounds,
                  subtitle: localizations.softSoundsLine,
                ),
                trailing: FuzzzyToggle(
                  value: state.softSounds,
                  qaId: 'settings.softSounds',
                  onChanged: (isOn) {
                    unawaited(InkHaptics.selection());
                    cubit.setSoftSounds(isOn);
                  },
                ),
                divider: false,
              ),
          ],
        );
      },
    );
  }
}

/// Settings → Look and language: Look (Like my phone · Light · Dark) and
/// Language (Like my phone · English · ქართული), each a small radio sheet,
/// kept on this device.
class SettingsLookAndLanguageSection extends StatelessWidget {
  const SettingsLookAndLanguageSection({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final look = context.watch<ThemeCubit>().state.chosenBrightness;
    final language = context.watch<LocalizationCubit>().state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(localizations.settingsLookAndLanguage),
        FuzzzyListTile(
          qaId: 'settings.look',
          leading: const _RowIcon(Icons.dark_mode_outlined),
          title: _RowText(
            title: localizations.settingsLook,
            subtitle: lookName(localizations, look),
          ),
          chevron: true,
          onTap: () => _showLookSheet(context),
        ),
        FuzzzyListTile(
          qaId: 'settings.language',
          leading: const _RowIcon(Icons.translate),
          title: _RowText(
            title: localizations.settingsLanguage,
            subtitle: languageName(localizations, languageChoiceOf(language)),
          ),
          chevron: true,
          divider: false,
          onTap: () => _showLanguageSheet(context),
        ),
      ],
    );
  }

  static String lookName(FuzzzyInkLocalizations l, ChosenBrightness look) =>
      switch (look) {
        ChosenBrightness.system => l.lookLikeMyPhone,
        ChosenBrightness.light => l.lookLight,
        ChosenBrightness.dark => l.lookDark,
      };

  /// 'phone', or a language code.
  static String languageChoiceOf(LocalizationState state) =>
      state.followsPhone ? _phone : state.locale.languageCode;

  static String languageName(FuzzzyInkLocalizations l, String choice) =>
      switch (choice) {
        'en' => l.languageEnglish,
        'ka' => l.languageGeorgian,
        _ => l.lookLikeMyPhone,
      };

  static const _phone = 'phone';

  Future<void> _showLookSheet(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final cubit = context.read<ThemeCubit>();
    return _showChoiceSheet<ChosenBrightness>(
      context,
      qaId: 'look',
      title: localizations.settingsLook,
      current: cubit.state.chosenBrightness,
      choices: [
        for (final look in [
          ChosenBrightness.system,
          ChosenBrightness.light,
          ChosenBrightness.dark,
        ])
          (look, lookName(localizations, look)),
      ],
      onChosen: cubit.setBrightness,
    );
  }

  Future<void> _showLanguageSheet(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final cubit = context.read<LocalizationCubit>();
    return _showChoiceSheet<String>(
      context,
      qaId: 'language',
      title: localizations.settingsLanguage,
      current: languageChoiceOf(cubit.state),
      choices: [
        for (final choice in [_phone, 'en', 'ka'])
          (choice, languageName(localizations, choice)),
      ],
      onChosen: (choice) => choice == _phone
          ? cubit.followPhone()
          : cubit.changeLocale(Locale(choice)),
    );
  }
}

Future<void> _showChoiceSheet<T>(
  BuildContext context, {
  required String qaId,
  required String title,
  required T current,
  required List<(T, String)> choices,
  required Future<void> Function(T choice) onChosen,
}) {
  return FuzzzyBottomSheet.show<void>(
    context,
    qaId: qaId,
    builder: (sheetContext) => FuzzzyBottomSheet(
      qaId: qaId,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: sheetContext.fuzzzyTextStyles.titleL.copyWith(
                color: sheetContext.fuzzzyColors.ink,
              ),
            ),
          ),
          SizedBox(height: sheetContext.fuzzzySpace.m),
          for (final (value, label) in choices)
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: sheetContext.fuzzzySpace.s,
              ),
              child: FuzzzyRadio<T>(
                value: value,
                groupValue: current,
                label: label,
                qaId: '$qaId.$value',
                onChanged: (choice) {
                  unawaited(InkHaptics.selection());
                  Navigator.of(sheetContext).pop();
                  onChosen(choice);
                },
              ),
            ),
        ],
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: context.fuzzzySpace.xl,
        bottom: context.fuzzzySpace.s,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: context.fuzzzyTextStyles.label.copyWith(
            color: context.fuzzzyColors.inkMute,
          ),
        ),
      ),
    );
  }
}

class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => Icon(
        icon,
        size: context.fuzzzyIconSize.l,
        color: context.fuzzzyColors.ink,
      );
}

class _RowText extends StatelessWidget {
  const _RowText({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        Text(
          subtitle,
          style: context.fuzzzyTextStyles.bodyS.copyWith(color: colors.inkMute),
        ),
      ],
    );
  }
}
