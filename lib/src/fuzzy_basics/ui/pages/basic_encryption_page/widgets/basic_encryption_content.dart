import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class BasicEncryptionContent extends StatelessWidget {
  final TextEditingController keyController;
  final TextEditingController textController;
  final String resultText;
  final List<String>? selectedFilePaths;
  final SelectedFilesCallback onFilesSelected;
  final VoidCallback onProcessFiles;

  const BasicEncryptionContent({
    super.key,
    required this.keyController,
    required this.textController,
    required this.resultText,
    required this.selectedFilePaths,
    required this.onFilesSelected,
    required this.onProcessFiles,
  });

  @override
  Widget build(BuildContext context) {
    return FuzzyScaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              FuzzzyAppBar(
                title: context.fuzzzyInkLocalizations.basicEncryption,
              ),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: keyController,
                builder: (context, _) {
                  String? helper;
                  final text = keyController.text;
                  if (text.isNotEmpty) {
                    if (text.length < 6) {
                      helper = currentContextLocalization.keyStrengthWeak;
                    } else if (!RegExp('[a-zA-Z]').hasMatch(text) ||
                        !RegExp('[0-9]').hasMatch(text)) {
                      helper = currentContextLocalization.keyStrengthModerate;
                    } else if (text.length > 12) {
                      helper = currentContextLocalization.keyStrengthStrong;
                    } else {
                      helper = currentContextLocalization.keyStrengthGood;
                    }
                  }
                  return FuzzzyTextField(
                    controller: keyController,
                    label: context.fuzzzyInkLocalizations.customKey,
                    hint: context.fuzzzyInkLocalizations.enterYourSecretKey,
                    helper: helper,
                  );
                },
              ),
              const SizedBox(height: 16),
              FuzzzyTextField(
                controller: textController,
                label: context.fuzzzyInkLocalizations.textToEncryptDecrypt,
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              BlocBuilder<BasicEncryptionCubit, BasicEncryptionState>(
                builder: (context, state) {
                  if (state.status.isLoading) {
                    return const DefaultLoadingWidget();
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: FuzzzyButton(
                          label: context.fuzzzyInkLocalizations.encryptText,
                          onPressed: () {
                            context.read<BasicEncryptionCubit>().encryptText(
                                  text: textController.text,
                                  key: keyController.text,
                                );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FuzzzyButton(
                          label: context.fuzzzyInkLocalizations.decryptText,
                          onPressed: () {
                            context.read<BasicEncryptionCubit>().decryptText(
                                  encryptedText: textController.text,
                                  key: keyController.text,
                                );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              if (resultText.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${context.fuzzzyInkLocalizations.result}:'),
                    const SizedBox(height: 8),
                    SelectableText(resultText),
                    const SizedBox(height: 24),
                  ],
                ),
              const Divider(),
              const SizedBox(height: 24),
              FileSelectorWidget(
                onSelected: onFilesSelected,
                selectedFilePaths: selectedFilePaths,
                allowMultiple: true,
              ),
              const SizedBox(height: 16),
              if (selectedFilePaths?.isNotEmpty == true)
                FuzzzyButton(
                  label: context.fuzzzyInkLocalizations.processSelectedFiles,
                  onPressed: onProcessFiles,
                ),
              const SizedBox(height: 16),
              BlocBuilder<CustomFileProcessingCubit<FileEncryptionOption>,
                  CustomFileProcessingState>(
                builder: (context, state) =>
                    _buildProcessedFilesList(state, context),
              ),
              BlocBuilder<CustomFileProcessingCubit<FileDecryptionOption>,
                  CustomFileProcessingState>(
                builder: (context, state) =>
                    _buildProcessedFilesList(state, context),
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProcessedFilesList(
    CustomFileProcessingState state,
    BuildContext context,
  ) {
    if (state.processedFiles.isEmpty && state.currentProcessingFile == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        if (state.currentProcessingFile != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              currentContextLocalization.processingFile(
                state.currentProcessingFile!.inputFilePath.split('/').last,
                (state.progress * 100).toStringAsFixed(1),
              ),
            ),
          ),
        ...state.processedFiles.map((file) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              file.inputFilePath.split('/').last,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              file.outputFilePath ??
                  file.failure?.type.toUiMessage(currentContextLocalization) ??
                  currentContextLocalization.processingFailed,
              maxLines: 2,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (file.outputFilePath != null) ...[
                  IconButton(
                    icon: const Icon(Icons.folder_open),
                    onPressed: () {
                      final dirPath = file.outputFilePath!
                          .substring(0, file.outputFilePath!.lastIndexOf('/'));
                      launchUrl(Uri.parse('file://$dirPath'));
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () {
                      ShareHelper.shareXFiles(
                        [XFile(file.outputFilePath!)],
                        context: context,
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}
