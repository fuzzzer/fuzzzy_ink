import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// "Waiting for Mom's reply": the invite steps picture (Invite sent done),
/// the two waiting notes, Share invite again and I got the reply.
class WaitingPersonCard extends StatelessWidget {
  const WaitingPersonCard({
    super.key,
    required this.name,
    required this.onShareInvite,
    required this.onGotReply,
  });

  final String name;
  final VoidCallback onShareInvite;
  final VoidCallback onGotReply;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;

    return FuzzzyCard(
      qaId: 'person.waiting',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              localizations.waitingCardTitle(name),
              style: context.fuzzzyTextStyles.titleS.copyWith(
                color: context.fuzzzyColors.ink,
              ),
            ),
          ),
          SizedBox(height: space.m),
          StepPicture(
            qaId: 'person.waiting',
            steps: StepPicture.inviteSteps(context, name: name),
            done: 1,
          ),
          SizedBox(height: space.l),
          WaitNotes(name: name, qaId: 'person.waiting'),
          SizedBox(height: space.l),
          FuzzzyButton(
            qaId: 'person.shareInvite',
            label: localizations.waitingShareInviteAgain,
            icon: const Icon(Icons.ios_share),
            onPressed: onShareInvite,
          ),
          SizedBox(height: space.s + space.xs / 2),
          FuzzzyButton(
            qaId: 'person.gotReply',
            label: localizations.waitingGotReply,
            icon: const Icon(Icons.move_to_inbox_outlined),
            variant: FuzzzyButtonVariant.secondary,
            onPressed: onGotReply,
          ),
        ],
      ),
    );
  }
}

/// "TODAY", "YESTERDAY", "TUE, OCT 20" over a day's rows.
class HistoryDayLabel extends StatelessWidget {
  const HistoryDayLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final space = context.fuzzzySpace;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        space.l + space.xs,
        space.l + space.xs,
        space.l + space.xs,
        space.s,
      ),
      child: Semantics(
        header: true,
        child: Text(
          label.toUpperCase(),
          style: context.fuzzzyTextStyles.label.copyWith(
            color: context.fuzzzyColors.inkMute,
          ),
        ),
      ),
    );
  }
}

/// Three skeleton rows while the history loads.
class HistoryLoadingRows extends StatelessWidget {
  const HistoryLoadingRows({super.key});

  @override
  Widget build(BuildContext context) {
    final space = context.fuzzzySpace;
    return Padding(
      key: const Key('person.loading'),
      padding: EdgeInsets.fromLTRB(
        space.l + space.xs,
        space.xl,
        space.l + space.xs,
        0,
      ),
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.only(bottom: space.l),
              child: Row(
                children: [
                  FuzzzySkeleton(
                    width: 40,
                    height: 40,
                    borderRadius: BorderRadius.circular(context.fuzzzyRadius.m),
                  ),
                  SizedBox(width: space.m),
                  const Expanded(child: FuzzzySkeleton(height: 14)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The history could not be read: one fact and Try again.
class HistoryLoadError extends StatelessWidget {
  const HistoryLoadError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    return Padding(
      key: const Key('person.error'),
      padding: EdgeInsets.fromLTRB(
        space.l + space.xs,
        space.xl,
        space.l + space.xs,
        0,
      ),
      child: Column(
        children: [
          Text(
            localizations.historyLoadError,
            textAlign: TextAlign.center,
            style: context.fuzzzyTextStyles.body.copyWith(
              color: context.fuzzzyColors.ink,
            ),
          ),
          SizedBox(height: space.m),
          FuzzzyButton(
            qaId: 'person.retry',
            label: localizations.tryAgain,
            variant: FuzzzyButtonVariant.secondary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// "Nothing here yet." (or nothing locked / opened yet, for a filter).
class HistoryEmpty extends StatelessWidget {
  const HistoryEmpty({super.key, required this.filter});

  final HistoryFilter filter;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final colors = context.fuzzzyColors;
    final text = switch (filter) {
      HistoryFilter.all => localizations.historyEmpty,
      HistoryFilter.locked => localizations.historyEmptyLocked,
      HistoryFilter.opened => localizations.historyEmptyOpened,
    };
    return Padding(
      key: const Key('person.empty'),
      padding: EdgeInsets.only(top: context.fuzzzySpace.xxl),
      child: Column(
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.schedule,
              size: context.fuzzzyIconSize.l * 1.5,
              color: colors.inkMute,
            ),
          ),
          SizedBox(height: context.fuzzzySpace.s),
          Text(
            text,
            textAlign: TextAlign.center,
            style: context.fuzzzyTextStyles.titleS.copyWith(color: colors.ink),
          ),
        ],
      ),
    );
  }
}

/// "History stays locked on this phone."
class HistoryFooter extends StatelessWidget {
  const HistoryFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    return Row(
      key: const Key('person.footer'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ExcludeSemantics(
          child: Icon(
            Icons.lock_outline,
            size: context.fuzzzyIconSize.s,
            color: colors.inkMute,
          ),
        ),
        SizedBox(width: context.fuzzzySpace.xs),
        Flexible(
          child: Text(
            context.fuzzzyInkLocalizations.historyStaysLocked,
            textAlign: TextAlign.center,
            style: context.fuzzzyTextStyles.bodyS.copyWith(
              color: colors.inkMute,
            ),
          ),
        ),
      ],
    );
  }
}
