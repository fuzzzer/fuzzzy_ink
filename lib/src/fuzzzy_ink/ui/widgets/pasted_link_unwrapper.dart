import 'package:flutter/widgets.dart';
import 'package:fuzzzy_ink/src/src.dart';

extension PastedLinkUnwrapper on TextEditingController {
  /// When the whole text is a Fuzzzy Ink link of [type], replaces it with the
  /// sealed text inside. A desktop app receives links this way: pasted into
  /// the field that takes the blob.
  void unwrapPastedLink(FuzzyLinkType type) {
    final blob = FuzzyLinkParser.blobFromPastedLink(text, type);
    if (blob != null) text = blob;
  }
}
