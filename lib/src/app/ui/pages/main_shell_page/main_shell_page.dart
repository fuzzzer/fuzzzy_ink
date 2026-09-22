import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

export 'widgets/widgets.dart';

class MainShellPage extends StatelessWidget {
  final Widget child;

  const MainShellPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final currentLoc = GoRouterState.of(context).uri.toString();
    final isChat = currentLoc == AppRouter.home;
    final isVault = currentLoc.startsWith('/vault');
    final loc = context.fuzzzySealLocalizations;

    String title = '';
    Widget? rightAction;

    if (isChat) {
      title = loc.fuzzzySeal;
      rightAction = const BasicEncryptionNavigatorAction();
    } else if (isVault) {
      title = loc.fuzzyVault;
      rightAction = BlocBuilder<VaultAuthCubit, VaultAuthState>(
        builder: (context, state) {
          if (state.authState == VaultAuthEnum.unlocked) {
            return IconButton(
              icon: Icon(
                Icons.more_vert,
                color: context.fuzzzyColors.ink,
              ),
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: context.fuzzzyColors.ground,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (sheetContext) {
                    return SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: context.fuzzzyColors.inkMute,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            ListTile(
                              leading: Icon(
                                Icons.lock_outline,
                                color: context.fuzzzyColors.ink,
                              ),
                              title: Text(
                                loc.vaultLockVault,
                                style: TextStyle(
                                  color: context.fuzzzyColors.ink,
                                ),
                              ),
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                context.read<VaultAuthCubit>().lock();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          }
          return const SizedBox();
        },
      );
    }

    final shellAppBar = FuzzzyAppBar(
      title: title,
      leading: Builder(
        builder: (context) {
          return IconButton(
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.menu,
              color: context.fuzzzyColors.ink,
            ),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          );
        },
      ),
      actions: rightAction != null ? [rightAction] : null,
    );

    return Scaffold(
      backgroundColor: context.fuzzzyColors.ground,
      drawer: const MainDrawer(),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          shellAppBar.preferredSize.height + MediaQuery.of(context).padding.top,
        ),
        child: SafeArea(
          child: shellAppBar,
        ),
      ),
      body: child,
    );
  }
}
