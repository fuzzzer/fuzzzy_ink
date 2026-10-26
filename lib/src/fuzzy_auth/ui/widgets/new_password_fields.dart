import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// A new password and its confirmation in the redesign (DESIGN.md section
/// 4.1): the field with its eye, the strength meter (Weak · Fair · Good ·
/// Strong), then "Type it again" with one short line while the two differ.
/// The caller's button stays off until [isReady]; the caller rebuilds on
/// every keystroke.
class NewPasswordFields extends StatelessWidget {
  const NewPasswordFields({
    super.key,
    required this.passwordController,
    required this.confirmController,
    required this.label,
    this.confirmLabel,
    this.onSubmitted,
    this.qaId = 'newPassword',
  });

  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final String label;

  /// "Type it again" when null.
  final String? confirmLabel;
  final VoidCallback? onSubmitted;
  final String qaId;

  /// Whether the two fields hold one password that reaches the bar
  /// ("Good" or better).
  static bool isReady({
    required String password,
    required String confirm,
  }) =>
      password.isNotEmpty &&
      password == confirm &&
      sl.get<PasswordStrengthService>().isStrongEnough(password);

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final password = passwordController.text;
    final confirm = confirmController.text;
    final mismatch = confirm.isNotEmpty && confirm != password;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkPasswordField(
          controller: passwordController,
          label: label,
          qaId: '$qaId.password',
        ),
        SizedBox(height: space.s),
        PasswordMeter(password: password, qaId: qaId),
        SizedBox(height: space.m),
        InkPasswordField(
          controller: confirmController,
          label: confirmLabel ?? localizations.accessTypeItAgain,
          errorText: mismatch ? localizations.accessPasswordsDontMatch : null,
          onSubmitted: onSubmitted,
          qaId: '$qaId.confirm',
        ),
      ],
    );
  }
}
