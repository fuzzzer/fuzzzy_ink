import 'package:flutter/material.dart';
import 'package:fuzzzy_seal/lib.dart';

class FileDecryptionProgressesDisplaylaceholder extends StatelessWidget {
  const FileDecryptionProgressesDisplaylaceholder({
    super.key,
    required this.chatId,
  });

  final String chatId;

  @override
  Widget build(BuildContext context) {
    return FileDecriptionCubitBuilder(
      builder: (context, state) {
        return SizedBox(
          height: state.currentProcessingFile?.chatId == chatId
              ? FileEncryptionProgressDisplay.height
              : 0,
        );
      },
    );
  }
}
