import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class ReceivedTextMessageArea extends StatelessWidget {
  final MessageData message;

  const ReceivedTextMessageArea({
    required this.message,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final fuzzzyColors = context.fuzzzyColors;
    final fuzzzyTextStyles = context.fuzzzyTextStyles;

    final isStrict = sl.get<PreferencesService>().copySecurityLevel ==
        CopySecurityLevel.strict;

    final textStyle = fuzzzyTextStyles.body.copyWith(
      color: fuzzzyColors.ink,
    );

    final decoration = BoxDecoration(
      color: fuzzzyColors.surface,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
        bottomRight: Radius.circular(12),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: double.maxFinite,
        child: Align(
          alignment: Alignment.centerLeft,
          child: isStrict
              ? InkWell(
                  onLongPress: () {
                    CopyGuard.copyPlaintext(
                      context: context,
                      textToCopy: message.decryptedMessage,
                    );
                  },
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: decoration,
                    child: Text(
                      message.decryptedMessage,
                      style: textStyle,
                    ),
                  ),
                )
              : Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: decoration,
                  child: SelectableText(
                    message.decryptedMessage,
                    style: textStyle,
                  ),
                ),
        ),
      ),
    );
  }
}
