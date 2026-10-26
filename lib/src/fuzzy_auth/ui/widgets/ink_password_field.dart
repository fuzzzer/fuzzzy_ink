import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// A password field in the redesign: hidden text, an eye to show it, a red
/// field and one short line when [errorText] is set. Shown or hidden, it is a
/// [GuardedTextField]: no copy, cut, share or other app's text action, and
/// no keyboard learning. [enabled] false greys it out and takes it out of
/// focus (the lockout wait).
class InkPasswordField extends StatefulWidget {
  const InkPasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.errorText,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.qaId,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final VoidCallback? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final String? qaId;

  @override
  State<InkPasswordField> createState() => _InkPasswordFieldState();
}

class _InkPasswordFieldState extends State<InkPasswordField> {
  bool _isVisible = false;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final enabled = widget.enabled;
    final field = GuardedTextField(
      controller: widget.controller,
      label: widget.label,
      errorText: widget.errorText,
      obscure: !_isVisible,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      keyboardType: TextInputType.visiblePassword,
      onSubmitted: (_) => widget.onSubmitted?.call(),
      qaId: widget.qaId,
      suffix: FuzzzyIconButton(
        icon: Icon(_isVisible ? Icons.visibility_off : Icons.visibility),
        semanticLabel: _isVisible
            ? localizations.accessHidePassword
            : localizations.accessShowPassword,
        qaId: '${widget.qaId ?? 'password'}.peek',
        onPressed:
            enabled ? () => setState(() => _isVisible = !_isVisible) : null,
      ),
    );
    if (enabled) return field;
    return IgnorePointer(
      child: ExcludeFocus(
        child: Opacity(opacity: 0.5, child: field),
      ),
    );
  }
}
