import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class SettingsToolbox extends StatefulWidget {
  final ChatGeneralData chatGeneralData;
  final void Function() onActionPressed;
  final void Function() onChatDeleted;

  const SettingsToolbox({
    super.key,
    required this.chatGeneralData,
    required this.onActionPressed,
    required this.onChatDeleted,
  });

  @override
  State<SettingsToolbox> createState() => _SettingsToolboxState();
}

class _SettingsToolboxState extends State<SettingsToolbox> {
  void _exportAcceptance({
    required FuzzzyInkLocalizations localizations,
  }) {
    final acceptanceReaderCubit = AcceptanceReaderCubit(
      cryptoCoreService: sl.get<CryptoCoreService>(),
    );

    acceptanceReaderCubit
        .generateAcceptance(chatId: widget.chatGeneralData.chatId)
        .then((_) {
      if (acceptanceReaderCubit.state.status.isSuccess) {
        _copyAcceptance(
          acceptanceContent:
              acceptanceReaderCubit.state.acceptance?.content ?? '',
          localizations: localizations,
        );
      } else {
        if (!mounted) return;
        FuzzzyToast.show(
          context,
          message: localizations.failedToGetAcceptance,
        );
      }
    });
  }

  void _copyAcceptance({
    required String acceptanceContent,
    required FuzzzyInkLocalizations localizations,
  }) {
    Clipboard.setData(
      ClipboardData(
        text: acceptanceContent,
      ),
    ).then((_) {
      if (!mounted) return;
      FuzzzyToast.show(
        context,
        message: localizations.acceptanceCopiedToClipboard,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;

    return IntrinsicWidth(
      child: FuzzyToolbox(
        children: [
          ListTile(
            leading: const Icon(Icons.delete),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(
              localizations.deleteChat,
            ),
            onTap: () {
              widget.onActionPressed();
              showChatDeletionDialog(
                context,
                chatId: widget.chatGeneralData.chatId,
                chatName: widget.chatGeneralData.chatName,
                onChatDeleted: widget.onChatDeleted,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.archive),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(
              localizations.exportChatArchive,
            ),
            onTap: () {
              widget.onActionPressed();
              showChatArchiveExportDialog(
                context,
                chatId: widget.chatGeneralData.chatId,
                chatName: widget.chatGeneralData.chatName,
              );
            },
          ),
          if (widget.chatGeneralData.didAcceptInvitation)
            ListTile(
              leading: const Icon(Icons.file_upload),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: Text(
                localizations.exportAcceptance,
              ),
              onTap: () {
                _exportAcceptance(localizations: localizations);

                widget.onActionPressed();
              },
            ),
        ],
      ),
    );
  }
}
