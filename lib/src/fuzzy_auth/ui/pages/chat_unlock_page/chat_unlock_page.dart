import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

class ChatUnlockPage extends StatefulWidget {
  const ChatUnlockPage({super.key});

  @override
  State<ChatUnlockPage> createState() => _ChatUnlockPageState();
}

class _ChatUnlockPageState extends State<ChatUnlockPage>
    with SingleTickerProviderStateMixin {
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _autoBiometricAttempted = false;

  /// Stays on this page once an update has turned biometric unlock off.
  bool _showBiometricReset = false;
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
      if (!mounted) return;
      _tryAutoBiometricUnlock(context.read<FuzzyAuthStore>().state);
    });
  }

  /// Once per page: at mount, or when the boot check resolves to `locked`
  /// while this page is already the gate (T-0329).
  void _tryAutoBiometricUnlock(FuzzyAuthState state) {
    if (_autoBiometricAttempted) return;
    if (state.biometricEnabled && state.status.isLocked) {
      _autoBiometricAttempted = true;
      context.read<FuzzyAuthStore>().unlockWithBiometrics();
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  /// The keyboard's Enter reaches here too, so the same rules as the button:
  /// nothing while an attempt or the boot check runs, or a wait is on.
  void _onUnlock() {
    if (_passwordController.text.isEmpty) return;
    final state = context.read<FuzzyAuthStore>().state;
    if (state.isLockedOut) return;
    if (state.status.isUnlocking || state.status.isInitial) return;
    context.read<FuzzyAuthStore>().unlock(_passwordController.text);
  }

  /// `m:ss`, rounded up so the last second still shows `0:01`.
  static String _formatWait(Duration remaining) {
    final seconds = (remaining.inMilliseconds + 999) ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  void _onBiometricUnlock() {
    context.read<FuzzyAuthStore>().unlockWithBiometrics();
  }

  /// The way out for someone with neither the password nor the recovery
  /// key: everything is erased after an explicit confirmation.
  Future<void> _onErase() async {
    final localizations = context.fuzzzyInkLocalizations;
    final erase = await FuzzzyDialog.show<bool>(
      context,
      title: localizations.eraseTitle,
      qaId: 'unlock.eraseConfirm',
      content: Text(
        localizations.eraseMessage,
        style: context.fuzzzyTextStyles.body
            .copyWith(color: context.fuzzzyColors.ink),
      ),
      actions: [
        FuzzzyButton(
          label: localizations.cancel,
          variant: FuzzzyButtonVariant.secondary,
          qaId: 'unlock.eraseCancel',
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
        ),
        FuzzzyButton(
          label: localizations.eraseConfirm,
          variant: FuzzzyButtonVariant.destructive,
          qaId: 'unlock.eraseYes',
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );
    if (!(erase ?? false) || !mounted) return;
    final eraseRes = await context.read<FuzzyAuthStore>().eraseEverything();
    if (eraseRes is CryptoCoreFailure<void> && mounted) {
      FuzzzyToast.show(
        context,
        message: localizations.unknownError,
        kind: FuzzzyToastKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FuzzyAuthStore, FuzzyAuthState>(
      listener: (context, state) {
        _tryAutoBiometricUnlock(state);
        if (state.verificationFailed) {
          _shakeController.forward(from: 0);
        }
        if (state.biometricInvalidated) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                currentContextLocalization.chatAuthBiometricInvalidated,
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        if (state.biometricReset) {
          setState(() => _showBiometricReset = true);
        }
      },
      builder: (context, state) {
        // `initial` = the boot-time store open still running (T-0329).
        final isLoading = state.status.isUnlocking || state.status.isInitial;

        return Scaffold(
          backgroundColor: context.fuzzzyColors.ground,
          body: Stack(
            children: [
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 60),
                      Icon(
                        Icons.lock_rounded,
                        size: 80,
                        color: context.fuzzzyColors.ink,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        currentContextLocalization.chatUnlockTitle,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: context.fuzzzyColors.ink,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        currentContextLocalization.chatUnlockSubtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: context.fuzzzyColors.inkMute,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      if (_showBiometricReset) ...[
                        SizedBox(height: context.fuzzzySpace.m),
                        Text(
                          currentContextLocalization.chatAuthBiometricReset,
                          style: context.fuzzzyTextStyles.bodyS.copyWith(
                            color: context.fuzzzyColors.ink,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 40),
                      if (state.status.isStorageUnavailable) ...[
                        Text(
                          currentContextLocalization.storageUnavailable,
                          key: const ValueKey('unlock.storageUnavailable'),
                          style: context.fuzzzyTextStyles.body.copyWith(
                            color: context.fuzzzyColors.destructiveText,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: context.fuzzzySpace.l),
                        FuzzzyButton(
                          label: currentContextLocalization.tryAgain,
                          qaId: 'unlock.retry',
                          onPressed: () =>
                              context.read<FuzzyAuthStore>().checkAuthStatus(),
                        ),
                      ] else ...[
                        AnimatedBuilder(
                          animation: _shakeController,
                          builder: (context, child) {
                            final sineValue = math.sin(
                                  4 * 3.14159265 * _shakeController.value,
                                ) *
                                8 *
                                (1 - _shakeController.value);
                            return Transform.translate(
                              offset: Offset(sineValue, 0),
                              child: child,
                            );
                          },
                          child: FuzzzyTextField(
                            controller: _passwordController,
                            label: currentContextLocalization.chatAuthPassword,
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
                        if (state.isLockedOut) ...[
                          SizedBox(height: context.fuzzzySpace.s),
                          Text(
                            currentContextLocalization.chatAuthLockedOut(
                              _formatWait(state.lockoutRemaining),
                            ),
                            style: context.fuzzzyTextStyles.bodyS.copyWith(
                              color: context.fuzzzyColors.destructiveText,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ] else if (state.verificationFailed) ...[
                          const SizedBox(height: 8),
                          Text(
                            currentContextLocalization
                                .chatAuthIncorrectPassword,
                            style: TextStyle(
                              color: context.fuzzzyColors.destructiveText,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 40),
                        FuzzzyButton(
                          label: currentContextLocalization.chatAuthUnlock,
                          onPressed: _passwordController.text.isNotEmpty &&
                                  !isLoading &&
                                  !state.isLockedOut
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
                                    currentContextLocalization
                                        .chatAuthBiometricUnlock,
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
                          currentContextLocalization.chatUnlockForgot,
                          style: context.fuzzzyTextStyles.bodyS.copyWith(
                            color: context.fuzzzyColors.inkMute,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: context.fuzzzySpace.s),
                        FuzzzyButton(
                          label: currentContextLocalization
                              .chatUnlockUseRecoveryKey,
                          variant: FuzzzyButtonVariant.secondary,
                          qaId: 'unlock.recover',
                          onPressed: isLoading
                              ? null
                              : () => context.go(AppRouter.recover),
                        ),
                        SizedBox(height: context.fuzzzySpace.s),
                        FuzzzyButton(
                          label: currentContextLocalization.chatUnlockErase,
                          variant: FuzzzyButtonVariant.ghost,
                          qaId: 'unlock.erase',
                          onPressed: isLoading ? null : _onErase,
                        ),
                      ],
                    ],
                  ),
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
          ),
        );
      },
    );
  }
}
