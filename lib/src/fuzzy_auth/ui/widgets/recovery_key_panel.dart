import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Shows a recovery key once: written out in groups, never selectable or
/// copyable (owner decision: nothing sensitive leaves through the
/// clipboard), with "save or print" through the system's save dialog. The
/// user goes on only by confirming the key is saved, or by skipping it
/// after an explicit warning.
class RecoveryKeyPanel extends StatefulWidget {
  const RecoveryKeyPanel({
    super.key,
    required this.recoveryKey,
    required this.busy,
    required this.onConfirmed,
    required this.onSkipped,
  });

  final String recoveryKey;
  final bool busy;
  final VoidCallback onConfirmed;
  final VoidCallback onSkipped;

  @override
  State<RecoveryKeyPanel> createState() => _RecoveryKeyPanelState();
}

class _RecoveryKeyPanelState extends State<RecoveryKeyPanel> {
  bool _confirmed = false;

  Future<void> _onSave() async {
    final localizations = context.fuzzzyInkLocalizations;
    final bytes = Uint8List.fromList(
      utf8.encode(localizations.recoveryKeyFileText(widget.recoveryKey)),
    );
    const fileName = 'fuzzzy-ink-recovery-key.txt';
    var saved = false;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // The plugin writes the bytes itself on phones.
        saved = await FilePicker.platform.saveFile(
              dialogTitle: localizations.recoveryKeySave,
              fileName: fileName,
              bytes: bytes,
            ) !=
            null;
      } else {
        final path = await FilePicker.platform.saveFile(
          dialogTitle: localizations.recoveryKeySave,
          fileName: fileName,
        );
        if (path != null) {
          await File(path).writeAsBytes(bytes, flush: true);
          saved = true;
        }
      }
    } catch (ex) {
      logger.w('Recovery key not saved: ${ex.runtimeType}');
      if (mounted) {
        FuzzzyToast.show(context, message: localizations.recoveryKeySaveFailed);
      }
      return;
    }
    if (saved && mounted) {
      FuzzzyToast.show(context, message: localizations.recoveryKeySaved);
    }
  }

  Future<void> _onSkip() async {
    final localizations = context.fuzzzyInkLocalizations;
    final skip = await FuzzzyDialog.show<bool>(
      context,
      title: localizations.recoveryKeySkipTitle,
      qaId: 'recoveryKey.skipWarning',
      content: Text(
        localizations.recoveryKeySkipMessage,
        style: context.fuzzzyTextStyles.body
            .copyWith(color: context.fuzzzyColors.ink),
      ),
      actions: [
        FuzzzyButton(
          label: localizations.cancel,
          variant: FuzzzyButtonVariant.secondary,
          qaId: 'recoveryKey.skipCancel',
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
        ),
        FuzzzyButton(
          label: localizations.recoveryKeySkipConfirm,
          variant: FuzzzyButtonVariant.destructive,
          qaId: 'recoveryKey.skipConfirm',
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );
    if (skip ?? false) widget.onSkipped();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          localizations.recoveryKeyTitle,
          style: context.fuzzzyTextStyles.titleL.copyWith(color: colors.ink),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: space.m),
        Text(
          localizations.recoveryKeyDescription,
          style: context.fuzzzyTextStyles.body.copyWith(color: colors.inkMute),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: space.l),
        Container(
          padding: EdgeInsets.all(space.m),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(context.fuzzzyRadius.m),
          ),
          child: Text(
            widget.recoveryKey.replaceAll('-', ' '),
            key: const ValueKey('recoveryKey.text'),
            style: context.fuzzzyTextStyles.dataL.copyWith(color: colors.ink),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: space.m),
        Text(
          localizations.recoveryKeyWarning,
          style: context.fuzzzyTextStyles.bodyS
              .copyWith(color: colors.destructiveText),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: space.l),
        FuzzzyButton(
          label: localizations.recoveryKeySave,
          variant: FuzzzyButtonVariant.secondary,
          icon: const Icon(Icons.save_alt),
          qaId: 'recoveryKey.save',
          onPressed: widget.busy ? null : _onSave,
        ),
        SizedBox(height: space.m),
        FuzzzyCheckbox(
          value: _confirmed,
          label: localizations.recoveryKeyConfirm,
          qaId: 'recoveryKey.confirmSaved',
          onChanged: widget.busy
              ? null
              : (value) => setState(() => _confirmed = value),
        ),
        SizedBox(height: space.l),
        FuzzzyButton(
          label: localizations.recoveryKeyContinue,
          qaId: 'recoveryKey.continue',
          loading: widget.busy,
          onPressed: _confirmed && !widget.busy ? widget.onConfirmed : null,
        ),
        SizedBox(height: space.s),
        FuzzzyButton(
          label: localizations.recoveryKeySkip,
          variant: FuzzzyButtonVariant.ghost,
          qaId: 'recoveryKey.skip',
          onPressed: widget.busy ? null : _onSkip,
        ),
      ],
    );
  }
}
