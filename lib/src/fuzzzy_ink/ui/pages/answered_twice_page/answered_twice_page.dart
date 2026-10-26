import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

/// "Someone else may have answered" (DESIGN.md section 4.3 step 5,
/// prototype `warn-twice`): a second, different reply arrived for an invite
/// that is already connected. A red note, then Check numbers, or Remove
/// Tamar and invite again. Never Fuzzzy Cast on a security warning.
class AnsweredTwicePage extends StatelessWidget {
  const AnsweredTwicePage({super.key, required this.chat});

  final ChatGeneralData chat;

  Future<void> _removeAndInviteAgain(BuildContext context) {
    return removePerson(
      context,
      chat,
      then: (router) {
        router.go(AppRouter.home);
        router.push(AppRouter.chatCreate, extra: chat.chatName);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final name = chat.chatName;

    return InkFlowScaffold(
      qaId: 'answeredTwice',
      close: true,
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FuzzzyButton(
            qaId: 'answeredTwice.check',
            label: localizations.personMenuCheckNumbers,
            icon: const Icon(Icons.verified_user_outlined),
            onPressed: () =>
                context.pushReplacement(AppRouter.chatVerify, extra: chat),
          ),
          SizedBox(height: space.s + space.xs / 2),
          FuzzzyButton(
            qaId: 'answeredTwice.remove',
            label: localizations.twiceRemove(name),
            variant: FuzzzyButtonVariant.destructive,
            onPressed: () => _removeAndInviteAgain(context),
          ),
        ],
      ),
      children: [
        const InkHeroSlot(
          qaId: 'answeredTwice',
          glyph: HeroGlyph(
            icon: Icons.warning_amber,
            tone: HeroGlyphTone.warning,
            qaId: 'answeredTwice',
          ),
        ),
        InkScreenTitle(localizations.twiceTitle),
        SizedBox(height: space.s),
        InkScreenLine(localizations.twiceLine(name)),
        SizedBox(height: space.l),
        InkNotice(
          kind: InkNoticeKind.danger,
          lead: localizations.twiceNoteLead(name),
          text: localizations.twiceNoteRest,
          qaId: 'answeredTwice',
        ),
      ],
    );
  }
}
