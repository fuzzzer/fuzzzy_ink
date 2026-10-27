import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

/// The person's "More" sheet (DESIGN.md section 4.9, prototype `pmenu`):
/// Check numbers (connected), Send my reply again (they invited you), Share
/// invite again (waiting), Save history as a file (connected), Remove.
/// Each row closes the sheet, then runs its action.
Future<void> showPersonMenuSheet(
  BuildContext context, {
  required ChatGeneralData chat,
  required PersonTrust trust,
  required VoidCallback onCheckNumbers,
  required VoidCallback onSendReplyAgain,
  required VoidCallback onShareInviteAgain,
  required VoidCallback onSaveHistory,
  required VoidCallback onRemove,
}) {
  final localizations = context.fuzzzyInkLocalizations;
  final isConnected = chat.setupStatus == ChatSetupStatus.connected;

  return FuzzzyBottomSheet.show<void>(
    context,
    qaId: 'personMenu',
    builder: (sheetContext) {
      VoidCallback then(VoidCallback action) => () {
            Navigator.of(sheetContext).pop();
            action();
          };

      return FuzzzyBottomSheet(
        qaId: 'personMenu',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHeading(chat.chatName),
            if (isConnected)
              SheetDoorRow(
                qaId: 'personMenu.check',
                icon: Icons.verified_user_outlined,
                title: localizations.personMenuCheckNumbers,
                hint: trust == PersonTrust.checked
                    ? localizations.chipChecked
                    : localizations.personMenuNotCheckedYet,
                onTap: then(onCheckNumbers),
              ),
            if (chat.didAcceptInvitation)
              SheetDoorRow(
                qaId: 'personMenu.reply',
                icon: Icons.ios_share,
                title: localizations.personMenuSendReplyAgain,
                hint: localizations.shareLineReply,
                onTap: then(onSendReplyAgain),
              ),
            if (!isConnected)
              SheetDoorRow(
                qaId: 'personMenu.invite',
                icon: Icons.ios_share,
                title: localizations.waitingShareInviteAgain,
                hint: localizations.shareLineInvite,
                onTap: then(onShareInviteAgain),
              ),
            if (isConnected)
              SheetDoorRow(
                qaId: 'personMenu.save',
                icon: Icons.save_alt,
                title: localizations.personMenuSaveHistory,
                hint: localizations.personMenuSaveHistoryHint,
                onTap: then(onSaveHistory),
              ),
            _DangerRow(
              qaId: 'personMenu.remove',
              label: localizations.personMenuRemove(chat.chatName),
              onTap: then(onRemove),
            ),
          ],
        ),
      );
    },
  );
}

