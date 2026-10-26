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
/// With a reply ([ChatInvitationPagePayload.prefillAcceptanceContent], from
/// "I got the reply" or a paste) it connects at once ([HandshakeCubit]) and
/// goes on to "Connected with Tamar". A reply that came by link asks
/// "Connect with Tamar?" first and connects only on Connect (security review
/// 2026-10-26).
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

  /// A reply from a link, waiting for Connect.
  String? _replyToConfirm;

  @override
  void initState() {
    super.initState();
    final reply = widget.payload.prefillAcceptanceContent;
    if (reply != null && widget.payload.confirmReply) {
      _replyToConfirm = reply;
    } else if (reply != null) {
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
    setState(() => _isShared = true);
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
          return InkFlowScaffold(
            qaId: 'inviteReady',
            close: true,
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

        final reply = _replyToConfirm;
        if (reply != null) return _confirm(context, reply);
        return BlocBuilder<InvitationReaderCubit, InvitationReaderState>(
          builder: _ready,
        );
      },
    );
  }

  /// "Connect with Tamar?": nothing is completed until Connect.
  Widget _confirm(BuildContext context, String reply) {
    final localizations = context.fuzzzyInkLocalizations;
    final name = widget.payload.chatName;
    return InkFlowScaffold(
      qaId: 'replyLink',
      close: true,
      onLeading: () => context.go(AppRouter.home),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FuzzzyButton(
            qaId: 'replyLink.connect',
            label: localizations.replyLinkConnect,
            size: FuzzzyButtonSize.l,
            onPressed: () {
              setState(() => _replyToConfirm = null);
              _connect(reply);
            },
          ),
          SizedBox(height: context.fuzzzySpace.s),
          FuzzzyButton(
            qaId: 'replyLink.notNow',
            label: localizations.openLinkNotNow,
            variant: FuzzzyButtonVariant.ghost,
            onPressed: () => setState(() => _replyToConfirm = null),
          ),
        ],
      ),
      children: [
        SizedBox(height: context.fuzzzySpace.xl),
        InkScreenTitle(localizations.replyLinkTitle(name)),
        SizedBox(height: context.fuzzzySpace.s),
        InkScreenLine(localizations.replyLinkLine(name)),
      ],
    );
  }

  Widget _ready(BuildContext context, InvitationReaderState reader) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final name = widget.payload.chatName;
    final invitation = reader.invitation?.content;

    return InkFlowScaffold(
      qaId: 'inviteReady',
      close: true,
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
          InkScreenLine(localizations.inviteSharedLine),
        ],
      ],
    );
  }
}
