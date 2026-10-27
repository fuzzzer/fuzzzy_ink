import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

/// "Connected with Tamar" (DESIGN.md section 4.3 step 4, prototype
/// `connected`): the reply was opened and Tamar is saved as connected. The
/// steps picture completes (its last step fills), the hero check draws (or
/// Fuzzz is happy), one medium buzz; then "Is it really Tamar?" with Check
/// now and Later.
class PersonConnectedPage extends StatefulWidget {
  const PersonConnectedPage({super.key, required this.chat});

  final ChatGeneralData chat;

  @override
  State<PersonConnectedPage> createState() => _PersonConnectedPageState();
}

class _PersonConnectedPageState extends State<PersonConnectedPage> {
  @override
  void initState() {
    super.initState();
    unawaited(InkHaptics.medium());
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;
    final chat = widget.chat;
    final name = chat.chatName;

    return FlowScaffold(
      qaId: 'connected',
      leading: FlowLeading.close,
      onLeading: () => PersonPage.goTo(context, chat.chatId),
      children: [
        const InkHeroSlot(
          qaId: 'connected',
          moment: FuzzzyCastMoment.connected,
          glyph: HeroGlyph(
            tone: HeroGlyphTone.inverted,
            drawCheck: true,
            qaId: 'connected',
          ),
        ),
        InkScreenTitle(localizations.connectedWith(name), large: true),
        SizedBox(height: space.l),
        StepPicture(
          qaId: 'connected',
          steps: StepPicture.inviteSteps(context, name: name),
          done: 3,
          justDone: 2,
        ),
        SizedBox(height: space.l),
        FuzzzyCard(
          qaId: 'connected.check',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.shield_outlined,
                      size: context.fuzzzyIconSize.l,
                      color: colors.warning,
                    ),
                  ),
                  SizedBox(width: space.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizations.isItReally(name),
                          style: context.fuzzzyTextStyles.titleS.copyWith(
                            color: colors.ink,
                          ),
                        ),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: space.s,
                          children: [
                            Text(
                              localizations.checkTogether,
                              style: context.fuzzzyTextStyles.bodyS.copyWith(
                                color: colors.inkMute,
                              ),
                            ),
                            const WhyLink(
                              topic: InkInfoTopic.checkNumbers,
                              qaId: 'connected.check',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: space.m),
              Row(
                children: [
                  Expanded(
                    child: FuzzzyButton(
                      qaId: 'connected.checkNow',
                      label: localizations.checkNow,
                      onPressed: () => context.pushReplacement(
                        AppRouter.chatVerify,
                        extra: chat,
                      ),
                    ),
                  ),
                  SizedBox(width: space.s + space.xs / 2),
                  Expanded(
                    child: FuzzzyButton(
                      qaId: 'connected.later',
                      label: localizations.checkLater,
                      variant: FuzzzyButtonVariant.secondary,
                      onPressed: () => PersonPage.goTo(context, chat.chatId),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
