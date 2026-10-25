import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

export 'widgets/widgets.dart';

/// The Home tab (DESIGN.md sections 2 and 4): the mark and the lock-now
/// button, two big tiles (Lock, Open), then the people. Every person comes
/// from [ChatGeneralDataListCubit]; trust comes from its verified flags.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.onPastedText});

  /// Opens a pasted Fuzzzy Ink link the way a tapped link opens; answers
  /// false when the text is not one ([FuzzyLinkHandler.openPastedText]).
  final bool Function(String text) onPastedText;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatGeneralDataListCubit, ChatGeneralDataListState>(
      builder: (context, state) {
        final people = state.chatList ?? const <ChatGeneralData>[];
        final isLoaded = state.status.isSuccess;

        return ColoredBox(
          color: context.fuzzzyColors.ground,
          child: SafeArea(
            bottom: false,
            child: CustomScrollView(
              key: const Key('home.scroll'),
              slivers: [
                const SliverToBoxAdapter(child: HomeHeader()),
                SliverToBoxAdapter(
                  child: HomeActionTiles(
                    onLock: () => showLockWhoSheet(
                      context,
                      people: people,
                      unverifiedChatIds: state.unverifiedChatIds,
                    ),
                    onOpen: () => showOpenSheet(
                      context,
                      onPastedText: onPastedText,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: HomeSectionHeader(
                    count: isLoaded ? people.length : null,
                    onAdd: isLoaded && people.isNotEmpty
                        ? () => showAddPersonSheet(context)
                        : null,
                  ),
                ),
                ..._content(context, state, people),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _content(
    BuildContext context,
    ChatGeneralDataListState state,
    List<ChatGeneralData> people,
  ) {
    switch (state.status) {
      case StateStatus.initial:
      case StateStatus.loading:
        return const [SliverToBoxAdapter(child: HomeLoadingRows())];
      case StateStatus.failed:
        return const [SliverToBoxAdapter(child: HomeLoadError())];
      case StateStatus.success:
        if (people.isEmpty) {
          return const [
            SliverFillRemaining(hasScrollBody: false, child: HomeEmptyState()),
          ];
        }
        return [
          const SliverToBoxAdapter(child: HomeListTop()),
          SliverList.builder(
            itemCount: people.length,
            itemBuilder: (context, index) => _personRow(
              context,
              people[index],
              state.unverifiedChatIds,
            ),
          ),
          SliverToBoxAdapter(
            child: AddPersonRow(onTap: () => showAddPersonSheet(context)),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: context.fuzzzySpace.xl),
          ),
        ];
    }
  }

  Widget _personRow(
    BuildContext context,
    ChatGeneralData chat,
    Set<String> unverifiedChatIds,
  ) {
    return PersonRow(
      key: ValueKey(chat.chatId),
      qaId: chat.chatId,
      name: chat.chatName,
      trust: trustOf(chat, unverifiedChatIds),
      onTap: () => openPerson(context, chat),
      onLongPress: () => showChatDeletionDialog(
        context,
        chatId: chat.chatId,
        chatName: chat.chatName,
      ),
    );
  }

  /// A waiting invite, a connected and checked person, or a connected one
  /// whose numbers were not compared (or could not be read).
  static PersonTrust trustOf(
    ChatGeneralData chat,
    Set<String> unverifiedChatIds,
  ) {
    if (chat.setupStatus == ChatSetupStatus.invited) return PersonTrust.waiting;
    return unverifiedChatIds.contains(chat.chatId)
        ? PersonTrust.notChecked
        : PersonTrust.checked;
  }

  /// A person's page. Until the person page of the next phase exists, a
  /// waiting person opens their invite and a connected one their chat (where
  /// locking, opening and history live today).
  static void openPerson(BuildContext context, ChatGeneralData chat) {
    if (chat.setupStatus == ChatSetupStatus.invited) {
      context.push(
        AppRouter.chatInvitation,
        extra: ChatInvitationPagePayload(
          chatName: chat.chatName,
          chatId: chat.chatId,
        ),
      );
      return;
    }
    context.push(
      AppRouter.chatConnected,
      extra: ConnectedChatPagePayload(chatGeneralData: chat),
    );
  }
}
