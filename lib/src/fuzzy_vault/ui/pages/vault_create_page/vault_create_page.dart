import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Creating the vault: by default the master password opens it (confirmed
/// here by typing it); on request the vault gets a password of its own.
class VaultCreatePage extends StatefulWidget {
  const VaultCreatePage({super.key});

  @override
  State<VaultCreatePage> createState() => _VaultCreatePageState();
}

class _VaultCreatePageState extends State<VaultCreatePage> {
  final _masterPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _ownPassword = false;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _masterPasswordController,
      _passwordController,
      _confirmController,
    ]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _masterPasswordController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _isValid() {
    if (!_ownPassword) return _masterPasswordController.text.isNotEmpty;
    return NewPasswordFields.isReady(
      password: _passwordController.text,
      confirm: _confirmController.text,
    );
  }

  void _onCreate() {
    if (!_isValid()) return;
    context.read<VaultAuthCubit>().createVault(
          _ownPassword
              ? _passwordController.text
              : _masterPasswordController.text,
          ownPassword: _ownPassword,
        );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = currentContextLocalization;

    return BlocConsumer<VaultAuthCubit, VaultAuthState>(
      listener: (context, state) {
        if (state.failureType != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.failureType == VaultFailureType.incorrectMasterPassword
                    ? localizations.chatAuthIncorrectPassword
                    : localizations.vaultFailedToCreate(
                        state.failureType!.name,
                      ),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state.status == StateStatus.loading;

        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Icon(
                    Icons.lock_person_rounded,
                    size: 64,
                    color: context.fuzzzyColors.ink,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    localizations.vaultCreateYourVault,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.fuzzzyColors.ink,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    localizations.vaultCreateWithMasterDescription,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.fuzzzyColors.inkMute,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  if (_ownPassword) ...[
                    NewPasswordFields(
                      passwordController: _passwordController,
                      confirmController: _confirmController,
                      label: localizations.vaultPassword,
                      onSubmitted: _onCreate,
                      qaId: 'vault.create',
                    ),
                    const SizedBox(height: 24),
                    Text(
                      localizations.vaultOwnPasswordNote,
                      style: context.fuzzzyTextStyles.bodyS.copyWith(
                        color: context.fuzzzyColors.destructiveText,
                      ),
                    ),
                  ] else
                    FuzzzyTextField(
                      controller: _masterPasswordController,
                      label: localizations.masterPassword,
                      obscure: true,
                      qaId: 'vault.create.masterPassword',
                      onSubmitted: (_) => _onCreate(),
                    ),
                  const SizedBox(height: 24),
                  FuzzzyCheckbox(
                    value: _ownPassword,
                    label: localizations.vaultUseOwnPassword,
                    qaId: 'vault.create.ownPassword',
                    onChanged: isLoading
                        ? null
                        : (value) => setState(() => _ownPassword = value),
                  ),
                  const SizedBox(height: 40),
                  FuzzzyButton(
                    label: localizations.vaultCreateVault,
                    qaId: 'vault.create.submit',
                    onPressed: _isValid() && !isLoading ? _onCreate : null,
                  ),
                ],
              ),
            ),
            if (isLoading)
              ColoredBox(
                color: context.fuzzzyColors.ground.withValues(alpha: 0.54),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        );
      },
    );
  }
}
