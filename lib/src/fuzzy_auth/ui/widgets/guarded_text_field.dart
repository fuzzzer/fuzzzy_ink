import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// A text field for anything secret or in the clear — a password, a recovery
/// key, a message before it is locked, an opened text — that looks like the
/// kit's `FuzzzyTextField` and keeps its text in the app (security review
/// 2026-10-26):
///
/// - its context menu offers only Paste, Select all, Delete and the camera's
///   text scan ([CopyGuard.plaintextContextMenuBuilder]): no Copy, Cut,
///   Share, Look Up, Search, nor another app's text action (Android's
///   "Translate" and the like);
/// - Ctrl/Cmd+C and X do nothing ([NoPlaintextCopy]);
/// - the keyboard gets no suggestions, no autocorrect and no personalised
///   learning, so what is typed does not end up in its learned words or
///   their cloud sync (where the keyboard honours the request).
///
/// The kit field takes none of these yet; once it does, this widget goes
/// (kit work after the owner approves the app). Same keys as the kit field:
/// the field is found as `field.<qaId>`.
class GuardedTextField extends StatefulWidget {
  const GuardedTextField({
    super.key,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.suffix,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.autofocus = false,
    this.focusNode,
    this.obscure = false,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.qaId,
  });

  final String? label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final Widget? suffix;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool obscure;
  final TextInputType? keyboardType;

  /// An [obscure] field stays at one line.
  final int? maxLines;
  final int? minLines;
  final String? qaId;

  @override
  State<GuardedTextField> createState() => _GuardedTextFieldState();
}

class _GuardedTextFieldState extends State<GuardedTextField> {
  FocusNode? _ownedNode;
  late FocusNode _focusNode;
  bool _focused = false;

  bool get _error => widget.errorText != null;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? (_ownedNode = FocusNode());
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(GuardedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode == oldWidget.focusNode) return;
    _focusNode.removeListener(_onFocusChange);
    _ownedNode?.dispose();
    _ownedNode = null;
    _focusNode = widget.focusNode ?? (_ownedNode = FocusNode());
    _focusNode.addListener(_onFocusChange);
    _onFocusChange();
  }

  void _onFocusChange() {
    if (_focused != _focusNode.hasFocus) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _ownedNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final form = context.fuzzzyFormStyles;
    final type = context.fuzzzyTextStyles;
    final space = context.fuzzzySpace;

    final Color borderColor;
    if (_error) {
      borderColor = colors.errorBorder;
    } else if (_focused) {
      borderColor = colors.focusBorder;
    } else {
      borderColor = colors.idleBorder;
    }
    final inputStyle = type.body.copyWith(color: colors.fieldText);
    final helpText = widget.errorText ?? widget.helper;
    final label = widget.label;
    final suffix = widget.suffix;

    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.fill,
        border: Border.all(color: borderColor, width: form.borderWidth),
        borderRadius: BorderRadius.circular(form.radius),
        boxShadow: _focused && !_error
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
                controller: widget.controller,
                focusNode: _focusNode,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                textInputAction: widget.textInputAction,
                autofocus: widget.autofocus,
                obscureText: widget.obscure,
                keyboardType: widget.keyboardType,
                maxLines: widget.obscure ? 1 : widget.maxLines,
                minLines: widget.obscure ? null : widget.minLines,
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                contextMenuBuilder: CopyGuard.plaintextContextMenuBuilder,
                style: inputStyle,
                cursorColor: colors.fieldText,
                decoration: InputDecoration.collapsed(
                  hintText: widget.hint,
                  hintStyle: inputStyle.copyWith(color: colors.hint),
                ),
              ),
            ),
            if (suffix != null) ...[
              SizedBox(width: space.s),
              IconTheme.merge(
                data: IconThemeData(color: colors.inkFaint),
                child: suffix,
              ),
            ],
          ],
        ),
      ),
    );

    return Semantics(
      identifier: widget.qaId != null ? 'field.${widget.qaId}' : null,
      container: true,
      textField: true,
      label: label,
      child: KeyedSubtree(
        key: widget.qaId != null ? Key('field.${widget.qaId}') : null,
        child: NoPlaintextCopy(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label != null) ...[
                Text(
                  label.toUpperCase(),
                  style: type.label.copyWith(color: colors.fieldLabel),
                ),
                SizedBox(height: space.s),
              ],
              box,
              if (helpText != null) ...[
                SizedBox(height: space.xs),
                Text(
                  helpText,
                  style: type.bodyS.copyWith(
                    color: _error ? colors.errorText : colors.helper,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
