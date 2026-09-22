import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

export 'components/components.dart';
export 'widgets/widgets.dart';

class ChatInvitationPage extends StatelessWidget {
  final ChatInvitationPagePayload payload;

  const ChatInvitationPage({
    super.key,
    required this.payload,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<InvitationReaderCubit>(
          create: (context) => InvitationReaderCubit(
            cryptoCoreService: sl.get<CryptoCoreService>(),
          )..generateInvitation(
              chatId: payload.chatId,
            ),
        ),
        BlocProvider<HandshakeCubit>(
          create: (context) => HandshakeCubit(
            cryptoCoreService: sl.get<CryptoCoreService>(),
            chatGeneralDataListRepository:
                sl.get<ChatGeneralDataListRepository>(),
          ),
        ),
      ],
      child: ProvidedChatInvitationPage(
        payload: payload,
      ),
    );
  }
}

class ProvidedChatInvitationPage extends StatefulWidget {
  final ChatInvitationPagePayload payload;

  const ProvidedChatInvitationPage({
    required this.payload,
    super.key,
  });

  @override
  State<ProvidedChatInvitationPage> createState() =>
      _ProvidedChatInvitationPageState();
}

class _ProvidedChatInvitationPageState
    extends State<ProvidedChatInvitationPage> {
  final TextEditingController acceptanceTextController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<InvitationReaderCubit>().generateInvitation(
          chatId: widget.payload.chatId,
        );

    if (widget.payload.prefillAcceptanceContent != null) {
      acceptanceTextController.text = widget.payload.prefillAcceptanceContent!;
    }

    acceptanceTextController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    acceptanceTextController.dispose();
    super.dispose();
  }

  void _importAcceptanceFromText() {
    final acceptanceContent = acceptanceTextController.text.trim();
    if (acceptanceContent.isNotEmpty) {
      context.read<HandshakeCubit>().completeHandshake(
            acceptanceContent: acceptanceContent,
            chatId: widget.payload.chatId,
          );
    } else {
      FuzzzyToast.show(
        context,
        message: FuzzzyInkLocalizations.of(context)
                ?.pleasePasteTheAcceptanceContent ??
            '',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;

    return MultiBlocListener(
      listeners: [
        BlocListener<HandshakeCubit, HandshakeState>(
          listener: (context, state) {
            if (state.status.isSuccess) {
              context.go(
                AppRouter.chatConnected,
                extra: ConnectedChatPagePayload(
                  chatGeneralData: state.chatData!,
                  openSafetyNumber: true,
                ),
              );
            } else if (state.status.isFailed) {
              FuzzzyToast.show(
                context,
                message: state.failure?.type.toUiMessage(
                      localizations,
                      customUnknownMessage:
                          localizations.failedToCompleteHandshake,
                    ) ??
                    localizations.failedToCompleteHandshake,
              );
            }
          },
        ),
      ],
      child: BlocBuilder<InvitationReaderCubit, InvitationReaderState>(
        builder: (context, invitationState) {
          return StatusBuilder.buildByStatus(
            status: invitationState.status,
            onInitial: () => const FuzzyLoadingPagebuilder(),
            onLoading: () => const FuzzyLoadingPagebuilder(),
            onSuccess: () => ChatInvitationContent(
              chatName: widget.payload.chatName,
              invitationContent: invitationState.invitation!.content,
              acceptanceTextController: acceptanceTextController,
              onAccept: _importAcceptanceFromText,
            ),
            onFailure: () => FuzzyScaffold(
              body: Center(
                child: FuzzzyEmptyState(
                  title: invitationState.failure?.message ??
                      localizations.failedToGenerateInvitation,
                  message:
                      localizations.unexpectedFailureOccuredPleaseContactUs,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
