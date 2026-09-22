import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class VaultCreatePage extends StatefulWidget {
  const VaultCreatePage({super.key});

  @override
  State<VaultCreatePage> createState() => _VaultCreatePageState();
}

class _VaultCreatePageState extends State<VaultCreatePage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmVisible = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
    _confirmController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _isValid() {
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    if (password.isEmpty || confirm.isEmpty) return false;
    if (password != confirm) return false;

    final service = sl.get<PasswordStrengthService>();
    final strength = service.assess(password);
    return strength.level == PasswordStrengthLevel.good ||
        strength.level == PasswordStrengthLevel.strong;
  }

  void _onCreate() {
    if (!_isValid()) return;
    context.read<VaultAuthCubit>().createVault(_passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VaultAuthCubit, VaultAuthState>(
      listener: (context, state) {
        if (state.failureType != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                currentContextLocalization
                    .vaultFailedToCreate(state.failureType!.name),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state.authState ==
            VaultAuthEnum
                .unlocking; // We use unlocking state during create too in Cubit
        // Wait, does createVault emit unlocking? Let's check.

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
                    currentContextLocalization.vaultCreateYourVault,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.fuzzzyColors.ink,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    currentContextLocalization.vaultCreateDescription,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.fuzzzyColors.inkMute,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  FuzzzyTextField(
                    controller: _passwordController,
                    label: currentContextLocalization.vaultPassword,
                    obscure: !_isPasswordVisible,
                    suffix: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: context.fuzzzyColors.inkMute,
                      ),
                      onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_passwordController.text.isNotEmpty) ...[
                    PasswordStrengthIndicator(
                      password: _passwordController.text,
                    ),
                    const SizedBox(height: 24),
                  ],
                  FuzzzyTextField(
                    controller: _confirmController,
                    label: currentContextLocalization.vaultConfirmPassword,
                    obscure: !_isConfirmVisible,
                    suffix: IconButton(
                      icon: Icon(
                        _isConfirmVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: context.fuzzzyColors.inkMute,
                      ),
                      onPressed: () => setState(
                        () => _isConfirmVisible = !_isConfirmVisible,
                      ),
                    ),
                  ),
                  if (_confirmController.text.isNotEmpty &&
                      _passwordController.text != _confirmController.text) ...[
                    const SizedBox(height: 8),
                    Text(
                      currentContextLocalization.vaultPasswordsDoNotMatch,
                      style: TextStyle(
                        color: context.fuzzzyColors.destructiveText,
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.fuzzzyColors.destructive
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.fuzzzyColors.destructiveLine,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: context.fuzzzyColors.destructiveText,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            currentContextLocalization
                                .vaultPasswordCannotBeReset,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: context.fuzzzyColors.destructiveText,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  FuzzzyButton(
                    label: currentContextLocalization.vaultCreateVault,
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
