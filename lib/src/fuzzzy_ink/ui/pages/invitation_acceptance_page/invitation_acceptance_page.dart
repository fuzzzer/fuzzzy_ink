import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

export 'components/components.dart';
export 'widgets/widgets.dart';

class InvitationAcceptancePage extends StatelessWidget {
  final String? prefillInvitationContent;

  const InvitationAcceptancePage({
    super.key,
    this.prefillInvitationContent,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<InvitationAcceptanceCubit>(
      create: (context) => InvitationAcceptanceCubit(
        chatGeneralDataListRepository: sl.get<ChatGeneralDataListRepository>(),
        cryptoCoreService: sl.get<CryptoCoreService>(),
      ),
      child: ProvidedInvitationAcceptancePage(
        prefillInvitationContent: prefillInvitationContent,
      ),
    );
  }
}

class ProvidedInvitationAcceptancePage extends StatefulWidget {
  final String? prefillInvitationContent;

  const ProvidedInvitationAcceptancePage({
    super.key,
    this.prefillInvitationContent,
  });

  @override
  State<ProvidedInvitationAcceptancePage> createState() =>
      _ProvidedInvitationAcceptancePageState();
}

class _ProvidedInvitationAcceptancePageState
    extends State<ProvidedInvitationAcceptancePage> {
  final TextEditingController _invitationTextController =
      TextEditingController();
  final TextEditingController _chatNameController = TextEditingController();

  @override
  void initState() {
    if (widget.prefillInvitationContent != null) {
      _invitationTextController.text = widget.prefillInvitationContent!;
    }

    _invitationTextController.addListener(() {
      setState(() {});
    });

    _chatNameController.addListener(() {
      setState(() {});
    });

    super.initState();
  }

  @override
  void dispose() {
    _invitationTextController.dispose();
    _chatNameController.dispose();
    super.dispose();
  }

  void _acceptInvitation() {
    final invitationText = _invitationTextController.text.trim();
    final chatName = _chatNameController.text.trim();
    if (invitationText.isNotEmpty && chatName.isNotEmpty) {
      context.read<InvitationAcceptanceCubit>().acceptInvitation(
            invitationContent: invitationText,
            chatName: chatName,
          );
    } else {
      FuzzzyToast.show(
        context,
        message: FuzzzyInkLocalizations.of(context)
                ?.pleaseProvideInvitationTextAndChatName ??
            '',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;

    return BlocConsumer<InvitationAcceptanceCubit, InvitationAcceptanceState>(
      listener: (context, state) {
        if (state.status.isSuccess && state.generatedAcceptance != null) {
          context.go(
            AppRouter.chatAcceptanceExport,
            extra: AcceptanceExportPagePayload(
              chatGeneralData: state.chatData!,
              hasBackButton: false,
            ),
          );
        } else if (state.status.isFailed) {
          FuzzzyToast.show(
            context,
            message: state.failure?.type.toUiMessage(
                  localizations,
                  customUnknownMessage: FuzzzyInkLocalizations.of(context)
                      ?.failedToAcceptInvitation,
                ) ??
                '',
          );
        }
      },
      builder: (context, state) {
        if (state.status.isLoading) {
          return const FuzzyLoadingPagebuilder();
        }

        return InvitationAcceptanceForm(
          chatNameController: _chatNameController,
          invitationTextController: _invitationTextController,
          onAccept: _acceptInvitation,
        );
      },
    );
  }
}
