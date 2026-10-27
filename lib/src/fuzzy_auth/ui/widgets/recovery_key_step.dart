import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// A recovery key shown once (DESIGN.md sections 4.1 step 4 and 4.12): the
/// key in its groups, never copyable, Print and Save as file, a short note,
/// then "I've kept it safe" — on only after a print or a save — and "Skip
/// for now", which asks first. Used by the first run and by Settings →
/// Recovery key. The screen around it must be a [SensitiveScreen].
class RecoveryKeyStepView extends StatefulWidget {
  const RecoveryKeyStepView({
    super.key,
    required this.recoveryKey,
    required this.busy,
    required this.onKept,
    required this.onSkipped,
    required this.title,
    this.line,
    this.pageTitle,
    this.onBack,
    this.steps,
    this.note,
    this.export = const RecoveryKeyExport(),
  });

  final String recoveryKey;
  final bool busy;
  final VoidCallback onKept;
  final VoidCallback onSkipped;
  final String title;
  final String? line;

  /// The header's title (Settings); none on the first run.
  final String? pageTitle;
  final VoidCallback? onBack;

  /// The step bar on the first run.
  final Widget? steps;

  /// The note under the key; the first run's "Keep it off this phone" when
  /// null.
  final Widget? note;
  final RecoveryKeyExport export;

  @override
  State<RecoveryKeyStepView> createState() => _RecoveryKeyStepViewState();
}

class _RecoveryKeyStepViewState extends State<RecoveryKeyStepView> {
  /// Printed or saved at least once: "I've kept it safe" turns on.
  bool _isHandedOver = false;

  void _markHandedOver() {
    if (!_isHandedOver) setState(() => _isHandedOver = true);
  }

  Future<bool> _print() async {
    final printed = await RecoveryKeyPrintPage.show(
      context,
      recoveryKey: widget.recoveryKey,
      export: widget.export,
    );
    if (printed) {
      unawaited(InkHaptics.light());
      _markHandedOver();
    }
    return printed;
  }

  Future<bool> _save() async {
    final localizations = context.fuzzzyInkLocalizations;
    var saved = false;
    try {
      saved = await widget.export.saveAsFile(
        context,
        text: localizations.recoveryKeyFileText(widget.recoveryKey),
        dialogTitle: localizations.accessSaveAsFile,
      );
    } catch (error) {
      logger.w('Recovery key not saved: ${error.runtimeType}');
      if (mounted) {
        showInkToast(
          context,
          message: localizations.recoveryKeySaveFailed,
          kind: FuzzzyToastKind.error,
        );
      }
      return false;
    }
    if (saved) {
      unawaited(InkHaptics.light());
      _markHandedOver();
    }
    return saved;
  }

  Future<void> _skip() async {
    final localizations = context.fuzzzyInkLocalizations;
    final skip = await FuzzzyDialog.show<bool>(
      context,
      title: localizations.accessSkipKeyTitle,
      qaId: 'recoveryKey.skipWarning',
      content: Text(
        localizations.accessSkipKeyMessage,
        style: context.fuzzzyTextStyles.body
            .copyWith(color: context.fuzzzyColors.ink),
      ),
      actions: [
        FuzzzyButton(
          label: localizations.accessSkipKeyKeep,
          qaId: 'recoveryKey.skipKeep',
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
        ),
        FuzzzyButton(
          label: localizations.accessSkipKeyAnyway,
          variant: FuzzzyButtonVariant.ghost,
          qaId: 'recoveryKey.skipAnyway',
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );
    if (skip ?? false) widget.onSkipped();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final busy = widget.busy;
    final steps = widget.steps;
    final line = widget.line;

    return AccessPage(
      qaId: 'recoveryKey',
      title: widget.pageTitle,
      onBack: widget.onBack,
      bottom: [
        FuzzzyButton(
          label: localizations.accessKeptItSafe,
          size: FuzzzyButtonSize.l,
          loading: busy,
          qaId: 'recoveryKey.kept',
          onPressed: _isHandedOver && !busy ? widget.onKept : null,
        ),
        FuzzzyButton(
          label: localizations.accessSkipForNow,
          variant: FuzzzyButtonVariant.ghost,
          qaId: 'recoveryKey.skip',
          onPressed: busy ? null : _skip,
        ),
      ],
      children: [
        if (steps != null) ...[steps, SizedBox(height: space.l)],
        AccessTitle(widget.title),
        if (line != null) ...[SizedBox(height: space.s), AccessLine(line)],
        SizedBox(height: space.l),
        RecoveryKeyBlock(
          recoveryKey: widget.recoveryKey,
          qaId: 'shown',
          actions: Row(
            children: [
              if (widget.export.canPrint) ...[
                Expanded(
                  child: InPlaceConfirmButton(
                    label: localizations.accessPrint,
                    confirmedLabel: localizations.confirmHandedOver,
                    icon: const Icon(Icons.print_outlined),
                    qaId: 'recoveryKey.print',
                    onPressed: busy ? null : _print,
                  ),
                ),
                SizedBox(width: space.s),
              ],
              Expanded(
                child: InPlaceConfirmButton(
                  label: localizations.accessSaveAsFile,
                  confirmedLabel: localizations.accessSaved,
                  icon: const Icon(Icons.save_alt),
                  qaId: 'recoveryKey.save',
                  onPressed: busy ? null : _save,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: space.l),
        widget.note ??
            AccessNote(
              tone: AccessNoteTone.warning,
              text: localizations.accessKeepOffPhone,
              trailing: const WhyLink(
                topic: InkInfoTopic.recoveryKey,
                label: WhyLinkLabel.more,
              ),
              qaId: 'recoveryKey.keepOff',
            ),
      ],
    );
  }
}
