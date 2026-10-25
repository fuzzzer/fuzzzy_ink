import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

/// No one yet: the picture slot (Fuzzz calm with Fuzzzy Cast on, a people
/// glyph otherwise), "No one yet", the three-step picture (its second step
/// settles once) and the two doors.
class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;

    return Padding(
      key: const Key('home.empty'),
      padding: EdgeInsets.fromLTRB(
        space.l + space.xs,
        0,
        space.l + space.xs,
        space.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(
            height: 132,
            child: Center(
              child: FuzzzyCastReaction(
                moment: FuzzzyCastMoment.noPeople,
                qaId: 'home.empty',
                fallback: HeroGlyph(
                  icon: Icons.people_outline,
                  qaId: 'home.empty',
                ),
              ),
            ),
          ),
          Text(
            localizations.homeNoOneYet,
            textAlign: TextAlign.center,
            style: context.fuzzzyTextStyles.titleM.copyWith(
              color: context.fuzzzyColors.ink,
            ),
          ),
          SizedBox(height: space.m),
          StepPicture(
            qaId: 'home.empty',
            settle: 1,
            steps: [
              StepPictureStep(
                icon: Icons.ios_share,
                label: localizations.stepYouSendInvite,
              ),
              StepPictureStep(
                icon: Icons.move_to_inbox_outlined,
                label: localizations.stepTheyReply,
              ),
              StepPictureStep(
                icon: Icons.lock_outline,
                label: localizations.stepLockForEachOther,
              ),
            ],
          ),
          SizedBox(height: space.l),
          FuzzzyButton(
            label: localizations.addSendInvite,
            icon: const Icon(Icons.person_add_alt),
            qaId: 'home.empty.sendInvite',
            onPressed: () => context.push(AppRouter.chatCreate),
          ),
          SizedBox(height: space.s + space.xs / 2),
          FuzzzyButton(
            label: localizations.addGotInvite,
            icon: const Icon(Icons.move_to_inbox_outlined),
            variant: FuzzzyButtonVariant.secondary,
            qaId: 'home.empty.gotInvite',
            onPressed: () => context.push(AppRouter.chatAccept),
          ),
        ],
      ),
    );
  }
}
