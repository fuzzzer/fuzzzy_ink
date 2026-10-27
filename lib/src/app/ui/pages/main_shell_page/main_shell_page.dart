import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

/// The three tabs, Home · My safe · Settings: a bottom bar on phones, a side
/// rail from 600 px wide. Each tab stays alive while another shows, so its
/// place is kept, and a chosen tab fades in ([tabStack]); choosing the tab
/// already shown goes back to its first screen. Every full-screen flow
/// (first run, lock screen, recovery, Lock, Open, adding a person, a
/// person's page) is a route outside this shell. The content lifts in once
/// when the shell appears, which is right after an unlock. On a computer,
/// ⌘/Ctrl + L, O and , open Lock, Open and Settings ([DesktopShortcuts]).
class MainShellPage extends StatelessWidget {
  const MainShellPage({
    super.key,
    required this.navigationShell,
    required this.preferencesService,
  });

  /// The tabs' own navigators, from the router's stateful shell.
  final StatefulNavigationShell navigationShell;
  final PreferencesService preferencesService;

  /// The router's container for the tabs' navigators: every tab kept alive,
  /// the chosen one fading in, My safe below its own header.
  static Widget tabStack(
    BuildContext context,
    StatefulNavigationShell navigationShell,
    List<Widget> children,
  ) {
    return TabFade(
      currentIndex: navigationShell.currentIndex,
      children: [
        for (var i = 0; i < children.length; i++)
          i == 1 ? _MySafeFrame(child: children[i]) : children[i],
      ],
    );
  }

  /// The tabs' locations, in order.
  static const tabs = [AppRouter.home, AppRouter.vaultHome, AppRouter.settings];

  /// The width from which the side rail replaces the bottom bar.
  static const double railFrom = 600;

  /// The side rail's own width.
  static const double railWidth = 232;

  static int indexOf(String location) {
    if (location.startsWith(AppRouter.vaultHome)) return 1;
    if (location.startsWith(AppRouter.settings)) return 2;
    return 0;
  }

  void _select(BuildContext context, int index) {
    final location = tabs[index];
    preferencesService.setLastSelectedTab(location);
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  /// Lock, as Home's tile: "Who's it for?" first.
  void _lock(BuildContext context) {
    final people = context.read<ChatGeneralDataListCubit>().state;
    showLockWhoSheet(
      context,
      people: people.chatList ?? const [],
      unverifiedChatIds: people.unverifiedChatIds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final colors = context.fuzzzyColors;
    final index = navigationShell.currentIndex;
    final isWide = MediaQuery.sizeOf(context).width >= railFrom;

    final labels = [
      (Icons.home_outlined, localizations.tabHome),
      (Icons.shield_outlined, localizations.tabMySafe),
      (Icons.settings_outlined, localizations.tabSettings),
    ];

    final body = DesktopShortcuts(
      onLock: () => _lock(context),
      onOpen: () => context.push(AppRouter.open),
      onSettings: () => _select(context, 2),
      onLockApp: () => context.read<FuzzyAuthStore>().lock(byUser: true),
      child: LiftIn(child: navigationShell),
    );

    if (isWide) {
      return Scaffold(
        backgroundColor: colors.ground,
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: railWidth,
                child: FuzzzySideNav(
                  qaId: 'tabs',
                  selectedIndex: index,
                  onSelect: (i) => _select(context, i),
                  header: Row(
                    children: [
                      const InkMark(qaId: 'rail'),
                      SizedBox(width: context.fuzzzySpace.s),
                      Flexible(
                        child: Text(
                          localizations.fuzzzyInk,
                          overflow: TextOverflow.ellipsis,
                          style: context.fuzzzyTextStyles.titleS.copyWith(
                            color: colors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  items: [
                    for (final (icon, label) in labels)
                      FuzzzySideNavItem(icon: Icon(icon), label: label),
                  ],
                ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.ground,
      body: body,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            context.fuzzzySpace.s,
            0,
            context.fuzzzySpace.s,
            context.fuzzzySpace.s,
          ),
          // The labels grow with the text size only as far as every word
          // still fits its third of the bar: larger, a word broke mid-word
          // ("MY SAFESETTING S", QA 2026-10-26). The system's own tab bars
          // stop growing too; the page above keeps the full size.
          child: _FittingTabLabels(
            labels: [for (final (_, label) in labels) label],
            child: FuzzzyBottomNav(
              qaId: 'tabs',
              selectedIndex: index,
              onChanged: (i) => _select(context, i),
              items: [
                for (final (icon, label) in labels)
                  FuzzzyNavItem(icon: Icon(icon), label: label),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// My safe's header: its name and, while it is open, the lock that closes
/// it (DESIGN.md section 4.11). The safe's own pages sit below. With Fuzzzy
/// Cast on, the Bridge Guard keeps the open safe from the header (both its
/// spots are there, outside the private pages); never while it is locked,
/// where its password is asked for.
class _MySafeFrame extends StatelessWidget {
  const _MySafeFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;

    final isOpen = context.select<VaultAuthCubit, bool>(
      (cubit) => cubit.state.authState == VaultAuthEnum.unlocked,
    );

    return CastKeeper(
      role: CastKeepers.mySafe,
      tabPath: AppRouter.vaultHome,
      qaId: 'mySafe',
      enabled: isOpen,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FuzzzyAppBar(
              qaId: 'mySafe',
              title: localizations.tabMySafe,
              actions: [
                CastKeeperSpot(
                  1,
                  padding: EdgeInsets.only(right: context.fuzzzySpace.xl),
                ),
                const CastKeeperSpot(0),
                BlocBuilder<VaultAuthCubit, VaultAuthState>(
                  builder: (context, state) {
                    if (state.authState != VaultAuthEnum.unlocked) {
                      return const SizedBox.shrink();
                    }
                    return FuzzzyIconButton(
                      icon: const Icon(Icons.lock_outline),
                      semanticLabel: localizations.safeLockButton,
                      qaId: 'mySafe.lock',
                      onPressed: () => context.read<VaultAuthCubit>().lock(),
                    );
                  },
                ),
              ],
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// Gives the bottom bar the largest text size, up to the person's own, at
/// which every tab label's longest word fits its third of the bar.
class _FittingTabLabels extends StatelessWidget {
  const _FittingTabLabels({required this.labels, required this.child});

  final List<String> labels;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final system = MediaQuery.textScalerOf(context);
    final style = context.fuzzzyTextStyles.label;
    final direction = Directionality.of(context);
    final words = [
      for (final label in labels) ...label.toUpperCase().split(' '),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // The bar's hairline border, then three equal items.
        final itemWidth = (constraints.maxWidth - 2) / labels.length;
        bool fits(double scale) => words.every((word) {
              final painter = TextPainter(
                text: TextSpan(text: word, style: style),
                textDirection: direction,
                textScaler: TextScaler.linear(scale),
                maxLines: 1,
              )..layout();
              final width = painter.width;
              painter.dispose();
              return width <= itemWidth;
            });

        var scale = system.scale(1);
        while (scale > 1 && !fits(scale)) {
          scale = (scale - 0.05).clamp(1, double.infinity);
        }
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child,
        );
      },
    );
  }
}
