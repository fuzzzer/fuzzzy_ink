import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Locking / Opening a file (DESIGN.md section 5): the picture (Fuzzz keeps
/// watch when Fuzzzy Cast is on), the file's name, the real progress from
/// the file job, then Pause / Go on and Cancel.
class FlowWorkingView extends StatelessWidget {
  const FlowWorkingView({
    super.key,
    required this.qaId,
    required this.title,
    required this.icon,
    required this.fileName,
    required this.progress,
    required this.onCancel,
    this.isPaused = false,
    this.onPause,
    this.onResume,
  });

  final String qaId;
  final String title;
  final IconData icon;
  final String fileName;

  /// 0..1 from the file job.
  final double progress;
  final bool isPaused;

  /// Null hides Pause (opening a person's file runs to the end or stops).
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final colors = context.fuzzzyColors;
    final type = context.fuzzzyTextStyles;
    final space = context.fuzzzySpace;
    final percent = (progress.clamp(0, 1) * 100).round();
    final status = isPaused
        ? localizations.workingPaused
        : progress <= 0
            ? localizations.workingStarting
            : '';

    return InkFlowScaffold(
      qaId: qaId,
      title: title,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FlowHero(
            castMoment: FuzzzyCastMoment.working,
            glyph: HeroGlyph(icon: icon, qaId: '$qaId.glyph'),
          ),
          Text(
            UserFileNames.forDisplay(fileName),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: type.titleS.copyWith(color: colors.ink),
          ),
          SizedBox(height: space.m),
          FuzzzyProgressBar(
            value: progress <= 0 ? null : progress.clamp(0, 1).toDouble(),
            qaId: '$qaId.progress',
          ),
          SizedBox(height: space.xs),
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    status,
                    style: type.bodyS.copyWith(color: colors.inkMute),
                  ),
                ),
                Text(
                  '$percent%',
                  key: Key('$qaId.percent'),
                  style: type.label.copyWith(color: colors.inkMute),
                ),
              ],
            ),
          ),
          SizedBox(height: space.l),
          Row(
            children: [
              if (onPause != null) ...[
                Expanded(
                  child: FuzzzyButton(
                    label: isPaused
                        ? localizations.workingGoOn
                        : localizations.workingPause,
                    icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                    variant: FuzzzyButtonVariant.secondary,
                    qaId: isPaused ? '$qaId.resume' : '$qaId.pause',
                    onPressed: isPaused ? onResume : onPause,
                  ),
                ),
                SizedBox(width: space.m),
              ],
              Expanded(
                child: FuzzzyButton(
                  label: localizations.cancel,
                  variant: FuzzzyButtonVariant.secondary,
                  qaId: '$qaId.cancel',
                  onPressed: onCancel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
