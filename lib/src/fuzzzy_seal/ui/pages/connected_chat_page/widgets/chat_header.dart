import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

class ChatHeader extends StatelessWidget {
  final ChatGeneralData chatGeneralData;
  final VoidCallback onBackPressed;

  const ChatHeader({
    required this.chatGeneralData,
    required this.onBackPressed,
    super.key,
  });

  Future<void> _openSafetyNumber(BuildContext context) async {
    await context.push(AppRouter.chatVerify, extra: chatGeneralData);
    if (context.mounted) await context.read<SafetyNumberCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final fuzzzyColors = context.fuzzzyColors;
    final fuzzzyTextStyles = context.fuzzzyTextStyles;

    return ColoredBox(
      color: fuzzzyColors.ground,
      child: Padding(
        padding: const EdgeInsets.only(
          top: 16,
          bottom: 4,
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBackPressed,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      chatGeneralData.chatName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: fuzzzyTextStyles.titleM
                          .copyWith(color: fuzzzyColors.ink),
                    ),
                  ),
                  BlocBuilder<SafetyNumberCubit, SafetyNumberState>(
                    builder: (context, state) {
                      return IconButton(
                        key: const ValueKey('verify_shield_button'),
                        icon: Icon(
                          state.isVerified
                              ? Icons.verified_user
                              : Icons.shield_outlined,
                          color: state.isVerified
                              ? fuzzzyColors.ink
                              : fuzzzyColors.inkMute,
                        ),
                        onPressed: () => _openSafetyNumber(context),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FuzzyOverlaySpawner(
                //TODO find better fix, so that offest is dynamically deduced
                offset: chatGeneralData.didAcceptInvitation
                    ? const Offset(-200, 0)
                    : const Offset(-150, 0),
                spawnedChildBuilder: (_, closeOverlay) => SettingsToolbox(
                  chatGeneralData: chatGeneralData,
                  onActionPressed: () {
                    closeOverlay();
                  },
                  onChatDeleted: () => context.goBack(),
                ),
                child: const Icon(
                  Icons.settings,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
