import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Which password opens the vault: by default the master password; on
/// request a password of its own, and back. Each switch re-wraps the same
/// vault key, so no item is re-encrypted. Functional section in the current
/// kit; the redesign restyles it.
class VaultPasswordModeSection extends StatefulWidget {
  const VaultPasswordModeSection({super.key});

  @override
  State<VaultPasswordModeSection> createState() =>
      _VaultPasswordModeSectionState();
}

class _VaultPasswordModeSectionState extends State<VaultPasswordModeSection> {
  final _masterPasswordController = TextEditingController();
  final _vaultPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _masterPasswordController,
      _vaultPasswordController,
      _newPasswordController,
      _confirmController,
    ]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _masterPasswordController.dispose();
    _vaultPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<VaultFailureType?> Function() change) async {
    final localizations = context.fuzzzyInkLocalizations;
    setState(() => _busy = true);
    final failure = await change();
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure == null) {
      for (final controller in [
        _masterPasswordController,
        _vaultPasswordController,
        _newPasswordController,
        _confirmController,
      ]) {
        controller.clear();
      }
    }
    final message = switch (failure) {
      null => localizations.vaultPasswordModeChanged,
      VaultFailureType.incorrectMasterPassword =>
        localizations.chatAuthIncorrectPassword,
      VaultFailureType.weakPassword => localizations.chatAuthPasswordTooWeak,
      _ => localizations.unknownError,
    };
    FuzzzyToast.show(
      context,
      message: message,
      kind: failure == null ? FuzzzyToastKind.success : FuzzzyToastKind.error,
    );
  }

  void _onUseOwnPassword() {
    _run(
      () => context.read<VaultAuthCubit>().useOwnPassword(
            masterPassword: _masterPasswordController.text,
            newPassword: _newPasswordController.text,
          ),
    );
  }

  void _onUseMasterPassword() {
    _run(
      () => context.read<VaultAuthCubit>().useMasterPassword(
            vaultPassword: _vaultPasswordController.text,
            masterPassword: _masterPasswordController.text,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;
    final vaultState = context.watch<VaultAuthCubit>().state;
    final hasVault = vaultState.authState == VaultAuthEnum.locked ||
        vaultState.authState == VaultAuthEnum.unlocking ||
        vaultState.authState == VaultAuthEnum.unlocked;
    if (!hasVault) return const SizedBox.shrink();

    final usesOwn = vaultState.usesOwnPassword;
    final bodyS = context.fuzzzyTextStyles.bodyS;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          localizations.vaultPasswordModeTitle,
          style: context.fuzzzyTextStyles.titleM.copyWith(color: colors.ink),
        ),
        SizedBox(height: space.s),
        Text(
          usesOwn
              ? localizations.vaultUsesOwnPassword
              : localizations.vaultUsesMasterPassword,
          key: const ValueKey('vault.passwordMode'),
          style: bodyS.copyWith(color: colors.inkMute),
        ),
        SizedBox(height: space.m),
        if (usesOwn) ...[
          FuzzzyTextField(
            controller: _vaultPasswordController,
            label: localizations.vaultCurrentPassword,
            obscure: true,
            qaId: 'vault.mode.vaultPassword',
          ),
          SizedBox(height: space.s),
          FuzzzyTextField(
            controller: _masterPasswordController,
            label: localizations.masterPassword,
            obscure: true,
            qaId: 'vault.mode.masterPassword',
          ),
          SizedBox(height: space.m),
          FuzzzyButton(
            label: localizations.vaultUseMasterPassword,
            variant: FuzzzyButtonVariant.secondary,
            qaId: 'vault.mode.useMaster',
            loading: _busy,
            onPressed: !_busy &&
                    _vaultPasswordController.text.isNotEmpty &&
                    _masterPasswordController.text.isNotEmpty
                ? _onUseMasterPassword
                : null,
          ),
        ] else ...[
          FuzzzyTextField(
            controller: _masterPasswordController,
            label: localizations.masterPassword,
            obscure: true,
            qaId: 'vault.mode.masterPassword',
          ),
          SizedBox(height: space.s),
          NewPasswordFields(
            passwordController: _newPasswordController,
            confirmController: _confirmController,
            label: localizations.vaultOwnNewPassword,
            qaId: 'vault.mode.new',
          ),
          SizedBox(height: space.s),
          const VaultOwnPasswordNote(),
          SizedBox(height: space.m),
          FuzzzyButton(
            label: localizations.vaultUseOwnPassword,
            variant: FuzzzyButtonVariant.secondary,
            qaId: 'vault.mode.useOwn',
            loading: _busy,
            onPressed: !_busy &&
                    _masterPasswordController.text.isNotEmpty &&
                    NewPasswordFields.isReady(
                      password: _newPasswordController.text,
                      confirm: _confirmController.text,
                    )
                ? _onUseOwnPassword
                : null,
          ),
        ],
      ],
    );
  }
}
