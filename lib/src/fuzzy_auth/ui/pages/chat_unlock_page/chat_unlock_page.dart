import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

/// The lock screen (DESIGN.md section 4.2, prototype `lockscreen`): the mark
/// settles, "Fuzzzy Ink is locked", the master password, Unlock, the
/// fingerprint button and "Forgot your password?". A wrong password turns
/// the field red with one short line and one firm buzz (no shake); after
/// too many the field waits and the button counts down ("Wait 0:30") over a
/// truthful bar. A link tapped while locked says it is waiting. A private
/// screen.
class ChatUnlockPage extends StatefulWidget {
  const ChatUnlockPage({super.key, this.pendingLink});

  /// Whether a link waits for the unlock; the link handler's when null.
  final ValueListenable<bool>? pendingLink;

  @override
  State<ChatUnlockPage> createState() => _ChatUnlockPageState();
}

class _ChatUnlockPageState extends State<ChatUnlockPage> {
  final _passwordController = TextEditingController();
  final _focusNode = FocusNode();
  bool _autoBiometricAttempted = false;

  /// The last try was wrong; cleared as soon as the password is edited.
  bool _isWrong = false;

  /// One-time notices that stay on this page once shown.
  bool _showBiometricReset = false;
  bool _showBiometricChanged = false;

  late final ValueListenable<bool> _pendingLink = widget.pendingLink ??
      (sl.isRegistered<FuzzyLinkHandler>()
          ? sl.get<FuzzyLinkHandler>().pendingLink
          : ValueNotifier(false));

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onEdited);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tryAutoBiometricUnlock(context.read<FuzzyAuthStore>().state);
    });
  }

  void _onEdited() {
    setState(() {
      if (_isWrong && _passwordController.text.isNotEmpty) {
        // Still selected for retyping: the next key replaces it.
        final selection = _passwordController.selection;
        final isWhole = selection.start == 0 &&
            selection.end == _passwordController.text.length;
        if (!isWhole) _isWrong = false;
      }
    });
  }

  /// Once per page: at mount, or when the boot check resolves to `locked`
  /// while this page is already the gate.
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
    _focusNode.dispose();
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
  static String formatWait(Duration remaining) {
    final seconds = (remaining.inMilliseconds + 999) ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  void _onStateChanged(BuildContext context, FuzzyAuthState state) {
    _tryAutoBiometricUnlock(state);
    if (state.verificationFailed) {
      unawaited(InkHaptics.heavy());
      setState(() => _isWrong = true);
      // Focus stays, the text selected for retyping.
      _passwordController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _passwordController.text.length,
      );
      if (!state.isLockedOut) _focusNode.requestFocus();
    }
    if (state.biometricInvalidated) {
      setState(() => _showBiometricChanged = true);
    }
    if (state.biometricReset) {
      setState(() => _showBiometricReset = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FuzzyAuthStore, FuzzyAuthState>(
      listener: _onStateChanged,
      builder: (context, state) {
        final localizations = context.fuzzzyInkLocalizations;
        final space = context.fuzzzySpace;
        // `initial` = the boot-time store open still running.
        final isLoading = state.status.isUnlocking || state.status.isInitial;
        final isOut = state.isLockedOut;
        final errorText = isOut
            ? localizations.accessTooManyTries
            : _isWrong
                ? localizations.accessWrongPassword
                : null;

        return AccessPage(
          qaId: 'unlock',
          centerContent: true,
          bottom: [
            FuzzzyButton(
              label: localizations.accessForgotPassword,
              variant: FuzzzyButtonVariant.ghost,
              qaId: 'unlock.recover',
              onPressed: isLoading ? null : () => context.go(AppRouter.recover),
            ),
          ],
          children: [
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: SettleIn(child: InkMark(size: 56, qaId: 'lock')),
            ),
            SizedBox(height: space.l),
            AccessTitle(localizations.accessLockedTitle),
            ValueListenableBuilder<bool>(
              valueListenable: _pendingLink,
              builder: (context, isWaiting, _) => isWaiting
                  ? Padding(
                      padding: EdgeInsets.only(top: space.m),
                      child: TipLine(
                        icon: Icons.link,
                        text: localizations.accessLinkWaiting,
                        qaId: 'unlock.linkWaiting',
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            if (_showBiometricChanged) ...[
              SizedBox(height: space.m),
              TipLine(
                icon: Icons.fingerprint,
                text: localizations.accessBioChanged,
                qaId: 'unlock.bioChanged',
              ),
            ],
            if (_showBiometricReset) ...[
              SizedBox(height: space.m),
              TipLine(
                icon: Icons.fingerprint,
                text: localizations.accessBioReset,
                qaId: 'unlock.bioReset',
              ),
            ],
            SizedBox(height: space.l),
            if (state.status.isStorageUnavailable) ...[
              AccessNote(
                tone: AccessNoteTone.danger,
                text: localizations.storageUnavailable,
                qaId: 'unlock.storageUnavailable',
              ),
              SizedBox(height: space.l),
              FuzzzyButton(
                label: localizations.tryAgain,
                size: FuzzzyButtonSize.l,
                qaId: 'unlock.retry',
                onPressed: () =>
                    context.read<FuzzyAuthStore>().checkAuthStatus(),
              ),
            ] else ...[
              Semantics(
                liveRegion: true,
                child: InkPasswordField(
                  controller: _passwordController,
                  focusNode: _focusNode,
                  label: localizations.masterPassword,
                  errorText: errorText,
                  enabled: !isOut,
                  onSubmitted: _onUnlock,
                  qaId: 'unlock.password',
                ),
              ),
              SizedBox(height: space.l),
              FuzzzyButton(
                label: isOut
                    ? localizations.lockoutWaitLeft(
                        formatWait(state.lockoutRemaining),
                      )
                    : localizations.chatAuthUnlock,
                size: FuzzzyButtonSize.l,
                loading: isLoading && !isOut,
                qaId: 'unlock.unlock',
                onPressed:
                    _passwordController.text.isNotEmpty && !isLoading && !isOut
                        ? _onUnlock
                        : null,
              ),
              if (isOut) ...[
                SizedBox(height: space.s),
                LockoutCountdownBar(remaining: state.lockoutRemaining),
              ],
              if (state.biometricEnabled) ...[
                SizedBox(height: space.s),
                FuzzzyButton(
                  label: localizations.accessUseBio,
                  variant: FuzzzyButtonVariant.secondary,
                  size: FuzzzyButtonSize.l,
                  icon: const Icon(Icons.fingerprint),
                  qaId: 'unlock.bio',
                  onPressed: isLoading
                      ? null
                      : context.read<FuzzyAuthStore>().unlockWithBiometrics,
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}
