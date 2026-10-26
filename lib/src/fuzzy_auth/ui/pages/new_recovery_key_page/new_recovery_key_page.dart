import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Settings → Recovery key (prototype `set-rec`): "Make a new key · The old
/// key stops working.", the master password — and My safe's own password
/// when it has one, so the new key opens My safe too (owner, 2026-10-26:
/// kept) — then the new key with Print and Save as file, as on the first
/// run. A private screen.
class NewRecoveryKeyPage extends StatelessWidget {
  const NewRecoveryKeyPage({super.key, this.export});

  final RecoveryKeyExport? export;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FuzzyUserAuthPreferencesCubit>(
      create: (_) => FuzzyUserAuthPreferencesCubit(
        chatAuthRepository: sl.get<ChatAuthRepository>(),
        fuzzyAuthStore: context.read<FuzzyAuthStore>(),
        biometricAuthRepository: sl.get<BiometricAuthRepository>(),
        passwordStrengthService: sl.get<PasswordStrengthService>(),
        vaultRepository: sl.get<VaultRepository>(),
      ),
      child: NewRecoveryKeyView(export: export),
    );
  }
}

/// The screen, below a [FuzzyUserAuthPreferencesCubit].
class NewRecoveryKeyView extends StatefulWidget {
  const NewRecoveryKeyView({super.key, this.export});

  final RecoveryKeyExport? export;

  @override
  State<NewRecoveryKeyView> createState() => _NewRecoveryKeyViewState();
}

class _NewRecoveryKeyViewState extends State<NewRecoveryKeyView> {
  final _passwordController = TextEditingController();
  final _safePasswordController = TextEditingController();
  String? _passwordError;
  String? _safePasswordError;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(
      () => setState(() => _passwordError = null),
    );
    _safePasswordController.addListener(
      () => setState(() => _safePasswordError = null),
    );
  }

  @override
  void dispose() {
    for (final controller in [_passwordController, _safePasswordController]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _safeHasOwnPassword(BuildContext context) =>
      context.select<VaultAuthCubit?, bool>(
        (cubit) => cubit?.state.usesOwnPassword ?? false,
      );

  void _onMake(bool safeHasOwnPassword) {
    context.read<FuzzyUserAuthPreferencesCubit>().newRecoveryKey(
          _passwordController.text,
          vaultPassword:
              safeHasOwnPassword ? _safePasswordController.text : null,
        );
  }

  void _onStateChanged(
    BuildContext context,
    FuzzyUserAuthPreferencesState state,
  ) {
    final localizations = context.fuzzzyInkLocalizations;
    final vault = context.read<VaultAuthCubit?>();
    switch ((state.lastAction, state.activationStatus)) {
      case (AuthPreferencesAction.newRecoveryKey, StateStatus.success):
        _passwordController.clear();
        _safePasswordController.clear();
        unawaited(vault?.refreshRecovery());
      case (AuthPreferencesAction.newRecoveryKey, StateStatus.failed):
        unawaited(InkHaptics.heavy());
        final message = state.activationFailure?.message;
        if (state.vaultPasswordWrong) {
          setState(
            () => _safePasswordError = localizations.accessWrongPassword,
          );
        } else if (message == localizations.chatAuthIncorrectPassword) {
          setState(() => _passwordError = localizations.accessWrongPassword);
        } else {
          showInkToast(
            context,
            message: message ?? localizations.unknownError,
            kind: FuzzzyToastKind.error,
          );
        }
      case (AuthPreferencesAction.saveRecoveryKey, StateStatus.success):
        unawaited(vault?.refreshRecovery());
        unawaited(InkHaptics.light());
        showInkToast(context, message: localizations.accessNewKeyKept);
        leaveAccessPage(context);
      case (AuthPreferencesAction.skipRecoveryKey, StateStatus.success):
        unawaited(vault?.refreshRecovery());
        leaveAccessPage(context);
      case (AuthPreferencesAction.saveRecoveryKey, StateStatus.failed):
        showInkToast(
          context,
          message: localizations.recoveryKeySaveFailed,
          kind: FuzzzyToastKind.error,
        );
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final safeHasOwnPassword = _safeHasOwnPassword(context);
    final noAccessNote = AccessNote(
      tone: AccessNoteTone.danger,
      text: localizations.accessNoPasswordNoKey,
      trailing: const WhyLink(
        topic: InkInfoTopic.recoveryKey,
        label: WhyLinkLabel.more,
      ),
      qaId: 'newKey.noAccess',
    );

    return BlocConsumer<FuzzyUserAuthPreferencesCubit,
        FuzzyUserAuthPreferencesState>(
      listener: _onStateChanged,
      builder: (context, state) {
        final cubit = context.read<FuzzyUserAuthPreferencesCubit>();
        final isLoading = state.activationStatus == StateStatus.loading;
        final pending = state.pendingRecoveryKey;

        if (pending != null) {
          return RecoveryKeyStepView(
            recoveryKey: pending,
            busy: isLoading,
            onKept: cubit.confirmRecoveryKeySaved,
            onSkipped: cubit.skipRecoveryKey,
            pageTitle: localizations.recoveryKeyTitle,
            title: localizations.accessYourNewKey,
            note: noAccessNote,
            export: widget.export ?? const RecoveryKeyExport(),
          );
        }

        final isReady = _passwordController.text.isNotEmpty &&
            (!safeHasOwnPassword || _safePasswordController.text.isNotEmpty);

        return AccessPage(
          qaId: 'newKey',
          title: localizations.recoveryKeyTitle,
          onBack: isLoading ? null : () => leaveAccessPage(context),
          bottom: [
            FuzzzyButton(
              label: isLoading
                  ? localizations.chatAuthResecuringKeys
                  : localizations.accessMakeNewKey,
              size: FuzzzyButtonSize.l,
              loading: isLoading,
              qaId: 'newKey.make',
              onPressed: isReady && !isLoading
                  ? () => _onMake(safeHasOwnPassword)
                  : null,
            ),
          ],
          children: [
            AccessTitle(localizations.accessMakeNewKey),
            SizedBox(height: space.s),
            AccessLine(localizations.accessOldKeyStops),
            SizedBox(height: space.l),
            InkPasswordField(
              controller: _passwordController,
              label: localizations.masterPassword,
              errorText: _passwordError,
              qaId: 'newKey.password',
            ),
            if (safeHasOwnPassword) ...[
              SizedBox(height: space.m),
              AccessLine(localizations.accessSafePasswordToo),
              SizedBox(height: space.s),
              InkPasswordField(
                controller: _safePasswordController,
                label: localizations.accessMySafePassword,
                errorText: _safePasswordError,
                qaId: 'newKey.safePassword',
              ),
            ],
            SizedBox(height: space.l),
            noAccessNote,
          ],
        );
      },
    );
  }
}
