import 'package:flutter/material.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class FuzzyBackButton extends StatelessWidget {
  const FuzzyBackButton({
    super.key,
    this.onTap,
  });

  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return FuzzzyIconButton(
      icon: const Icon(Icons.arrow_back),
      variant: FuzzzyIconButtonVariant.filled,
      semanticLabel: 'Back',
      onPressed: onTap ?? () => context.goBack(),
    );
  }
}