/// "Remove Nino? Their history and files leave this phone. No undo."
/// Cancel, Remove. Answers true when Remove was tapped.
Future<bool> confirmRemovePerson(BuildContext context, String name) async {
  final localizations = context.fuzzzyInkLocalizations;
  final confirmed = await FuzzzyDialog.showBuilder<bool>(
    context,
    builder: (dialogContext) => FuzzzyDialog(
      qaId: 'removePerson',
      title: localizations.removePersonTitle(name),
      content: Text(localizations.removePersonBody),
      actions: [
        FuzzzyButton(
          qaId: 'removePerson.cancel',
          label: localizations.cancel,
          variant: FuzzzyButtonVariant.secondary,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        FuzzzyButton(
          qaId: 'removePerson.confirm',
          label: localizations.removePersonConfirm,
          variant: FuzzzyButtonVariant.destructive,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Asks, then removes [chat]: its keys, history rows and kept files leave
/// the phone ([ChatGeneralDataListCubit.deleteChat]). Then Home, with "Nino
/// was removed.", or [then] when given. Answers whether it was removed.
Future<bool> removePerson(
  BuildContext context,
  ChatGeneralData chat, {
  void Function(GoRouter router)? then,
}) async {
  final confirmed = await confirmRemovePerson(context, chat.chatName);
  if (!confirmed || !context.mounted) return false;

  final localizations = context.fuzzzyInkLocalizations;
  final listCubit = context.read<ChatGeneralDataListCubit>();
  final router = GoRouter.of(context);
  await listCubit.deleteChat(chatId: chat.chatId);
  if (!context.mounted) return false;

  if (listCubit.state.actionStatus.isFailed) {
    showInkToast(
      context,
      message: localizations.removePersonFailed(chat.chatName),
      kind: FuzzzyToastKind.error,
    );
    return false;
  }

  // The toast lives in the app's overlay, so it stays while the page goes.
  showInkToast(
    context,
    message: localizations.removePersonDone(chat.chatName),
    kind: FuzzzyToastKind.info,
  );
  if (then != null) {
    then(router);
  } else {
    router.go(AppRouter.home);
  }
  return true;
}

/// "Different numbers": a red note and Remove (DESIGN.md section 4.3,
/// prototype `mismatch`). [onRemove] runs after the sheet closed.
Future<void> showMismatchSheet(
  BuildContext context, {
  required String name,
  required VoidCallback onRemove,
}) {
  final localizations = context.fuzzzyInkLocalizations;
  return FuzzzyBottomSheet.show<void>(
    context,
    qaId: 'mismatch',
    builder: (sheetContext) => FuzzzyBottomSheet(
      qaId: 'mismatch',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHeading(localizations.safetyDifferent),
          InkNotice(
            kind: InkNoticeKind.danger,
            lead: localizations.mismatchLead(name),
            text: localizations.mismatchRest,
            qaId: 'mismatch',
          ),
          SizedBox(height: sheetContext.fuzzzySpace.l),
          FuzzzyButton(
            qaId: 'mismatch.remove',
            label: localizations.personMenuRemove(name),
            variant: FuzzzyButtonVariant.destructive,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              onRemove();
            },
          ),
          SizedBox(height: sheetContext.fuzzzySpace.s),
          FuzzzyButton(
            qaId: 'mismatch.close',
            label: localizations.close,
            variant: FuzzzyButtonVariant.ghost,
            onPressed: () => Navigator.of(sheetContext).pop(),
          ),
        ],
      ),
    ),
  );
}

/// What a pasted or chosen invite or reply must be.
enum SealedTextKind {
  invitation(FuzzyLinkType.invitation),
  acceptance(FuzzyLinkType.acceptance);

  const SealedTextKind(this.linkType);

  final FuzzyLinkType linkType;
}

/// The longest invite or reply file read: they are a few kilobytes.
const _maxSealedTextFileBytes = 64 * 1024;

/// Reads [text] as an invite or reply: a whole link becomes its `Fuzz/`
/// text, the `Fuzz/` text stays as it is, anything else answers null.
String? sealedTextOf(String text, SealedTextKind kind) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final fromLink = FuzzyLinkParser.blobFromPastedLink(trimmed, kind.linkType);
  if (fromLink != null) return fromLink;
  return trimmed.startsWith(fuzzIdentificator) ? trimmed : null;
}

/// The clipboard's invite or reply (read only on this tap). Toasts
/// [nothingToPaste] when the clipboard is empty and [notIt] when it holds
/// something else.
Future<String?> pasteSealedText(
  BuildContext context, {
  required SealedTextKind kind,
  required String nothingToPaste,
  required String notIt,
}) async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  if (!context.mounted) return null;
  return sealedTextFromPaste(
    context,
    data?.text ?? '',
    kind: kind,
    nothingToPaste: nothingToPaste,
    notIt: notIt,
  );
}

/// [pasteSealedText] for a text already pasted (the iPhone's own Paste
/// button, [InkPasteButton]).
String? sealedTextFromPaste(
  BuildContext context,
  String pasted, {
  required SealedTextKind kind,
  required String nothingToPaste,
  required String notIt,
}) {
  final text = pasted.trim();
  if (text.isEmpty) {
    showInkToast(context, message: nothingToPaste, kind: FuzzzyToastKind.info);
    return null;
  }
  final sealed = sealedTextOf(text, kind);
  if (sealed == null) {
    showInkToast(context, message: notIt, kind: FuzzzyToastKind.info);
  }
  return sealed;
}

/// The invite or reply in a file the person chooses (the "Send as a file"
/// the other phone made). Toasts when it cannot be read or is something
/// else.
Future<String?> chooseSealedTextFile(
  BuildContext context, {
  required SealedTextKind kind,
  required String notIt,
}) async {
  final localizations = context.fuzzzyInkLocalizations;
  final result = await FilePicker.platform.pickFiles();
  final filePath = result?.files.singleOrNull?.path;
  if (filePath == null || !context.mounted) return null;

  String? text;
  try {
    final file = File(filePath);
    if (await file.length() <= _maxSealedTextFileBytes) {
      text = await file.readAsString();
    }
  } on Object catch (error) {
    logger.w('PEOPLE: could not read the chosen file: $error');
  }
  if (!context.mounted) return null;
  if (text == null) {
    showInkToast(
      context,
      message: localizations.couldNotReadFile,
      kind: FuzzzyToastKind.error,
    );
    return null;
  }
  final sealed = sealedTextOf(text, kind);
  if (sealed == null) {
    showInkToast(context, message: notIt, kind: FuzzzyToastKind.info);
  }
  return sealed;
}

/// "Open the reply": Paste it · Choose a file. Answers the reply's `Fuzz/`
/// text, or null.
Future<String?> showOpenReplySheet(BuildContext context) {
  final localizations = context.fuzzzyInkLocalizations;
  return FuzzzyBottomSheet.show<String>(
    context,
    qaId: 'openReply',
    builder: (sheetContext) {
      void done(String? sealed) {
        if (sealed != null) Navigator.of(sheetContext).pop(sealed);
      }

      return FuzzzyBottomSheet(
        qaId: 'openReply',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHeading(localizations.replyOpenTitle),
            SheetDoorRow(
              qaId: 'openReply.paste',
              icon: Icons.content_paste,
              emphasised: true,
              title: localizations.openPasteIt,
              hint: localizations.pasteItHint,
              onTap: () async => done(
                await pasteSealedText(
                  sheetContext,
                  kind: SealedTextKind.acceptance,
                  nothingToPaste: localizations.replyNothingToPaste,
                  notIt: localizations.notAReply,
                ),
              ),
              trailing: InkPasteButton.isAvailable
                  ? InkPasteButton(
                      qaId: 'openReply',
                      onPasted: (text) => done(
                        sealedTextFromPaste(
                          sheetContext,
                          text,
                          kind: SealedTextKind.acceptance,
                          nothingToPaste: localizations.replyNothingToPaste,
                          notIt: localizations.notAReply,
                        ),
                      ),
                    )
                  : null,
            ),
            SheetDoorRow(
              qaId: 'openReply.file',
              icon: Icons.description_outlined,
              title: localizations.chooseFile,
              hint: localizations.chooseFileHint,
              divider: false,
              onTap: () async => done(
                await chooseSealedTextFile(
                  sheetContext,
                  kind: SealedTextKind.acceptance,
                  notIt: localizations.notAReply,
                ),
              ),
            ),
            SizedBox(height: sheetContext.fuzzzySpace.m),
            TipLine(
              icon: Icons.link,
              text: localizations.openLinksTip,
              qaId: 'openReply.links',
            ),
          ],
        ),
      );
    },
  );
}

