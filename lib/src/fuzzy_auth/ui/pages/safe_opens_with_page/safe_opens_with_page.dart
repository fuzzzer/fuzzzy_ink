import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Settings → My safe → Opens with (prototype `set-safepw`): Master password
/// ("Simplest. Recommended.") or Its own password ("One more to
/// remember"). Choosing its own asks for the new password (Good or better,
/// twice); My safe then gets a new key, everything in it is locked again
/// under that key, and a new recovery key is shown here to print or save,
/// as on the first run (security review 2026-10-26). Going back asks for
/// My safe's password and keeps the key. Either way the master password
/// confirms the change. A private screen.
class SafeOpensWithPage extends StatefulWidget {
  const SafeOpensWithPage({super.key, this.export});

  final RecoveryKeyExport? export;

  @override
  State<SafeOpensWithPage> createState() => _SafeOpensWithPageState();
}

class _SafeOpensWithPageState extends State<SafeOpensWithPage> {
  final _masterController = TextEditingController();
  final _safeController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  /// The choice on screen; the current mode until the person picks.
  bool? _chooseOwn;
  bool _busy = false;

  /// The recovery key the switch to its own password made, on screen until
  /// it is kept or skipped.
  PendingRecoveryKey? _pending;
  String? _masterError;
  String? _safeError;

  List<TextEditingController> get _controllers =>
      [_masterController, _safeController, _newController, _confirmController];

  @override
  void initState() {
    super.initState();
    _masterController.addListener(() => setState(() => _masterError = null));
    _safeController.addListener(() => setState(() => _safeError = null));
    _newController.addListener(() => setState(() {}));
    _confirmController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save({required bool toOwn}) async {
    final localizations = context.fuzzzyInkLocalizations;
    final cubit = context.read<VaultAuthCubit>();
    setState(() => _busy = true);
    final VaultFailureType? failure;
    PendingRecoveryKey? pending;
    if (toOwn) {
      final result = await cubit.useOwnPassword(
        masterPassword: _masterController.text,
        newPassword: _newController.text,
      );
      failure = result.failure;
      pending = result.recovery;
    } else {
      failure = await cubit.useMasterPassword(
        vaultPassword: _safeController.text,
        masterPassword: _masterController.text,
      );
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure == null) {
      for (final controller in _controllers) {
        controller.clear();
      }
      unawaited(InkHaptics.light());
      showInkToast(
        context,
        message: toOwn
            ? localizations.accessSafeHasOwnPassword
            : localizations.accessSafeUsesMaster,
      );
      if (pending != null) {
        setState(() => _pending = pending);
      } else {
        leaveAccessPage(context);
      }
    } else if (failure == VaultFailureType.incorrectMasterPassword) {
      unawaited(InkHaptics.heavy());
      setState(() => _masterError = localizations.accessWrongPassword);
    } else if (failure == VaultFailureType.incorrectCustomPassword) {
      unawaited(InkHaptics.heavy());
      setState(() => _safeError = localizations.accessWrongPassword);
    } else {
      showInkToast(
        context,
        message: switch (failure) {
          VaultFailureType.weakPassword =>
            localizations.chatAuthPasswordTooWeak,
          VaultFailureType.tooManyAttempts => localizations.accessTooManyTries,
          _ => localizations.unknownError,
        },
        kind: FuzzzyToastKind.error,
      );
    }
  }

  Future<void> _keepRecoveryKey(PendingRecoveryKey pending) async {
    final localizations = context.fuzzzyInkLocalizations;
    setState(() => _busy = true);
    final failure =
        await context.read<VaultAuthCubit>().keepRecoveryKey(pending);
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure != null) {
      showInkToast(
        context,
        message: localizations.recoveryKeySaveFailed,
        kind: FuzzzyToastKind.error,
      );
      return;
    }
    unawaited(InkHaptics.light());
    showInkToast(context, message: localizations.accessNewKeyKept);
    setState(() => _pending = null);
    leaveAccessPage(context);
  }

