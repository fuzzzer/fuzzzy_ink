import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// My safe, locked (DESIGN.md section 4.11): "My safe is locked", what opens
/// it, then Open with fingerprint and the password, which appears in place
/// when asked for. A safe with its own password that the recovery key can
/// open also offers "Use recovery key".
///
/// Before the safe exists ([VaultAuthEnum.noVault]) the same screen makes it
/// with the master password: the first open is the creation. A separate safe
/// password is chosen later in Settings → My safe opens with.
///
/// A master password typed here shares the app lock's wrong-password wait:
/// while it runs the button reads "Wait 0:30" over a real countdown bar.
/// Private screen: responses are in place only (red field, one firm buzz).
class VaultUnlockPage extends StatefulWidget {
  const VaultUnlockPage({super.key});

  @override
  State<VaultUnlockPage> createState() => _VaultUnlockPageState();
}

class _VaultUnlockPageState extends State<VaultUnlockPage> {
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _isPasswordVisible = false;
  bool _showsPassword = false;
  bool _recovering = false;
  bool _autoBiometricAttempted = false;
  bool _isWrong = false;

  Duration _wait = Duration.zero;
  Timer? _waitTicker;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onTyped);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<VaultAuthCubit>();
      unawaited(_readWait());
      if (_autoBiometricAttempted) return;
      if (cubit.state.biometricEnabled &&
          cubit.state.authState == VaultAuthEnum.locked) {
        _autoBiometricAttempted = true;
        cubit.unlockWithBiometrics();
      }
    });
  }

  String _typed = '';

  /// A changed password clears "Not right"; selecting it for retyping does
  /// not.
  void _onTyped() {
    final text = _passwordController.text;
    if (text == _typed) return;
    _typed = text;
    setState(() => _isWrong = false);
  }

  @override
  void dispose() {
    _waitTicker?.cancel();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool get _isWaiting => _wait > Duration.zero;

  /// Reads the shared wait and counts it down once a second.
  Future<void> _readWait() async {
    final remaining = await context.read<VaultAuthCubit>().lockoutRemaining();
    if (!mounted) return;
    _waitTicker?.cancel();
    setState(() => _wait = remaining);
    if (remaining <= Duration.zero) return;
    _waitTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final left = _wait - const Duration(seconds: 1);
      setState(() => _wait = left > Duration.zero ? left : Duration.zero);
      if (!_isWaiting) timer.cancel();
    });
  }

  void _submit() {
    final password = _passwordController.text;
    if (password.isEmpty || _isWaiting) return;
    final cubit = context.read<VaultAuthCubit>();
    if (cubit.state.authState == VaultAuthEnum.noVault) {
      cubit.createVault(password);
    } else {
      cubit.unlock(password);
    }
  }

  void _onState(BuildContext context, VaultAuthState state) {
    final failure = state.failureType;
    if (state.status != StateStatus.failed || failure == null) return;
    if (failure == VaultFailureType.incorrectMasterPassword) {
      setState(() => _isWrong = true);
      unawaited(InkHaptics.heavy());
      _passwordController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _passwordController.text.length,
      );
      _passwordFocus.requestFocus();
    }
    if (failure == VaultFailureType.incorrectMasterPassword ||
        failure == VaultFailureType.tooManyAttempts) {
      unawaited(_readWait());
      return;
    }
    showInkToast(
      context,
      message: context.fuzzzyInkLocalizations.safeCouldNotOpen,
      kind: FuzzzyToastKind.error,
    );
  }

  /// `m:ss`, rounded up so the last second still shows `0:01`.
  static String _formatWait(Duration remaining) {
    final seconds = (remaining.inMilliseconds + 999) ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VaultAuthCubit, VaultAuthState>(
      listenWhen: (previous, current) =>
          current.status == StateStatus.failed &&
          (previous.status != current.status ||
              previous.failureType != current.failureType),
      listener: _onState,
      builder: (context, state) {
        final space = context.fuzzzySpace;
        if (_recovering && state.usesOwnPassword && state.recoverable) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(space.l, space.l, space.l, space.xl),
            child: VaultRecoveryForm(
              onCancel: () => setState(() => _recovering = false),
            ),
          );
        }
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(space.l, space.xl, space.l, space.xl),
          child: _lockedBody(context, state),
        );
      },
    );
  }

  Widget _lockedBody(BuildContext context, VaultAuthState state) {
    final localizations = context.fuzzzyInkLocalizations;
    final colors = context.fuzzzyColors;
    final type = context.fuzzzyTextStyles;
    final space = context.fuzzzySpace;

    final isNew = state.authState == VaultAuthEnum.noVault;
    final ownPassword = state.usesOwnPassword && !isNew;
    final isBusy = state.authState == VaultAuthEnum.unlocking ||
        state.status == StateStatus.loading;
    final hasBiometrics = state.biometricEnabled && !isNew;
    final canRecover = ownPassword && state.recoverable;

    final passwordLabel = ownPassword
        ? localizations.safePasswordField
        : localizations.masterPassword;
    final errorText = _isWaiting
        ? localizations.safeTooManyTries
        : _isWrong
            ? localizations.safeWrongPassword
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: HeroGlyph(
            icon: Icons.shield_outlined,
            tone: HeroGlyphTone.inverted,
            settle: true,
            qaId: 'safe.locked',
          ),
        ),
        SizedBox(height: space.l),
        Semantics(
          header: true,
          child: Text(
            localizations.safeLockedTitle,
            textAlign: TextAlign.center,
            style: type.titleL.copyWith(color: colors.ink),
          ),
        ),
        SizedBox(height: space.s),
        Text(
          ownPassword
              ? localizations.safeOpensWithOwn
              : localizations.safeOpensWithMaster,
          textAlign: TextAlign.center,
          style: type.body.copyWith(color: colors.inkMute),
        ),
        SizedBox(height: space.xl),
        if (hasBiometrics) ...[
          FuzzzyButton(
            label: localizations.safeOpenWithFingerprint,
            icon: const Icon(Icons.fingerprint),
            qaId: 'safe.fingerprint',
            onPressed: isBusy
                ? null
                : () => context.read<VaultAuthCubit>().unlockWithBiometrics(),
          ),
          SizedBox(height: space.s),
        ],
        if (_showsPassword) ...[
          GuardedTextField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            label: passwordLabel,
            obscure: !_isPasswordVisible,
            keyboardType: TextInputType.visiblePassword,
            autofocus: true,
            errorText: errorText,
            qaId: 'safe.password',
            onSubmitted: (_) => _submit(),
            suffix: FuzzzyIconButton(
              icon: Icon(
                _isPasswordVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              semanticLabel: _isPasswordVisible
                  ? localizations.safeHidePassword
                  : localizations.safeShowPassword,
              qaId: 'safe.password.show',
              onPressed: () =>
                  setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
          ),
          SizedBox(height: space.m),
          FuzzzyButton(
            label: _isWaiting
                ? localizations.lockoutWaitLeft(_formatWait(_wait))
                : localizations.safeOpenButton,
            qaId: 'safe.open',
            loading: isBusy,
            onPressed: _passwordController.text.isEmpty || isBusy || _isWaiting
                ? null
                : _submit,
          ),
          if (_isWaiting) ...[
            SizedBox(height: space.s),
            LockoutCountdownBar(remaining: _wait),
          ],
        ] else
          FuzzzyButton(
            label: ownPassword
                ? localizations.safeUseSafePassword
                : localizations.safeUseMasterPassword,
            variant: hasBiometrics
                ? FuzzzyButtonVariant.secondary
                : FuzzzyButtonVariant.primary,
            qaId: 'safe.usePassword',
            onPressed:
                isBusy ? null : () => setState(() => _showsPassword = true),
          ),
        if (canRecover) ...[
          SizedBox(height: space.s),
          FuzzzyButton(
            label: localizations.safeUseRecoveryKey,
            variant: FuzzzyButtonVariant.ghost,
            qaId: 'vault.useRecoveryKey',
            onPressed: isBusy ? null : () => setState(() => _recovering = true),
          ),
        ],
        if (state.biometricInvalidated) ...[
          SizedBox(height: space.l),
          TipLine(
            icon: Icons.fingerprint,
            text: localizations.vaultBiometricInvalidated,
            qaId: 'safe.biometricInvalidated',
          ),
        ],
        if (ownPassword && !state.recoverable) ...[
          SizedBox(height: space.l),
          TipLine(
            text: localizations.vaultForgotPassword,
            qaId: 'safe.noRecovery',
          ),
        ],
      ],
    );
  }
}
