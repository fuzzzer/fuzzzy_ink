import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// The My safe tab: locked (or not made yet) → [VaultUnlockPage]; open →
/// [VaultHomePage]; an unfinished move to its private folder says so and
/// offers nothing else.
///
/// Every state is a private screen: one [SensitiveScreen] covers them all
/// and is kept across the change (no gap in the protection). When the safe
/// opens, its content lifts in once (DESIGN.md section 10, "unlock"); the
/// lift sits above the private screen because it is the unlock response,
/// not a response inside the safe.
class VaultEntryPage extends StatefulWidget {
  const VaultEntryPage({super.key});

  @override
  State<VaultEntryPage> createState() => _VaultEntryPageState();
}

class _VaultEntryPageState extends State<VaultEntryPage> {
  final _privateKey = GlobalKey(debugLabel: 'mySafe.private');

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<VaultItemsCubit>(
          create: (context) => sl.get<VaultItemsCubit>(),
        ),
        BlocProvider<VaultGroupsCubit>(
          create: (context) => sl.get<VaultGroupsCubit>(),
        ),
        BlocProvider<VaultSearchCubit>(
          create: (context) => sl.get<VaultSearchCubit>(),
        ),
      ],
      child: BlocBuilder<VaultAuthCubit, VaultAuthState>(
        buildWhen: (previous, current) =>
            previous.authState != current.authState,
        builder: (context, state) {
          final isOpen = state.authState == VaultAuthEnum.unlocked;
          return LiftIn(
            key: ValueKey(isOpen),
            enabled: isOpen,
            child: SensitiveScreen(
              key: _privateKey,
              child: _body(context, state.authState),
            ),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, VaultAuthEnum authState) {
    switch (authState) {
      case VaultAuthEnum.initial:
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      case VaultAuthEnum.moveUnfinished:
        return Center(
          child: FuzzzyEmptyState(
            title: context.fuzzzyInkLocalizations.vaultMoveUnfinishedTitle,
            message: context.fuzzzyInkLocalizations.vaultMoveUnfinishedMessage,
            qaId: 'vault.moveUnfinished',
          ),
        );
      case VaultAuthEnum.noVault:
      case VaultAuthEnum.locked:
      case VaultAuthEnum.unlocking:
        return const VaultUnlockPage();
      case VaultAuthEnum.unlocked:
        return const VaultHomePage();
    }
  }
}
