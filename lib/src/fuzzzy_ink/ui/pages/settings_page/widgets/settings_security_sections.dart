import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

/// Settings → Keeping it safe (DESIGN.md section 4.12): Master password ·
/// Recovery key · Fingerprint or face · Lock the app after · Lock now. The
/// master password can't be switched off. The fingerprint switch covers My
/// safe too while My safe opens with the master password.
class SettingsKeepingSafeSection extends StatelessWidget {
  const SettingsKeepingSafeSection({
    super.key,
    required this.canUseBiometrics,
  });

  /// `null` while it is being checked.
  final bool? canUseBiometrics;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final biometricOn = context.select<FuzzyAuthStore, bool>(
      (store) => store.state.biometricEnabled,
    );
    final biometricKind = context.select<FuzzyAuthStore, BiometricKind>(
      (store) => store.state.biometricKind,
    );
    final hasRecoveryKey = context.select<FuzzyUserAuthPreferencesCubit, bool?>(
      (cubit) => cubit.state.hasRecoveryKey,
    );
    final autoLock = context.watch<AutoLockCubit>().state;
    final canUse = canUseBiometrics ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionLabel(localizations.accessSettingsKeepingSafe),
        FuzzzyListTile(
          qaId: 'settings.masterPassword',
          leading: const SettingsRowIcon(Icons.key_outlined),
          title: SettingsRowText(
            title: localizations.masterPassword,
            subtitle: localizations.accessChangeIt,
          ),
          chevron: true,
          onTap: () => context.push(AppRouter.settingsMasterPassword),
        ),
        FuzzzyListTile(
          qaId: 'settings.recoveryKey',
          leading: const SettingsRowIcon(Icons.print_outlined),
          title: SettingsRowText(
            title: localizations.recoveryKeyTitle,
            subtitle: hasRecoveryKey == false
                ? localizations.accessNoKeyYet
                : localizations.accessMakeNewOne,
          ),
          chevron: true,
          onTap: () async {
            await context.push(AppRouter.settingsRecoveryKey);
            if (context.mounted) {
              unawaited(
                context
                    .read<FuzzyUserAuthPreferencesCubit>()
                    .loadRecoveryKeyStatus(),
              );
            }
          },
        ),
        FuzzzyListTile(
          qaId: 'settings.biometric',
          leading: SettingsRowIcon(biometricKind.icon),
          title: SettingsRowText(
            title: localizations.accessFingerprintOrFace(biometricKind.l10nKey),
            subtitle: canUseBiometrics == false
                ? localizations.accessNotOnThisDevice
                : null,
          ),
          trailing: FuzzzyToggle(
            value: biometricOn && canUse,
            qaId: 'settings.biometric',
            onChanged: canUse
                ? (isOn) {
                    unawaited(InkHaptics.selection());
                    unawaited(
                      isOn ? _turnOnBiometrics(context) : _turnOff(context),
                    );
                  }
                : null,
          ),
        ),
        FuzzzyListTile(
          qaId: 'settings.autoLock',
          leading: const SettingsRowIcon(Icons.schedule),
          title: SettingsRowText(
            title: localizations.accessLockTheApp,
            subtitle: lockAfterSubtitle(localizations, autoLock.lockAfterIndex),
          ),
          chevron: true,
          onTap: () => _showLockAfterSheet(context),
        ),
        FuzzzyListTile(
          qaId: 'settings.lockNow',
          leading: const SettingsRowIcon(Icons.lock_outline),
          title: SettingsRowText(title: localizations.accessLockNow),
          divider: false,
          onTap: () => context.read<FuzzyAuthStore>().lock(byUser: true),
        ),
      ],
    );
  }

  /// The five "Lock the app after" names, in [AutoLockSettings.
  /// lockAfterChoices] order.
  /// "After 5 minutes", but "Right away" alone (never "After Right
  /// away").
  static String lockAfterSubtitle(FuzzzyInkLocalizations l, int index) =>
      index == 0
          ? l.accessRightAway
          : l.accessLockAfter(lockAfterName(l, index));

  static String lockAfterName(FuzzzyInkLocalizations l, int index) =>
      switch (index) {
        0 => l.accessRightAway,
        1 => l.accessOneMinute,
        2 => l.accessFiveMinutes,
        3 => l.accessFifteenMinutes,
        _ => l.accessOneHour,
      };

  Future<void> _showLockAfterSheet(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final cubit = context.read<AutoLockCubit>();
    final standard =
        AutoLockSettings.lockAfterChoices.indexOf(AutoLockSettings.standard);
    return showSettingsChoiceSheet<int>(
      context,
      qaId: 'autoLock',
      title: localizations.accessLockAfterTitle,
      current: cubit.state.lockAfterIndex,
      notes: {standard: localizations.accessRecommended},
      choices: [
        for (var i = 0; i < AutoLockSettings.lockAfterChoices.length; i++)
          (i, lockAfterName(localizations, i)),
      ],
      onChosen: (index) async {
        final saved =
            await cubit.update(AutoLockSettings.lockAfterChoices[index]);
        if (!saved && context.mounted) {
          showInkToast(
            context,
            message: localizations.autoLockSaveFailed,
            kind: FuzzzyToastKind.error,
          );
        }
      },
    );
  }

  /// The master password once, then the device's own prompt. My safe gets
  /// the same shortcut while the master password opens it.
  Future<void> _turnOnBiometrics(BuildContext context) async {
    final localizations = context.fuzzzyInkLocalizations;
    final kind = context.read<FuzzyAuthStore>().state.biometricKind.l10nKey;
    final preferences = context.read<FuzzyUserAuthPreferencesCubit>();
    final vault = context.read<VaultAuthCubit>();
    final turnedOn = await showPasswordConfirmSheet(
      context,
      qaId: 'biometric',
      title: localizations.accessTurnOnBioTitle(kind),
      line: localizations.accessTurnOnBioLine,
      label: localizations.masterPassword,
      action: localizations.accessTurnOn,
      onSubmit: (password) async {
        await preferences.enableBiometric(password);
        final state = preferences.state;
        if (state.activationStatus != StateStatus.success) {
          final message = state.activationFailure?.message;
          return message == null ||
                  message == localizations.chatAuthIncorrectPassword
              ? localizations.accessWrongPassword
              : message;
        }
        if (_vaultFollowsMaster(vault.state)) {
          await vault.enableBiometric(password);
        }
        return null;
      },
    );
    if (turnedOn && context.mounted) {
      unawaited(InkHaptics.light());
      showInkToast(context, message: localizations.accessBioOn(kind));
    }
  }

  Future<void> _turnOff(BuildContext context) async {
    final vault = context.read<VaultAuthCubit>();
    await context.read<FuzzyUserAuthPreferencesCubit>().disableBiometric();
    if (_vaultFollowsMaster(vault.state)) await vault.disableBiometric();
  }

  static bool _vaultFollowsMaster(VaultAuthState state) =>
      SettingsMySafeSection.hasVault(state) && !state.usesOwnPassword;
}

