import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

export 'widgets/widgets.dart';

/// A person (DESIGN.md section 4.9, prototype `person`): the door to their
/// history. Waiting for their reply, it shows the waiting card; connected,
/// the trust chip or the "Not checked yet" banner, Lock and Open, and the
/// history (All · Locked · Opened) grouped by day, rows never showing the
/// secret. Replaces the old chat page as the person's main view.
///
/// The route is [AppRouter.person] with `?chat=<chat id>`; `&new=<row id>`
/// lets the row just added glow once ([location]).
class PersonPage extends StatelessWidget {
  const PersonPage({
    super.key,
    required this.chatId,
    this.newMessageId,
    this.justChecked = false,
  });

  final String chatId;

  /// The history row that was just added (it glows once).
  final int? newMessageId;

  /// Arriving from "Checked": the chip rises where the banner was.
  final bool justChecked;

  /// Where a person's page is: `/person?chat=<id>[&new=<row id>]`.
  static String location(
    String chatId, {
    int? newMessageId,
    bool justChecked = false,
  }) {
    return Uri(
      path: AppRouter.person,
      queryParameters: {
        'chat': chatId,
        if (newMessageId != null) 'new': '$newMessageId',
        if (justChecked) 'checked': '1',
      },
    ).toString();
  }

  /// The page the router builds from `?chat=…` (or a chat id or chat as
  /// `extra`).
  factory PersonPage.fromState(GoRouterState state) {
    final query = state.uri.queryParameters;
    final extra = state.extra;
    final chatId = query['chat'] ??
        switch (extra) {
          final String id => id,
          final ChatGeneralData chat => chat.chatId,
          _ => '',
        };
    return PersonPage(
      chatId: chatId,
      newMessageId: int.tryParse(query['new'] ?? ''),
      justChecked: query['checked'] == '1',
    );
  }

  /// Home with this person's page on top: where "Done" and "Later" lead at
  /// the end of a flow.
  static void goTo(
    BuildContext context,
    String chatId, {
    int? newMessageId,
    bool justChecked = false,
  }) {
    final router = GoRouter.of(context);
    router.go(AppRouter.home);
    router.push(
      location(chatId, newMessageId: newMessageId, justChecked: justChecked),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ConnectedChatCubit>(
      create: (_) => ConnectedChatCubit(
        chatId: chatId,
        messageDataRepository: sl.get<MessageDataRepository>(),
        cryptoCoreService: sl.get<CryptoCoreService>(),
        messagesPerPage: 30,
      )..loadInitialMessages(),
      child: ProvidedPersonPage(
        chatId: chatId,
        newMessageId: newMessageId,
        justChecked: justChecked,
      ),
    );
  }
}

/// Which rows the history shows.
enum HistoryFilter { all, locked, opened }

class ProvidedPersonPage extends StatefulWidget {
  const ProvidedPersonPage({
    super.key,
    required this.chatId,
    this.newMessageId,
    this.justChecked = false,
    this.fileSizeOf,
  });

  final String chatId;
  final int? newMessageId;
  final bool justChecked;

  /// The kept file's size in bytes; tests replace the file system.
  final Future<int?> Function(MessageData message)? fileSizeOf;

  @override
  State<ProvidedPersonPage> createState() => _ProvidedPersonPageState();
}

class _ProvidedPersonPageState extends State<ProvidedPersonPage> {
  final _scroll = ScrollController();
  HistoryFilter _filter = HistoryFilter.all;
  int? _highlightId;
  late bool _holdBanner = widget.justChecked;
  final Map<int, String?> _sizes = {};

  /// The rows last shown, kept while a reload runs so nothing flashes.
  List<MessageData> _shown = const [];

