import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

export 'components/components.dart';
export 'widgets/widgets.dart';

/// Lock for a person, or with a password (DESIGN.md sections 4.5–4.7):
/// What (private while typing) → Locking (files) → Locked → Share. "Who's it
/// for?" is the step before, on Home; from a person's page it is skipped.
class LockPage extends StatelessWidget {
  const LockPage({super.key, required this.payload});

  final LockPagePayload payload;

  @override
  Widget build(BuildContext context) {
    final chat = payload.chat;
    final chatId = payload.chatId;
    if (chat == null && chatId != null) {
      return _PersonLoader(chatId: chatId, payload: payload);
    }
    return BlocProvider(
      create: (context) => LockFlowCubit(
        target: chat == null
            ? const LockTarget.password()
            : LockTarget.person(chat),
        cryptoCoreService: sl.get<CryptoCoreService>(),
        messageDataRepository: sl.get<MessageDataRepository>(),
        userFileStore: sl.get<UserFileStore>(),
        passwordStrengthService: sl.get<PasswordStrengthService>(),
        chatFileQueue:
            context.read<FileProcessingCubit<FileEncryptionOption>>(),
      ),
      child: LockFlowView(chat: chat, returnsToPerson: payload.returnsToPerson),
    );
  }
}

/// The flow's screens, one per phase.
class LockFlowView extends StatelessWidget {
  const LockFlowView({
    super.key,
    required this.chat,
    this.returnsToPerson = false,
  });

  final ChatGeneralData? chat;
  final bool returnsToPerson;

  void _done(BuildContext context, LockFlowState state) {
    final chat = this.chat;
    if (chat == null) {
      context.goBack();
      return;
    }
    landOnPerson(
      context,
      chat: chat,
      returnsToPerson: returnsToPerson,
      historyRowId: state.item?.historyRowId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LockFlowCubit, LockFlowState>(
      listenWhen: (previous, current) => previous.phase != current.phase,
      listener: (context, state) {
        // "Lock done": one medium buzz, with or without Fuzzzy Cast; the
        // keeper of the tab the person goes back to does its happy move.
        if (state.phase == LockPhase.locked) {
          InkHaptics.medium();
          CastKeeperCues.cue(CastKeeperCue.locked);
        }
      },
      builder: (context, state) {
        final cubit = context.read<LockFlowCubit>();
        final localizations = context.fuzzzyInkLocalizations;
        switch (state.phase) {
          case LockPhase.what:
            // Private while typing: no screenshots, no copy, no Fuzzz.
            return SensitiveScreen(
              child: LockWhatView(chat: chat, onClose: context.goBack),
            );
          case LockPhase.working:
            return PopScope(
              canPop: false,
              child: FlowWorkingView(
                qaId: 'lock.working',
                title: localizations.workingLocking,
                icon: Icons.lock_outline,
                fileName: state.file?.name ?? '',
                progress: state.progress,
                isPaused: state.isPaused,
                onPause: cubit.pause,
                onResume: cubit.resume,
                onCancel: cubit.cancel,
              ),
            );
          case LockPhase.locked:
            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop) _done(context, state);
              },
              child: LockedView(
                chat: chat,
                state: state,
                onShared: cubit.markShared,
                onDone: () => _done(context, cubit.state),
              ),
            );
        }
      },
    );
  }
}

/// Reads the person when only their id came with the route.
class _PersonLoader extends StatelessWidget {
  const _PersonLoader({required this.chatId, required this.payload});

  final String chatId;
  final LockPagePayload payload;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ChatGeneralData?>(
      future: sl.get<ChatGeneralDataListRepository>().getChatById(chatId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: context.fuzzzyColors.ground,
            body: const Center(child: FuzzzyProgressRing()),
          );
        }
        final chat = snapshot.data;
        if (chat == null || chat.setupStatus != ChatSetupStatus.connected) {
          return FlowScaffold(
            qaId: 'lock.missing',
            onLeading: context.goBack,
            leading: FlowLeading.close,
            children: [
              FlowTitle(
                title: context.fuzzzyInkLocalizations.openErrorNotYoursTitle,
              ),
            ],
          );
        }
        return LockPage(
          payload: LockPagePayload(
            chat: chat,
            returnsToPerson: payload.returnsToPerson,
          ),
        );
      },
    );
  }
}
