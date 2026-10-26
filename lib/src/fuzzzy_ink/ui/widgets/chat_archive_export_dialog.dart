import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:path/path.dart' as path;

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

/// The archive's file name: `fuzzzy_ink_archive_<date>.fuzz`.
String chatArchiveFileName() {
  final date = DateTime.now().toIso8601String().substring(0, 10);
  return 'fuzzzy_ink_archive_$date.$fuzzedFileIdentificator';
}

/// Where a sealed archive is written: on a computer the path the user picks
/// in the system save dialog; on Android and iOS a copy in the app's hand-off
/// folder, given to the system save dialog by [handChatArchiveToUser] and
/// wiped right after. Null when the user cancelled.
Future<String?> chooseChatArchiveOutput(String dialogTitle) async {
  if (Platform.isAndroid || Platform.isIOS) {
    return sl.get<UserFileStore>().newHandoffPath(chatArchiveFileName());
  }
  return FilePicker.platform.saveFile(
    dialogTitle: dialogTitle,
    fileName: chatArchiveFileName(),
  );
}

/// On a phone, gives the archive at [outputPath] to the system save dialog
/// and wipes the app's copy; on a computer it is already where the user
/// chose. True once the user has it; a failure is toasted.
Future<bool> handChatArchiveToUser(
  BuildContext context, {
  required String outputPath,
  required String dialogTitle,
}) async {
  if (!(Platform.isAndroid || Platform.isIOS)) return true;
  final store = sl.get<UserFileStore>();
  try {
    return await DeviceFileInteractor.saveFile(
      outputPath,
      fileName: path.basename(outputPath),
      store: store,
      dialogTitle: dialogTitle,
      context: context,
    );
  } catch (error) {
    logger.w('ARCHIVE EXPORT: could not save: $error');
    if (context.mounted) {
      FuzzzyToast.show(
        context,
        message: context.fuzzzyInkLocalizations.couldNotSaveFile,
      );
    }
    return false;
  } finally {
    await store.wipe(outputPath);
  }
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
  /// system save dialog on a computer; on Android and iOS a copy in the
  /// app's hand-off folder, given to the system save dialog (iOS: the share
  /// sheet's "Save to Files") and wiped right after.
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

  Future<void> _onExport(FuzzzyInkLocalizations localizations) async {
    final outputPath =
        await chooseChatArchiveOutput(localizations.exportChatArchive);
    if (outputPath == null) return;

    _outputPath = outputPath;
    await _exportCubit.exportChat(
      chatId: widget.chatId,
      chatName: widget.chatName,
      password: _passwordController.text,
      outputPath: outputPath,
    );
  }

  Future<void> _onExported(FuzzzyInkLocalizations localizations) async {
    final saved = await handChatArchiveToUser(
      context,
      outputPath: _outputPath,
      dialogTitle: localizations.exportChatArchive,
    );
    if (!mounted) return;
    if (!saved) {
      Navigator.of(context).pop();
      return;
    }
    FuzzzyToast.show(
      context,
      message: localizations.exportChatArchiveDone,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;

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
                  PasswordMeter(
                    password: _passwordController.text,
                    qaId: 'exportArchive',
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
