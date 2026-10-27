import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

/// One screen of the access flows (first run, lock screen, recovery and the
/// Settings sub-screens) in the redesign's recipe (DESIGN.md section 6): an
/// optional header with a back button, the content scrolling below it, and
/// the main buttons pinned at the bottom in the same place on every screen.
/// On a wide screen the content keeps to a centred 560 px column.
class AccessPage extends StatelessWidget {
  const AccessPage({
    super.key,
    required this.children,
    this.title,
    this.onBack,
    this.bottom = const [],
    this.centerContent = false,
    this.qaId,
    this.actions = const [],
  });

  final List<Widget> children;

  /// The header's title; no header at all when both this and [onBack] are
  /// null.
  final String? title;
  final VoidCallback? onBack;

  /// The main buttons, top to bottom.
  final List<Widget> bottom;

  /// Centres the content vertically when there is room (welcome, lock
  /// screen).
  final bool centerContent;
  final String? qaId;

  /// At the header's end (a Fuzzzy Cast keeper's spots).
  final List<Widget> actions;

  /// The widest the content gets (the design's dialog width on a computer).
  static const double maxContentWidth = 560;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;
    final hasHeader = title != null || onBack != null;
    final back = onBack;

    Widget column(List<Widget> items) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxContentWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: items,
            ),
          ),
        );

    return Scaffold(
      key: qaId == null ? null : Key('access.$qaId'),
      backgroundColor: colors.ground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasHeader)
              FuzzzyAppBar(
                qaId: qaId ?? 'access',
                title: title ?? '',
                // Not the kit's onLeading: its arrow always says "Back" in
                // English.
                leading: back == null
                    ? null
                    : AppBarBack(barQaId: qaId ?? 'access', onPressed: back),
                actions: actions,
              ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: space.l),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: centerContent ? constraints.maxHeight : 0,
                    ),
                    child: Column(
                      mainAxisAlignment: centerContent
                          ? MainAxisAlignment.center
                          : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: space.l),
                        column(children),
                        SizedBox(height: space.l),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (bottom.isNotEmpty)
              Padding(
                padding:
                    EdgeInsets.fromLTRB(space.l, space.s, space.l, space.l),
                child: column([
                  for (final (index, button) in bottom.indexed) ...[
                    if (index > 0) SizedBox(height: space.s),
                    button,
                  ],
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

/// A screen title in the redesign's voice: one short line, Space Grotesk.
class AccessTitle extends StatelessWidget {
  const AccessTitle(this.text, {super.key, this.center = false});

  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) => Semantics(
        header: true,
        child: Text(
          text,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: context.fuzzzyTextStyles.titleL
              .copyWith(color: context.fuzzzyColors.ink),
        ),
      );
}

/// The one short line under a title.
class AccessLine extends StatelessWidget {
  const AccessLine(this.text, {super.key, this.center = false});

  final String text;
  final bool center;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: context.fuzzzyTextStyles.body
            .copyWith(color: context.fuzzzyColors.inkMute),
      );
}

/// How strong a note is: a required safety warning ([danger]), a caution
/// ([warning]) or a good result ([success]).
enum AccessNoteTone { danger, warning, success }

/// A short note box with an icon: "**No reset.** Lose it and your recovery
/// key, and everything is gone. Why?". [bold] leads in bold; [trailing]
/// (usually a [WhyLink]) follows the text.
class AccessNote extends StatelessWidget {
  const AccessNote({
    super.key,
    required this.text,
    required this.tone,
    this.bold,
    this.trailing,
    this.qaId,
    this.actions = const [],
  });

  final String text;
  final String? bold;
  final AccessNoteTone tone;
  final Widget? trailing;
  final String? qaId;

  /// At the header's end (a Fuzzzy Cast keeper's spots).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;
    final type = context.fuzzzyTextStyles;
    final (Color tint, Color textColor, IconData icon) = switch (tone) {
      AccessNoteTone.danger => (
          colors.destructive,
          colors.destructiveText,
          Icons.warning_amber_rounded,
        ),
      AccessNoteTone.warning => (
          colors.warning,
          colors.ink,
          Icons.warning_amber_rounded,
        ),
      AccessNoteTone.success => (
          colors.success,
          colors.ink,
          Icons.check_circle_outline,
        ),
    };
    final style = type.bodyS.copyWith(color: textColor);
    final bold = this.bold;
    final trailing = this.trailing;

    return Container(
      key: qaId == null ? null : Key('note.$qaId'),
      padding: EdgeInsets.symmetric(horizontal: space.m, vertical: space.s),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        border: Border.all(color: tint.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(context.fuzzzyRadius.m),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: space.s),
            child: ExcludeSemantics(
              child: Icon(icon, size: context.fuzzzyIconSize.m, color: tint),
            ),
          ),
          SizedBox(width: space.s),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: space.s * 0.75,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: space.s),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        if (bold != null)
                          TextSpan(
                            text: '$bold ',
                            style: style.copyWith(fontWeight: FontWeight.w700),
                          ),
                        TextSpan(text: text),
                      ],
                    ),
                    style: style,
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Runs [action] with a context on the app's top screen once the
/// navigation that is under way has been drawn: for a message or a sheet
/// that belongs to the screen the app moves to (after the first run or a
/// recovery, when the screen that asked is gone).
Future<void> runOnTopScreen(void Function(BuildContext context) action) async {
  await WidgetsBinding.instance.endOfFrame;
  await WidgetsBinding.instance.endOfFrame;
  final overlay = navigatorKey.currentState?.overlay;
  if (overlay == null || !overlay.mounted) return;
  // A context inside one of the navigator's screens: sheets and toasts need
  // one below the overlay.
  BuildContext? inside;
  void visit(Element element) {
    if (inside != null) return;
    if (Overlay.maybeOf(element) != null) {
      inside = element;
      return;
    }
    element.visitChildElements(visit);
  }

  overlay.context.visitChildElements(visit);
  final context = inside;
  if (context != null && context.mounted) action(context);
}

/// Back from a Settings screen: the screen it was opened from, or the
/// Settings tab when it was opened on its own.
void leaveAccessPage(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppRouter.settings);
  }
}
