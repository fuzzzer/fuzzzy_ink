import 'package:flutter/material.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class ChatCreationInitialContent extends StatelessWidget {
  final TextEditingController chatNameController;
  final FocusNode focusNode;
  final VoidCallback onCreate;

  const ChatCreationInitialContent({
    super.key,
    required this.chatNameController,
    required this.focusNode,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzySealLocalizations;

    return FuzzyScaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FuzzzyAppBar(
              title: localizations.createANewChat,
            ),
            const Spacer(),
            FuzzzyTextField(
              controller: chatNameController,
              focusNode: focusNode,
              label: localizations.enterChatName,
              hint: '${localizations.eg} ${localizations.chatWithAlice}',
            ),
            const Spacer(),
          ],
        ),
      ),
      actionsRow: FuzzyActionsRow(
        isMainActionEnabled: chatNameController.text.isNotEmpty,
        mainActionLabel: localizations.create,
        onMainActionPressed: onCreate,
      ),
    );
  }
}
