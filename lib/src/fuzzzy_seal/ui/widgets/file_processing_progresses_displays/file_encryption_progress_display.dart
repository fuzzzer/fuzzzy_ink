import 'package:flutter/material.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class FileEncryptionProgressDisplay extends StatelessWidget {
  const FileEncryptionProgressDisplay({
    super.key,
    required this.chatId,
  });

  static const height = 30.0;

  final String chatId;

  @override
  Widget build(BuildContext context) {
    final fuzzzyColors = context.fuzzzyColors;
    final fuzzzyTextStyles = context.fuzzzyTextStyles;

    const borderWidth = 2.0;

    return FileEncriptionCubitBuilder(
      builder: (context, state) {
        if (state.currentProcessingFile?.chatId != chatId) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: height,
          child: Row(
            children: [
              Container(
                width: 50,
                height: height,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: fuzzzyColors.surface,
                    width: borderWidth,
                  ),
                ),
                child: Center(
                  child: Text(
                    state
                        .getToBeProcessedFilesByChatId(chatId)
                        .length
                        .toString(),
                    style: fuzzzyTextStyles.titleM.copyWith(
                      color: fuzzzyColors.inkMute,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: HorizontalProgressBar(
                  thickness: height,
                  progress: state.progress,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
