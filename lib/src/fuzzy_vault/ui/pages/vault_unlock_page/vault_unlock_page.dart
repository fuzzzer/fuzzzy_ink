import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class VaultUnlockPage extends StatefulWidget {
  const VaultUnlockPage({super.key});

  @override
  State<VaultUnlockPage> createState() => _VaultUnlockPageState();
}

class _VaultUnlockPageState extends State<VaultUnlockPage>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _autoBiometricAttempted = false;
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _autoBiometricAttempted) return;
      final cubit = context.read<VaultAuthCubit>();
      if (cubit.state.biometricEnabled &&
          cubit.state.authState == VaultAuthEnum.locked) {
        _autoBiometricAttempted = true;
        cubit.unlockWithBiometrics();
      }
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onUnlock() {
    if (_passwordController.text.isEmpty) return;
    context.read<VaultAuthCubit>().unlock(_passwordController.text);
  }

  void _onBiometricUnlock() {
    context.read<VaultAuthCubit>().unlockWithBiometrics();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VaultAuthCubit, VaultAuthState>(
      listener: (context, state) {
        if (state.failureType != null) {
          _shakeController.forward(from: 0);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.failureType == VaultFailureType.incorrectMasterPassword
                    ? currentContextLocalization.vaultIncorrectPassword
                    : currentContextLocalization
                        .vaultUnlockFailed(state.failureType!.name),
              ),
            ),
          );
        }
        if (state.biometricInvalidated) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                currentContextLocalization.vaultBiometricInvalidated,
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state.authState == VaultAuthEnum.unlocking;

        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  Icon(
                    Icons.lock_rounded,
                    size: 80,
                    color: context.fuzzzyColors.ink,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    currentContextLocalization.vaultUnlockVault,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: context.fuzzzyColors.ink,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  AnimatedBuilder(
                    animation: _shakeController,
                    builder: (context, child) {
                      final sineValue =
                          math.sin(4 * 3.14159265 * _shakeController.value) *
                              8 *
                              (1 - _shakeController.value);
                      return Transform.translate(
                        offset: Offset(sineValue, 0),
                        child: child,
                      );
                    },
                    child: FuzzzyTextField(
                      controller: _passwordController,
                      label: currentContextLocalization.vaultPassword,
                      obscure: !_isPasswordVisible,
                      onSubmitted: (_) => _onUnlock(),
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
                  ),
                  if (state.failureType != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      currentContextLocalization.vaultIncorrectPassword,
                      style: TextStyle(
                        color: context.fuzzzyColors.destructiveText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 40),
                  FuzzzyButton(
                    label: currentContextLocalization.vaultUnlock,
                    onPressed: _passwordController.text.isNotEmpty && !isLoading
                        ? _onUnlock
                        : null,
                  ),
                  if (state.biometricEnabled) ...[
                    const SizedBox(height: 24),
                    InkWell(
                      onTap: isLoading ? null : _onBiometricUnlock,
                      borderRadius: BorderRadius.circular(48),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Icon(
                              Icons.fingerprint,
                              size: 56,
                              color: context.fuzzzyColors.ink,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currentContextLocalization.vaultBiometricUnlock,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: context.fuzzzyColors.inkMute,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  Text(
                    currentContextLocalization.vaultForgotPassword,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.fuzzzyColors.inkMute,
                        ),
                    textAlign: TextAlign.center,
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
