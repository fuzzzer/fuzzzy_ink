import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Locks the whole app now: the store closes (its key is wiped in the core)
/// and the master password is asked for again.
class AppLockButton extends StatelessWidget {
  const AppLockButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FuzzzyIconButton(
      icon: const Icon(Icons.lock_outline),
      semanticLabel: context.fuzzzyInkLocalizations.appLockNow,
      qaId: 'app.lock',
      onPressed: () => context.read<FuzzyAuthStore>().lock(),
    );
  }
}
