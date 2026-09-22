import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class FuzzyUserAuthPage extends StatelessWidget {
  const FuzzyUserAuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FuzzyUserAuthPreferencesCubit>(
      create: (context) => FuzzyUserAuthPreferencesCubit(
        chatAuthRepository: sl.get<ChatAuthRepository>(),
        fuzzyAuthStore: sl.get<FuzzyAuthStore>(),
        biometricAuthRepository: sl.get<BiometricAuthRepository>(),
      ),
      child: const _FuzzyUserAuthPageContent(),
    );
  }
}

class _FuzzyUserAuthPageContent extends StatefulWidget {
  const _FuzzyUserAuthPageContent();

  @override
  State<_FuzzyUserAuthPageContent> createState() =>
      _FuzzyUserAuthPageContentState();
}

class _FuzzyUserAuthPageContentState extends State<_FuzzyUserAuthPageContent> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _vaultPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isVaultPasswordVisible = false;
  bool _showMismatchError = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _oldPasswordController.dispose();
    _vaultPasswordController.dispose();
    super.dispose();
  }

  void _clearFields() {
    _passwordController.clear();
    _confirmPasswordController.clear();
    _oldPasswordController.clear();
    setState(() {
      _showMismatchError = false;
    });
  }

  void _togglePasswordVisibility() {
    setState(() => _isPasswordVisible = !_isPasswordVisible);
  }

  void _onEnableAuth() {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (password.isEmpty) return;

    if (password != confirm) {
      setState(() => _showMismatchError = true);
      return;
    }

    setState(() => _showMismatchError = false);
    context.read<FuzzyUserAuthPreferencesCubit>().enableAuth(password);
  }

  void _onChangePassword() {
    final oldPassword = _oldPasswordController.text;
    final newPassword = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (oldPassword.isEmpty || newPassword.isEmpty) return;

    if (newPassword != confirm) {
      setState(() => _showMismatchError = true);
      return;
    }

    setState(() => _showMismatchError = false);
    context.read<FuzzyUserAuthPreferencesCubit>().changePassword(
          oldPassword: oldPassword,
          newPassword: newPassword,
        );
  }

  void _onDisableAuth() {
    final oldPassword = _oldPasswordController.text;
    if (oldPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentContextLocalization.chatAuthEnterPassword),
        ),
      );
      return;
    }

    context.read<FuzzyUserAuthPreferencesCubit>().disableAuth(oldPassword);
  }

  void _onEnableBiometric() {
    final oldPassword = _oldPasswordController.text;
    if (oldPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(currentContextLocalization.chatAuthBiometricDescription),
        ),
      );
      return;
    }

    context.read<FuzzyUserAuthPreferencesCubit>().enableBiometric(oldPassword);
  }

  void _onDisableBiometric() {
    context.read<FuzzyUserAuthPreferencesCubit>().disableBiometric();
  }

  void _toggleVaultPasswordVisibility() {
    setState(() => _isVaultPasswordVisible = !_isVaultPasswordVisible);
  }

  Future<void> _onEnableVaultBiometric() async {
    final password = _vaultPasswordController.text;
    final localizations = currentContextLocalization;
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.vaultBiometricDescription)),
      );
      return;
    }
    final success =
        await context.read<VaultAuthCubit>().enableBiometric(password);
    if (!mounted) return;
    if (success) {
      _vaultPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.vaultBiometricEnabled)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.vaultBiometricInvalidPassword)),
      );
    }
  }

  Future<void> _onDisableVaultBiometric() async {
    await context.read<VaultAuthCubit>().disableBiometric();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fuzzzyColors = context.fuzzzyColors;
    final localizations = context.fuzzzyInkLocalizations;
    final authStatus = context.watch<FuzzyAuthStore>().state.status;
    final isAuthEnabled = authStatus.isAuthenticated || authStatus.isLocked;

    return BlocConsumer<FuzzyUserAuthPreferencesCubit,
        FuzzyUserAuthPreferencesState>(
      listener: (context, state) {
        if (state.activationStatus == StateStatus.success) {
          _clearFields();
          final String message;
          switch (state.lastAction) {
            case AuthPreferencesAction.enable:
              message = localizations.chatAuthEnabled;
            case AuthPreferencesAction.disable:
              message = localizations.chatAuthDisabled;
            case AuthPreferencesAction.changePassword:
              message = localizations.chatAuthPasswordChanged;
            case AuthPreferencesAction.enableBiometric:
              message = localizations.chatAuthBiometricEnabled;
            case AuthPreferencesAction.disableBiometric:
              message = localizations.chatAuthDisabled;
            case AuthPreferencesAction.none:
              message = localizations.chatAuthEnabled;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        } else if (state.activationStatus == StateStatus.failed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.activationFailure?.message ?? localizations.unknownError,
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state.activationStatus == StateStatus.loading;

        return Stack(
          children: [
            FuzzyScaffold(
              body: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child:
                        FuzzzyAppBar(title: localizations.chatAuthSetupTitle),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizations.chatAuthProtectionDescription,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: fuzzzyColors.inkMute,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (isAuthEnabled) ...[
                            _ChangePasswordSection(
                              passwordController: _passwordController,
                              confirmPasswordController:
                                  _confirmPasswordController,
                              oldPasswordController: _oldPasswordController,
                              isPasswordVisible: _isPasswordVisible,
                              showMismatchError: _showMismatchError,
                              onTogglePasswordVisibility:
                                  _togglePasswordVisibility,
                              onChangePassword: _onChangePassword,
                              onDisableAuth: _onDisableAuth,
                            ),
                            const SizedBox(height: 16),
                            _BiometricSection(
                              onEnableBiometric: _onEnableBiometric,
                              onDisableBiometric: _onDisableBiometric,
                            ),
                          ] else
                            _SetupPasswordSection(
                              passwordController: _passwordController,
                              confirmPasswordController:
                                  _confirmPasswordController,
                              isPasswordVisible: _isPasswordVisible,
                              showMismatchError: _showMismatchError,
                              onTogglePasswordVisibility:
                                  _togglePasswordVisibility,
                              onEnableAuth: _onEnableAuth,
                            ),
                          const SizedBox(height: 32),
                          Divider(
                            color: fuzzzyColors.focus.withValues(alpha: 0.2),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            localizations.vaultAuthentication,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: fuzzzyColors.ink,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            localizations.vaultAuthenticationDescription,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: fuzzzyColors.inkMute,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _VaultBiometricSection(
                            passwordController: _vaultPasswordController,
                            isPasswordVisible: _isVaultPasswordVisible,
                            onTogglePasswordVisibility:
                                _toggleVaultPasswordVisibility,
                            onEnableBiometric: _onEnableVaultBiometric,
                            onDisableBiometric: _onDisableVaultBiometric,
                          ),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              Positioned.fill(
                child: ColoredBox(
                  color: context.fuzzzyColors.ground.withValues(alpha: 0.54),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        state.lastAction == AuthPreferencesAction.changePassword
                            ? localizations.chatAuthResecuringKeys
                            : localizations.chatAuthMigratingKeys,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: context.fuzzzyColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SetupPasswordSection extends StatelessWidget {
  const _SetupPasswordSection({
    required this.passwordController,
    required this.confirmPasswordController,
    required this.isPasswordVisible,
    required this.showMismatchError,
    required this.onTogglePasswordVisibility,
    required this.onEnableAuth,
  });

  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool isPasswordVisible;
  final bool showMismatchError;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onEnableAuth;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;

    return BlocBuilder<FuzzyUserAuthPreferencesCubit,
        FuzzyUserAuthPreferencesState>(
      builder: (context, state) {
        final isLoading = state.activationStatus == StateStatus.loading;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FuzzzyTextField(
              controller: passwordController,
              label: localizations.chatAuthPassword,
              obscure: !isPasswordVisible,
              suffix: _PasswordVisibilityToggle(
                isVisible: isPasswordVisible,
                onPressed: onTogglePasswordVisibility,
              ),
            ),
            const SizedBox(height: 12),
            FuzzzyTextField(
              controller: confirmPasswordController,
              label: localizations.chatAuthConfirmPassword,
              obscure: !isPasswordVisible,
              onSubmitted: (_) => onEnableAuth(),
            ),
            if (showMismatchError) ...[
              const SizedBox(height: 8),
              Text(
                localizations.chatAuthPasswordsDoNotMatch,
                style: TextStyle(color: context.fuzzzyColors.destructiveText),
              ),
            ],
            const SizedBox(height: 24),
            FuzzzyButton(
              label: localizations.chatAuthEnableProtection,
              onPressed: !isLoading ? onEnableAuth : null,
            ),
          ],
        );
      },
    );
  }
}

class _ChangePasswordSection extends StatelessWidget {
  const _ChangePasswordSection({
    required this.passwordController,
    required this.confirmPasswordController,
    required this.oldPasswordController,
    required this.isPasswordVisible,
    required this.showMismatchError,
    required this.onTogglePasswordVisibility,
    required this.onChangePassword,
    required this.onDisableAuth,
  });

  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final TextEditingController oldPasswordController;
  final bool isPasswordVisible;
  final bool showMismatchError;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onChangePassword;
  final VoidCallback onDisableAuth;

  @override
  Widget build(BuildContext context) {
    final fuzzzyColors = context.fuzzzyColors;
    final localizations = context.fuzzzyInkLocalizations;

    return BlocBuilder<FuzzyUserAuthPreferencesCubit,
        FuzzyUserAuthPreferencesState>(
      builder: (context, state) {
        final isLoading = state.activationStatus == StateStatus.loading;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusBadge(
              text: localizations.chatAuthEnabled,
              color: fuzzzyColors.focus,
            ),
            const SizedBox(height: 24),
            FuzzzyTextField(
              controller: oldPasswordController,
              label: localizations.chatAuthCurrentPassword,
              obscure: !isPasswordVisible,
            ),
            const SizedBox(height: 12),
            FuzzzyTextField(
              controller: passwordController,
              label: localizations.chatAuthNewPassword,
              obscure: !isPasswordVisible,
              suffix: _PasswordVisibilityToggle(
                isVisible: isPasswordVisible,
                onPressed: onTogglePasswordVisibility,
              ),
            ),
            const SizedBox(height: 12),
            FuzzzyTextField(
              controller: confirmPasswordController,
              label: localizations.chatAuthConfirmPassword,
              obscure: !isPasswordVisible,
              onSubmitted: (_) => onChangePassword(),
            ),
            if (showMismatchError) ...[
              const SizedBox(height: 8),
              Text(
                localizations.chatAuthPasswordsDoNotMatch,
                style: TextStyle(color: context.fuzzzyColors.destructiveText),
              ),
            ],
            const SizedBox(height: 24),
            FuzzzyButton(
              label: localizations.chatAuthSetPassword,
              onPressed: !isLoading ? onChangePassword : null,
            ),
            const SizedBox(height: 12),
            FuzzzyButton(
              label: localizations.chatAuthDisableProtection,
              onPressed: !isLoading ? onDisableAuth : null,
            ),
          ],
        );
      },
    );
  }
}

class _PasswordVisibilityToggle extends StatelessWidget {
  const _PasswordVisibilityToggle({
    required this.isVisible,
    required this.onPressed,
  });

  final bool isVisible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        isVisible ? Icons.visibility_off : Icons.visibility,
        color: context.fuzzzyColors.inkMute,
      ),
      onPressed: onPressed,
    );
  }
}

class _BiometricSection extends StatefulWidget {
  const _BiometricSection({
    required this.onEnableBiometric,
    required this.onDisableBiometric,
  });

  final VoidCallback onEnableBiometric;
  final VoidCallback onDisableBiometric;

  @override
  State<_BiometricSection> createState() => _BiometricSectionState();
}

class _BiometricSectionState extends State<_BiometricSection> {
  bool? _canUseBiometrics;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final canUse = await sl.get<BiometricAuthRepository>().canUseBiometrics();
    if (!mounted) return;
    setState(() => _canUseBiometrics = canUse);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fuzzzyColors = context.fuzzzyColors;
    final localizations = context.fuzzzyInkLocalizations;
    final biometricEnabled =
        context.watch<FuzzyAuthStore>().state.biometricEnabled;
    final canUse = _canUseBiometrics;

    return BlocBuilder<FuzzyUserAuthPreferencesCubit,
        FuzzyUserAuthPreferencesState>(
      builder: (context, state) {
        final isLoading = state.activationStatus == StateStatus.loading;

        if (canUse == false) {
          return Text(
            localizations.chatAuthBiometricUnavailable,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: fuzzzyColors.inkMute),
          );
        }

        if (canUse == null) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (biometricEnabled) ...[
              _StatusBadge(
                text: localizations.chatAuthBiometricEnabled,
                color: fuzzzyColors.focus,
              ),
              const SizedBox(height: 12),
              FuzzzyButton(
                label: localizations.chatAuthBiometricDisable,
                onPressed: !isLoading ? widget.onDisableBiometric : null,
              ),
            ] else ...[
              Text(
                localizations.chatAuthBiometricDescription,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: fuzzzyColors.inkMute),
              ),
              const SizedBox(height: 12),
              FuzzzyButton(
                label: localizations.chatAuthBiometricEnable,
                onPressed: !isLoading ? widget.onEnableBiometric : null,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _VaultBiometricSection extends StatefulWidget {
  const _VaultBiometricSection({
    required this.passwordController,
    required this.isPasswordVisible,
    required this.onTogglePasswordVisibility,
    required this.onEnableBiometric,
    required this.onDisableBiometric,
  });

  final TextEditingController passwordController;
  final bool isPasswordVisible;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onEnableBiometric;
  final VoidCallback onDisableBiometric;

  @override
  State<_VaultBiometricSection> createState() => _VaultBiometricSectionState();
}

class _VaultBiometricSectionState extends State<_VaultBiometricSection> {
  bool? _canUseBiometrics;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final canUse = await sl.get<BiometricAuthRepository>().canUseBiometrics();
    if (!mounted) return;
    setState(() => _canUseBiometrics = canUse);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fuzzzyColors = context.fuzzzyColors;
    final localizations = context.fuzzzyInkLocalizations;
    final vaultState = context.watch<VaultAuthCubit>().state;
    final biometricEnabled = vaultState.biometricEnabled;
    final hasVault = vaultState.authState != VaultAuthEnum.noVault &&
        vaultState.authState != VaultAuthEnum.initial;
    final canUse = _canUseBiometrics;

    if (canUse == false) {
      return Text(
        localizations.vaultBiometricUnavailable,
        style: theme.textTheme.bodySmall?.copyWith(color: fuzzzyColors.inkMute),
      );
    }

    if (canUse == null) {
      return const SizedBox.shrink();
    }

    if (!hasVault) {
      return Text(
        localizations.vaultNotCreated,
        style: theme.textTheme.bodySmall?.copyWith(color: fuzzzyColors.inkMute),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (biometricEnabled) ...[
          _StatusBadge(
            text: localizations.vaultBiometricEnabled,
            color: fuzzzyColors.focus,
          ),
          const SizedBox(height: 12),
          FuzzzyButton(
            label: localizations.vaultBiometricDisable,
            onPressed: widget.onDisableBiometric,
          ),
        ] else ...[
          Text(
            localizations.vaultBiometricDescription,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: fuzzzyColors.inkMute),
          ),
          const SizedBox(height: 12),
          FuzzzyTextField(
            controller: widget.passwordController,
            label: localizations.vaultPassword,
            obscure: !widget.isPasswordVisible,
            suffix: _PasswordVisibilityToggle(
              isVisible: widget.isPasswordVisible,
              onPressed: widget.onTogglePasswordVisibility,
            ),
          ),
          const SizedBox(height: 12),
          FuzzzyButton(
            label: localizations.vaultBiometricEnable,
            onPressed: widget.onEnableBiometric,
          ),
        ],
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.shield, color: color, size: 20),
          const SizedBox(width: 10),
          Text(
            text,
            style: context.fuzzzyTextStyles.body.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
