import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:path/path.dart' as path;

export 'components/components.dart';

/// One history row, read again (DESIGN.md section 4.9, prototype `item`):
/// - your locked message (private): your text, "No copy", the locked
///   version, Share again and Copy locked;
/// - your locked file: its `.fuzz` card, Share again and Save;
/// - an opened message (private): the text, "No copy";
/// - an opened file (private): its card, Open and Save.
///
/// The opened views are minimal versions of the Open flow's opened screens.
class HistoryItemPage extends StatelessWidget {
  const HistoryItemPage({super.key, required this.payload});

  final HistoryItemPagePayload payload;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ChatFileCubit>(
      create: (_) => ChatFileCubit(
        cryptoCoreService: sl.get<CryptoCoreService>(),
        userFileStore: sl.get<UserFileStore>(),
      ),
      child: ProvidedHistoryItemPage(payload: payload),
    );
  }
}

class ProvidedHistoryItemPage extends StatelessWidget {
  const ProvidedHistoryItemPage({super.key, required this.payload});

  final HistoryItemPagePayload payload;

  /// Plain text or an opened file is on screen.
  static bool isPrivate(MessageData message) =>
      message.type.isText || !message.isSent;

  @override
  Widget build(BuildContext context) {
    final message = payload.message;
    final view = switch ((message.isSent, message.type)) {
      (true, MessageType.text) => _LockedTextView(payload: payload),
      (true, MessageType.file) => _LockedFileView(payload: payload),
      (false, MessageType.text) => _OpenedTextView(payload: payload),
      (false, MessageType.file) => _OpenedFileView(payload: payload),
    };
    return isPrivate(message) ? SensitiveScreen(child: view) : view;
  }
}

String _when(BuildContext context, MessageData message, {required bool sent}) {
  final localizations = context.fuzzzyInkLocalizations;
  final day = HistoryFormat.dayLabel(context, message.sentAt);
  final time = HistoryFormat.timeLabel(context, message.sentAt);
  return sent
      ? localizations.itemYouLockedWhen(day, time)
      : localizations.itemOpenedWhen(day, time);
}

/// The phone's save dialog for [filePath]; true once saved. Only a failure
/// says so in a toast: success is the button's own "Handed over".
Future<bool> _handOver(
  BuildContext context, {
  required String filePath,
  required String fileName,
  required UserFileStore store,
}) async {
  final localizations = context.fuzzzyInkLocalizations;
  try {
    return await DeviceFileInteractor.saveFile(
      filePath,
      fileName: fileName,
      store: store,
      dialogTitle: localizations.saveFile,
      context: context,
    );
  } on Object catch (error) {
    logger.w('HISTORY ITEM: could not save: $error');
    if (context.mounted) {
      showInkToast(
        context,
        message: localizations.couldNotSaveFile,
        kind: FuzzzyToastKind.error,
      );
    }
    return false;
  }
}

class _WhenLine extends StatelessWidget {
  const _WhenLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.fuzzzyTextStyles.bodyS.copyWith(
        color: context.fuzzzyColors.inkMute,
      ),
    );
  }
}

/// The text itself, large, in a box. Never selectable or copyable.
class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.message});

  final MessageData message;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final type = context.fuzzzyTextStyles;
    final unreadable = message.isUnreadable;

    return Container(
      key: const Key('item.text'),
      padding: EdgeInsets.all(context.fuzzzySpace.l),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.line),
        borderRadius: BorderRadius.circular(context.fuzzzyRadius.l),
      ),
      child: Text(
        unreadable
            ? context.fuzzzyInkLocalizations.itemUnreadable
            : message.decryptedMessage,
        style: unreadable
            ? type.body.copyWith(color: colors.inkMute)
            : type.titleM.copyWith(
                color: colors.ink,
                fontWeight: type.body.fontWeight,
              ),
      ),
    );
  }
}

class _NoCopyRow extends StatelessWidget {
  const _NoCopyRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        KeyTag(
          label: context.fuzzzyInkLocalizations.tagNoCopy,
          qaId: 'item.noCopy',
        ),
        const Spacer(),
        const WhyLink(topic: InkInfoTopic.noCopying, qaId: 'item.noCopy'),
      ],
    );
  }
}

class _LockedTextView extends StatelessWidget {
  const _LockedTextView({required this.payload});

  final HistoryItemPagePayload payload;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final message = payload.message;
    final content = SealedShareContent.message(
      chatId: message.chatId,
      encryptedMessage: message.encryptedMessage,
    );

    return InkFlowScaffold(
      qaId: 'item',
      title: localizations.itemForName(payload.chat.chatName),
      footer: Row(
        children: [
          Expanded(
            child: FuzzzyButton(
              qaId: 'item.shareAgain',
              label: localizations.itemShareAgain,
              icon: const Icon(Icons.ios_share),
              onPressed: () => showSealedShareSheet(
                context,
                content: content,
                personName: payload.chat.chatName,
              ),
            ),
          ),
          SizedBox(width: space.s + space.xs / 2),
          Expanded(
            child: InPlaceConfirmButton(
              qaId: 'item.copyLocked',
              label: localizations.itemCopyLocked,
              confirmedLabel: localizations.confirmCopied,
              icon: const Icon(Icons.copy_outlined),
              onPressed: () => CopyGuard.copyQuietly(
                text: content.sealedText,
                content: CopyContent.sealedMessage,
              ),
            ),
          ),
        ],
      ),
      children: [
        _WhenLine(_when(context, message, sent: true)),
        SizedBox(height: space.m),
        _MessageBox(message: message),
        SizedBox(height: space.s),
        const _NoCopyRow(),
        SizedBox(height: space.l),
        LockedTextPreview(
          lockedText: content.sealedText,
          showLabel: true,
          qaId: 'item',
        ),
      ],
    );
  }
}

