import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Unfuzzes the received file row [message] into a short-lived copy while a
/// progress dialog (with Cancel) is shown; answers the copy's path, or `null`
/// after a toast when it failed or was cancelled. The caller wipes the copy
/// through [ChatFileCubit].
Future<String?> unfuzzChatFile(
  BuildContext context,
  MessageData message,
) async {
  final cubit = context.read<ChatFileCubit>();
  final localizations = context.fuzzzyInkLocalizations;
  final navigator = Navigator.of(context, rootNavigator: true);

  final dialog = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: const _UnfuzzProgressDialog(),
    ),
  );

  final copy = await cubit.unfuzz(message);
  navigator.pop();
  await dialog;

  if (copy == null && context.mounted) {
    final failure = cubit.state.failure;
    if (failure != null) {
      FuzzzyToast.show(
        context,
        message: failure.type.toUiMessage(
          localizations,
          customUnknownMessage: localizations.couldNotOpenFile,
        ),
      );
    }
  }
  return copy;
}

class _UnfuzzProgressDialog extends StatelessWidget {
  const _UnfuzzProgressDialog();

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;

    return AlertDialog(
      content: BlocBuilder<ChatFileCubit, ChatFileState>(
        builder: (context, state) => Row(
          children: [
            FuzzzyProgressRing(
              value: state.progress > 0 ? state.progress : null,
              qaId: 'chatFile.unfuzzProgress',
            ),
            SizedBox(width: space.m),
            Expanded(child: Text(localizations.unfuzzingFile)),
          ],
        ),
      ),
      actions: [
        FuzzzyButton(
          label: localizations.cancel,
          variant: FuzzzyButtonVariant.ghost,
          onPressed: () => context.read<ChatFileCubit>().cancel(),
          qaId: 'chatFile.cancelUnfuzz',
        ),
      ],
    );
  }
}
