import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// "Locked for Nino" (DESIGN.md sections 4.5–4.7): the lock snaps shut (or
/// Fuzzz squares up, "determined"), "Now send it.", the locked text or the
/// `.fuzz` card, then Share — which steps back to "Share again" once the
/// system says it was shared, when Done becomes the main button — and
/// "Copy locked text" ("Copied" in place) or "Save locked file". Not private:
/// only locked things are on it.
class LockedView extends StatelessWidget {
  const LockedView({
    super.key,
    required this.chat,
    required this.state,
    required this.onShared,
    required this.onDone,
  });

  final ChatGeneralData? chat;
  final LockFlowState state;
  /// The system share finished; `copied` when it was "Copy as text".
  final void Function({bool copied}) onShared;
  final VoidCallback onDone;

  SealedShareContent _shareContent(LockedItem item) {
    final filePath = item.lockedFilePath;
    if (filePath != null) return SealedShareContent.lockedFile(filePath);
    final text = item.lockedText!;
    final chat = this.chat;
    if (chat == null) return SealedShareContent.passwordText(text);
    return SealedShareContent.message(
      chatId: chat.chatId,
      encryptedMessage: text.substring(fuzzIdentificator.length),
    );
  }

  Future<void> _share(BuildContext context, LockedItem item) async {
    final result = await showSealedShareSheet(
      context,
      content: _shareContent(item),
      personName: chat?.chatName,
    );
    if (result != null && result.isDone) {
      onShared(copied: result.action == SealedShareAction.copied);
    }
  }

  Future<bool> _copy(LockedItem item) {
    return CopyGuard.copyQuietly(
      text: item.lockedText!,
      content:
          chat == null ? CopyContent.sealedText : CopyContent.sealedMessage,
    );
  }

  /// The locked file to the system's save dialog; it stays locked, and the
  /// app keeps its own copy.
  Future<bool> _save(BuildContext context, LockedItem item) async {
    try {
      return await DeviceFileInteractor.saveFile(
        item.lockedFilePath!,
        fileName: '${item.fileName ?? 'file'}.$fuzzedFileIdentificator',
        store: sl.get<UserFileStore>(),
        dialogTitle: context.fuzzzyInkLocalizations.saveFile,
        context: context,
      );
    } catch (error) {
      logger.w('LOCK: could not save the locked file: $error');
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
    final space = context.fuzzzySpace;
    final item = state.item!;
    final chat = this.chat;
    final isShared = state.isShared;

    return FlowScaffold(
      qaId: 'locked',
      onLeading: onDone,
      leading: FlowLeading.close,
      footer: FuzzzyButton(
        label: localizations.flowDone,
        variant:
            isShared ? FuzzzyButtonVariant.primary : FuzzzyButtonVariant.ghost,
        size: FuzzzyButtonSize.l,
        qaId: 'locked.done',
        onPressed: onDone,
      ),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FlowHero(
              castMoment: FuzzzyCastMoment.locked,
              // The buzz is the page's, so it also comes with Fuzzz.
              glyph: LockSnapGlyph(buzz: false, qaId: 'locked.glyph'),
            ),
            FlowTitle(
              title: chat == null
                  ? localizations.lockedWithPassword
                  : localizations.lockedForName(chat.chatName),
              line: !isShared
                  ? localizations.lockedNowSendIt
                  : state.sharedByCopy
                      ? localizations.shareCopiedStaysLocked
                      : localizations.lockedSentToShareMenu,
            ),
            SizedBox(height: space.l),
            if (item.isFile)
              FileCard(
                name: '${item.fileName ?? ''}.$fuzzedFileIdentificator',
                size: item.fileSize == null
                    ? null
                    : formatFileSize(item.fileSize!),
                state: FileCardState.locked,
                qaId: 'locked.file',
              )
            else
              LockedTextPreview(
                lockedText: item.lockedText!,
                showLabel: true,
                qaId: 'locked.text',
              ),
            SizedBox(height: space.m),
            AnimatedSwitcher(
              duration: InkMotion.isReduced(context)
                  ? Duration.zero
                  : context.fuzzzyMotion.standard,
              child: FuzzzyButton(
                key: ValueKey(isShared),
                label: isShared
                    ? localizations.lockedShareAgain
                    : localizations.share,
                icon: const Icon(Icons.ios_share),
                variant: isShared
                    ? FuzzzyButtonVariant.secondary
                    : FuzzzyButtonVariant.primary,
                size: FuzzzyButtonSize.l,
                qaId: 'locked.share',
                onPressed: () => _share(context, item),
              ),
            ),
            SizedBox(height: space.s),
            if (item.isFile)
              InPlaceConfirmButton(
                label: localizations.lockedSaveFile,
                confirmedLabel: localizations.confirmHandedOver,
                icon: const Icon(Icons.save_alt),
                size: FuzzzyButtonSize.l,
                hold: InkMotionTiming.handedOverHold,
                qaId: 'locked.save',
                onPressed: () => _save(context, item),
              )
            else
              InPlaceConfirmButton(
                label: localizations.lockedCopyText,
                confirmedLabel: localizations.confirmCopied,
                icon: const Icon(Icons.copy_outlined),
                size: FuzzzyButtonSize.l,
                qaId: 'locked.copy',
                onPressed: () => _copy(item),
              ),
            if (chat == null) ...[
              SizedBox(height: space.m),
              TipLine(
                icon: Icons.key_outlined,
                text: localizations.lockSayPassword,
                qaId: 'locked.tip.password',
              ),
            ],
          ],
        ),
      ],
    );
  }
}
