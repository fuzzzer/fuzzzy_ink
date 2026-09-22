import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

Future<void> showChatArchiveExportDialog(
  BuildContext context, {
  required String chatId,
  required String chatName,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return _ChatArchiveExportDialog(
        chatId: chatId,
        chatName: chatName,
      );
    },
  );
}

class _ChatArchiveExportDialog extends StatefulWidget {
  final String chatId;
  final String chatName;

  const _ChatArchiveExportDialog({
    required this.chatId,
    required this.chatName,
  });

  @override
  State<_ChatArchiveExportDialog> createState() =>
      _ChatArchiveExportDialogState();
}

class _ChatArchiveExportDialogState extends State<_ChatArchiveExportDialog> {
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  late final ChatArchiveExportCubit _exportCubit;

  /// Where the sealed archive is written: the path the user picked in the
  /// system save dialog on desktop, a temp file handed to the share sheet on
  /// Android and iOS.
  late String _outputPath;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
    _exportCubit = ChatArchiveExportCubit(
      chatArchiveRepository: sl.get<ChatArchiveRepository>(),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _exportCubit.close();
    super.dispose();
  }

  bool _isValid() {
    final password = _passwordController.text;
    if (password.isEmpty) return false;

    final service = sl.get<PasswordStrengthService>();
    final strength = service.assess(password);
    return strength.level == PasswordStrengthLevel.good ||
        strength.level == PasswordStrengthLevel.strong;
  }

  String get _defaultFileName {
    final date = DateTime.now().toIso8601String().substring(0, 10);
    return 'fuzzzy_seal_archive_$date.$fuzzedFileIdentificator';
  }

  Future<void> _onExport(FuzzzySealLocalizations localizations) async {
    final String? outputPath;
    if (Platform.isAndroid || Platform.isIOS) {
      final dir = await getTemporaryDirectory();
      outputPath = path.join(dir.path, _defaultFileName);
    } else {
      outputPath = await FilePicker.platform.saveFile(
        dialogTitle: localizations.exportChatArchive,
        fileName: _defaultFileName,
      );
    }
    if (outputPath == null) return;

    _outputPath = outputPath;
    await _exportCubit.exportChat(
      chatId: widget.chatId,
      chatName: widget.chatName,
      password: _passwordController.text,
      outputPath: outputPath,
    );
  }

  Future<void> _onExported(FuzzzySealLocalizations localizations) async {
    final outputPath = _outputPath;

    if (Platform.isAndroid || Platform.isIOS) {
      await DeviceFileInteractor.shareFile(outputPath, context: context);
      final file = File(outputPath);
      if (file.existsSync()) file.deleteSync();
    }

    if (!mounted) return;
    FuzzzyToast.show(
      context,
      message: localizations.exportChatArchiveDone,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzySealLocalizations;

    return BlocConsumer<ChatArchiveExportCubit, ChatArchiveExportState>(
      bloc: _exportCubit,
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status.isSuccess) {
          _onExported(localizations);
        } else if (state.status.isFailed) {
          FuzzzyToast.show(
            context,
            message: state.failureType!.toUiMessage(localizations),
          );
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final isLoading = state.status.isLoading;

        return PopScope(
          canPop: !isLoading,
          child: AlertDialog(
            title: Text(localizations.exportChatArchive),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(localizations.exportChatArchiveDescription),
                const SizedBox(height: 24),
                FuzzzyTextField(
                  controller: _passwordController,
                  label: localizations.exportChatArchivePassword,
                  obscure: !_isPasswordVisible,
                  autofocus: true,
                  suffix: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: context.fuzzzyColors.inkMute,
                    ),
                    onPressed: () => setState(
                      () => _isPasswordVisible = !_isPasswordVisible,
                    ),
                  ),
                ),
                if (_passwordController.text.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  PasswordStrengthIndicator(
                    password: _passwordController.text,
                  ),
                ],
                if (isLoading) ...[
                  const SizedBox(height: 24),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: context.fuzzzyColors.focus,
                ),
                child: Text(
                  localizations.cancel,
                ),
              ),
              TextButton(
                onPressed: _isValid() && !isLoading
                    ? () => _onExport(localizations)
                    : null,
                style: TextButton.styleFrom(
                  foregroundColor: context.fuzzzyColors.focus,
                ),
                child: Text(
                  localizations.export,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
