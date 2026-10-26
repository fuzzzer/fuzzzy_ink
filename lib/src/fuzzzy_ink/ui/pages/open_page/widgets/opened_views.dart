import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// An opened message (private): "From Nino", where it went ("Just now ·
/// kept in Nino's history", or not kept for a password text), the text
/// large and not selectable, the "No copy" tag with Why?, and Done.
class OpenedTextView extends StatelessWidget {
  const OpenedTextView({super.key, required this.state, required this.onDone});

  final OpenFlowState state;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final colors = context.fuzzzyColors;
    final type = context.fuzzzyTextStyles;
    final space = context.fuzzzySpace;
    final chat = state.chat;

    return InkFlowScaffold(
      qaId: 'opened.text',
      title: chat == null
          ? localizations.openedWithPassword
          : localizations.openedFromName(chat.chatName),
      onLeading: onDone,
      footer: FuzzzyButton(
        label: localizations.flowDone,
        size: FuzzzyButtonSize.l,
        qaId: 'opened.done',
        onPressed: onDone,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            chat == null
                ? localizations.openedNotKept
                : localizations.openedKeptInHistory(chat.chatName),
            style: type.bodyS.copyWith(color: colors.inkMute),
          ),
          SizedBox(height: space.m),
          Container(
            padding: EdgeInsets.all(space.m),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.line),
              borderRadius: BorderRadius.circular(context.fuzzzyRadius.m),
            ),
            // Plain Text: never selectable, so nothing can be copied out.
            child: Text(
              state.openedText ?? '',
              key: const Key('opened.text.body'),
              style: type.titleS.copyWith(color: colors.ink),
            ),
          ),
          SizedBox(height: space.s),
          Row(
            children: [
              KeyTag(
                label: localizations.tagNoCopy,
                icon: Icons.content_copy_outlined,
                qaId: 'opened.nocopy',
              ),
              const Spacer(),
              const WhyLink(
                topic: InkInfoTopic.noCopying,
                qaId: 'opened.why.copy',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// An opened file (private): "From Nino", the file card, Open (the viewer
/// inside the app, for pictures and text only) and Save (the system's save
/// dialog; "Handed over" once the system says it saved), and the tip that
/// Fuzzzy Ink keeps only the locked copy. Every plain copy made here is
/// wiped right after use, and again when Open closes.
class OpenedFileView extends StatelessWidget {
  const OpenedFileView({super.key, required this.state, required this.onDone});

  final OpenFlowState state;
  final VoidCallback onDone;

  /// A plain copy to use now, and whether this view must wipe it after.
  Future<(String, bool)?> _plainCopy(BuildContext context) async {
    final file = state.openedFile!;
    final plain = file.plainPath;
    if (plain != null) return (plain, false);
    final copy = await unfuzzChatFile(context, file.keptRow!);
    return copy == null ? null : (copy, true);
  }

  Future<void> _open(BuildContext context) async {
    final files = context.read<ChatFileCubit>();
    final name = state.openedFile!.name;
    final copy = await _plainCopy(context);
    if (copy == null || !context.mounted) return;
    final (path, isOwnCopy) = copy;
    await PlainFileViewerPage.show(
      context,
      fileName: name,
      filePath: path,
      onSave: (viewerContext) => _saveCopy(viewerContext, path, name),
      onClosed: isOwnCopy ? () => files.wipe(path) : null,
    );
  }

  Future<bool> _save(BuildContext context) async {
    final files = context.read<ChatFileCubit>();
    final copy = await _plainCopy(context);
    if (copy == null || !context.mounted) return false;
    final (path, isOwnCopy) = copy;
    final saved = await _saveCopy(context, path, state.openedFile!.name);
    if (isOwnCopy) await files.wipe(path);
    return saved;
  }

  static Future<bool> _saveCopy(
    BuildContext context,
    String path,
    String name,
  ) async {
    try {
      return await DeviceFileInteractor.saveFile(
        path,
        fileName: name,
        store: sl.get<UserFileStore>(),
        dialogTitle: context.fuzzzyInkLocalizations.saveFile,
        context: context,
      );
    } catch (error) {
      logger.w('OPEN: could not save: $error');
      if (context.mounted) {
        FuzzzyToast.show(
          context,
          message: context.fuzzzyInkLocalizations.couldNotSaveFile,
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final colors = context.fuzzzyColors;
    final type = context.fuzzzyTextStyles;
    final space = context.fuzzzySpace;
    final chat = state.chat;
    final file = state.openedFile!;
    final canShow = PlainFileKind.of(file.name) != PlainFileKind.none;

    return InkFlowScaffold(
      qaId: 'opened.file',
      title: chat == null
          ? localizations.openedWithPassword
          : localizations.openedFromName(chat.chatName),
      onLeading: onDone,
      footer: FuzzzyButton(
        label: localizations.flowDone,
        variant: FuzzzyButtonVariant.ghost,
        size: FuzzzyButtonSize.l,
        qaId: 'opened.done',
        onPressed: onDone,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            chat == null
                ? localizations.openedNotKept
                : localizations.openedKeptInHistory(chat.chatName),
            style: type.bodyS.copyWith(color: colors.inkMute),
          ),
          SizedBox(height: space.m),
          FileCard(name: file.name, qaId: 'opened.file.card'),
          SizedBox(height: space.m),
          if (!canShow) ...[
            Text(
              localizations.fileNoPreview,
              key: const Key('opened.file.noPreview'),
              style: type.bodyS.copyWith(color: colors.inkMute),
            ),
            SizedBox(height: space.m),
          ],
          Row(
            children: [
              if (canShow) ...[
                Expanded(
                  child: FuzzzyButton(
                    label: localizations.open,
                    icon: const Icon(Icons.visibility_outlined),
                    size: FuzzzyButtonSize.l,
                    qaId: 'opened.file.open',
                    onPressed: () => _open(context),
                  ),
                ),
                SizedBox(width: space.m),
              ],
              Expanded(
                child: InPlaceConfirmButton(
                  label: localizations.saveFile,
                  confirmedLabel: localizations.confirmHandedOver,
                  icon: const Icon(Icons.save_alt),
                  variant: canShow
                      ? FuzzzyButtonVariant.secondary
                      : FuzzzyButtonVariant.primary,
                  size: FuzzzyButtonSize.l,
                  hold: InkMotionTiming.handedOverHold,
                  qaId: 'opened.file.save',
                  onPressed: () => _save(context),
                ),
              ),
            ],
          ),
          SizedBox(height: space.m),
          TipLine(
            icon: Icons.lock_outline,
            text: localizations.openedSaveTip,
            trailing: const WhyLink(
              topic: InkInfoTopic.files,
              qaId: 'opened.why.files',
            ),
            qaId: 'opened.tip.files',
          ),
        ],
      ),
    );
  }
}
