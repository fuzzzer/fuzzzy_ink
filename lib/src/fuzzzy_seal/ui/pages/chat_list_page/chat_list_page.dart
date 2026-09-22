import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

export 'widgets/widgets.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProvidedChatListPage();
  }
}

class ProvidedChatListPage extends StatefulWidget {
  const ProvidedChatListPage({super.key});

  @override
  State<ProvidedChatListPage> createState() => _ProvidedChatListPageState();
}

class _ProvidedChatListPageState extends State<ProvidedChatListPage> {
  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzySealLocalizations;

    return FuzzyScaffold(
      hasAutomaticBackButton: false,
      body: BlocBuilder<ChatGeneralDataListCubit, ChatGeneralDataListState>(
        builder: (context, state) {
          return StatusBuilder.buildByStatus(
            status: state.status,
            onInitial: () => const FuzzyLoadingPagebuilder(),
            onLoading: () => const FuzzyLoadingPagebuilder(),
            onSuccess: () => ChatListContent(
              chatGeneralDataList: state.chatList!,
            ),
            onFailure: () => FuzzyScaffold(
              hasAutomaticBackButton: false,
              body: Center(
                child: FuzzzyEmptyState(
                  title:
                      state.failure?.message ?? localizations.failedToLoadChats,
                  message:
                      localizations.unexpectedFailureOccuredPleaseContactUs,
                ),
              ),
            ),
          );
        },
      ),
      actionsRow: Align(
        alignment: Alignment.bottomRight,
        child: FloatingToolbox(
          onNewChatPressed: () {
            context.push(AppRouter.chatCreate);
          },
          onAcceptInvitationPressed: () {
            context.push(AppRouter.chatAccept);
          },
        ),
      ),
    );
  }
}
