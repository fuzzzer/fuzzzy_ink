import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// A vault item's opened text (title, username, password, address, note):
/// looks like the kit's text field, but its context menu never offers copy,
/// cut, share or look-up, so the plaintext stays in the app (copy_guard).
///
/// The kit's `FuzzzyTextField` takes no context menu yet; once it does, this
/// widget goes and the editor uses the kit field with
/// `CopyGuard.plaintextContextMenuBuilder`.
class VaultPlaintextField extends StatefulWidget {
  const VaultPlaintextField({
    required this.controller,
    required this.label,
    this.obscure = false,
    this.suffix,
    this.minLines,
    this.maxLines = 1,
    this.hint,
    this.autofocus = false,
    this.onSubmitted,
    this.keyboardType,
    this.qaId,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final Widget? suffix;
  final int? minLines;
  final int? maxLines;
  final String? hint;
  final bool autofocus;
  final VoidCallback? onSubmitted;
  final TextInputType? keyboardType;

  /// The field is found as `field.<qaId>`.
  final String? qaId;

  @override
  State<VaultPlaintextField> createState() => _VaultPlaintextFieldState();
}

class _VaultPlaintextFieldState extends State<VaultPlaintextField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() => setState(() {});

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final form = context.fuzzzyFormStyles;
    final type = context.fuzzzyTextStyles;
    final space = context.fuzzzySpace;
    final isFocused = _focusNode.hasFocus;
    final inputStyle = type.body.copyWith(color: colors.fieldText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: type.label.copyWith(color: colors.fieldLabel),
        ),
        SizedBox(height: space.s),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.fill,
            border: Border.all(
              color: isFocused ? colors.focusBorder : colors.idleBorder,
              width: form.borderWidth,
            ),
            borderRadius: BorderRadius.circular(form.radius),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: colors.focusBorder,
                      spreadRadius: form.focusRingWidth,
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: form.contentPadding,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: widget.qaId == null
                        ? null
                        : Key('field.${widget.qaId}'),
                    controller: widget.controller,
                    autofocus: widget.autofocus,
                    keyboardType: widget.keyboardType,
                    onSubmitted: widget.onSubmitted == null
                        ? null
                        : (_) => widget.onSubmitted!(),
                    focusNode: _focusNode,
                    obscureText: widget.obscure,
                    minLines: widget.minLines,
                    maxLines: widget.obscure ? 1 : widget.maxLines,
                    contextMenuBuilder: CopyGuard.plaintextContextMenuBuilder,
                    // No suggestions, autocorrect or keyboard learning for
                    // opened text (security review 2026-10-26).
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
                    style: inputStyle,
                    cursorColor: colors.fieldText,
                    decoration: InputDecoration.collapsed(
                      hintText: widget.hint,
                      hintStyle: type.body.copyWith(color: colors.hint),
                    ),
                  ),
                ),
                if (widget.suffix != null) ...[
                  SizedBox(width: space.s),
                  widget.suffix!,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
