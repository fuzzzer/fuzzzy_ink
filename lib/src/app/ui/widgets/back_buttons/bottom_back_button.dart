import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// The round back button at the bottom of the older screens (About
/// encryption, the file viewer, Basics), read aloud in the app's language.
/// Pass it as `FuzzyScaffold.actionsRow`: the old local kit's own back
/// button always says "Back" in English.
class BottomBackButton extends StatelessWidget {
  const BottomBackButton({super.key, this.qaId});

  final String? qaId;

  @override
  Widget build(BuildContext context) {
    return FuzzzyIconButton(
      icon: const Icon(Icons.arrow_back),
      variant: FuzzzyIconButtonVariant.filled,
      semanticLabel: context.fuzzzyInkLocalizations.back,
      qaId: qaId,
      onPressed: context.goBack,
    );
  }
}