class _OpenedTextView extends StatelessWidget {
  const _OpenedTextView({required this.payload});

  final HistoryItemPagePayload payload;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final message = payload.message;

    return InkFlowScaffold(
      qaId: 'item',
      title: localizations.itemFromName(payload.chat.chatName),
      footer: FuzzzyButton(
        qaId: 'item.done',
        label: localizations.itemDone,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      children: [
        _WhenLine(_when(context, message, sent: false)),
        SizedBox(height: space.m),
        _MessageBox(message: message),
        SizedBox(height: space.s),
        const _NoCopyRow(),
      ],
    );
  }
}

class _LockedFileView extends StatelessWidget {
  const _LockedFileView({required this.payload});

  final HistoryItemPagePayload payload;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final message = payload.message;
    final cubit = context.read<ChatFileCubit>();
    final sealedPath = cubit.sealedPathOf(message);
    final sealedName = UserFileNames.forDisplay(
      path.basename(message.encryptedMessage),
    );

    return InkFlowScaffold(
      qaId: 'item',
      title: localizations.itemForName(payload.chat.chatName),
      footer: Row(
        children: [
          Expanded(
            child: FuzzzyButton(
              qaId: 'item.shareAgain',
              label: localizations.itemShareAgain,
              icon: const Icon(Icons.ios_share),
              // The kept `.fuzz` file is sealed: it goes out as it is.
              onPressed: () => shareFileForUser(
                context,
                filePath: sealedPath,
                store: cubit.userFileStore,
              ),
            ),
          ),
          SizedBox(width: space.s + space.xs / 2),
          Expanded(
            child: InPlaceConfirmButton(
              qaId: 'item.save',
              label: localizations.itemSave,
              confirmedLabel: localizations.confirmHandedOver,
              hold: InkMotionTiming.handedOverHold,
              icon: const Icon(Icons.save_alt),
              onPressed: () => _handOver(
                context,
                filePath: sealedPath,
                fileName: path.basename(message.encryptedMessage),
                store: cubit.userFileStore,
              ),
            ),
          ),
        ],
      ),
      children: [
        _WhenLine(_when(context, message, sent: true)),
        SizedBox(height: space.m),
        FileCard(
          qaId: 'item',
          name: sealedName,
          size: payload.fileSize,
          state: FileCardState.locked,
        ),
        SizedBox(height: space.m),
        TipLine(
          qaId: 'item.onlyLocked',
          icon: Icons.lock_outline,
          text: localizations.itemOnlyLockedKept,
          trailing:
              const WhyLink(topic: InkInfoTopic.files, qaId: 'item.files'),
        ),
      ],
    );
  }
}

class _OpenedFileView extends StatelessWidget {
  const _OpenedFileView({required this.payload});

  final HistoryItemPagePayload payload;

  String get _fileName => ChatFileCubit.fileNameOf(payload.message);

  /// Unfuzzes the kept container into a short-lived copy and shows it in
  /// the app's viewer; the copy is wiped when the viewer closes.
  Future<void> _open(BuildContext context) async {
    final cubit = context.read<ChatFileCubit>();
    final store = cubit.userFileStore;
    final copy = await unfuzzChatFile(context, payload.message);
    if (copy == null || !context.mounted) return;
    await PlainFileViewerPage.show(
      context,
      fileName: _fileName,
      filePath: copy,
      onSave: (viewerContext) => saveFileForUser(
        viewerContext,
        filePath: copy,
        fileName: _fileName,
        store: store,
      ),
      onShare: (viewerContext) async {
        await shareFileForUser(viewerContext, filePath: copy, store: store);
        cubit.wipeWhenBack(copy);
      },
      onClosed: () => cubit.wipe(copy),
    );
  }

  /// A normal copy for the phone's save menu; the app keeps none.
  Future<bool> _save(BuildContext context) async {
    final cubit = context.read<ChatFileCubit>();
    final copy = await unfuzzChatFile(context, payload.message);
    if (copy == null || !context.mounted) return false;
    try {
      return await _handOver(
        context,
        filePath: copy,
        fileName: _fileName,
        store: cubit.userFileStore,
      );
    } finally {
      unawaited(cubit.wipe(copy));
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final message = payload.message;

    return InkFlowScaffold(
      qaId: 'item',
      title: localizations.itemFromName(payload.chat.chatName),
      footer: FuzzzyButton(
        qaId: 'item.done',
        label: localizations.itemDone,
        variant: FuzzzyButtonVariant.ghost,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      children: [
        _WhenLine(_when(context, message, sent: false)),
        SizedBox(height: space.m),
        FileCard(
          qaId: 'item',
          name: UserFileNames.forDisplay(_fileName),
          size: payload.fileSize,
        ),
        SizedBox(height: space.m),
        Row(
          children: [
            Expanded(
              child: FuzzzyButton(
                qaId: 'item.open',
                label: localizations.itemOpen,
                icon: const Icon(Icons.visibility_outlined),
                onPressed: () => _open(context),
              ),
            ),
            SizedBox(width: space.s + space.xs / 2),
            Expanded(
              child: InPlaceConfirmButton(
                qaId: 'item.save',
                label: localizations.itemSave,
                confirmedLabel: localizations.confirmHandedOver,
                hold: InkMotionTiming.handedOverHold,
                icon: const Icon(Icons.save_alt),
                onPressed: () => _save(context),
              ),
            ),
          ],
        ),
        SizedBox(height: space.m),
        TipLine(
          qaId: 'item.saveCopy',
          icon: Icons.lock_outline,
          text: localizations.itemSaveGivesCopy,
          trailing:
              const WhyLink(topic: InkInfoTopic.files, qaId: 'item.files'),
        ),
      ],
    );
  }
}
