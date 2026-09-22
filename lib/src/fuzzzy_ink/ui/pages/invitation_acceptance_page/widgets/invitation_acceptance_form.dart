import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class InvitationAcceptanceForm extends StatelessWidget {
  final TextEditingController chatNameController;
  final TextEditingController invitationTextController;
  final VoidCallback onAccept;

  const InvitationAcceptanceForm({
    super.key,
    required this.chatNameController,
    required this.invitationTextController,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;

    return FuzzyScaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FuzzzyAppBar(
                title: localizations.acceptChatInvitation,
              ),
              const SizedBox(height: 32),
              Text(
                localizations
                    .stepPasteTheirInviteCode, // Note: We only have 'Paste Their Invite Code'
                textAlign: TextAlign.start,
                style: context.fuzzzyTextStyles.body.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: context.fuzzzyColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                localizations
                    .askYourContactToShareTheirInviteCodeSecurelyAndPasteItBelow,
                textAlign: TextAlign.start,
                style: context.fuzzzyTextStyles.body.copyWith(
                  color: context.fuzzzyColors.inkMute,
                ),
              ),
              const SizedBox(height: 16),
              FuzzzyTextField(
                controller: invitationTextController,
                label: localizations.pasteInvitationText,
                maxLines: 4,
              ),
              const SizedBox(height: 32),
              Divider(
                height: 20,
                thickness: 4,
                color: context.fuzzzyColors.inkMute,
              ),
              const SizedBox(height: 32),
              Text(
                localizations.stepNameThisChat,
                textAlign: TextAlign.start,
                style: context.fuzzzyTextStyles.body.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: context.fuzzzyColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                localizations.chooseALocalNameForThisChatThisIsOnlyVisibleToYou,
                textAlign: TextAlign.start,
                style: context.fuzzzyTextStyles.body.copyWith(
                  color: context.fuzzzyColors.inkMute,
                ),
              ),
              const SizedBox(height: 16),
              FuzzzyTextField(
                controller: chatNameController,
                label: localizations.enterChatName,
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      actionsRow: FuzzyActionsRow(
        isMainActionEnabled: chatNameController.text.isNotEmpty &&
            invitationTextController.text.isNotEmpty,
        mainActionLabel: localizations.acceptInvitation,
        onMainActionPressed: onAccept,
      ),
    );
  }
}