  void _skipRecoveryKey() {
    unawaited(context.read<VaultAuthCubit>().refreshRecovery());
    setState(() => _pending = null);
    leaveAccessPage(context);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final pending = _pending;
    if (pending != null) {
      return RecoveryKeyStepView(
        recoveryKey: pending.recoveryKey,
        busy: _busy,
        onKept: () => _keepRecoveryKey(pending),
        onSkipped: _skipRecoveryKey,
        pageTitle: localizations.recoveryKeyTitle,
        title: localizations.accessYourNewKey,
        note: AccessNote(
          tone: AccessNoteTone.danger,
          text: localizations.accessNoPasswordNoKey,
          trailing: const WhyLink(
            topic: InkInfoTopic.recoveryKey,
            label: WhyLinkLabel.more,
          ),
          qaId: 'safeOpensWith.noAccess',
        ),
        export: widget.export ?? const RecoveryKeyExport(),
      );
    }
    final vault = context.watch<VaultAuthCubit>().state;
    final hasVault = SettingsMySafeSection.hasVault(vault);
    final usesOwn = vault.usesOwnPassword;
    final chooseOwn = _chooseOwn ?? usesOwn;
    final isChange = hasVault && chooseOwn != usesOwn;

    final bool isReady;
    if (!isChange) {
      isReady = false;
    } else if (chooseOwn) {
      isReady = _masterController.text.isNotEmpty &&
          NewPasswordFields.isReady(
            password: _newController.text,
            confirm: _confirmController.text,
          );
    } else {
      isReady =
          _masterController.text.isNotEmpty && _safeController.text.isNotEmpty;
    }

    Widget choice({
      required bool own,
      required String title,
      required String subtitle,
    }) =>
        FuzzzyListTile(
          qaId: own ? 'safeOpensWith.own' : 'safeOpensWith.master',
          leading: ExcludeSemantics(
            child: FuzzzyRadio<bool>(
              value: own,
              groupValue: chooseOwn,
              onChanged: hasVault && !_busy
                  ? (_) => setState(() => _chooseOwn = own)
                  : null,
            ),
          ),
          title: SettingsRowText(title: title, subtitle: subtitle),
          selected: chooseOwn == own,
          divider: !own,
          onTap: hasVault && !_busy
              ? () {
                  unawaited(InkHaptics.selection());
                  setState(() => _chooseOwn = own);
                }
              : null,
        );

    return AccessPage(
      qaId: 'safeOpensWith',
      title: localizations.accessSafeOpensWith,
      onBack: _busy ? null : () => leaveAccessPage(context),
      bottom: [
        if (isChange)
          FuzzzyButton(
            label: chooseOwn
                ? localizations.accessSaveSafePassword
                : localizations.accessUseMasterPassword,
            size: FuzzzyButtonSize.l,
            loading: _busy,
            qaId: 'safeOpensWith.save',
            onPressed: isReady && !_busy ? () => _save(toOwn: chooseOwn) : null,
          ),
      ],
      children: [
        if (!hasVault) ...[
          TipLine(
            icon: Icons.shield_outlined,
            text: localizations.accessSafeNotMadeYet,
            qaId: 'safeOpensWith.noSafe',
          ),
          SizedBox(height: space.m),
        ],
        choice(
          own: false,
          title: localizations.masterPassword,
          subtitle: localizations.accessSimplestRecommended,
        ),
        choice(
          own: true,
          title: localizations.accessItsOwnPassword,
          subtitle: localizations.accessOneMoreToRemember,
        ),
        if (isChange) ...[
          SizedBox(height: space.l),
          if (chooseOwn) ...[
            NewPasswordFields(
              passwordController: _newController,
              confirmController: _confirmController,
              label: localizations.accessSafePassword,
              qaId: 'safeOpensWith.new',
            ),
            SizedBox(height: space.m),
            TipLine(
              icon: Icons.print_outlined,
              text: localizations.accessSafeGetsNewKey,
              trailing: const WhyLink(topic: InkInfoTopic.safePassword),
              qaId: 'safeOpensWith.recovery',
            ),
          ] else
            InkPasswordField(
              controller: _safeController,
              label: localizations.accessMySafePassword,
              errorText: _safeError,
              qaId: 'safeOpensWith.safePassword',
            ),
          SizedBox(height: space.l),
          InkPasswordField(
            controller: _masterController,
            label: localizations.accessMasterPasswordToConfirm,
            errorText: _masterError,
            qaId: 'safeOpensWith.masterPassword',
          ),
        ],
      ],
    );
  }
}
