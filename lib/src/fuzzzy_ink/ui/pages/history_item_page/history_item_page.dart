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
/// - an opened message (private): Open's opened-message screen
///   ([OpenedTextView]) with when it was opened;
/// - an opened file (private): Open's opened-file screen ([OpenedFileView]):
///   its card, Open (pictures and text) and Save.
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
      (false, MessageType.text) => _openedText(context),
      (false, MessageType.file) => _openedFile(context),
    };
    return isPrivate(message) ? SensitiveScreen(child: view) : view;
  }

  Widget _openedText(BuildContext context) {
    final message = payload.message;
    return OpenedTextView(
      state: OpenFlowState(
        phase: OpenPhase.openedText,
        chat: payload.chat,
        openedText: message.isUnreadable
            ? context.fuzzzyInkLocalizations.itemUnreadable
            : message.decryptedMessage,
      ),
      whenLine: _when(context, message, sent: false),
      onDone: () => Navigator.of(context).maybePop(),
    );
  }

  Widget _openedFile(BuildContext context) {
    final message = payload.message;
    return OpenedFileView(
      state: OpenFlowState(
        phase: OpenPhase.openedFile,
        chat: payload.chat,
        openedFile: OpenedFile(
          name: ChatFileCubit.fileNameOf(message),
          keptRow: message,
        ),
      ),
      whenLine: _when(context, message, sent: false),
      fileSize: payload.fileSize,
      onDone: () => Navigator.of(context).maybePop(),
    );
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

    return FlowScaffold(
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

    return FlowScaffold(
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
