import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Home's header: the mark (26), "Fuzzzy Ink" and "Lock the app now".
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final type = context.fuzzzyTextStyles;
    final space = context.fuzzzySpace;

    return Padding(
      padding:
          EdgeInsets.fromLTRB(space.l + space.xs, space.xs, space.s, space.xs),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            const InkMark(qaId: 'home'),
            SizedBox(width: space.s + space.xs / 2),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  context.fuzzzyInkLocalizations.fuzzzyInk,
                  style: type.titleM.copyWith(
                    color: context.fuzzzyColors.ink,
                    fontFamily: type.displayL.fontFamily,
                    fontWeight: type.displayL.fontWeight,
                  ),
                ),
              ),
            ),
            const AppLockButton(),
          ],
        ),
      ),
    );
  }
}

/// The two tiles: Lock (inverted ink) and Open (surface).
class HomeActionTiles extends StatelessWidget {
  const HomeActionTiles({
    super.key,
    required this.onLock,
    required this.onOpen,
  });

  final VoidCallback onLock;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        space.l + space.xs,
        space.s,
        space.l + space.xs,
        0,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ActionTile(
                qaId: 'home.lock',
                icon: Icons.lock_outline,
                title: localizations.homeLockTitle,
                subtitle: localizations.homeLockSubtitle,
                inverted: true,
                onTap: onLock,
              ),
            ),
            SizedBox(width: space.m),
            Expanded(
              child: ActionTile(
                qaId: 'home.open',
                icon: CupertinoIcons.lock_open,
                title: localizations.homeOpenTitle,
                subtitle: localizations.homeOpenSubtitle,
                onTap: onOpen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "PEOPLE · 3" with the small Add button (once someone is there).
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({super.key, this.count, this.onAdd});

  /// Null while loading.
  final int? count;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final count = this.count;
    final onAdd = this.onAdd;
    final label = count == null || count == 0
        ? localizations.homePeople
        : localizations.homePeopleCount(count);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        space.l + space.xs,
        space.xl,
        space.l,
        space.s,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                label.toUpperCase(),
                style: context.fuzzzyTextStyles.label.copyWith(
                  color: context.fuzzzyColors.inkMute,
                ),
              ),
            ),
          ),
          if (onAdd != null)
            FuzzzyButton(
              label: localizations.homeAdd,
              icon: const Icon(Icons.add),
              variant: FuzzzyButtonVariant.ghost,
              size: FuzzzyButtonSize.s,
              qaId: 'home.add',
              onPressed: onAdd,
            ),
        ],
      ),
    );
  }
}

/// The hairline above the first person.
class HomeListTop extends StatelessWidget {
  const HomeListTop({super.key});

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, thickness: 1, color: context.fuzzzyColors.line);
}

/// The last row: "Add a person", with a dashed avatar.
class AddPersonRow extends StatelessWidget {
  const AddPersonRow({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;

    return Semantics(
      identifier: 'home.addPerson',
      button: true,
      container: true,
      child: FuzzzyTappable(
        key: const Key('home.addPerson'),
        onTap: onTap,
        focusRingInset: true,
        builder: (context, active) => Container(
          constraints: const BoxConstraints(minHeight: 64),
          color: active ? colors.surface : null,
          padding: EdgeInsets.symmetric(
            horizontal: space.l + space.xs,
            vertical: space.m,
          ),
          child: Row(
            children: [
              CustomPaint(
                painter: FuzzzyDashedRRectPainter(
                  color: colors.lineStrong,
                  radius: 22,
                ),
                child: SizedBox.square(
                  dimension: 44,
                  child: Icon(
                    Icons.add,
                    size: context.fuzzzyIconSize.l,
                    color: colors.ink,
                  ),
                ),
              ),
              SizedBox(width: space.m + space.xs / 2),
              Text(
                context.fuzzzyInkLocalizations.homeAddPerson,
                style: context.fuzzzyTextStyles.titleS.copyWith(
                  color: colors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// While the people load: three skeleton rows.
class HomeLoadingRows extends StatelessWidget {
  const HomeLoadingRows({super.key});

  @override
  Widget build(BuildContext context) {
    final space = context.fuzzzySpace;

    return Column(
      key: const Key('home.loading'),
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: space.l + space.xs,
              vertical: space.m,
            ),
            child: Row(
              children: [
                const FuzzzySkeleton(width: 44, height: 44, circle: true),
                SizedBox(width: space.m + space.xs / 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FuzzzySkeleton(width: 140, height: 14),
                      SizedBox(height: space.s),
                      const FuzzzySkeleton(width: 200, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The people could not be read.
class HomeLoadError extends StatelessWidget {
  const HomeLoadError({super.key});

  @override
  Widget build(BuildContext context) {
    final space = context.fuzzzySpace;

    return Padding(
      key: const Key('home.error'),
      padding: EdgeInsets.all(space.l + space.xs),
      child: FuzzzyAlert(
        message: context.fuzzzyInkLocalizations.homeLoadError,
        kind: FuzzzyAlertKind.error,
      ),
    );
  }
}
