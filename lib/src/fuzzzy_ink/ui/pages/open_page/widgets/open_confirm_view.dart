import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// A message that came by link, or a message or file another app handed over
/// (security review 2026-10-26): "Open the message from {name}?" (or "the
/// file") with Open and Not now. Nothing has been opened or spent yet;
/// nothing arriving from outside opens by itself. Not private: only the
/// person's name is on it.
class OpenConfirmView extends StatelessWidget {
  const OpenConfirmView({
    super.key,
    required this.chat,
    required this.onOpen,
    required this.onNotNow,
    this.isFile = false,
  });

  final ChatGeneralData chat;
  final bool isFile;
  final VoidCallback onOpen;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    final l = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    return FlowScaffold(
      qaId: 'open.confirm',
      leading: FlowLeading.close,
      onLeading: onNotNow,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FuzzzyButton(
            label: l.openLinkOpen,
            icon: const Icon(CupertinoIcons.lock_open),
            size: FuzzzyButtonSize.l,
            qaId: 'open.confirm.open',
            onPressed: onOpen,
          ),
          SizedBox(height: space.s),
          FuzzzyButton(
            label: l.openLinkNotNow,
            variant: FuzzzyButtonVariant.ghost,
            qaId: 'open.confirm.notNow',
            onPressed: onNotNow,
          ),
        ],
      ),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FlowHero(
              glyph: HeroGlyph(
                icon: Icons.mail_lock_outlined,
                qaId: 'open.confirm',
              ),
            ),
            FlowTitle(
              title: isFile
                  ? l.openArrivedFileTitle(chat.chatName)
                  : l.openLinkTitle(chat.chatName),
              line: l.openLinkLine,
            ),
          ],
        ),
      ],
    );
  }
}
