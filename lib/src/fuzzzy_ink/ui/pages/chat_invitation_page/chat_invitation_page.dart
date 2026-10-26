import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

export 'components/components.dart';

/// "Send it to Tamar" (DESIGN.md section 4.3 step 3, prototype `inv-ready`):
/// the invite is ready. The steps picture's first step fills, the two
/// waiting notes, Share invite (then Share again, and Done for now becomes
/// the main button), and "I got Tamar's reply".
///
/// With a reply ([ChatInvitationPagePayload.prefillAcceptanceContent], from a
/// reply link or "I got the reply") it connects at once ([HandshakeCubit])
/// and goes on to "Connected with Tamar".
class ChatInvitationPage extends StatelessWidget {
  final ChatInvitationPagePayload payload;

  const ChatInvitationPage({super.key, required this.payload});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<InvitationReaderCubit>(
          create: (context) => InvitationReaderCubit(
            cryptoCoreService: sl.get<CryptoCoreService>(),
          )..generateInvitation(chatId: payload.chatId),
        ),
        BlocProvider<HandshakeCubit>(
          create: (context) => HandshakeCubit(
            cryptoCoreService: sl.get<CryptoCoreService>(),
            chatGeneralDataListRepository:
                sl.get<ChatGeneralDataListRepository>(),
          ),
        ),
      ],
      child: ProvidedChatInvitationPage(payload: payload),
    );
  }
}

class ProvidedChatInvitationPage extends StatefulWidget {
  final ChatInvitationPagePayload payload;

  const ProvidedChatInvitationPage({required this.payload, super.key});

  @override
  State<ProvidedChatInvitationPage> createState() =>
      _ProvidedChatInvitationPageState();
}

class _ProvidedChatInvitationPageState
    extends State<ProvidedChatInvitationPage> {
  bool _isShared = false;

  /// The last way out was "Copy as text": the line says it was copied, not
  /// sent to the share menu.
  bool _wasCopied = false;

  @override
  void initState() {
    super.initState();
    final reply = widget.payload.prefillAcceptanceContent;
    if (reply != null) {
      _connect(reply);
    } else if (widget.payload.justMade) {
      // Invite made: step 1 fills (micro-interaction 5).
      unawaited(InkHaptics.light());
    }
  }

  void _connect(String reply) {
    context.read<HandshakeCubit>().completeHandshake(
          acceptanceContent: reply,
          chatId: widget.payload.chatId,
        );
  }

  Future<void> _share(String invitation) async {
    final result = await showSealedShareSheet(
      context,
      content: SealedShareContent.invitation(invitation),
      personName: widget.payload.chatName,
    );
    if (!mounted || result == null || !result.isDone) return;
    setState(() {
      _isShared = true;
      _wasCopied = result.action == SealedShareAction.copied;
    });
  }

  Future<void> _gotReply() async {
    final reply = await showOpenReplySheet(context);
    if (reply == null || !mounted) return;
    _connect(reply);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;

    return BlocConsumer<HandshakeCubit, HandshakeState>(
      listener: (context, state) {
        if (state.status.isSuccess) {
          final chat = (state.chatData ??
                  ChatGeneralData(
                    chatId: widget.payload.chatId,
                    chatName: widget.payload.chatName,
                    setupStatus: ChatSetupStatus.connected,
                    didAcceptInvitation: false,
                  ))
              .copyWith(setupStatus: ChatSetupStatus.connected);
          context.pushReplacement(AppRouter.personConnected, extra: chat);
        } else if (state.status.isFailed) {
          showInkToast(
            context,
            message: state.failure?.type.toUiMessage(
                  localizations,
                  customUnknownMessage: localizations.replyNotConnected,
                ) ??
                localizations.replyNotConnected,
            kind: FuzzzyToastKind.error,
          );
        }
      },
      builder: (context, handshake) {
        if (handshake.status.isLoading || handshake.status.isSuccess) {
          return FlowScaffold(
            qaId: 'inviteReady',
            leading: FlowLeading.close,
            onLeading: () => context.go(AppRouter.home),
            children: [
              SizedBox(height: context.fuzzzySpace.xxl),
              const Center(
                child: FuzzzyProgressRing(qaId: 'inviteReady.connecting'),
              ),
              SizedBox(height: context.fuzzzySpace.l),
              InkScreenLine(localizations.inviteConnecting),
            ],
          );
        }

        return BlocBuilder<InvitationReaderCubit, InvitationReaderState>(
          builder: _ready,
        );
      },
    );
  }

  Widget _ready(BuildContext context, InvitationReaderState reader) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final name = widget.payload.chatName;
    final invitation = reader.invitation?.content;

    return FlowScaffold(
      qaId: 'inviteReady',
      leading: FlowLeading.close,
      onLeading: () => context.go(AppRouter.home),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FuzzzyButton(
            qaId: 'inviteReady.done',
            label: localizations.inviteDoneForNow,
            variant: _isShared
                ? FuzzzyButtonVariant.primary
                : FuzzzyButtonVariant.ghost,
            onPressed: () => context.go(AppRouter.home),
          ),
          SizedBox(height: space.s),
          FuzzzyButton(
            qaId: 'inviteReady.gotReply',
            label: localizations.inviteGotNameReply(name),
            variant: FuzzzyButtonVariant.ghost,
            onPressed: _gotReply,
          ),
        ],
      ),
      children: [
        if (widget.payload.justMade)
          StepsIndicator(
            qaId: 'inviteReady',
            step: 2,
            total: 2,
            label: localizations.inviteStepSend,
          ),
        const InkHeroSlot(
          qaId: 'inviteReady',
          moment: FuzzzyCastMoment.inviteReady,
          glyph: HeroGlyph(
            icon: Icons.send_outlined,
            tone: HeroGlyphTone.inverted,
            settle: true,
            qaId: 'inviteReady',
          ),
        ),
        InkScreenTitle(localizations.inviteSendTo(name)),
        SizedBox(height: space.l),
        StepPicture(
          qaId: 'inviteReady',
          steps: StepPicture.inviteSteps(context, name: name),
          done: 1,
          justDone: widget.payload.justMade ? 0 : null,
        ),
        SizedBox(height: space.l),
        WaitNotes(name: name, qaId: 'inviteReady'),
        SizedBox(height: space.l),
        if (reader.status.isFailed)
          InkNotice(
            kind: InkNoticeKind.danger,
            text: localizations.inviteLoadFailed,
            qaId: 'inviteReady.failed',
          )
        else
          FuzzzyButton(
            qaId: 'inviteReady.share',
            label: _isShared
                ? localizations.itemShareAgain
                : localizations.shareTitleInvite,
            icon: const Icon(Icons.ios_share),
            variant: _isShared
                ? FuzzzyButtonVariant.secondary
                : FuzzzyButtonVariant.primary,
            loading: invitation == null,
            onPressed: invitation == null ? null : () => _share(invitation),
          ),
        if (_isShared) ...[
          SizedBox(height: space.s),
          InkScreenLine(
                _wasCopied
                    ? localizations.shareCopiedStaysLocked
                    : localizations.inviteSharedLine,
              ),
        ],
      ],
    );
  }
}
