import 'package:flutter/material.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class FuzzyErrorPageBuilder extends StatelessWidget {
  final String? message;
  final bool hasAutomaticBackButton;

  const FuzzyErrorPageBuilder({
    super.key,
    this.message,
    this.hasAutomaticBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final fuzzzyColors = context.fuzzzyColors;
    final fuzzzyTextStyles = context.fuzzzyTextStyles;

    final localizations = context.fuzzzySealLocalizations;

    return FuzzyScaffold(
      hasAutomaticBackButton: hasAutomaticBackButton,
      body: Center(
        child: Text(
          message ?? localizations.unexpectedFailureOccuredPleaseContactUs,
          style: fuzzzyTextStyles.body.copyWith(
            fontWeight: FontWeight.w600,
            color: fuzzzyColors.destructiveText,
          ),
        ),
      ),
    );
  }
}
