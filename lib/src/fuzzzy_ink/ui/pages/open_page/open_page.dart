import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:go_router/go_router.dart';

export 'components/components.dart';
export 'widgets/widgets.dart';

/// Open (DESIGN.md section 4.8): "Open what you got" — Paste it, Choose a
/// file, and links, which come here and wait for Open ("Open the message
/// from {name}?", security review 2026-10-26) — then whatever it was:
/// the opened message or file (private), the password question, or one
/// "can't open" screen. Invites go on to "I got an invite" (straight to
/// "Who sent it?"), replies connect on the invite's page, and a second reply
/// goes to "Someone else may have answered".
class OpenPage extends StatelessWidget {
  const OpenPage({super.key, this.payload = const OpenPagePayload()});

  final OpenPagePayload payload;

  @override
  Widget build(BuildContext context) {
    final request = payload.request;
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) {
            final cubit = OpenFlowCubit(
              cryptoCoreService: sl.get<CryptoCoreService>(),
              chatRepository: sl.get<ChatGeneralDataListRepository>(),
              messageDataRepository: sl.get<MessageDataRepository>(),
              userFileStore: sl.get<UserFileStore>(),
              receiveQueue:
                  context.read<FileProcessingCubit<FileDecryptionOption>>(),
            );
            if (request != null) cubit.open(request);
            return cubit;
          },
        ),
        // Opens a kept file again for Open and Save; wipes every plain copy
        // it made when Open closes.
        BlocProvider(
          create: (_) => ChatFileCubit(
            cryptoCoreService: sl.get<CryptoCoreService>(),
            userFileStore: sl.get<UserFileStore>(),
          ),
        ),
      ],
      child: OpenFlowView(returnsToPerson: payload.returnsToPerson),
    );
  }
}

/// The flow's screens, one per phase.
class OpenFlowView extends StatelessWidget {
  const OpenFlowView({super.key, this.returnsToPerson = false});

  final bool returnsToPerson;

  void _followRoute(BuildContext context, OpenRoute route) {
    final cubit = context.read<OpenFlowCubit>();
    switch (route) {
      case OpenRouteInvite(:final invitation):
        cubit.routeTaken();
        context.pushReplacement(AppRouter.chatAccept, extra: invitation);
      case OpenRouteReply(:final chat, :final acceptance, :final arrived):
        cubit.routeTaken();
        context.pushReplacement(
          AppRouter.chatInvitation,
          extra: ChatInvitationPagePayload(
            chatName: chat.chatName,
            chatId: chat.chatId,
            prefillAcceptanceContent: acceptance,
            confirmReply: arrived,
          ),
        );
      case OpenRouteSecondReply(:final chat):
        cubit.routeTaken();
        // "Someone else may have answered": Check numbers or Remove.
        context.pushReplacement(AppRouter.personAnsweredTwice, extra: chat);
    }
  }

  void _done(BuildContext context, OpenFlowState state) {
    final chat = state.chat;
    if (chat == null) {
      context.goBack();
      return;
    }
    landOnPerson(
      context,
      chat: chat,
      returnsToPerson: returnsToPerson,
      historyRowId: state.historyRowId,
      toast: state.historyRowId == null
          ? null
          : context.fuzzzyInkLocalizations.openedInHistoryNow(chat.chatName),
      castMoment: FuzzzyCastMoment.opened,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OpenFlowCubit, OpenFlowState>(
      listenWhen: (previous, current) =>
          (current.route != null && previous.route != current.route) ||
          (current.phase == OpenPhase.openedFile &&
              previous.phase != OpenPhase.openedFile),
      listener: (context, state) {
        final route = state.route;
        if (route != null) return _followRoute(context, route);
        // A file finished opening: one light buzz.
        InkHaptics.light();
      },
      builder: (context, state) {
        final cubit = context.read<OpenFlowCubit>();
        final localizations = context.fuzzzyInkLocalizations;
        switch (state.phase) {
          case OpenPhase.choose:
            return OpenChooseView(onClose: context.goBack);
          case OpenPhase.reading:
            return const OpenReadingView();
          case OpenPhase.working:
            return PopScope(
              canPop: false,
              child: FlowWorkingView(
                qaId: 'open.working',
                title: localizations.workingOpening,
                icon: CupertinoIcons.lock_open,
                fileName: state.workingName ?? '',
                progress: state.progress,
                onCancel: cubit.cancel,
              ),
            );
          case OpenPhase.password:
            return SensitiveScreen(
              child: OpenPasswordView(onBack: cubit.startOver),
            );
          case OpenPhase.confirmMessage:
            final chat = state.chat;
            if (chat == null) return const OpenReadingView();
            return OpenConfirmView(
              chat: chat,
              isFile: state.pendingFilePath != null,
              onOpen: cubit.confirmOpen,
              onNotNow: context.goBack,
            );
          case OpenPhase.openedText:
            return SensitiveScreen(
              child: OpenedTextView(
                state: state,
                onDone: () => _done(context, state),
              ),
            );
          case OpenPhase.openedFile:
            return SensitiveScreen(
              child: OpenedFileView(
                state: state,
                onDone: () => _done(context, cubit.state),
              ),
            );
          case OpenPhase.problem:
            return OpenProblemView(
              problem: state.problem ?? OpenProblem.failed,
              chat: state.chat,
              onBack: cubit.startOver,
              onGoToPerson: (chat) => landOnPerson(
                context,
                chat: chat,
                returnsToPerson: returnsToPerson,
              ),
            );
        }
      },
    );
  }
}
