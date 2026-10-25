import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// A new password and its confirmation, with the vault's strength meter and
/// why the caller's button stays off: too weak (below "good") or not the
/// same twice. The caller rebuilds on every keystroke.
class NewPasswordFields extends StatefulWidget {
  const NewPasswordFields({
    super.key,
    required this.passwordController,
    required this.confirmController,
    required this.label,
    this.onSubmitted,
    this.qaId = 'newPassword',
  });

  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final String label;
  final VoidCallback? onSubmitted;
  final String qaId;

  /// Whether the two fields hold one password that reaches the bar.
  static bool isReady({
    required String password,
    required String confirm,
  }) =>
      password.isNotEmpty &&
      password == confirm &&
      sl.get<PasswordStrengthService>().isStrongEnough(password);

  @override
  State<NewPasswordFields> createState() => _NewPasswordFieldsState();
}

class _NewPasswordFieldsState extends State<NewPasswordFields> {
  bool _isVisible = false;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final password = widget.passwordController.text;
    final confirm = widget.confirmController.text;
    final isStrongEnough =
        sl.get<PasswordStrengthService>().isStrongEnough(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FuzzzyTextField(
          controller: widget.passwordController,
          label: widget.label,
          obscure: !_isVisible,
          qaId: '${widget.qaId}.password',
          suffix: IconButton(
            icon: Icon(
              _isVisible ? Icons.visibility_off : Icons.visibility,
              color: context.fuzzzyColors.inkMute,
            ),
            onPressed: () => setState(() => _isVisible = !_isVisible),
          ),
        ),
        if (password.isNotEmpty) ...[
          SizedBox(height: context.fuzzzySpace.m),
          PasswordStrengthIndicator(password: password),
          if (!isStrongEnough) ...[
            SizedBox(height: context.fuzzzySpace.s),
            Text(
              localizations.chatAuthPasswordTooWeak,
              style: context.fuzzzyTextStyles.bodyS.copyWith(
                color: context.fuzzzyColors.destructiveText,
              ),
            ),
          ],
        ],
        SizedBox(height: context.fuzzzySpace.m),
        FuzzzyTextField(
          controller: widget.confirmController,
          label: localizations.chatAuthConfirmPassword,
          obscure: !_isVisible,
          qaId: '${widget.qaId}.confirm',
          onSubmitted: (_) => widget.onSubmitted?.call(),
        ),
        if (confirm.isNotEmpty && confirm != password) ...[
          SizedBox(height: context.fuzzzySpace.s),
          Text(
            localizations.chatAuthPasswordsDoNotMatch,
            style: context.fuzzzyTextStyles.bodyS.copyWith(
              color: context.fuzzzyColors.destructiveText,
            ),
          ),
        ],
      ],
    );
  }
}
