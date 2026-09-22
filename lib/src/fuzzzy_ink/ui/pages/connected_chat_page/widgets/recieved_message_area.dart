import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/lib.dart';

class ReceivedMessageArea extends StatelessWidget {
  final MessageData message;

  const ReceivedMessageArea({
    required this.message,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return switch (message.type) {
      MessageType.file => ReceivedFileMessageArea(message: message),
      MessageType.text => ReceivedTextMessageArea(message: message),
    };
  }
}
