import 'package:flutter/material.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class ChatListErrorContent extends StatelessWidget {
  final String? message;

  const ChatListErrorContent({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final fuzzzyColors = context.fuzzzyColors;
    final fuzzzyTextStyles = context.fuzzzyTextStyles;

    final localizations = context.fuzzzySealLocalizations;

    return Center(
      child: Text(
        message ?? localizations.failedToLoadChats,
        style: fuzzzyTextStyles.body.copyWith(
          fontWeight: FontWeight.w600,
          color: fuzzzyColors.destructiveText,
        ),
      ),
    );
  }
}
