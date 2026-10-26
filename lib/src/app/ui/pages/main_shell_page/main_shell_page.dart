import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

/// The three tabs, Home · My safe · Settings: a bottom bar on phones, a side
/// rail from 600 px wide. Every full-screen flow (first run, lock screen,
/// recovery, Lock, Open, adding a person, a person's page) is a route
/// outside this shell. The content lifts in once when the shell appears,
/// which is right after an unlock. On a computer, ⌘/Ctrl + L, O and ,
/// open Lock, Open and Settings ([DesktopShortcuts]).
class MainShellPage extends StatelessWidget {
  const MainShellPage({
    super.key,
    required this.child,
    required this.preferencesService,
  });

  final Widget child;
  final PreferencesService preferencesService;

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
    context.go(location);
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
    final index = indexOf(GoRouterState.of(context).uri.path);
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
      onLockApp: () => context.read<FuzzyAuthStore>().lock(),
      child: LiftIn(
        child: index == 1 ? _MySafeFrame(child: child) : child,
      ),
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
    );
  }
}

/// My safe's header: its name and, while it is open, the lock that closes
/// it (DESIGN.md section 4.11). The safe's own pages sit below.
class _MySafeFrame extends StatelessWidget {
  const _MySafeFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FuzzzyAppBar(
            qaId: 'mySafe',
            title: localizations.tabMySafe,
            actions: [
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
    );
  }
}
