import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

/// Send an invite, step 1 of 2 (DESIGN.md section 4.3, prototype
/// `inv-name`): "Who's it for?", their name (only you see it), the invite
/// steps picture, Make the invite. The invite itself is made by
/// [ChatCreationCubit]; then "Send it to Tamar" follows.
class ChatCreationPage extends StatelessWidget {
  const ChatCreationPage({super.key, this.prefillName});

  /// A name to start from ("Remove Tamar, invite again").
  final String? prefillName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ChatCreationCubit>(
      create: (context) => ChatCreationCubit(
        cryptoCoreService: sl.get<CryptoCoreService>(),
        chatGeneralDataListRepository: sl.get<ChatGeneralDataListRepository>(),
      ),
      child: ProvidedChatCreationPage(prefillName: prefillName),
    );
  }
}

class ProvidedChatCreationPage extends StatefulWidget {
  const ProvidedChatCreationPage({super.key, this.prefillName});

  final String? prefillName;

  @override
  State<ProvidedChatCreationPage> createState() =>
      _ProvidedChatCreationPageState();
}

class _ProvidedChatCreationPageState extends State<ProvidedChatCreationPage> {
  late final TextEditingController _name =
      TextEditingController(text: widget.prefillName);
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.addListener(() {
      if (_error != null) _error = null;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _make() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    context.read<ChatCreationCubit>().createChat(chatName: name);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;

    return BlocConsumer<ChatCreationCubit, ChatCreationState>(
      listener: (context, state) {
        if (state.status.isSuccess && state.chatId != null) {
          context.pushReplacement(
            AppRouter.chatInvitation,
            extra: ChatInvitationPagePayload(
              chatName: state.chatName!,
              chatId: state.chatId!,
              justMade: true,
            ),
          );
        } else if (state.status.isFailed) {
          setState(() {
            _error = state.failure?.type == ChatCreationFailureType.existingName
                ? localizations.inviteNameTaken
                : localizations.inviteMakeFailed;
          });
        }
      },
      builder: (context, state) {
        final isMaking = state.status.isLoading;

        return InkFlowScaffold(
          qaId: 'sendInvite',
          title: localizations.addSendInvite,
          close: true,
          footer: FuzzzyButton(
            qaId: 'sendInvite.make',
            label: localizations.inviteMake,
            loading: isMaking,
            onPressed: _name.text.trim().isEmpty || isMaking ? null : _make,
          ),
          children: [
            StepsIndicator(
              qaId: 'sendInvite',
              step: 1,
              total: 2,
              label: localizations.inviteStepName,
            ),
            SizedBox(height: space.l),
            Semantics(
              header: true,
              child: Text(
                localizations.inviteWhoFor,
                style: context.fuzzzyTextStyles.titleL.copyWith(
                  color: context.fuzzzyColors.ink,
                ),
              ),
            ),
            SizedBox(height: space.l),
            FuzzzyTextField(
              qaId: 'sendInvite.name',
              controller: _name,
              autofocus: true,
              label: localizations.inviteTheirName,
              hint: localizations.inviteNameHint,
              helper: localizations.inviteOnlyYouSee,
              errorText: _error,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _make(),
            ),
            SizedBox(height: space.l),
            StepPicture(
              qaId: 'sendInvite',
              steps: StepPicture.inviteSteps(context),
            ),
          ],
        );
      },
    );
  }
}
