import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// The two notes under a waiting invite (owner's approval note): once they
/// reply you can lock for each other, and the invite can be sent any way,
/// even publicly, with "How?" opening "Safe to send anywhere".
class WaitNotes extends StatelessWidget {
  const WaitNotes({super.key, required this.name, this.qaId});

  final String name;
  final String? qaId;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;

    return Column(
      key: qaId == null ? null : Key('wait_notes.$qaId'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _WaitNote(
          icon: Icons.people_outline,
          text: localizations.waitNoteReply(name),
        ),
        SizedBox(height: space.s),
        _WaitNote(
          icon: Icons.public,
          text: localizations.waitNoteAnyWay,
          trailing: WhyLink(
            topic: InkInfoTopic.safeAnywhere,
            label: WhyLinkLabel.how,
            qaId: qaId == null ? null : '$qaId.how',
          ),
        ),
      ],
    );
  }
}

class _WaitNote extends StatelessWidget {
  const _WaitNote({required this.icon, required this.text, this.trailing});

  final IconData icon;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final trailing = this.trailing;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child:
              Icon(icon, size: context.fuzzzyIconSize.m, color: colors.inkMute),
        ),
        SizedBox(width: context.fuzzzySpace.s + context.fuzzzySpace.xs / 2),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: context.fuzzzySpace.s * 0.75,
            children: [
              Text(
                text,
                style:
                    context.fuzzzyTextStyles.bodyS.copyWith(color: colors.ink),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ],
    );
  }
}
