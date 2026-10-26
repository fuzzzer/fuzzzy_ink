import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Lock → "What?" (step 2 of 2, private): Message | File, the message box
/// (paste allowed, copy and cut refused) or the file (pick, or drop on a
/// computer), and for a password lock the password with its strength, which
/// must reach Good. One main button: Lock.
class LockWhatView extends StatefulWidget {
  const LockWhatView({super.key, required this.chat, required this.onClose});

  /// Null for "Lock with a password".
  final ChatGeneralData? chat;
  final VoidCallback onClose;

  @override
  State<LockWhatView> createState() => _LockWhatViewState();
}

class _LockWhatViewState extends State<LockWhatView> {
  final _message = TextEditingController();
  final _password = TextEditingController();
  bool _isPicking = false;

  @override
  void dispose() {
    _message.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      // The system picker: no storage permission; on a phone it hands back
      // a copy in the app's cache, deleted once locked.
      final result = await FilePicker.platform.pickFiles();
      final picked = result?.files.firstOrNull?.path;
      if (picked != null && mounted) {
        await context.read<LockFlowCubit>().chooseFile(picked);
      }
    } catch (error) {
      logger.w('LOCK: could not pick a file: $error');
      if (mounted) {
        FuzzzyToast.show(
          context,
          message: context.fuzzzyInkLocalizations.errorPickingFiles,
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _lock() {
    FocusScope.of(context).unfocus();
    context
        .read<LockFlowCubit>()
        .lock(text: _message.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final chat = widget.chat;
    final title = chat == null
        ? localizations.lockWithPassword
        : localizations.lockForName(chat.chatName);

    return BlocBuilder<LockFlowCubit, LockFlowState>(
      builder: (context, state) {
        final cubit = context.read<LockFlowCubit>();
        final isFile = state.kind == LockKind.file;

        // A file dropped anywhere on the screen (a computer) is the file.
        return FileDropArea(
          onDropped: (paths) {
            if (paths.isNotEmpty) cubit.chooseFile(paths.first);
          },
          child: InkFlowScaffold(
            qaId: 'lock.what',
            title: title,
            onLeading: widget.onClose,
            footer: FuzzzyButton(
              label: localizations.lockAction,
              icon: const Icon(Icons.lock_outline),
              size: FuzzzyButtonSize.l,
              loading: state.isBusy,
              qaId: 'lock.do',
              onPressed: _lock,
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StepsIndicator(
                  step: 2,
                  total: 2,
                  label: localizations.lockStepWhat,
                  qaId: 'lock.steps',
                ),
                SizedBox(height: space.l),
                // The kit control cannot shrink yet: long words at large text
                // sizes scale it down instead of overflowing.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: FuzzzySegmentedControl(
                    segments: [
                      localizations.lockKindMessage,
                      localizations.lockKindFile,
                    ],
                    selectedIndex: isFile ? 1 : 0,
                    onChanged: (index) => cubit.chooseKind(
                      index == 1 ? LockKind.file : LockKind.message,
                    ),
                    qaId: 'lock.kind',
                  ),
                ),
                SizedBox(height: space.m),
                if (isFile)
                  _FileChoice(
                    file: state.file,
                    isPicking: _isPicking,
                    onPick: _pick,
                  )
                else
                  _MessageBox(controller: _message),
                FlowErrorLine(
                  text: switch (state.failure) {
                    LockFailure.writeSomethingFirst =>
                      localizations.lockWriteSomethingFirst,
                    LockFailure.chooseFileFirst =>
                      localizations.lockChooseFileFirst,
                    LockFailure.stopped => localizations.lockStoppedNothingKept,
                    LockFailure.failed => localizations.lockFailed,
                    LockFailure.passwordNotGood || null => null,
                  },
                  qaId: 'lock.error',
                ),
                SizedBox(height: space.s),
                if (chat == null) ...[
                  _PasswordField(
                    controller: _password,
                    isNotGood: state.failure == LockFailure.passwordNotGood,
                  ),
                  SizedBox(height: space.m),
                  TipLine(
                    icon: Icons.key_outlined,
                    text: localizations.lockSayPassword,
                    trailing: const WhyLink(
                      topic: InkInfoTopic.passwordLocking,
                      qaId: 'lock.why.password',
                    ),
                    qaId: 'lock.tip.password',
                  ),
                ] else
                  TipLine(
                    icon: Icons.lock_outline,
                    text: localizations.lockOnlyNameOnce(chat.chatName),
                    qaId: 'lock.tip.once',
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The message box: paste stays, copy, cut, share and look-up go (the
/// screen's [SensitiveScreen] also refuses the copy shortcuts).
class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final type = context.fuzzzyTextStyles;
    final radius = BorderRadius.circular(context.fuzzzyRadius.m);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color),
        );

    return Semantics(
      identifier: 'field.lock.message',
      textField: true,
      child: TextField(
        key: const Key('field.lock.message'),
        controller: controller,
        minLines: 6,
        maxLines: 12,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        contextMenuBuilder: CopyGuard.plaintextContextMenuBuilder,
        style: type.body.copyWith(color: colors.fieldText),
        cursorColor: colors.ink,
        decoration: InputDecoration(
          hintText: context.fuzzzyInkLocalizations.lockWriteMessageHint,
          hintStyle: type.body.copyWith(color: colors.hint),
          filled: true,
          fillColor: colors.fill,
          contentPadding: EdgeInsets.all(context.fuzzzySpace.m),
          enabledBorder: border(colors.idleBorder),
          focusedBorder: border(colors.focusBorder),
        ),
      ),
    );
  }
}

class _FileChoice extends StatelessWidget {
  const _FileChoice({
    required this.file,
    required this.isPicking,
    required this.onPick,
  });

  final LockFileChoice? file;
  final bool isPicking;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final colors = context.fuzzzyColors;
    final type = context.fuzzzyTextStyles;
    final file = this.file;

    if (file != null) {
      return FileCard(
        name: file.name,
        size: formatFileSize(file.size),
        qaId: 'lock.file',
        trailing: FuzzzyButton(
          label: localizations.lockChangeFile,
          variant: FuzzzyButtonVariant.ghost,
          size: FuzzzyButtonSize.s,
          qaId: 'lock.file.change',
          onPressed: isPicking ? null : onPick,
        ),
      );
    }

    return Semantics(
      identifier: 'lock.file.choose',
      button: true,
      child: FuzzzyTappable(
        key: const Key('lock.file.choose'),
        onTap: isPicking ? null : onPick,
        builder: (context, active) => Container(
          padding: EdgeInsets.symmetric(vertical: context.fuzzzySpace.xl),
          decoration: BoxDecoration(
            color: active ? colors.surface : colors.fill,
            border: Border.all(color: colors.lineStrong),
            borderRadius: BorderRadius.circular(context.fuzzzyRadius.m),
          ),
          child: Column(
            children: [
              Icon(
                Icons.insert_drive_file_outlined,
                size: context.fuzzzyIconSize.l,
                color: colors.ink,
              ),
              SizedBox(height: context.fuzzzySpace.s),
              Text(
                localizations.lockChooseFile,
                style: type.titleS.copyWith(color: colors.ink),
              ),
              Text(
                localizations.lockDropHint,
                style: type.bodyS.copyWith(color: colors.inkMute),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Password for this", its strength (Weak · Fair · Good · Strong), and
/// "It needs to reach Good." when Lock was pressed below it.
class _PasswordField extends StatefulWidget {
  const _PasswordField({required this.controller, required this.isNotGood});

  final TextEditingController controller;
  final bool isNotGood;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final text = widget.controller.text;
    final level = sl.get<PasswordStrengthService>().assess(text).level;
    final colors = context.fuzzzyColors;
    final type = context.fuzzzyTextStyles;
    // The kit meter's level words are English only; the same bar with the
    // app's own words (kit request after approval).
    final (Color tint, double fraction) = switch (level) {
      PasswordStrengthLevel.weak => (colors.destructive, 0.25),
      PasswordStrengthLevel.fair => (colors.warning, 0.5),
      PasswordStrengthLevel.good => (colors.info, 0.75),
      PasswordStrengthLevel.strong => (colors.success, 1.0),
    };
    final levelName = switch (level) {
      PasswordStrengthLevel.weak => localizations.lockStrengthWeak,
      PasswordStrengthLevel.fair => localizations.lockStrengthFair,
      PasswordStrengthLevel.good => localizations.lockStrengthGood,
      PasswordStrengthLevel.strong => localizations.lockStrengthStrong,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FuzzzyTextField(
          controller: widget.controller,
          label: localizations.lockPasswordLabel,
          obscure: true,
          errorText:
              widget.isNotGood ? localizations.lockPasswordNotGood : null,
          onChanged: (_) => setState(() {}),
          qaId: 'lock.password',
        ),
        SizedBox(height: context.fuzzzySpace.s),
        Semantics(
          identifier: 'lock.strength',
          label: '${localizations.lockStrengthLabel}: $levelName',
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        localizations.lockStrengthLabel,
                        style: type.label.copyWith(color: colors.inkMute),
                      ),
                    ),
                    if (text.isNotEmpty)
                      Text(
                        levelName,
                        key: const Key('lock.strength.level'),
                        style: type.label.copyWith(color: tint),
                      ),
                  ],
                ),
                SizedBox(height: context.fuzzzySpace.xs),
                FuzzzyProgressBar(
                  value: text.isEmpty ? 0 : fraction,
                  color: tint,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
