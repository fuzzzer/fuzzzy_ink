import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

Future<void> showChatDeletionDialog(
  BuildContext context, {
  required String chatName,
  required String chatId,
  void Function()? onChatDeleted,
}) async {
  await showDialog<bool>(
    context: context,
    builder: (context) {
      final localizations = context.fuzzzySealLocalizations;

      return AlertDialog(
        title: Text(localizations.deleteChat),
        content: Text(
          localizations.areYouSureYouWantToDeleteChatWith(chatName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: context.fuzzzyColors.focus,
            ),
            child: Text(
              localizations.cancel,
            ),
          ),
          TextButton(
            onPressed: () {
              context.read<ChatGeneralDataListCubit>().deleteChat(
                    chatId: chatId,
                  );
              Navigator.pop(context);

              if (onChatDeleted != null) {
                onChatDeleted();
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: context.fuzzzyColors.destructiveText,
            ),
            child: Text(
              localizations.delete,
            ),
          ),
        ],
      );
    },
  );
}
