import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// The master password's settings: change it, the biometric shortcut, the
/// recovery key, the auto-lock times, and which password opens the vault.
/// The master password itself cannot be switched off.
class FuzzyUserAuthPage extends StatelessWidget {
  const FuzzyUserAuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FuzzyUserAuthPreferencesCubit>(
      create: (context) => FuzzyUserAuthPreferencesCubit(
        chatAuthRepository: sl.get<ChatAuthRepository>(),
        fuzzyAuthStore: sl.get<FuzzyAuthStore>(),
        biometricAuthRepository: sl.get<BiometricAuthRepository>(),
        passwordStrengthService: sl.get<PasswordStrengthService>(),
        vaultRepository: sl.get<VaultRepository>(),
      )..loadRecoveryKeyStatus(),
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
  final _recoveryPasswordController = TextEditingController();
  final _recoveryVaultPasswordController = TextEditingController();
  final _vaultPasswordController = TextEditingController();
  bool _isVaultPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    // The strength meter and the buttons follow the fields as they are typed.
    for (final controller in [
      _passwordController,
      _confirmPasswordController,
      _oldPasswordController,
      _recoveryPasswordController,
      _recoveryVaultPasswordController,
    ]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _oldPasswordController.dispose();
    _recoveryPasswordController.dispose();
    _recoveryVaultPasswordController.dispose();
    _vaultPasswordController.dispose();
    super.dispose();
  }

  void _clearFields() {
    _passwordController.clear();
    _confirmPasswordController.clear();
    _oldPasswordController.clear();
    _recoveryPasswordController.clear();
    _recoveryVaultPasswordController.clear();
  }

  void _onChangePassword() {
    final oldPassword = _oldPasswordController.text;
    if (oldPassword.isEmpty ||
        !NewPasswordFields.isReady(
          password: _passwordController.text,
          confirm: _confirmPasswordController.text,
        )) {
      return;
    }
    context.read<FuzzyUserAuthPreferencesCubit>().changePassword(
          oldPassword: oldPassword,
          newPassword: _passwordController.text,
        );
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

  void _onNewRecoveryKey() {
    final password = _recoveryPasswordController.text;
    if (password.isEmpty) return;
    final vaultHasOwnPassword =
        context.read<VaultAuthCubit>().state.usesOwnPassword;
    context.read<FuzzyUserAuthPreferencesCubit>().newRecoveryKey(
          password,
          vaultPassword: vaultHasOwnPassword
              ? _recoveryVaultPasswordController.text
              : null,
        );
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
    final result =
        await context.read<VaultAuthCubit>().enableBiometric(password);
    if (!mounted) return;
    if (result == BiometricEnableResult.enabled) {
      _vaultPasswordController.clear();
    }
    final message = switch (result) {
      BiometricEnableResult.enabled => localizations.vaultBiometricEnabled,
      BiometricEnableResult.wrongPassword =>
        localizations.vaultBiometricInvalidPassword,
      BiometricEnableResult.notStrongEnough =>
        localizations.biometricNotStrongEnough,
      BiometricEnableResult.cancelled ||
      BiometricEnableResult.failed =>
        localizations.biometricNotTurnedOn,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _onDisableVaultBiometric() async {
    await context.read<VaultAuthCubit>().disableBiometric();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fuzzzyColors = context.fuzzzyColors;
    final localizations = context.fuzzzyInkLocalizations;

    return BlocConsumer<FuzzyUserAuthPreferencesCubit,
        FuzzyUserAuthPreferencesState>(
      listener: (context, state) {
        if (state.activationStatus == StateStatus.success) {
          final String? message;
          switch (state.lastAction) {
            case AuthPreferencesAction.changePassword:
              _clearFields();
              context.read<VaultAuthCubit>().onMasterPasswordChanged();
              message = localizations.chatAuthPasswordChanged;
            case AuthPreferencesAction.enableBiometric:
              _clearFields();
              message = localizations.chatAuthBiometricEnabled;
            case AuthPreferencesAction.newRecoveryKey:
              _clearFields();
              context.read<VaultAuthCubit>().refreshRecovery();
              message = null;
            case AuthPreferencesAction.saveRecoveryKey:
              context.read<VaultAuthCubit>().refreshRecovery();
              message = localizations.recoveryKeyIsSet;
            case AuthPreferencesAction.skipRecoveryKey:
              context.read<VaultAuthCubit>().refreshRecovery();
              message = null;
            case AuthPreferencesAction.disableBiometric:
            case AuthPreferencesAction.none:
              message = null;
          }
          if (message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
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
        final pendingRecoveryKey = state.pendingRecoveryKey;
        final cubit = context.read<FuzzyUserAuthPreferencesCubit>();

        return Stack(
          children: [
            FuzzyScaffold(
              body: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: FuzzzyAppBar(title: localizations.masterPassword),
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
                          _ChangePasswordSection(
                            passwordController: _passwordController,
                            confirmPasswordController:
                                _confirmPasswordController,
                            oldPasswordController: _oldPasswordController,
                            onChangePassword: _onChangePassword,
                          ),
                          const SizedBox(height: 16),
                          _BiometricSection(
                            onEnableBiometric: _onEnableBiometric,
                            onDisableBiometric: _onDisableBiometric,
                          ),
                          const SizedBox(height: 32),
                          _SectionTitle(localizations.recoveryKeyTitle),
                          const SizedBox(height: 8),
                          if (pendingRecoveryKey != null)
                            RecoveryKeyPanel(
                              recoveryKey: pendingRecoveryKey,
                              busy: isLoading,
                              onConfirmed: cubit.confirmRecoveryKeySaved,
                              onSkipped: cubit.skipRecoveryKey,
                            )
                          else
                            _RecoveryKeySection(
                              hasRecoveryKey: state.hasRecoveryKey,
                              passwordController: _recoveryPasswordController,
                              vaultPasswordController:
                                  _recoveryVaultPasswordController,
                              onCreate: isLoading ? null : _onNewRecoveryKey,
                            ),
                          const SizedBox(height: 32),
                          _SectionTitle(localizations.autoLockTitle),
                          const SizedBox(height: 8),
                          const _AutoLockSection(),
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
                          const VaultPasswordModeSection(),
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
                        localizations.chatAuthResecuringKeys,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.fuzzzyTextStyles.titleM
          .copyWith(color: context.fuzzzyColors.ink),
    );
  }
}

class _ChangePasswordSection extends StatelessWidget {
  const _ChangePasswordSection({
    required this.passwordController,
    required this.confirmPasswordController,
    required this.oldPasswordController,
    required this.onChangePassword,
  });

  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final TextEditingController oldPasswordController;
  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) {
    final fuzzzyColors = context.fuzzzyColors;
    final localizations = context.fuzzzyInkLocalizations;

    return BlocBuilder<FuzzyUserAuthPreferencesCubit,
        FuzzyUserAuthPreferencesState>(
      builder: (context, state) {
        final isLoading = state.activationStatus == StateStatus.loading;
        final isReady = oldPasswordController.text.isNotEmpty &&
            NewPasswordFields.isReady(
              password: passwordController.text,
              confirm: confirmPasswordController.text,
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusBadge(
              text: localizations.masterPasswordIsOn,
              color: fuzzzyColors.focus,
            ),
            const SizedBox(height: 24),
            FuzzzyTextField(
              controller: oldPasswordController,
              label: localizations.chatAuthCurrentPassword,
              obscure: true,
              qaId: 'auth.currentPassword',
            ),
            const SizedBox(height: 12),
            NewPasswordFields(
              passwordController: passwordController,
              confirmController: confirmPasswordController,
              label: localizations.chatAuthNewPassword,
              onSubmitted: onChangePassword,
              qaId: 'auth.newPassword',
            ),
            const SizedBox(height: 24),
            FuzzzyButton(
              label: localizations.chatAuthSetPassword,
              qaId: 'auth.changePassword',
              onPressed: !isLoading && isReady ? onChangePassword : null,
            ),
          ],
        );
      },
    );
  }
}

class _RecoveryKeySection extends StatelessWidget {
  const _RecoveryKeySection({
    required this.hasRecoveryKey,
    required this.passwordController,
    required this.vaultPasswordController,
    required this.onCreate,
  });

  final bool? hasRecoveryKey;
  final TextEditingController passwordController;

  /// A vault with its own password: its password too, so the new key opens
  /// it (the master password alone never does).
  final TextEditingController vaultPasswordController;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final colors = context.fuzzzyColors;
    final hasKey = hasRecoveryKey;
    final vaultHasOwnPassword = context.select<VaultAuthCubit, bool>(
      (cubit) => cubit.state.usesOwnPassword,
    );
    final isReady = passwordController.text.isNotEmpty &&
        (!vaultHasOwnPassword || vaultPasswordController.text.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasKey != null)
          Text(
            hasKey
                ? localizations.recoveryKeyIsSet
                : localizations.recoveryKeyNotSet,
            key: const ValueKey('auth.recoveryKeyStatus'),
            style: context.fuzzzyTextStyles.bodyS.copyWith(
              color: hasKey ? colors.inkMute : colors.destructiveText,
            ),
          ),
        const SizedBox(height: 8),
        Text(
          localizations.recoveryKeyCreateNewDescription,
          style: context.fuzzzyTextStyles.bodyS.copyWith(color: colors.inkMute),
        ),
        const SizedBox(height: 12),
        FuzzzyTextField(
          controller: passwordController,
          label: localizations.masterPassword,
          obscure: true,
          qaId: 'auth.recoveryPassword',
        ),
        if (vaultHasOwnPassword) ...[
          const SizedBox(height: 12),
          Text(
            localizations.recoveryKeyVaultPasswordNote,
            style:
                context.fuzzzyTextStyles.bodyS.copyWith(color: colors.inkMute),
          ),
          const SizedBox(height: 8),
          FuzzzyTextField(
            controller: vaultPasswordController,
            label: localizations.vaultPassword,
            obscure: true,
            qaId: 'auth.recoveryVaultPassword',
          ),
        ],
        const SizedBox(height: 12),
        FuzzzyButton(
          label: localizations.recoveryKeyCreateNew,
          variant: FuzzzyButtonVariant.secondary,
          qaId: 'auth.newRecoveryKey',
          onPressed: isReady ? onCreate : null,
        ),
      ],
    );
  }
}

/// The two auto-lock times, as the offered choices.
class _AutoLockSection extends StatelessWidget {
  const _AutoLockSection();

  String _labelOf(BuildContext context, Duration duration) {
    final localizations = context.fuzzzyInkLocalizations;
    return duration == Duration.zero
        ? localizations.autoLockImmediately
        : localizations.autoLockMinutes(duration.inMinutes);
  }

  Future<void> _update(BuildContext context, AutoLockSettings settings) async {
    final saved = await context.read<AutoLockCubit>().update(settings);
    if (!saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.fuzzzyInkLocalizations.autoLockSaveFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final settings = context.watch<AutoLockCubit>().state;
    final labelStyle = context.fuzzzyTextStyles.bodyS
        .copyWith(color: context.fuzzzyColors.inkMute);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(localizations.autoLockIdle, style: labelStyle),
        const SizedBox(height: 8),
        FuzzzySegmentedControl(
          segments: [
            for (final choice in AutoLockSettings.idleChoices)
              _labelOf(context, choice),
          ],
          selectedIndex: AutoLockSettings.idleChoices.indexOf(settings.idle),
          qaId: 'auth.autoLockIdle',
          onChanged: (index) => _update(
            context,
            settings.copyWith(idle: AutoLockSettings.idleChoices[index]),
          ),
        ),
        const SizedBox(height: 16),
        Text(localizations.autoLockBackground, style: labelStyle),
        const SizedBox(height: 8),
        FuzzzySegmentedControl(
          segments: [
            for (final choice in AutoLockSettings.backgroundChoices)
              _labelOf(context, choice),
          ],
          selectedIndex:
              AutoLockSettings.backgroundChoices.indexOf(settings.background),
          qaId: 'auth.autoLockBackground',
          onChanged: (index) => _update(
            context,
            settings.copyWith(
              background: AutoLockSettings.backgroundChoices[index],
            ),
          ),
        ),
      ],
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
        vaultState.authState != VaultAuthEnum.moveUnfinished &&
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
            label: vaultState.usesOwnPassword
                ? localizations.vaultPassword
                : localizations.masterPassword,
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
