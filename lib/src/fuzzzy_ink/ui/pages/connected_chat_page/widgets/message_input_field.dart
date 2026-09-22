import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class MessageInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final SelectedFilesCallback onFilesSelected;
  final List<String>? selectedFilePaths;
  final bool isEncrypting;
  final String chatId;

  const MessageInputField({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.onFilesSelected,
    required this.isEncrypting,
    required this.selectedFilePaths,
    required this.chatId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final fuzzzyColors = context.fuzzzyColors;
    final fuzzzyTextStyles = context.fuzzzyTextStyles;

    final localizations = context.fuzzzyInkLocalizations;

    const height = 200.0;
    const aroundTextFieldPadding = 8.0;

    final fullWidth = MediaQuery.of(context).size.width;

    return Container(
      height: height + 2,
      color: fuzzzyColors.ground,
      child: Column(
        children: [
          Container(
            height: 2,
            width: fullWidth,
            color: fuzzzyColors.surface,
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  );
                },
                child: Text(
                  isEncrypting
                      ? localizations.encrypting
                      : localizations.decrypting,
                  key: ValueKey<bool>(isEncrypting),
                  style: fuzzzyTextStyles.body.copyWith(
                    color: isEncrypting
                        ? fuzzzyColors.inkFaint
                        : fuzzzyColors.inkMute,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Container(
            height: 2,
            width: fullWidth,
            color: fuzzzyColors.surface,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(aroundTextFieldPadding),
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      maxLines: 7,
                      decoration: InputDecoration.collapsed(
                        hintText: '${localizations.textGoesHere}...',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: FileSelectorWidget(
                      onSelected: onFilesSelected,
                      selectedFilePaths: selectedFilePaths,
                      allowMultiple: true,
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onSend,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: height,
                    width: 60,
                    decoration: BoxDecoration(
                      color: fuzzzyColors.actionPrimaryBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.send,
                      color: fuzzzyColors.actionPrimaryFg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
