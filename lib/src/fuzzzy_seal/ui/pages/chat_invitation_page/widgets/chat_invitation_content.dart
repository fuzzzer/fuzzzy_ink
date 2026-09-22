import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class ChatInvitationContent extends StatefulWidget {
  final String chatName;
  final String invitationContent;
  final TextEditingController acceptanceTextController;
  final VoidCallback onAccept;

  const ChatInvitationContent({
    super.key,
    required this.chatName,
    required this.invitationContent,
    required this.acceptanceTextController,
    required this.onAccept,
  });

  @override
  State<ChatInvitationContent> createState() => _ChatInvitationContentState();
}

class _ChatInvitationContentState extends State<ChatInvitationContent> {
  final deboucer = Debouncer(milliseconds: 500);

  @override
  void dispose() {
    deboucer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fuzzzyColors = context.fuzzzyColors;
    final fuzzzyTextStyles = context.fuzzzyTextStyles;

    final localizations = context.fuzzzySealLocalizations;

    return FuzzyScaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FuzzzyAppBar(
                title: widget.chatName,
              ),
              const SizedBox(height: 20),
              Text(
                localizations.stepSendYourInviteCode,
                textAlign: TextAlign.start,
                style: fuzzzyTextStyles.body.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: fuzzzyColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                localizations
                    .sendThisCodeToThePersonYouWantToChatWithUsingAnySecureChannel,
                textAlign: TextAlign.start,
                style: fuzzzyTextStyles.body.copyWith(
                  color: fuzzzyColors.inkMute,
                ),
              ),
              const SizedBox(height: 20),
              FuzzzyButton(
                label: localizations.copyInvitation,
                icon: const Icon(Icons.copy),
                onPressed: () {
                  deboucer.run(() {
                    Clipboard.setData(
                      ClipboardData(text: widget.invitationContent),
                    ).then((_) {
                      if (!context.mounted) return;
                      FuzzzyToast.show(
                        context,
                        message: localizations.invitationCopiedToClipboard,
                      );
                    });
                  });
                },
              ),
              const SizedBox(height: 12),
              FuzzzyButton(
                label: localizations.shareInvitation,
                icon: const Icon(Icons.share),
                onPressed: () {
                  ShareHelper.share(widget.invitationContent, context: context);
                },
              ),
              const SizedBox(height: 12),
              FuzzzyButton(
                label: localizations.shareAsLink,
                icon: const Icon(Icons.share),
                onPressed: () {
                  final link = FuzzyLinkGenerator.generateInvitationLink(
                    widget.invitationContent,
                  );
                  final shareable = FuzzyLinkGenerator.generateShareableContent(
                    link: link,
                    rawFuzz: widget.invitationContent,
                    type: FuzzyLinkType.invitation,
                  );
                  ShareHelper.share(shareable, context: context);
                },
              ),
              const SizedBox(height: 12),
              FuzzzyButton(
                label: localizations.copyAsLink,
                icon: const Icon(Icons.link),
                onPressed: () {
                  deboucer.run(() {
                    final link = FuzzyLinkGenerator.generateInvitationLink(
                      widget.invitationContent,
                    );
                    Clipboard.setData(ClipboardData(text: link)).then((_) {
                      if (!context.mounted) return;
                      FuzzzyToast.show(
                        context,
                        message: localizations.linkCopiedToClipboard,
                      );
                    });
                  });
                },
              ),
              const SizedBox(height: 20),
              Text(
                localizations.forwardSecrecyNotice,
                textAlign: TextAlign.start,
                style: fuzzzyTextStyles.bodyS.copyWith(
                  color: fuzzzyColors.inkMute,
                ),
              ),
              const SizedBox(height: 32),
              Divider(
                height: 20,
                thickness: 4,
                color: fuzzzyColors.inkMute,
              ),
              const SizedBox(height: 32),
              Text(
                localizations.stepPasteTheirAcceptanceCode,
                textAlign: TextAlign.start,
                style: fuzzzyTextStyles.body.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: fuzzzyColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                localizations
                    .onceTheyAcceptYourInviteTheyWillSendACodeBackPasteItBelow,
                textAlign: TextAlign.start,
                style: fuzzzyTextStyles.body.copyWith(
                  color: fuzzzyColors.inkMute,
                ),
              ),
              const SizedBox(height: 16),
              FuzzzyTextField(
                label: localizations.acceptanceText,
                controller: widget.acceptanceTextController,
                maxLines: 5,
                scrollPadding: const EdgeInsets.only(bottom: 150),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
      actionsRow: FuzzyActionsRow(
        isMainActionEnabled: widget.acceptanceTextController.text.isNotEmpty,
        mainActionLabel: localizations.accept,
        onMainActionPressed: widget.onAccept,
      ),
    );
  }
}
