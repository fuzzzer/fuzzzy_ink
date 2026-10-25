import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// The line under a vault's own password: with a recovery key kept, the key
/// still opens the vault; without one, the password is the only way in.
class VaultOwnPasswordNote extends StatelessWidget {
  const VaultOwnPasswordNote({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final colors = context.fuzzzyColors;
    final kept = context.select<VaultAuthCubit, bool>(
      (cubit) => cubit.state.recoveryKeyKept,
    );
    return Text(
      kept
          ? localizations.vaultOwnPasswordRecoveryNote
          : localizations.vaultOwnPasswordNote,
      key: const ValueKey('vault.ownPasswordNote'),
      style: context.fuzzzyTextStyles.bodyS.copyWith(
        color: kept ? colors.inkMute : colors.destructiveText,
      ),
    );
  }
}
