import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

export 'components/components.dart';

/// I got an invite, step 3 of 3 (DESIGN.md section 4.4, prototype
/// `got-reply`): "Send your reply to Tamar", the same way the invite came.
/// The steps picture (Invite opened → You reply → Lock for each other),
/// Share reply (then Share again, and Done becomes the main button), and
/// "Then check numbers together." Done opens Tamar's page.
class AcceptanceExportPage extends StatelessWidget {
  final AcceptanceExportPagePayload payload;

  const AcceptanceExportPage({super.key, required this.payload});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AcceptanceReaderCubit>(
      create: (context) => AcceptanceReaderCubit(
        cryptoCoreService: sl.get<CryptoCoreService>(),
      )..generateAcceptance(chatId: payload.chatGeneralData.chatId),
      child: ProvidedAcceptanceExportPage(payload: payload),
    );
  }
}

class ProvidedAcceptanceExportPage extends StatefulWidget {
  final AcceptanceExportPagePayload payload;

  const ProvidedAcceptanceExportPage({super.key, required this.payload});

  @override
  State<ProvidedAcceptanceExportPage> createState() =>
      _ProvidedAcceptanceExportPageState();
}

class _ProvidedAcceptanceExportPageState
    extends State<ProvidedAcceptanceExportPage> {
  bool _isShared = false;

  /// The last way out was "Copy as text": the line says it was copied, not
  /// sent to the share menu.
  bool _wasCopied = false;

  @override
  void initState() {
    super.initState();
    // The reply is made: its step fills (micro-interaction 5).
    unawaited(InkHaptics.light());
  }

  Future<void> _share(String acceptance) async {
    final result = await showSealedShareSheet(
      context,
      content: SealedShareContent.acceptance(acceptance),
      personName: widget.payload.chatGeneralData.chatName,
    );
    if (!mounted || result == null || !result.isDone) return;
    setState(() {
      _isShared = true;
      _wasCopied = result.action == SealedShareAction.copied;
    });
  }

  void _done() =>
      PersonPage.goTo(context, widget.payload.chatGeneralData.chatId);

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final name = widget.payload.chatGeneralData.chatName;

    return BlocBuilder<AcceptanceReaderCubit, AcceptanceReaderState>(
      builder: (context, state) {
        final acceptance = state.acceptance?.content;

        return FlowScaffold(
          qaId: 'reply',
          leading: FlowLeading.close,
          onLeading: _done,
          footer: FuzzzyButton(
            qaId: 'reply.done',
            label: localizations.itemDone,
            variant: _isShared
                ? FuzzzyButtonVariant.primary
                : FuzzzyButtonVariant.ghost,
            onPressed: _done,
          ),
          children: [
            StepsIndicator(
              qaId: 'reply',
              step: 3,
              total: 3,
              label: localizations.gotStepReply,
            ),
            const InkHeroSlot(
              qaId: 'reply',
              moment: FuzzzyCastMoment.inviteReady,
              glyph: HeroGlyph(
                icon: Icons.send_outlined,
                tone: HeroGlyphTone.inverted,
                settle: true,
                qaId: 'reply',
              ),
            ),
            InkScreenTitle(localizations.replySendTo(name)),
            SizedBox(height: space.s),
            InkScreenLine(localizations.replySameWay),
            SizedBox(height: space.l),
            StepPicture(
              qaId: 'reply',
              steps: [
                StepPictureStep(
                  icon: Icons.move_to_inbox_outlined,
                  label: localizations.stepInviteOpened,
                ),
                StepPictureStep(
                  icon: Icons.ios_share,
                  label: localizations.stepYouReply,
                ),
                StepPictureStep(
                  icon: Icons.lock_outline,
                  label: localizations.stepLockForEachOther,
                ),
              ],
              done: 1,
              justDone: 0,
            ),
            SizedBox(height: space.l),
            if (state.status.isFailed)
              InkNotice(
                kind: InkNoticeKind.danger,
                text: localizations.failedToReadAcceptance,
                qaId: 'reply.failed',
              )
            else
              FuzzzyButton(
                qaId: 'reply.share',
                label: _isShared
                    ? localizations.itemShareAgain
                    : localizations.shareTitleReply,
                icon: const Icon(Icons.ios_share),
                variant: _isShared
                    ? FuzzzyButtonVariant.secondary
                    : FuzzzyButtonVariant.primary,
                loading: acceptance == null,
                onPressed: acceptance == null ? null : () => _share(acceptance),
              ),
            if (_isShared) ...[
              SizedBox(height: space.s),
              InkScreenLine(
                _wasCopied
                    ? localizations.shareCopiedStaysLocked
                    : localizations.inviteSharedLine,
              ),
            ],
            SizedBox(height: space.m),
            TipLine(
              qaId: 'reply.check',
              icon: Icons.shield_outlined,
              text: localizations.replyCheckTip,
              trailing: const WhyLink(
                topic: InkInfoTopic.checkNumbers,
                qaId: 'reply.check',
              ),
            ),
          ],
        );
      },
    );
  }
}
