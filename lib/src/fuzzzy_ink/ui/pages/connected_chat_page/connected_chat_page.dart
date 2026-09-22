import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

export 'components/components.dart';
export 'widgets/widgets.dart';

class ConnectedChatPage extends StatelessWidget {
  final ConnectedChatPagePayload payload;

  const ConnectedChatPage({
    required this.payload,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ConnectedChatCubit>(
          create: (context) => ConnectedChatCubit(
            chatId: payload.chatGeneralData.chatId,
            messageDataRepository: sl.get<MessageDataRepository>(),
            cryptoCoreService: sl.get<CryptoCoreService>(),
          )..loadInitialMessages(),
        ),
        BlocProvider<SafetyNumberCubit>(
          create: (context) => SafetyNumberCubit(
            chatId: payload.chatGeneralData.chatId,
            cryptoCoreService: sl.get<CryptoCoreService>(),
          )..load(),
        ),
      ],
      child: ProvidedConnectedChatPage(payload: payload),
    );
  }
}

class ProvidedConnectedChatPage extends StatefulWidget {
  final ConnectedChatPagePayload payload;

  const ProvidedConnectedChatPage({
    required this.payload,
    super.key,
  });

  @override
  State<ProvidedConnectedChatPage> createState() =>
      _ProvidedConnectedChatPageState();
}

/// A failure toasts once, on the transition into `failed`: `actionStatus` is
/// sticky across later page loads, so any other transition must stay silent.
@visibleForTesting
bool shouldToastFailure(
  ConnectedChatState previous,
  ConnectedChatState current,
) {
  return (previous.status != current.status && current.status.isFailed) ||
      (previous.actionStatus != current.actionStatus &&
          current.actionStatus.isFailed);
}

