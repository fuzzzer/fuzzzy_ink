import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class VaultEntryPage extends StatelessWidget {
  const VaultEntryPage({super.key});

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
        builder: (context, state) {
          switch (state.authState) {
            case VaultAuthEnum.initial:
              return const FuzzyLoadingPagebuilder();
            case VaultAuthEnum.noVault:
              return const VaultCreatePage();
            case VaultAuthEnum.moveUnfinished:
              return Center(
                child: FuzzzyEmptyState(
                  title:
                      context.fuzzzyInkLocalizations.vaultMoveUnfinishedTitle,
                  message:
                      context.fuzzzyInkLocalizations.vaultMoveUnfinishedMessage,
                  qaId: 'vault.moveUnfinished',
                ),
              );
            case VaultAuthEnum.locked:
            case VaultAuthEnum.unlocking:
              return const VaultUnlockPage();
            case VaultAuthEnum.unlocked:
              return const VaultHomePage();
          }
        },
      ),
    );
  }
}
