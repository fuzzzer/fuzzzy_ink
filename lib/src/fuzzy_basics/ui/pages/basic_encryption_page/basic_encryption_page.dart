import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

export 'components/components.dart';
export 'widgets/widgets.dart';

class BasicEncryptionPage extends StatelessWidget {
  const BasicEncryptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<BasicEncryptionCubit>(
          create: (context) => BasicEncryptionCubit(
            cryptoCoreService: sl.get<CryptoCoreService>(),
          ),
        ),
        BlocProvider<CustomFileProcessingCubit<FileEncryptionOption>>(
          create: (context) => CustomFileProcessingCubit(
            cryptoCoreService: sl.get<CryptoCoreService>(),
            processingOption: const FileEncryptionOption(),
          ),
        ),
        BlocProvider<CustomFileProcessingCubit<FileDecryptionOption>>(
          create: (context) => CustomFileProcessingCubit(
            cryptoCoreService: sl.get<CryptoCoreService>(),
            processingOption: const FileDecryptionOption(),
          ),
        ),
      ],
      child: const _ProvidedBasicEncryptionPage(),
    );
  }
}

class _ProvidedBasicEncryptionPage extends StatefulWidget {
  const _ProvidedBasicEncryptionPage();

  @override
  State<_ProvidedBasicEncryptionPage> createState() =>
      _ProvidedBasicEncryptionPageState();
}

class _ProvidedBasicEncryptionPageState
    extends State<_ProvidedBasicEncryptionPage> {
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _textController = TextEditingController();

  String _resultText = '';
  List<String>? _selectedFilePaths;

  @override
  void initState() {
    super.initState();
    _keyController.addListener(() => setState(() {}));
    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _keyController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _onFilesSelected(List<String> paths) {
    setState(() {
      _selectedFilePaths = paths;
    });
  }

  void _processFiles() {
    final key = _keyController.text;
    if (key.isEmpty) {
      FuzzzyToast.show(
        context,
        message: context.fuzzzySealLocalizations.pleaseEnterAKey,
      );
      return;
    }
    if (_selectedFilePaths?.isNotEmpty != true) {
      FuzzzyToast.show(
        context,
        message: context.fuzzzySealLocalizations.pleaseSelectFilesToProcess,
      );
      return;
    }

    final encryptionCubit =
        context.read<CustomFileProcessingCubit<FileEncryptionOption>>();
    final decryptionCubit =
        context.read<CustomFileProcessingCubit<FileDecryptionOption>>();

    final filesToEncrypt = _selectedFilePaths!
        .where((path) => !path.endsWith(fuzzedFileIdentificator))
        .toList();
    final filesToDecrypt = _selectedFilePaths!
        .where((path) => path.endsWith(fuzzedFileIdentificator))
        .toList();

    if (filesToEncrypt.isNotEmpty) {
      encryptionCubit.addFilesToProcess(
        filePaths: filesToEncrypt,
        customKey: key,
      );
    }
    if (filesToDecrypt.isNotEmpty) {
      decryptionCubit.addFilesToProcess(
        filePaths: filesToDecrypt,
        customKey: key,
      );
    }

    setState(() {
      _selectedFilePaths = null;
    });
  }

  String _localizeFailureMessage(BuildContext context, String? message) {
    if (message == null) {
      return context.fuzzzySealLocalizations.anUnknownErrorOccurred;
    }
    switch (message) {
      case 'textAndKeyCannotBeEmpty':
        return context.fuzzzySealLocalizations.textAndKeyCannotBeEmpty;
      case 'encryptionFailed':
        return context.fuzzzySealLocalizations.encryptionFailed;
      case 'encryptedTextAndKeyCannotBeEmpty':
        return context.fuzzzySealLocalizations.encryptedTextAndKeyCannotBeEmpty;
      case 'decryptionFailedCheckYourKeyOrEncryptedText':
        return context
            .fuzzzySealLocalizations.decryptionFailedCheckYourKeyOrEncryptedText;
      case 'basicsWrongPassword':
        return context.fuzzzySealLocalizations.basicsWrongPassword;
      case 'corruptBlob':
        return context.fuzzzySealLocalizations.corruptBlob;
      default:
        return message;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<BasicEncryptionCubit, BasicEncryptionState>(
          listener: (context, state) {
            if (state.status.isSuccess) {
              setState(() {
                _resultText = state.result ?? '';
              });
            } else if (state.status.isFailed) {
              setState(() {
                _resultText = '';
              });
              FuzzzyToast.show(
                context,
                message:
                    _localizeFailureMessage(context, state.failure?.message),
              );
            }
          },
        ),
        BlocListener<CustomFileProcessingCubit<FileEncryptionOption>,
            CustomFileProcessingState>(
          listener: (context, state) {
            // print encryption $state
          },
        ),
        BlocListener<CustomFileProcessingCubit<FileDecryptionOption>,
            CustomFileProcessingState>(
          listener: (context, state) {
            // print decritpion $state
          },
        ),
      ],
      child: FileDropArea(
        onDropped: _onFilesSelected,
        child: BasicEncryptionContent(
          keyController: _keyController,
          textController: _textController,
          resultText: _resultText,
          selectedFilePaths: _selectedFilePaths,
          onFilesSelected: _onFilesSelected,
          onProcessFiles: _processFiles,
        ),
      ),
    );
  }
}
