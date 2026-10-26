import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

/// "Forgot your password?" (DESIGN.md section 4.2, prototype `rec-enter`
/// and `rec-new`): type the recovery key — a typo is caught at once by its
/// check byte, before any new password is asked for ("Key accepted.") —
/// then a new master password. Whether the key opens this device shows only
/// when the new password is saved, so a key of another device brings the
/// person back to the key with "That key doesn't match. Check each group."
/// After it the app opens (it lifts in) with
/// "New master password saved." The way out for someone with neither the
/// password nor the key — erase everything — sits here, behind a
/// confirmation. A private screen.
class MasterPasswordRecoveryPage extends StatelessWidget {
  const MasterPasswordRecoveryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MasterPasswordRecoveryCubit>(
      create: (_) => MasterPasswordRecoveryCubit(
        chatAuthRepository: sl.get<ChatAuthRepository>(),
        fuzzyAuthStore: sl.get<FuzzyAuthStore>(),
        passwordStrengthService: sl.get<PasswordStrengthService>(),
      ),
      child: const MasterPasswordRecoveryView(),
    );
  }
}

/// The two steps, below a [MasterPasswordRecoveryCubit].
class MasterPasswordRecoveryView extends StatefulWidget {
  const MasterPasswordRecoveryView({super.key});

  /// Characters in a recovery key (8 groups of 4), spaces and dashes aside.
  static const keyLength = 32;

  /// The key as typed, without the spaces and dashes the core ignores.
  static int lengthOf(String key) =>
      key.replaceAll(RegExp(r'[\s-]'), '').length;

  @override
  State<MasterPasswordRecoveryView> createState() =>
      _MasterPasswordRecoveryViewState();
}

class _MasterPasswordRecoveryViewState
    extends State<MasterPasswordRecoveryView> {
  final _keyController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _onPasswordStep = false;
  String? _keyError;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _keyController,
      _passwordController,
      _confirmController,
    ]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _keyController,
      _passwordController,
      _confirmController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _checkingKey = false;

  Future<void> _onKeyContinue() async {
    final localizations = context.fuzzzyInkLocalizations;
    if (MasterPasswordRecoveryView.lengthOf(_keyController.text) !=
        MasterPasswordRecoveryView.keyLength) {
      setState(() => _keyError = localizations.accessKeyTooShort);
      return;
    }
    if (_checkingKey) return;
    setState(() => _checkingKey = true);
    final checkRes = await sl
        .get<ChatAuthRepository>()
        .checkRecoveryKey(_keyController.text);
    if (!mounted) return;
    setState(() {
      _checkingKey = false;
      if (checkRes is CryptoCoreFailure<void>) {
        _keyError = localizations.accessKeyDoesntMatch;
        return;
      }
      _keyError = null;
      _onPasswordStep = true;
    });
    if (checkRes is CryptoCoreFailure<void>) unawaited(InkHaptics.heavy());
  }

  bool get _isPasswordReady => NewPasswordFields.isReady(
        password: _passwordController.text,
        confirm: _confirmController.text,
      );

  void _onSave() {
    if (!_isPasswordReady) return;
    context.read<MasterPasswordRecoveryCubit>().recover(
          recoveryKey: _keyController.text,
          newPassword: _passwordController.text,
        );
  }

  void _onStateChanged(
    BuildContext context,
    MasterPasswordRecoveryState state,
  ) {
    final localizations = context.fuzzzyInkLocalizations;
    if (state.status.isSuccess) {
      final message = localizations.accessNewPasswordSaved;
      unawaited(
        runOnTopScreen(
          (topContext) => showInkToast(topContext, message: message),
        ),
      );
      return;
    }
    if (!state.status.isFailed || state.tooWeak) return;
    final failure = state.failureType;
    if (failure == CryptoCoreFailureType.corrupt ||
        failure == CryptoCoreFailureType.wrongPassword) {
      unawaited(InkHaptics.heavy());
      setState(() {
        _onPasswordStep = false;
        _keyError = localizations.accessKeyDoesntMatch;
      });
      return;
    }
    showInkToast(
      context,
      message: localizations.unknownError,
      kind: FuzzzyToastKind.error,
    );
  }

  /// Everything goes, after an explicit confirmation.
  Future<void> _onErase() =>
      confirmAndEraseEverything(context, qaId: 'recover');

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MasterPasswordRecoveryCubit,
        MasterPasswordRecoveryState>(
      listener: _onStateChanged,
      builder: (context, state) {
        final isLoading = state.status.isLoading || state.status.isSuccess;
        return _onPasswordStep
            ? _passwordStep(context, isLoading)
            : _keyStep(context, isLoading);
      },
    );
  }

  Widget _keyStep(BuildContext context, bool isLoading) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;

    return AccessPage(
      qaId: 'recover.key',
      title: localizations.accessRecoveryKeyHeader,
      onBack: isLoading ? null : () => context.go(AppRouter.chatUnlock),
      bottom: [
        FuzzzyButton(
          label: localizations.accessContinue,
          size: FuzzzyButtonSize.l,
          qaId: 'recover.continue',
          loading: _checkingKey,
          onPressed:
              _keyController.text.trim().isEmpty || isLoading || _checkingKey
                  ? null
                  : _onKeyContinue,
        ),
      ],
      children: [
        AccessTitle(localizations.accessTypeRecoveryKey),
        SizedBox(height: space.s),
        AccessLine(localizations.accessSpacesDontMatter),
        SizedBox(height: space.l),
        // The key is a secret: no copy, cut, share or other app's text
        // action, and no keyboard learning (GuardedTextField).
        GuardedTextField(
          controller: _keyController,
          label: localizations.recoveryKeyField,
          hint: recoveryKeyHint,
          errorText: _keyError,
          keyboardType: TextInputType.visiblePassword,
          onSubmitted: (_) => _onKeyContinue(),
          qaId: 'recover.keyField',
        ),
        SizedBox(height: space.m),
        TipLine(
          icon: Icons.warning_amber_rounded,
          text: localizations.accessNoKeyNothing,
          trailing: const WhyLink(topic: InkInfoTopic.noReset),
          qaId: 'recover.noKey',
        ),
        SizedBox(height: space.xl),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FuzzzyButton(
            label: localizations.chatUnlockErase,
            variant: FuzzzyButtonVariant.ghost,
            size: FuzzzyButtonSize.s,
            qaId: 'recover.erase',
            onPressed: isLoading ? null : _onErase,
          ),
        ),
      ],
    );
  }

  Widget _passwordStep(BuildContext context, bool isLoading) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;

    return AccessPage(
      qaId: 'recover.password',
      title: localizations.accessNewMasterPassword,
      onBack: isLoading ? null : () => setState(() => _onPasswordStep = false),
      bottom: [
        FuzzzyButton(
          label: isLoading
              ? localizations.chatAuthResecuringKeys
              : localizations.accessSaveNewPassword,
          size: FuzzzyButtonSize.l,
          loading: isLoading,
          qaId: 'recover.submit',
          onPressed: _isPasswordReady && !isLoading ? _onSave : null,
        ),
      ],
      children: [
        TipLine(
          icon: Icons.check_circle_outline,
          text: localizations.accessKeyAccepted,
          qaId: 'recover.keyAccepted',
        ),
        SizedBox(height: space.l),
        NewPasswordFields(
          passwordController: _passwordController,
          confirmController: _confirmController,
          label: localizations.accessNewMasterPassword,
          onSubmitted: _onSave,
          qaId: 'recover',
        ),
      ],
    );
  }
}