/// Settings → My safe: Opens with (master password, or its own) ·
/// Fingerprint for My safe (only with its own password) · Copy passwords
/// (on by default, cleared after 30 seconds).
class SettingsMySafeSection extends StatelessWidget {
  const SettingsMySafeSection({super.key, required this.canUseBiometrics});

  final bool? canUseBiometrics;

  static bool hasVault(VaultAuthState state) =>
      state.authState == VaultAuthEnum.locked ||
      state.authState == VaultAuthEnum.unlocking ||
      state.authState == VaultAuthEnum.unlocked;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final vault = context.watch<VaultAuthCubit>().state;
    final usesOwn = hasVault(vault) && vault.usesOwnPassword;
    final biometricKind = context.select<FuzzyAuthStore, BiometricKind>(
      (store) => store.state.biometricKind,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionLabel(localizations.tabMySafe),
        FuzzzyListTile(
          qaId: 'settings.safeOpensWith',
          leading: const SettingsRowIcon(Icons.shield_outlined),
          title: SettingsRowText(
            title: localizations.accessOpensWith,
            subtitle: usesOwn
                ? localizations.accessItsOwnPassword
                : localizations.masterPassword,
          ),
          chevron: true,
          onTap: () => context.push(AppRouter.settingsSafePassword),
        ),
        if (usesOwn && (canUseBiometrics ?? false))
          FuzzzyListTile(
            qaId: 'settings.safeBiometric',
            leading: SettingsRowIcon(biometricKind.icon),
            title: SettingsRowText(
              title:
                  localizations.accessTurnOnSafeBioTitle(biometricKind.l10nKey),
            ),
            trailing: FuzzzyToggle(
              value: vault.biometricEnabled,
              qaId: 'settings.safeBiometric',
              onChanged: (isOn) {
                unawaited(InkHaptics.selection());
                unawaited(
                  isOn
                      ? _turnOnSafeBiometrics(context)
                      : context.read<VaultAuthCubit>().disableBiometric(),
                );
              },
            ),
          ),
        ValueListenableBuilder<bool>(
          valueListenable: vaultPasswordCopySetting,
          builder: (context, isOn, _) => FuzzzyListTile(
            qaId: 'settings.copyPasswords',
            leading: const SettingsRowIcon(Icons.copy_outlined),
            title: SettingsRowText(
              title: localizations.accessCopyPasswords,
              subtitle: isOn
                  ? localizations.accessClearsAfter30
                  : localizations.accessOff,
            ),
            divider: false,
            trailing: FuzzzyToggle(
              value: isOn,
              qaId: 'settings.copyPasswords',
              onChanged: (value) {
                unawaited(InkHaptics.selection());
                vaultPasswordCopySetting.value = value;
                unawaited(
                  sl.get<PreferencesService>().setVaultPasswordCopy(value),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _turnOnSafeBiometrics(BuildContext context) async {
    final localizations = context.fuzzzyInkLocalizations;
    final kind = context.read<FuzzyAuthStore>().state.biometricKind.l10nKey;
    final vault = context.read<VaultAuthCubit>();
    final turnedOn = await showPasswordConfirmSheet(
      context,
      qaId: 'safeBiometric',
      title: localizations.accessTurnOnSafeBioTitle(kind),
      line: localizations.accessTurnOnSafeBioLine,
      label: localizations.accessMySafePassword,
      action: localizations.accessTurnOn,
      onSubmit: (password) async {
        final result = await vault.enableBiometric(password);
        return switch (result) {
          BiometricEnableResult.enabled => null,
          BiometricEnableResult.wrongPassword =>
            localizations.accessWrongPassword,
          BiometricEnableResult.notStrongEnough =>
            localizations.biometricNotStrongEnough,
          BiometricEnableResult.cancelled ||
          BiometricEnableResult.failed =>
            localizations.biometricNotTurnedOn,
        };
      },
    );
    if (turnedOn && context.mounted) {
      unawaited(InkHaptics.light());
      showInkToast(context, message: localizations.accessBioOn(kind));
    }
  }
}

/// A small sheet that asks for one password ([label]) and runs [onSubmit]
/// with it. [onSubmit] answers null when it worked (the sheet closes and
/// this answers true) or the line to show under the field. A private
/// sheet: the field never leaves through the clipboard and is cleared when
/// the sheet closes.
Future<bool> showPasswordConfirmSheet(
  BuildContext context, {
  required String qaId,
  required String title,
  required String line,
  required String label,
  required String action,
  required Future<String?> Function(String password) onSubmit,
}) async {
  final done = await FuzzzyBottomSheet.show<bool>(
    context,
    qaId: qaId,
    builder: (sheetContext) => FuzzzyBottomSheet(
      qaId: qaId,
      child: SensitiveScreen(
        child: _PasswordConfirmBody(
          qaId: qaId,
          title: title,
          line: line,
          label: label,
          action: action,
          onSubmit: onSubmit,
        ),
      ),
    ),
  );
  return done ?? false;
}

class _PasswordConfirmBody extends StatefulWidget {
  const _PasswordConfirmBody({
    required this.qaId,
    required this.title,
    required this.line,
    required this.label,
    required this.action,
    required this.onSubmit,
  });

  final String qaId;
  final String title;
  final String line;
  final String label;
  final String action;
  final Future<String?> Function(String password) onSubmit;

  @override
  State<_PasswordConfirmBody> createState() => _PasswordConfirmBodyState();
}

class _PasswordConfirmBodyState extends State<_PasswordConfirmBody> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.isEmpty || _busy) return;
    setState(() => _busy = true);
    final error = await widget.onSubmit(_controller.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    unawaited(InkHaptics.heavy());
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final space = context.fuzzzySpace;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccessTitle(widget.title),
        SizedBox(height: space.s),
        AccessLine(widget.line),
        SizedBox(height: space.l),
        InkPasswordField(
          controller: _controller,
          label: widget.label,
          errorText: _error,
          autofocus: true,
          onSubmitted: _submit,
          qaId: '${widget.qaId}.password',
        ),
        SizedBox(height: space.l),
        FuzzzyButton(
          label: widget.action,
          size: FuzzzyButtonSize.l,
          loading: _busy,
          qaId: '${widget.qaId}.submit',
          onPressed: _controller.text.isEmpty || _busy ? null : _submit,
        ),
      ],
    );
  }
}