/// Opens the Share sheet for the invite of the waiting person [chatId] (the
/// core makes the same invite again). Answers what happened.
Future<SealedShareResult?> shareInviteOf(
  BuildContext context, {
  required String chatId,
  required String name,
}) async {
  final reader =
      InvitationReaderCubit(cryptoCoreService: sl.get<CryptoCoreService>());
  await reader.generateInvitation(chatId: chatId);
  final invitation = reader.state.invitation;
  await reader.close();
  if (!context.mounted) return null;
  if (invitation == null) {
    showInkToast(
      context,
      message: context.fuzzzyInkLocalizations.inviteLoadFailed,
      kind: FuzzzyToastKind.error,
    );
    return null;
  }
  return showSealedShareSheet(
    context,
    content: SealedShareContent.invitation(invitation.content),
    personName: name,
  );
}

/// Opens the Share sheet for the reply you made to [chatId]'s invite ("Send
/// my reply again").
Future<SealedShareResult?> shareReplyOf(
  BuildContext context, {
  required String chatId,
  required String name,
}) async {
  final reader =
      AcceptanceReaderCubit(cryptoCoreService: sl.get<CryptoCoreService>());
  await reader.generateAcceptance(chatId: chatId);
  final acceptance = reader.state.acceptance;
  await reader.close();
  if (!context.mounted) return null;
  if (acceptance == null) {
    showInkToast(
      context,
      message: context.fuzzzyInkLocalizations.failedToGetAcceptance,
      kind: FuzzzyToastKind.error,
    );
    return null;
  }
  return showSealedShareSheet(
    context,
    content: SealedShareContent.acceptance(acceptance.content),
    personName: name,
  );
}

class _SheetHeading extends StatelessWidget {
  const _SheetHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.fuzzzySpace.s),
      child: Semantics(
        header: true,
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.fuzzzyTextStyles.titleL.copyWith(
            color: context.fuzzzyColors.ink,
          ),
        ),
      ),
    );
  }
}

class _DangerRow extends StatelessWidget {
  const _DangerRow({
    required this.qaId,
    required this.label,
    required this.onTap,
  });

  final String qaId;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;

    return Semantics(
      identifier: qaId,
      button: true,
      container: true,
      child: FuzzzyTappable(
        key: Key(qaId),
        onTap: onTap,
        focusRingInset: true,
        builder: (context, active) => Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: EdgeInsets.symmetric(vertical: space.m),
          color: active ? colors.surface : null,
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Icon(
                  Icons.delete_outline,
                  size: context.fuzzzyIconSize.l,
                  color: colors.destructiveText,
                ),
              ),
              SizedBox(width: space.m + space.xs / 2),
              Expanded(
                child: Text(
                  label,
                  style: context.fuzzzyTextStyles.titleS.copyWith(
                    color: colors.destructiveText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
