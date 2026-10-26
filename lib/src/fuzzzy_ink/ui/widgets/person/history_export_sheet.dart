import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// "Save Nino's history": one file, locked with a password that must reach
/// Good, then the phone's save menu (DESIGN.md section 4.13, prototype
/// `export`). The person's whole history goes into one sealed archive
/// ([ChatArchiveExportCubit]); it opens later through Open.
Future<void> showHistoryExportSheet(
  BuildContext context, {
  required ChatGeneralData chat,
  ChatArchiveExportCubit? cubit,
}) {
  return FuzzzyBottomSheet.show<void>(
    context,
    qaId: 'exportHistory',
    builder: (sheetContext) => FuzzzyBottomSheet(
      qaId: 'exportHistory',
      // A password is typed here.
      child: SensitiveScreen(
        child: HistoryExportSheetBody(chat: chat, cubit: cubit),
      ),
    ),
  );
}

/// The sheet's content: title, line, password, meter, Save file.
class HistoryExportSheetBody extends StatefulWidget {
  const HistoryExportSheetBody({super.key, required this.chat, this.cubit});

  final ChatGeneralData chat;

  /// Tests pass one; otherwise the sheet makes its own.
  final ChatArchiveExportCubit? cubit;

  @override
  State<HistoryExportSheetBody> createState() => _HistoryExportSheetBodyState();
}

class _HistoryExportSheetBodyState extends State<HistoryExportSheetBody> {
  final _password = TextEditingController();
  late final ChatArchiveExportCubit _cubit;
  late final bool _ownsCubit;
  bool _isVisible = false;
  late String _outputPath;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ??
        ChatArchiveExportCubit(
          chatArchiveRepository: sl.get<ChatArchiveRepository>(),
        );
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    if (_ownsCubit) _cubit.close();
    super.dispose();
  }

  Future<void> _save() async {
    final localizations = context.fuzzzyInkLocalizations;
    final outputPath =
        await chooseChatArchiveOutput(localizations.personMenuSaveHistory);
    if (outputPath == null || !mounted) return;
    _outputPath = outputPath;
    await _cubit.exportChat(
      chatId: widget.chat.chatId,
      chatName: widget.chat.chatName,
      password: _password.text,
      outputPath: outputPath,
    );
  }

  Future<void> _onExported() async {
    final localizations = context.fuzzzyInkLocalizations;
    final saved = await handChatArchiveToUser(
      context,
      outputPath: _outputPath,
      dialogTitle: localizations.personMenuSaveHistory,
    );
    if (!mounted) return;
    if (saved) {
      showInkToast(context, message: localizations.exportHistorySaved);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final colors = context.fuzzzyColors;
    final type = context.fuzzzyTextStyles;
    final space = context.fuzzzySpace;
    final service = sl.get<PasswordStrengthService>();
    final password = _password.text;

    return BlocConsumer<ChatArchiveExportCubit, ChatArchiveExportState>(
      bloc: _cubit,
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status.isSuccess) {
          _onExported();
        } else if (state.status.isFailed) {
          showInkToast(
            context,
            message: state.failureType!.toUiMessage(localizations),
            kind: FuzzzyToastKind.error,
          );
        }
      },
      builder: (context, state) {
        final isSaving = state.status.isLoading;
        final canSave = !isSaving && service.isStrongEnough(password);

        return PopScope(
          canPop: !isSaving,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  localizations.exportHistoryTitle(widget.chat.chatName),
                  style: type.titleL.copyWith(color: colors.ink),
                ),
              ),
              SizedBox(height: space.xs),
              Text(
                localizations.exportHistoryLine,
                style: type.bodyS.copyWith(color: colors.inkMute),
              ),
              SizedBox(height: space.l),
              GuardedTextField(
                qaId: 'exportHistory.password',
                controller: _password,
                label: localizations.exportHistoryPassword,
                obscure: !_isVisible,
                keyboardType: TextInputType.visiblePassword,
                autofocus: true,
                suffix: FuzzzyIconButton(
                  qaId: 'exportHistory.peek',
                  icon: Icon(
                    _isVisible ? Icons.visibility_off : Icons.visibility,
                  ),
                  semanticLabel: localizations.exportHistoryPassword,
                  onPressed: () => setState(() => _isVisible = !_isVisible),
                ),
              ),
              SizedBox(height: space.m),
              PasswordMeter(password: password, qaId: 'exportHistory'),
              SizedBox(height: space.l),
              FuzzzyButton(
                qaId: 'exportHistory.save',
                label: localizations.exportHistorySave,
                icon: const Icon(Icons.save_alt),
                loading: isSaving,
                onPressed: canSave ? _save : null,
              ),
            ],
          ),
        );
      },
    );
  }
}
