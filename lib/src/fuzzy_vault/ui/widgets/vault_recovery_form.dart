import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// "Forgot the vault password": the recovery key opens a vault with its own
/// password, which then gets a new password — or opens with the master
/// password from now on. Functional form in the current kit; the redesign
/// restyles it.
class VaultRecoveryForm extends StatefulWidget {
  const VaultRecoveryForm({required this.onCancel, super.key});

  final VoidCallback onCancel;

  @override
  State<VaultRecoveryForm> createState() => _VaultRecoveryFormState();
}

class _VaultRecoveryFormState extends State<VaultRecoveryForm> {
  final _recoveryKeyController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _useMasterPassword = false;
  bool _busy = false;
  VaultFailureType? _failure;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _recoveryKeyController,
      _passwordController,
      _confirmController,
    ]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _recoveryKeyController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _isReady =>
      !_busy &&
      _recoveryKeyController.text.trim().isNotEmpty &&
      (_useMasterPassword ||
          NewPasswordFields.isReady(
            password: _passwordController.text,
            confirm: _confirmController.text,
          ));

  Future<void> _onRecover() async {
    if (!_isReady) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final failure = await context.read<VaultAuthCubit>().recover(
          recoveryKey: _recoveryKeyController.text,
          newPassword: _useMasterPassword ? null : _passwordController.text,
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = failure;
    });
  }

  String? _errorText() {
    final localizations = context.fuzzzyInkLocalizations;
    return switch (_failure) {
      null => null,
      VaultFailureType.recoveryKeyTypo => localizations.recoveryKeyTypo,
      VaultFailureType.recoveryKeyWrong => localizations.recoveryKeyWrong,
      VaultFailureType.weakPassword => localizations.chatAuthPasswordTooWeak,
      _ => localizations.unknownError,
    };
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          localizations.vaultRecoveryTitle,
          style: context.fuzzzyTextStyles.titleM.copyWith(color: colors.ink),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: space.s),
        Text(
          localizations.vaultRecoveryDescription,
          style: context.fuzzzyTextStyles.bodyS.copyWith(color: colors.inkMute),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: space.l),
        FuzzzyTextField(
          controller: _recoveryKeyController,
          label: localizations.recoveryKeyField,
          hint: 'XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX',
          errorText: _errorText(),
          qaId: 'vault.recover.key',
        ),
        SizedBox(height: space.m),
        FuzzzyCheckbox(
          value: _useMasterPassword,
          label: localizations.vaultRecoveryUseMasterPassword,
          qaId: 'vault.recover.useMaster',
          onChanged: _busy
              ? null
              : (value) => setState(() => _useMasterPassword = value),
        ),
        if (!_useMasterPassword) ...[
          SizedBox(height: space.m),
          NewPasswordFields(
            passwordController: _passwordController,
            confirmController: _confirmController,
            label: localizations.vaultOwnNewPassword,
            onSubmitted: _onRecover,
            qaId: 'vault.recover',
          ),
        ],
        SizedBox(height: space.l),
        FuzzzyButton(
          label: localizations.vaultRecoverySubmit,
          qaId: 'vault.recover.submit',
          loading: _busy,
          onPressed: _isReady ? _onRecover : null,
        ),
        SizedBox(height: space.s),
        FuzzzyButton(
          label: localizations.cancel,
          variant: FuzzzyButtonVariant.secondary,
          qaId: 'vault.recover.cancel',
          onPressed: _busy ? null : widget.onCancel,
        ),
      ],
    );
  }
}
