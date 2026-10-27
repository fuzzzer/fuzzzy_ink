import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// The back arrow for a kit `FuzzzyAppBar`, read aloud in the app's language.
///
/// Pass it as the bar's `leading` and leave `onLeading` empty: with
/// `onLeading` the kit wraps the arrow in its own button that always says
/// "Back" in English, also on Georgian screens. This keeps the kit's QA key
/// and identifier (`<bar qaId>.back`) and a 44 × 44 touch area.
class AppBarBack extends StatelessWidget {
  const AppBarBack({
    super.key,
    required this.barQaId,
    required this.onPressed,
  });

  /// The bar's own `qaId` (the kit's default is `appbar`).
  final String barQaId;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final id = '$barQaId.back';
    return Semantics(
      identifier: id,
      container: true,
      button: true,
      label: context.fuzzzyInkLocalizations.back,
      child: KeyedSubtree(
        key: Key(id),
        child: FuzzzyTappable(
          onTap: onPressed,
          focusRadius: context.fuzzzyRadius.s,
          pressInk: true,
          builder: (context, _) => SizedBox.square(
            dimension: kFuzzzyMinTouchTarget,
            child: Center(
              child: Icon(
                Icons.arrow_back,
                size: context.fuzzzyIconSize.s,
                color: context.fuzzzyColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
