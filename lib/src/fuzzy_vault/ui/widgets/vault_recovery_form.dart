import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// "Use recovery key" on a locked My safe with its own password (DESIGN.md
/// section 4.11): the recovery key opens it, and it gets a new safe password
/// (or opens with the master password from now on). The key and the new
/// password go to the core in one step, so a wrong key changes nothing.
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
        const Center(
          child: HeroGlyph(icon: Icons.key_outlined, qaId: 'safe.recover'),
        ),
        SizedBox(height: space.l),
        Semantics(
          header: true,
          child: Text(
            localizations.safeRecoveryTitle,
            style: context.fuzzzyTextStyles.titleL.copyWith(color: colors.ink),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: space.s),
        Text(
          localizations.safeRecoveryLine,
          style: context.fuzzzyTextStyles.body.copyWith(color: colors.inkMute),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: space.l),
        FuzzzyTextField(
          controller: _recoveryKeyController,
          label: localizations.recoveryKeyField,
          hint: recoveryKeyHint,
          errorText: _errorText(),
          qaId: 'vault.recover.key',
        ),
        SizedBox(height: space.s),
        TipLine(
          icon: Icons.key_off_outlined,
          text: localizations.safeRecoveryNoKey,
          trailing: const WhyLink(
            topic: InkInfoTopic.recoveryKey,
            qaId: 'safe.recover.why',
          ),
          qaId: 'safe.recover.noKey',
        ),
        SizedBox(height: space.l),
        if (!_useMasterPassword) ...[
          NewPasswordFields(
            passwordController: _passwordController,
            confirmController: _confirmController,
            label: localizations.safeRecoveryNewPassword,
            onSubmitted: _onRecover,
            qaId: 'vault.recover',
          ),
          SizedBox(height: space.m),
        ],
        FuzzzyCheckbox(
          value: _useMasterPassword,
          label: localizations.vaultRecoveryUseMasterPassword,
          qaId: 'vault.recover.useMaster',
          onChanged: _busy
              ? null
              : (value) => setState(() => _useMasterPassword = value),
        ),
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
          variant: FuzzzyButtonVariant.ghost,
          qaId: 'vault.recover.cancel',
          onPressed: _busy ? null : widget.onCancel,
        ),
      ],
    );
  }
}
