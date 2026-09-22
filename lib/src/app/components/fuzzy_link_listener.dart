import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/lib.dart';

class FuzzyLinkListener extends StatefulWidget {
  const FuzzyLinkListener({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<FuzzyLinkListener> createState() => _FuzzyLinkListenerState();
}

class _FuzzyLinkListenerState extends State<FuzzyLinkListener> {
  late final FuzzyLinkHandler _handler;

  @override
  void initState() {
    super.initState();
    _handler = sl.get<FuzzyLinkHandler>();
    _handler.initialize();
  }

  @override
  void dispose() {
    _handler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
