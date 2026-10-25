import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:path/path.dart' as path;

class BasicEncryptionContent extends StatelessWidget {
  final TextEditingController keyController;
  final TextEditingController textController;
  final String resultText;

  /// Sealed output can be copied; an opened (decrypted) result is shown but
  /// never selectable or copyable (copy_guard).
  final bool isResultSealed;
  final List<String>? selectedFilePaths;
  final SelectedFilesCallback onFilesSelected;
  final VoidCallback onProcessFiles;
  final ValueChanged<String> onOpenFuzzedFile;

  const BasicEncryptionContent({
    super.key,
    required this.keyController,
    required this.textController,
    required this.resultText,
    required this.isResultSealed,
    required this.selectedFilePaths,
    required this.onFilesSelected,
    required this.onProcessFiles,
    required this.onOpenFuzzedFile,
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
                    Text(resultText),
                    if (isResultSealed) ...[
                      const SizedBox(height: 8),
                      FuzzzyButton(
                        label: context.fuzzzyInkLocalizations.copy,
                        icon: const Icon(Icons.copy),
                        qaId: 'basics.copy_sealed',
                        onPressed: () => CopyGuard.copy(
                          context,
                          text: resultText,
                          content: CopyContent.sealedText,
                        ),
                      ),
                    ],
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
                    _buildProcessedFilesList(state, context, isPlain: false),
              ),
              BlocBuilder<CustomFileProcessingCubit<FileDecryptionOption>,
                  CustomFileProcessingState>(
                builder: (context, state) =>
                    _buildProcessedFilesList(state, context, isPlain: true),
              ),
              BasicsFuzzedFilesList(onOpen: onOpenFuzzedFile),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  /// This session's results. A fuzzed file is listed with the kept ones
  /// below; an unfuzzed one ([isPlain]) is a short-lived copy: Open shows it
  /// in the app, Save gives it to the save dialog and wipes it, and every
  /// copy is wiped when the page closes.
  Widget _buildProcessedFilesList(
    CustomFileProcessingState state,
    BuildContext context, {
    required bool isPlain,
  }) {
    if (state.processedFiles.isEmpty && state.currentProcessingFile == null) {
      return const SizedBox.shrink();
    }
    final localizations = context.fuzzzyInkLocalizations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        if (state.currentProcessingFile != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              currentContextLocalization.processingFile(
                path.basename(state.currentProcessingFile!.inputFilePath),
                (state.progress * 100).toStringAsFixed(1),
              ),
            ),
          ),
        ...state.processedFiles.map((file) {
          final plainCopy = isPlain ? file.outputFilePath : null;
          final failure = file.status == FileProcessingStatus.completed
              ? null
              : file.failure?.type.toUiMessage(currentContextLocalization) ??
                  currentContextLocalization.processingFailed;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              UserFileNames.forDisplay(path.basename(file.inputFilePath)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: failure == null ? null : Text(failure, maxLines: 2),
            trailing: plainCopy == null
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FuzzzyIconButton(
                        icon: const Icon(Icons.visibility_rounded),
                        semanticLabel: localizations.open,
                        onPressed: () => _openPlainCopy(context, plainCopy),
                        qaId: 'basics.openPlain',
                      ),
                      FuzzzyIconButton(
                        icon: const Icon(Icons.save_alt_rounded),
                        semanticLabel: localizations.saveFile,
                        onPressed: () => _savePlainCopy(
                          context,
                          cubit: context.read<
                              CustomFileProcessingCubit<
                                  FileDecryptionOption>>(),
                          plainCopy: plainCopy,
                        ),
                        qaId: 'basics.savePlain',
                      ),
                    ],
                  ),
          );
        }),
      ],
    );
  }

  Future<void> _openPlainCopy(BuildContext context, String plainCopy) {
    final cubit =
        context.read<CustomFileProcessingCubit<FileDecryptionOption>>();
    // The viewer is a route of its own: it gets the cubit, not this context.
    return PlainFileViewerPage.show(
      context,
      fileName: path.basename(plainCopy),
      filePath: plainCopy,
      onSave: (viewerContext) =>
          _savePlainCopy(viewerContext, cubit: cubit, plainCopy: plainCopy),
    );
  }

  Future<void> _savePlainCopy(
    BuildContext context, {
    required CustomFileProcessingCubit<FileDecryptionOption> cubit,
    required String plainCopy,
  }) async {
    final saved = await saveFileForUser(
      context,
      filePath: plainCopy,
      fileName: path.basename(plainCopy),
      store: cubit.userFileStore,
    );
    if (saved) await cubit.wipePlainCopy(plainCopy);
  }
}
