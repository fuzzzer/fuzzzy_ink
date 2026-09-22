import 'package:flutter/material.dart';
import 'package:fuzzzy_seal/lib.dart';

extension BuildContextExtension on BuildContext {
  FuzzzySealLocalizations get fuzzzySealLocalizations =>
      FuzzzySealLocalizations.of(this)!;
}