class _ProvidedConnectedChatPageState extends State<ProvidedConnectedChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<String>? selectedFilePaths;

  bool isEncrypting = true;
  late bool _showTutorial;

  @override
  void initState() {
    _showTutorial = !sl.get<PreferencesService>().hasCompletedTutorial;
    _messageController.addListener(_onMessageUpdated);
    initializePagination();
    super.initState();

    // Pre-fill encrypted message from deep link.
    if (widget.payload.prefillEncryptedMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _messageController.text =
            '$fuzzIdentificator${widget.payload.prefillEncryptedMessage}';
      });
    }

    // The safety number sits on top of the chat (back lands here); the
    // header's shield reloads when it pops, as it does from the header.
    if (widget.payload.openSafetyNumber) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openSafetyNumber());
    }
  }

  Future<void> _openSafetyNumber() async {
    await context.push(
      AppRouter.chatVerify,
      extra: widget.payload.chatGeneralData,
    );
    if (mounted) await context.read<SafetyNumberCubit>().load();
  }

  void _onMessageUpdated() {
    setState(() {
      isEncrypting = !_messageController.text.startsWith(fuzzIdentificator);
    });
  }

  void initializePagination() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 20) {
        loadOlderMessages();
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void loadOlderMessages() {
    final connectedChatCubit = context.read<ConnectedChatCubit>();

    if (connectedChatCubit.state.status.isLoading) return;
    if (connectedChatCubit.state.status.isFailed) {
      connectedChatCubit.loadCurrentMessagesPage();
      return;
    }

    connectedChatCubit.loadOlderMessages();
  }

  void _onSend() {
    _sendText();
    _sendFiles();
  }

  void _sendFiles() {
    final fileEncryptionCubit =
        context.read<FileProcessingCubit<FileEncryptionOption>>();
    final fileDecryptionCubit =
        context.read<FileProcessingCubit<FileDecryptionOption>>();

    if (selectedFilePaths?.isNotEmpty == true) {
      for (final filePath in selectedFilePaths!) {
        if (filePath.endsWith(fuzzedFileIdentificator)) {
          fileDecryptionCubit.addFilesToProcess(
            chatName: widget.payload.chatGeneralData.chatName,
            chatId: widget.payload.chatGeneralData.chatId,
            filePaths: [filePath],
          );
        } else {
          fileEncryptionCubit.addFilesToProcess(
            chatName: widget.payload.chatGeneralData.chatName,
            chatId: widget.payload.chatGeneralData.chatId,
            filePaths: [filePath],
          );
        }
      }
    }

    setState(() {
      selectedFilePaths = null;
    });
  }

  void _sendText() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_showTutorial && mounted) {
      sl.get<PreferencesService>().setHasCompletedTutorial(true);
      setState(() {
        _showTutorial = false;
      });
    }

    final isFuzzed = text.startsWith(fuzzIdentificator);

    if (isFuzzed) {
      _receiveMessage(text.substring(5));
    } else {
      _sendMessage(text);
    }
  }

  void onFilesSelected(List<String> paths) {
    setState(() {
      selectedFilePaths = paths;
    });
  }

  void _sendMessage(String text) {
    context.read<ConnectedChatCubit>().sendMessage(text: text);
    _messageController.clear();
    _scrollToBottom();
  }

  void _receiveMessage(String text) {
    context.read<ConnectedChatCubit>().receiveMessage(encryptedText: text);
    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatId = widget.payload.chatGeneralData.chatId;

    return FuzzyScaffold(
      hasAutomaticBackButton: false,
      body: BlocConsumer<ConnectedChatCubit, ConnectedChatState>(
        listenWhen: shouldToastFailure,
        listener: (context, state) {
          if (state.status.isFailed) {
            if (state.failure?.message?.isEmpty ?? true) return;
            FuzzzyToast.show(context, message: state.failure?.message ?? '');
          } else if (state.actionStatus.isFailed) {
            FuzzzyToast.show(
              context,
              message: state.actionFailure?.type
                      .toUiMessage(context.fuzzzyInkLocalizations) ??
                  '',
            );
          }
        },
        builder: (context, state) {
          return FileDropArea(
            onDropped: onFilesSelected,
            child: Stack(
              children: [
                CustomScrollView(
                  reverse: true,
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 300),
                    ),
                    MessageListSliver(
                      messages: state.messages,
                    ),
                    if (state.status.isLoading)
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 24),
                      ),
                    if (state.status.isLoading)
                      const SliverToBoxAdapter(
                        child: Center(child: FuzzzyProgressRing(size: 32)),
                      ),
                    SliverToBoxAdapter(
                      child: FileDecryptionProgressesDisplaylaceholder(
                        chatId: chatId,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: FileEncryptionProgressesDisplaylaceholder(
                        chatId: chatId,
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 80),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: ChatHeader(
                    chatGeneralData: widget.payload.chatGeneralData,
                    onBackPressed: () => context.goBack(),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_showTutorial)
                        _buildTutorialBanner(
                          context,
                          context.fuzzzyInkLocalizations,
                        ),
                      FileDecryptionProgressDisplay(
                        chatId: chatId,
                      ),
                      FileEncryptionProgressDisplay(
                        chatId: chatId,
                      ),
                      MessageInputField(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        onSend: _onSend,
                        onFilesSelected: onFilesSelected,
                        selectedFilePaths: selectedFilePaths,
                        isEncrypting: isEncrypting,
                        chatId: chatId,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTutorialBanner(
    BuildContext context,
    FuzzzyInkLocalizations localizations,
  ) {
    final theme = Theme.of(context);
    final fuzzzyColors = context.fuzzzyColors;

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fuzzzyColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fuzzzyColors.inkFaint, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                localizations.firstEncryption,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: fuzzzyColors.ink,
                ),
              ),
              GestureDetector(
                onTap: () {
                  sl.get<PreferencesService>().setHasCompletedTutorial(true);
                  setState(() {
                    _showTutorial = false;
                  });
                },
                child: Icon(Icons.close, color: fuzzzyColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            localizations
                .typeAMessageAndPressSendItWillBeEncryptedLocallyAndYouCanThenCopyTheSecureFuzzedText,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: fuzzzyColors.inkMute,
            ),
          ),
        ],
      ),
    );
  }
}
