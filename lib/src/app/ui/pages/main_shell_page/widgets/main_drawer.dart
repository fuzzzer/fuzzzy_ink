import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = context.fuzzzyInkLocalizations;
    final prefs = sl.get<PreferencesService>();
    final currentLoc = GoRouterState.of(context).uri.toString();

    final isChat = currentLoc == AppRouter.home;
    final isVault = currentLoc.startsWith('/vault');

    return Drawer(
      backgroundColor: context.fuzzzyColors.ground,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                loc.menu,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.fuzzzyColors.ink,
                    ),
              ),
            ),
            ListTile(
              leading: Icon(
                Icons.chat_bubble_outline,
                color: isChat
                    ? context.fuzzzyColors.ink
                    : context.fuzzzyColors.inkMute,
              ),
              title: Text(
                loc.fuzzzyInk,
                style: TextStyle(
                  color: isChat
                      ? context.fuzzzyColors.ink
                      : context.fuzzzyColors.ink,
                  fontWeight: isChat ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                prefs.setLastSelectedTab(AppRouter.home);
                context.go(AppRouter.home);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.lock_outline,
                color: isVault
                    ? context.fuzzzyColors.ink
                    : context.fuzzzyColors.inkMute,
              ),
              title: Text(
                loc.fuzzyVault,
                style: TextStyle(
                  color: isVault
                      ? context.fuzzzyColors.ink
                      : context.fuzzzyColors.ink,
                  fontWeight: isVault ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/vault');
              },
            ),
            const Spacer(),
            ListTile(
              leading: Icon(
                Icons.settings_outlined,
                color: context.fuzzzyColors.inkMute,
              ),
              title: Text(
                loc.settings,
                style: TextStyle(
                  color: context.fuzzzyColors.ink,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                context.push(AppRouter.settings);
              },
            ),
          ],
        ),
      ),
    );
  }
}
