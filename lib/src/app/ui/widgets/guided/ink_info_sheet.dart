import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// The nine "Why?" explanations of DESIGN.md section 7, and [otherApps] for
/// the experimental "Lock from other apps". Each is a title and two or three
/// short lines; the explanations live here instead of on the screens.
enum InkInfoTopic {
  noReset,
  recoveryKey,
  opensOnce,
  safeAnywhere,
  checkNumbers,
  files,
  noCopying,
  passwordLocking,
  safePassword,
  otherApps;

  String title(FuzzzyInkLocalizations l) => switch (this) {
        noReset => l.infoNoResetTitle,
        recoveryKey => l.infoRecoveryKeyTitle,
        opensOnce => l.infoOpensOnceTitle,
        safeAnywhere => l.infoSafeAnywhereTitle,
        checkNumbers => l.infoCheckNumbersTitle,
        files => l.infoFilesTitle,
        noCopying => l.infoNoCopyingTitle,
        passwordLocking => l.infoPasswordLockingTitle,
        safePassword => l.infoSafePasswordTitle,
        otherApps => l.infoOtherAppsTitle,
      };

  List<String> lines(FuzzzyInkLocalizations l) => switch (this) {
        noReset => [
            l.infoNoResetLine1,
            l.infoNoResetLine2,
            l.infoNoResetLine3,
          ],
        recoveryKey => [
            l.infoRecoveryKeyLine1,
            l.infoRecoveryKeyLine2,
            l.infoRecoveryKeyLine3,
          ],
        opensOnce => [
            l.infoOpensOnceLine1,
            l.infoOpensOnceLine2,
            l.infoOpensOnceLine3,
          ],
        safeAnywhere => [
            l.infoSafeAnywhereLine1,
            l.infoSafeAnywhereLine2,
            l.infoSafeAnywhereLine3,
          ],
        checkNumbers => [l.infoCheckNumbersLine1, l.infoCheckNumbersLine2],
        files => [l.infoFilesLine1, l.infoFilesLine2, l.infoFilesLine3],
        noCopying => [l.infoNoCopyingLine1, l.infoNoCopyingLine2],
        passwordLocking => [
            l.infoPasswordLockingLine1,
            l.infoPasswordLockingLine2,
          ],
        safePassword => [l.infoSafePasswordLine1, l.infoSafePasswordLine2],
        otherApps => [
            l.infoOtherAppsLine1,
            l.infoOtherAppsLine2,
            l.infoOtherAppsLine3,
          ],
      };

  /// "Safe to send anywhere" also shows the invite steps.
  bool get showsInviteSteps => this == safeAnywhere;
}

/// Opens the "Why?" sheet for [topic]: its title, its lines, closed by
/// "Got it". Never needed to finish a flow.
Future<void> showInkInfoSheet(BuildContext context, InkInfoTopic topic) {
  return FuzzzyBottomSheet.show<void>(
    context,
    qaId: 'info.${topic.name}',
    builder: (sheetContext) => FuzzzyBottomSheet(
      qaId: 'info.${topic.name}',
      child: InkInfoSheetBody(topic: topic),
    ),
  );
}

/// The content of the "Why?" sheet, also usable inside a dialog or popover.
class InkInfoSheetBody extends StatelessWidget {
  const InkInfoSheetBody({super.key, required this.topic});

  final InkInfoTopic topic;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;
    final type = context.fuzzzyTextStyles;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            topic.title(localizations),
            style: type.titleL.copyWith(color: colors.ink),
          ),
        ),
        SizedBox(height: space.m),
        if (topic.showsInviteSteps) ...[
          StepPicture(steps: StepPicture.inviteSteps(context)),
          SizedBox(height: space.m),
        ],
        for (final line in topic.lines(localizations))
          Padding(
            padding: EdgeInsets.symmetric(vertical: space.xs * 1.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.check,
                    size: context.fuzzzyIconSize.l,
                    color: colors.inkMute,
                  ),
                ),
                SizedBox(width: space.s + space.xs / 2),
                Expanded(
                  child: Text(
                    line,
                    style: type.body.copyWith(color: colors.ink),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(height: space.l),
        FuzzzyButton(
          label: localizations.gotIt,
          variant: FuzzzyButtonVariant.secondary,
          qaId: 'info.${topic.name}.gotIt',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
