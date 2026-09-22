import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

export 'widgets/widgets.dart';

class ChatCreationPage extends StatelessWidget {
  const ChatCreationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ChatCreationCubit>(
      create: (context) => ChatCreationCubit(
        cryptoCoreService: sl.get<CryptoCoreService>(),
        chatGeneralDataListRepository: sl.get<ChatGeneralDataListRepository>(),
      ),
      child: const ProvidedChatCreationPage(),
    );
  }
}

class ProvidedChatCreationPage extends StatefulWidget {
  const ProvidedChatCreationPage({super.key});

  @override
  State<ProvidedChatCreationPage> createState() =>
      _ProvidedChatCreationPageState();
}

class _ProvidedChatCreationPageState extends State<ProvidedChatCreationPage> {
  final TextEditingController _chatNameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _focusNode.requestFocus();
    });

    _chatNameController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _chatNameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _createChat() {
    final chatName = _chatNameController.text.trim();
    if (chatName.isNotEmpty) {
      context.read<ChatCreationCubit>().createChat(chatName: chatName);
    } else {
      FuzzzyToast.show(
        context,
        message:
            FuzzzySealLocalizations.of(context)?.pleaseEnterAChatName ?? '',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzySealLocalizations;

    return BlocConsumer<ChatCreationCubit, ChatCreationState>(
      listener: (context, state) {
        if (state.status.isSuccess && state.generatedChatInvitation != null) {
          context.go(
            AppRouter.chatInvitation,
            extra: ChatInvitationPagePayload(
              chatName: state.chatName!,
              chatId: state.chatId!,
            ),
          );
        } else if (state.status.isFailed) {
          FuzzzyToast.show(
            context,
            message: state.failure?.type.toUiMessage(localizations) ?? '',
          );
        }
      },
      builder: (context, state) {
        if (state.status.isLoading) {
          return const FuzzyLoadingPagebuilder();
        }

        return ChatCreationInitialContent(
          chatNameController: _chatNameController,
          focusNode: _focusNode,
          onCreate: _createChat,
        );
      },
    );
  }
}