  @override
  void initState() {
    super.initState();
    // The row Lock or Open just wrote, when they landed here from Home.
    _highlightId = widget.newMessageId ?? RecentHistoryRow.take(widget.chatId);
    _scroll.addListener(_onScroll);
    if (_holdBanner) {
      // The chip rises where the banner was (micro-interaction 7).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _holdBanner = false);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels < position.maxScrollExtent - 240) return;
    final cubit = context.read<ConnectedChatCubit>();
    if (cubit.state.status.isLoading || cubit.state.hasFetchedAllMessages) {
      return;
    }
    cubit.loadOlderMessages();
  }

  /// Runs a flow that may add rows (Lock, Open), then reads the history
  /// again; the row the flow wrote ([RecentHistoryRow]) glows once, or else
  /// any row that was not there before.
  Future<void> _runAndReload(Future<void> Function() flow) async {
    final cubit = context.read<ConnectedChatCubit>();
    final known = {for (final message in cubit.state.messages) message.id};
    await flow();
    if (!mounted) return;
    await cubit.reloadMessages();
    if (!mounted) return;
    final marked = RecentHistoryRow.take(widget.chatId);
    final added = [
      for (final message in cubit.state.messages)
        if (!known.contains(message.id)) message.id,
    ];
    final glow = marked ??
        (added.isEmpty ? null : added.reduce((a, b) => a > b ? a : b));
    if (glow != null) setState(() => _highlightId = glow);
  }

  /// Lock for this person: straight to "What?"; Done comes back here.
  Future<void> _lockFor(ChatGeneralData chat) {
    return _runAndReload(
      () => context.push(
        AppRouter.lockFor,
        extra: LockPagePayload(chat: chat, returnsToPerson: true),
      ),
    );
  }

  /// Open what they sent; Done comes back here.
  Future<void> _openFrom() {
    return _runAndReload(
      () => context.push(
        AppRouter.open,
        extra: const OpenPagePayload(returnsToPerson: true),
      ),
    );
  }

  Future<void> _checkNumbers(ChatGeneralData chat) async {
    await context.push(AppRouter.chatVerify, extra: chat);
  }

  Future<void> _gotReply(ChatGeneralData chat) async {
    final reply = await showOpenReplySheet(context);
    if (reply == null || !mounted) return;
    await context.push(
      AppRouter.chatInvitation,
      extra: ChatInvitationPagePayload(
        chatName: chat.chatName,
        chatId: chat.chatId,
        prefillAcceptanceContent: reply,
      ),
    );
  }

  void _openMenu(ChatGeneralData chat, PersonTrust trust) {
    showPersonMenuSheet(
      context,
      chat: chat,
      trust: trust,
      onCheckNumbers: () => _checkNumbers(chat),
      onSendReplyAgain: () =>
          shareReplyOf(context, chatId: chat.chatId, name: chat.chatName),
      onShareInviteAgain: () =>
          shareInviteOf(context, chatId: chat.chatId, name: chat.chatName),
      onSaveHistory: () => showHistoryExportSheet(context, chat: chat),
      onRemove: () => removePerson(context, chat),
    );
  }

  void _openItem(ChatGeneralData chat, MessageData message) {
    context.push(
      AppRouter.personItem,
      extra: HistoryItemPagePayload(
        chat: chat,
        message: message,
        fileSize: _sizes[message.id],
      ),
    );
  }

  String? _sizeOf(MessageData message) {
    if (!message.type.isFile) return null;
    if (_sizes.containsKey(message.id)) return _sizes[message.id];
    _sizes[message.id] = null;
    final read = widget.fileSizeOf ?? _readFileSize;
    unawaited(
      read(message).then((bytes) {
        if (!mounted || bytes == null) return;
        setState(() => _sizes[message.id] = HistoryFormat.fileSize(bytes));
      }),
    );
    return null;
  }

  static Future<int?> _readFileSize(MessageData message) async {
    try {
      final store = sl.get<UserFileStore>();
      return await File(store.resolve(message.encryptedMessage)).length();
    } on Object {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;

    return BlocBuilder<ChatGeneralDataListCubit, ChatGeneralDataListState>(
      builder: (context, listState) {
        final chat = listState.chatList
            ?.firstWhereOrNull((chat) => chat.chatId == widget.chatId);

        if (chat == null) {
          return InkFlowScaffold(
            qaId: 'person',
            headerLine: true,
            children: [
              if (!listState.status.isSuccess) const HistoryLoadingRows(),
            ],
          );
        }

        final trust = HomePage.trustOf(chat, listState.unverifiedChatIds);
        final initial = chat.chatName.trim().isEmpty
            ? '?'
            : chat.chatName.trim().characters.first.toUpperCase();

        return Scaffold(
          key: const Key('screen.person'),
          backgroundColor: colors.ground,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkFlowHeader(
                  qaId: 'person',
                  title: chat.chatName,
                  line: true,
                  leading: ExcludeSemantics(
                    child: FuzzzyAvatar(
                      initials: initial,
                    ),
                  ),
                  actions: [
                    FuzzzyIconButton(
                      qaId: 'person.more',
                      icon: const Icon(Icons.more_horiz),
                      semanticLabel: context.fuzzzyInkLocalizations
                          .personMoreFor(chat.chatName),
                      onPressed: () => _openMenu(chat, trust),
                    ),
                  ],
                ),
                Expanded(
                  child: trust == PersonTrust.waiting
                      ? _waiting(context, chat)
                      : _connected(context, chat, trust),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _waiting(BuildContext context, ChatGeneralData chat) {
    final side = context.fuzzzySpace.l + context.fuzzzySpace.xs;
    return ListView(
      key: const Key('person.scroll'),
      padding: EdgeInsets.fromLTRB(side, context.fuzzzySpace.l, side, side),
      children: [
        WaitingPersonCard(
          name: chat.chatName,
          onShareInvite: () => shareInviteOf(
            context,
            chatId: chat.chatId,
            name: chat.chatName,
          ),
          onGotReply: () => _gotReply(chat),
        ),
      ],
    );
  }

  Widget _connected(
    BuildContext context,
    ChatGeneralData chat,
    PersonTrust trust,
  ) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final side = space.l + space.xs;
    final showsBanner = trust == PersonTrust.notChecked || _holdBanner;

    return BlocBuilder<ConnectedChatCubit, ConnectedChatState>(
      builder: (context, state) {
        if (state.status.isSuccess || state.messages.isNotEmpty) {
          _shown = _unique(state.messages);
        }
        final rows = [
          for (final message in _shown)
            if (switch (_filter) {
              HistoryFilter.all => true,
              HistoryFilter.locked => message.isSent,
              HistoryFilter.opened => !message.isSent,
            })
              message,
        ];
        final isFirstLoad = _shown.isEmpty &&
            (state.status.isLoading || state.status == StateStatus.initial);
        final failed = state.status.isFailed && _shown.isEmpty;

        return CustomScrollView(
          key: const Key('person.scroll'),
          controller: _scroll,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, space.m, side, 0),
              sliver: SliverList.list(
                children: [
                  ChipSwap(
                    child: showsBanner
                        ? InkNotice(
                            key: const ValueKey('banner'),
                            kind: InkNoticeKind.warning,
                            lead: localizations.personNotCheckedLead,
                            text: localizations.personNotCheckedAction,
                            onTap: () => _checkNumbers(chat),
                            qaId: 'person.notChecked',
                          )
                        : Align(
                            key: const ValueKey('chip'),
                            alignment: AlignmentDirectional.centerStart,
                            child: PersonTrustChip(
                              trust: trust,
                              qaId: 'person.trust',
                            ),
                          ),
                  ),
                  SizedBox(height: space.m),
                  Row(
                    children: [
                      Expanded(
                        child: FuzzzyButton(
                          qaId: 'person.lock',
                          label: localizations.homeLockTitle,
                          icon: const Icon(Icons.lock_outline),
                          onPressed: () => _lockFor(chat),
                        ),
                      ),
                      SizedBox(width: space.s + space.xs / 2),
                      Expanded(
                        child: FuzzzyButton(
                          qaId: 'person.open',
                          label: localizations.homeOpenTitle,
                          icon: const Icon(Icons.lock_open_outlined),
                          variant: FuzzzyButtonVariant.secondary,
                          onPressed: _openFrom,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: space.l),
                  FuzzzySegmentedControl(
                    qaId: 'person.filter',
                    segments: [
                      localizations.historyFilterAll,
                      localizations.historyFilterLocked,
                      localizations.historyFilterOpened,
                    ],
                    selectedIndex: _filter.index,
                    onChanged: (index) =>
                        setState(() => _filter = HistoryFilter.values[index]),
                  ),
                ],
              ),
            ),
            if (isFirstLoad)
              const SliverToBoxAdapter(child: HistoryLoadingRows())
            else if (failed)
              SliverToBoxAdapter(
                child: HistoryLoadError(
                  onRetry: () => context
                      .read<ConnectedChatCubit>()
                      .loadCurrentMessagesPage(),
                ),
              )
            else if (rows.isEmpty)
              SliverToBoxAdapter(child: HistoryEmpty(filter: _filter))
            else
              ..._days(context, chat, rows),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: space.xl),
                child: const HistoryFooter(),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _days(
    BuildContext context,
    ChatGeneralData chat,
    List<MessageData> rows,
  ) {
    final slivers = <Widget>[];
    DateTime? day;
    var group = <MessageData>[];

    void flush() {
      if (group.isEmpty) return;
      final items = group;
      slivers
        ..add(
          SliverToBoxAdapter(
            child: HistoryDayLabel(
              HistoryFormat.dayLabel(context, items.first.sentAt),
            ),
          ),
        )
        ..add(
          SliverList.list(
            children: [
              for (final message in items)
                HistoryRow(
                  key: ValueKey(message.id),
                  qaId: '${message.id}',
                  direction: message.isSent
                      ? HistoryDirection.locked
                      : HistoryDirection.opened,
                  time: HistoryFormat.timeLabel(context, message.sentAt),
                  fileName: message.type.isFile
                      ? UserFileNames.forDisplay(
                          ChatFileCubit.fileNameOf(message),
                        )
                      : null,
                  fileSize: _sizeOf(message),
                  highlight: message.id == _highlightId,
                  onTap: () => _openItem(chat, message),
                ),
            ],
          ),
        );
      group = [];
    }

    for (final message in rows) {
      final messageDay = HistoryFormat.dayOf(message.sentAt);
      if (day != messageDay) {
        flush();
        day = messageDay;
      }
      group.add(message);
    }
    flush();
    return slivers;
  }

  /// Newest first, each row once (a reload can shift the pages by a row).
  static List<MessageData> _unique(List<MessageData> messages) {
    final seen = <int>{};
    final unique = [
      for (final message in messages)
        if (seen.add(message.id)) message,
    ]..sort((a, b) {
        final byTime = b.sentAt.compareTo(a.sentAt);
        return byTime != 0 ? byTime : b.id.compareTo(a.id);
      });
    return unique;
  }
}
