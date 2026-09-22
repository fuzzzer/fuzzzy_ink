import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class VaultSearchBar extends StatelessWidget {
  const VaultSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: FuzzzyTextField(
        label: currentContextLocalization.vaultSearchHint,
        suffix: const Icon(Icons.search),
        onChanged: (query) {
          context.read<VaultSearchCubit>().updateQuery(query);
        },
      ),
    );
  }
}
