import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/lib.dart';

class FuzzyLoadingPagebuilder extends StatelessWidget {
  const FuzzyLoadingPagebuilder({super.key});

  @override
  Widget build(BuildContext context) {
    return const FuzzyScaffold(
      body: Center(
        child: DefaultLoadingWidget(),
      ),
      hasAutomaticBackButton: false,
    );
  }
}
