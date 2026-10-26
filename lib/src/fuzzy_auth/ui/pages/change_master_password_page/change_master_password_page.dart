import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Settings → Master password (prototype `set-pw`): the current password,
/// a new one with its strength (Good or better) and once again, then
/// "Change password". The recovery key keeps working; the fingerprint
/// shortcut held the old password and turns off. A private screen.
class ChangeMasterPasswordPage extends StatelessWidget {
  const ChangeMasterPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FuzzyUserAuthPreferencesCubit>(
      create: (_) => FuzzyUserAuthPreferencesCubit(
        chatAuthRepository: sl.get<ChatAuthRepository>(),
        fuzzyAuthStore: context.read<FuzzyAuthStore>(),
        biometricAuthRepository: sl.get<BiometricAuthRepository>(),
        passwordStrengthService: sl.get<PasswordStrengthService>(),
      ),
      child: const ChangeMasterPasswordView(),
    );
  }
}

/// The screen, below a [FuzzyUserAuthPreferencesCubit].
class ChangeMasterPasswordView extends StatefulWidget {
  const ChangeMasterPasswordView({super.key});

  @override
  State<ChangeMasterPasswordView> createState() =>
      _ChangeMasterPasswordViewState();
}

class _ChangeMasterPasswordViewState extends State<ChangeMasterPasswordView> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isCurrentWrong = false;

  @override
  void initState() {
    super.initState();
    _currentController.addListener(
      () => setState(() => _isCurrentWrong = false),
    );
    _newController.addListener(() => setState(() {}));
    _confirmController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final controller in [
      _currentController,
      _newController,
      _confirmController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _isReady =>
      _currentController.text.isNotEmpty &&
      NewPasswordFields.isReady(
        password: _newController.text,
        confirm: _confirmController.text,
      );

  void _onChange() {
    if (!_isReady) return;
    context.read<FuzzyUserAuthPreferencesCubit>().changePassword(
          oldPassword: _currentController.text,
          newPassword: _newController.text,
        );
  }

  void _onStateChanged(
    BuildContext context,
    FuzzyUserAuthPreferencesState state,
  ) {
    final localizations = context.fuzzzyInkLocalizations;
    if (state.lastAction != AuthPreferencesAction.changePassword) return;
    if (state.activationStatus == StateStatus.success) {
      unawaited(context.read<VaultAuthCubit?>()?.onMasterPasswordChanged());
      unawaited(InkHaptics.light());
      showInkToast(context, message: localizations.accessMasterPasswordChanged);
      leaveAccessPage(context);
    } else if (state.activationStatus == StateStatus.failed) {
      final message = state.activationFailure?.message;
      if (message == localizations.chatAuthIncorrectPassword) {
        unawaited(InkHaptics.heavy());
        setState(() => _isCurrentWrong = true);
      } else {
        showInkToast(
          context,
          message: message ?? localizations.unknownError,
          kind: FuzzzyToastKind.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;

    return BlocConsumer<FuzzyUserAuthPreferencesCubit,
        FuzzyUserAuthPreferencesState>(
      listener: _onStateChanged,
      builder: (context, state) {
        final isLoading = state.activationStatus == StateStatus.loading;
        return AccessPage(
          qaId: 'changePassword',
          title: localizations.accessChangeMasterPassword,
          onBack: isLoading ? null : () => leaveAccessPage(context),
          bottom: [
            FuzzzyButton(
              label: isLoading
                  ? localizations.chatAuthResecuringKeys
                  : localizations.accessChangePassword,
              size: FuzzzyButtonSize.l,
              loading: isLoading,
              qaId: 'changePassword.submit',
              onPressed: _isReady && !isLoading ? _onChange : null,
            ),
          ],
          children: [
            InkPasswordField(
              controller: _currentController,
              label: localizations.accessCurrentPassword,
              errorText:
                  _isCurrentWrong ? localizations.accessWrongPassword : null,
              qaId: 'changePassword.current',
            ),
            SizedBox(height: space.l),
            NewPasswordFields(
              passwordController: _newController,
              confirmController: _confirmController,
              label: localizations.accessNewPassword,
              onSubmitted: _onChange,
              qaId: 'changePassword',
            ),
            SizedBox(height: space.l),
            TipLine(
              icon: Icons.print_outlined,
              text: localizations.accessRecoveryKeepsWorking,
              qaId: 'changePassword.recovery',
            ),
          ],
        );
      },
    );
  }
}
