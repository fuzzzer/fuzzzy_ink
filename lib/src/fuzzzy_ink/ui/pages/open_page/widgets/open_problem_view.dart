import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

/// One "can't open" screen per problem (DESIGN.md section 7, errors): the
/// picture (Fuzzz "sad" when Fuzzzy Cast is on), one title, one line, one
/// button. Not private: nothing secret is on it.
class OpenProblemView extends StatelessWidget {
  const OpenProblemView({
    super.key,
    required this.problem,
    required this.chat,
    required this.onBack,
    required this.onGoToPerson,
  });

  final OpenProblem problem;
  final ChatGeneralData? chat;
  final VoidCallback onBack;
  final void Function(ChatGeneralData chat) onGoToPerson;

  @override
  Widget build(BuildContext context) {
    final l = context.fuzzzyInkLocalizations;
    final chat = this.chat;
    final name = chat?.chatName ?? '';

    final (String title, String line) = switch (problem) {
      OpenProblem.alreadyOpened => (
          l.openErrorAlreadyTitle,
          l.openErrorAlreadyLine(name),
        ),
      OpenProblem.notFromYourPeople => (
          l.openErrorNotYoursTitle,
          l.openErrorNotYoursLine,
        ),
      OpenProblem.damaged => (
          l.openErrorDamagedTitle,
          l.openErrorDamagedLine,
        ),
      OpenProblem.tooOld => (l.openErrorOldTitle, l.openErrorOldLine(name)),
      OpenProblem.newerApp => (l.openErrorNewerTitle, l.openErrorNewerLine),
      OpenProblem.ownInvite => (l.openErrorOwnTitle, l.openErrorOwnLine),
      OpenProblem.alreadyConnected => (
          l.openErrorConnectedTitle,
          l.openErrorConnectedLine(name),
        ),
      OpenProblem.notFuzzzy => (
          l.openErrorNotFuzzzyTitle,
          l.openErrorNotFuzzzyLine,
        ),
      OpenProblem.stillArriving => (
          l.openErrorArrivingTitle,
          l.openErrorArrivingLine,
        ),
      OpenProblem.askResend => (
          l.openErrorResendTitle,
          l.openErrorResendLine,
        ),
      OpenProblem.failed => (l.openErrorDamagedTitle, l.openFailed),
    };

    final goesToPerson = chat != null &&
        (problem == OpenProblem.alreadyOpened ||
            problem == OpenProblem.tooOld ||
            problem == OpenProblem.alreadyConnected);

    final FuzzzyButton button;
    if (goesToPerson) {
      button = FuzzzyButton(
        label: l.openErrorGoToName(name),
        size: FuzzzyButtonSize.l,
        qaId: 'open.problem.person',
        onPressed: () => onGoToPerson(chat),
      );
    } else if (problem == OpenProblem.notFromYourPeople) {
      button = FuzzzyButton(
        label: l.homeAddPerson,
        icon: const Icon(Icons.person_add_alt),
        size: FuzzzyButtonSize.l,
        qaId: 'open.problem.add',
        onPressed: () => _addPerson(context),
      );
    } else if (problem == OpenProblem.newerApp) {
      button = FuzzzyButton(
        label: l.openErrorOk,
        size: FuzzzyButtonSize.l,
        qaId: 'open.problem.ok',
        onPressed: context.goBack,
      );
    } else {
      button = FuzzzyButton(
        label: problem == OpenProblem.ownInvite ? l.openErrorOk : l.back,
        size: FuzzzyButtonSize.l,
        qaId: 'open.problem.back',
        onPressed: onBack,
      );
    }

    return FlowScaffold(
      qaId: 'open.problem',
      onLeading: context.goBack,
      leading: FlowLeading.close,
      footer: button,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FlowHero(
              castMoment: FuzzzyCastMoment.cantOpen,
              glyph: HeroGlyph(
                icon: Icons.priority_high,
                tone: HeroGlyphTone.warning,
                qaId: 'open.problem.${problem.name}',
              ),
            ),
            FlowTitle(title: title, line: line),
            if (problem == OpenProblem.alreadyOpened) ...[
              SizedBox(height: context.fuzzzySpace.s),
              const Center(
                child: WhyLink(
                  topic: InkInfoTopic.opensOnce,
                  qaId: 'open.problem.why',
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Home, with "Add a person" open on it.
  void _addPerson(BuildContext context) {
    GoRouter.of(context).go(AppRouter.home);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sheetContext = navigatorKey.currentState?.overlay?.context;
      if (sheetContext != null && sheetContext.mounted) {
        showAddPersonSheet(sheetContext);
      }
    });
  }
}
