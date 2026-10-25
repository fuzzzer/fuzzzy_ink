import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// One step of a [StepPicture].
class StepPictureStep {
  const StepPictureStep({required this.icon, required this.label});

  final IconData icon;

  /// Short; the picture wraps it to two lines.
  final String label;
}

/// The small picture that replaces a paragraph: three dots with arrows and
/// captions ("Invite sent → Tamar replies → Lock for each other"). Steps
/// before [done] are filled ink with a check.
///
/// Micro-interactions (DESIGN.md section 10): [justDone] is the step that was
/// just reached; it fills once (slow 420 ms, scale 0.86 to 1), its check
/// draws after 240 ms and the arrow before it arrives 4 px from the left.
/// [settle] lets one waiting step settle once (the empty Home). Reduced
/// motion shows the final state; on private screens only the fill and check
/// play, nothing travels. At large text sizes the steps stack vertically.
class StepPicture extends StatelessWidget {
  const StepPicture({
    super.key,
    required this.steps,
    this.done = 0,
    this.justDone,
    this.settle,
    this.qaId,
  });

  final List<StepPictureStep> steps;
  final int done;
  final int? justDone;
  final int? settle;
  final String? qaId;

  /// The invite flow's picture, the same everywhere it is shown: "Invite
  /// sent → [name] replies → Lock for each other" ("They reply" without a
  /// name).
  static List<StepPictureStep> inviteSteps(
    BuildContext context, {
    String? name,
  }) {
    final localizations = context.fuzzzyInkLocalizations;
    return [
      StepPictureStep(
        icon: Icons.ios_share,
        label: localizations.stepInviteSent,
      ),
      StepPictureStep(
        icon: Icons.move_to_inbox_outlined,
        label: name == null
            ? localizations.stepTheyReply
            : localizations.stepNameReplies(name),
      ),
      StepPictureStep(
        icon: Icons.lock_outline,
        label: localizations.stepLockForEachOther,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final localizations = context.fuzzzyInkLocalizations;
    final stacked = MediaQuery.textScalerOf(context).scale(1) >= 2;

    final description = [
      for (var i = 0; i < steps.length; i++)
        i < done
            ? localizations.stepDone(steps[i].label)
            : localizations.stepNext(steps[i].label),
    ].join('. ');

    final children = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      if (i > 0) {
        children.add(
          _StepArrow(arrives: i == justDone, vertical: stacked),
        );
      }
      final node = _StepNode(
        step: steps[i],
        isDone: i < done,
        fills: i == justDone,
        settles: i == settle,
        vertical: stacked,
      );
      children.add(stacked ? node : Expanded(child: node));
    }

    return Semantics(
      identifier: qaId == null ? null : 'steps_picture.$qaId',
      container: true,
      label: description,
      child: ExcludeSemantics(
        child: Container(
          key: qaId == null ? null : Key('steps_picture.$qaId'),
          padding: context.fuzzzyDensity.snug,
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.line),
            borderRadius: BorderRadius.circular(context.fuzzzyRadius.l),
          ),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
        ),
      ),
    );
  }
}

class _StepNode extends StatefulWidget {
  const _StepNode({
    required this.step,
    required this.isDone,
    required this.fills,
    required this.settles,
    required this.vertical,
  });

  final StepPictureStep step;
  final bool isDone;
  final bool fills;
  final bool settles;
  final bool vertical;

  static const double dot = 34;

  @override
  State<_StepNode> createState() => _StepNodeState();
}

class _StepNodeState extends State<_StepNode>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final controller = AnimationController(
      vsync: this,
      duration: context.fuzzzyMotion.slow,
      value: 1,
    );
    _controller = controller;
    final plays = (widget.fills && widget.isDone) || widget.settles;
    if (plays && InkMotion.allowsInPlace(context)) controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final iconSize = context.fuzzzyIconSize.m;
    final progress = CurvedAnimation(
      parent: _controller!,
      curve: context.fuzzzyMotion.slowCurve,
    );
    final isDone = widget.isDone;

    final dot = AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final t = progress.value;
        final filling = widget.fills && isDone;
        final fill = isDone
            ? Color.lerp(
                colors.raised,
                colors.actionPrimaryBg,
                filling ? t : 1,
              )!
            : colors.raised;
        final scale = filling || widget.settles ? 0.86 + 0.14 * t : 1.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: _StepNode.dot,
            height: _StepNode.dot,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDone ? colors.actionPrimaryBg : colors.lineStrong,
              ),
            ),
            child: isDone
                ? (filling
                    ? CheckDraw(
                        size: iconSize,
                        color: colors.actionPrimaryFg,
                        delay: InkMotionTiming.stepCheckDelay,
                      )
                    : Icon(
                        Icons.check,
                        size: iconSize,
                        color: colors.actionPrimaryFg,
                      ))
                : Icon(widget.step.icon, size: iconSize, color: colors.ink),
          ),
        );
      },
    );

    final label = Text(
      widget.step.label,
      textAlign: widget.vertical ? TextAlign.start : TextAlign.center,
      style: context.fuzzzyTextStyles.bodyS.copyWith(color: colors.inkMute),
    );

    if (widget.vertical) {
      return Row(
        children: [
          dot,
          SizedBox(width: context.fuzzzySpace.m),
          Expanded(child: label),
        ],
      );
    }
    return Column(
      children: [dot, SizedBox(height: context.fuzzzySpace.s * 0.75), label],
    );
  }
}

class _StepArrow extends StatefulWidget {
  const _StepArrow({required this.arrives, required this.vertical});

  final bool arrives;
  final bool vertical;

  @override
  State<_StepArrow> createState() => _StepArrowState();
}

class _StepArrowState extends State<_StepArrow>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final controller = AnimationController(
      vsync: this,
      duration: InkMotionTiming.arrowDelay + context.fuzzzyMotion.slow,
      value: 1,
    );
    _controller = controller;
    if (widget.arrives && InkMotion.allowsTravel(context)) {
      controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller!;
    final total = controller.duration!.inMicroseconds;
    final progress = CurvedAnimation(
      parent: controller,
      curve: Interval(
        InkMotionTiming.arrowDelay.inMicroseconds / total,
        1,
        curve: context.fuzzzyMotion.slowCurve,
      ),
    );
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;

    return Padding(
      padding: widget.vertical
          ? EdgeInsets.only(left: space.s, top: space.xs, bottom: space.xs)
          : EdgeInsets.only(top: space.s),
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, child) => Opacity(
          opacity: 0.15 + 0.85 * progress.value,
          child: Transform.translate(
            offset: Offset(-4 * (1 - progress.value), 0),
            child: child,
          ),
        ),
        child: Icon(
          widget.vertical ? Icons.arrow_downward : Icons.arrow_forward,
          size: context.fuzzzyIconSize.s,
          color: colors.inkFaint,
        ),
      ),
    );
  }
}
