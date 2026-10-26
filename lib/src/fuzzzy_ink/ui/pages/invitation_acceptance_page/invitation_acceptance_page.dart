import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

export 'components/components.dart';

/// I got an invite (DESIGN.md section 4.4, prototypes `got-start` and
/// `got-name`): step 1 "Open the invite" (Paste it · Choose a file; a tapped
/// invite link skips it), step 2 "The invite is good. Who sent it?" with
/// Accept. Then "Send your reply to Tamar" follows. A problem invite (your
/// own, already accepted, damaged) stays on step 1 with one fact.
class InvitationAcceptancePage extends StatelessWidget {
  final String? prefillInvitationContent;

  const InvitationAcceptancePage({super.key, this.prefillInvitationContent});

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
  final _name = TextEditingController();

  /// The good invite; null while on step 1.
  String? _invitation;

  /// Why the last invite cannot be used.
  InvitationCheck? _problem;
  String? _nameError;
  bool _isReading = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() {
      _nameError = null;
      setState(() {});
    });
    final prefill = widget.prefillInvitationContent;
    if (prefill != null) {
      final sealed = sealedTextOf(prefill, SealedTextKind.invitation);
      if (sealed != null) {
        // A tapped invite link: read it at once, skipping step 1.
        _isReading = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _read(sealed));
      } else {
        _problem = InvitationCheck.damaged;
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _read(String? invitation) async {
    if (invitation == null) return;
    setState(() => _isReading = true);
    final check = await context
        .read<InvitationAcceptanceCubit>()
        .checkInvitation(invitation);
    if (!mounted) return;
    setState(() {
      _isReading = false;
      if (check == InvitationCheck.good) {
        _invitation = invitation;
        _problem = null;
      } else {
        _problem = check;
      }
    });
  }

  void _accept() {
    final invitation = _invitation;
    final name = _name.text.trim();
    if (invitation == null || name.isEmpty) return;
    context.read<InvitationAcceptanceCubit>().acceptInvitation(
          invitationContent: invitation,
          chatName: name,
        );
  }

  void _onFailed(ChatCreationFailureType type) {
    final localizations = context.fuzzzyInkLocalizations;
    setState(() {
      switch (type) {
        case ChatCreationFailureType.existingName:
          _nameError = localizations.inviteNameTaken;
        case ChatCreationFailureType.ownInvitation:
          _invitation = null;
          _problem = InvitationCheck.ownInvitation;
        case ChatCreationFailureType.invalidInvitation:
          _invitation = null;
          _problem = InvitationCheck.damaged;
        case ChatCreationFailureType.newerApp:
          _invitation = null;
          _problem = InvitationCheck.newerApp;
        case ChatCreationFailureType.invalidAcceptance ||
              ChatCreationFailureType.invitationAlreadyUsed ||
              ChatCreationFailureType.wrongChat ||
              ChatCreationFailureType.unknown:
          showInkToast(
            context,
            message: localizations.gotAcceptFailed,
            kind: FuzzzyToastKind.error,
          );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InvitationAcceptanceCubit, InvitationAcceptanceState>(
      listener: (context, state) {
        if (state.status.isSuccess && state.chatData != null) {
          context.pushReplacement(
            AppRouter.chatAcceptanceExport,
            extra: AcceptanceExportPagePayload(
              chatGeneralData: state.chatData!,
              hasBackButton: false,
            ),
          );
        } else if (state.status.isFailed) {
          _onFailed(state.failure?.type ?? ChatCreationFailureType.unknown);
        }
      },
      builder: (context, state) => _invitation == null
          ? _openStep(context)
          : _nameStep(context, isAccepting: state.status.isLoading),
    );
  }

  Widget _openStep(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final problem = _problem;

    return FlowScaffold(
      qaId: 'gotInvite',
      title: localizations.addGotInvite,
      leading: FlowLeading.close,
      children: [
        StepsIndicator(
          qaId: 'gotInvite',
          step: 1,
          total: 3,
          label: localizations.gotStepOpen,
        ),
        SizedBox(height: space.l),
        Semantics(
          header: true,
          child: Text(
            localizations.gotOpenTitle,
            style: context.fuzzzyTextStyles.titleL.copyWith(
              color: context.fuzzzyColors.ink,
            ),
          ),
        ),
        if (problem != null) ...[
          SizedBox(height: space.m),
          _ProblemNotice(problem: problem),
        ],
        SizedBox(height: space.m),
        if (_isReading)
          Padding(
            padding: EdgeInsets.symmetric(vertical: space.l),
            child: const Center(
              child: FuzzzyProgressRing(qaId: 'gotInvite.reading'),
            ),
          )
        else ...[
          SheetDoorRow(
            qaId: 'gotInvite.paste',
            icon: Icons.content_paste,
            emphasised: true,
            title: localizations.openPasteIt,
            hint: localizations.pasteItHint,
            onTap: () async => _read(
              await pasteSealedText(
                context,
                kind: SealedTextKind.invitation,
                nothingToPaste: localizations.inviteNothingToPaste,
                notIt: localizations.gotDamagedLine,
              ),
            ),
          ),
          SheetDoorRow(
            qaId: 'gotInvite.file',
            icon: Icons.description_outlined,
            title: localizations.chooseFile,
            hint: localizations.chooseFileHint,
            divider: false,
            onTap: () async => _read(
              await chooseSealedTextFile(
                context,
                kind: SealedTextKind.invitation,
                notIt: localizations.gotDamagedLine,
              ),
            ),
          ),
        ],
        SizedBox(height: space.m),
        TipLine(
          qaId: 'gotInvite.links',
          icon: Icons.link,
          text: localizations.openLinksTip,
        ),
      ],
    );
  }

  Widget _nameStep(BuildContext context, {required bool isAccepting}) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;

    return FlowScaffold(
      qaId: 'gotInvite',
      title: localizations.addGotInvite,
      leading: FlowLeading.close,
      footer: FuzzzyButton(
        qaId: 'gotInvite.accept',
        label: localizations.gotAccept,
        loading: isAccepting,
        onPressed: _name.text.trim().isEmpty || isAccepting ? null : _accept,
      ),
      children: [
        StepsIndicator(
          qaId: 'gotInvite',
          step: 2,
          total: 3,
          label: localizations.inviteStepName,
        ),
        SizedBox(height: space.l),
        InkNotice(
          kind: InkNoticeKind.ok,
          text: localizations.gotInviteGood,
          qaId: 'gotInvite.good',
        ),
        SizedBox(height: space.l),
        Semantics(
          header: true,
          child: Text(
            localizations.gotWhoSent,
            style: context.fuzzzyTextStyles.titleL.copyWith(
              color: context.fuzzzyColors.ink,
            ),
          ),
        ),
        SizedBox(height: space.l),
        FuzzzyTextField(
          qaId: 'gotInvite.name',
          controller: _name,
          autofocus: true,
          label: localizations.inviteTheirName,
          hint: localizations.inviteNameHint,
          helper: localizations.inviteOnlyYouSee,
          errorText: _nameError,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _accept(),
        ),
      ],
    );
  }
}

class _ProblemNotice extends StatelessWidget {
  const _ProblemNotice({required this.problem});

  final InvitationCheck problem;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final (String title, String line) = switch (problem) {
      InvitationCheck.ownInvitation => (
          localizations.gotOwnInviteTitle,
          localizations.gotOwnInviteLine,
        ),
      InvitationCheck.alreadyConnected => (
          localizations.gotAlreadyTitle,
          localizations.gotAlreadyLine,
        ),
      InvitationCheck.newerApp => (
          localizations.openErrorNewerTitle,
          localizations.openErrorNewerLine,
        ),
      InvitationCheck.damaged || InvitationCheck.good => (
          localizations.gotDamagedTitle,
          localizations.gotDamagedLine,
        ),
    };
    return InkNotice(
      kind: InkNoticeKind.warning,
      lead: '$title.',
      text: line,
      qaId: 'gotInvite.problem',
    );
  }
}
