import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

/// "Is it really Tamar?" (DESIGN.md section 4.3, prototype `safety`): the
/// 12 groups of 5 digits both phones show, and the version of the
/// computation that made them (only equal versions compare). Same numbers
/// saves Checked and goes on to "It's really Tamar"; Different numbers opens
/// the red sheet with Remove; once checked, Mark as not checked. The numbers
/// are not secret, so this is not a private screen.
class SafetyNumberPage extends StatelessWidget {
  final ChatGeneralData chatGeneralData;

  const SafetyNumberPage({super.key, required this.chatGeneralData});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SafetyNumberCubit>(
      create: (context) => SafetyNumberCubit(
        chatId: chatGeneralData.chatId,
        cryptoCoreService: sl.get<CryptoCoreService>(),
      )..load(),
      child: ProvidedSafetyNumberPage(chatGeneralData: chatGeneralData),
    );
  }
}

class ProvidedSafetyNumberPage extends StatelessWidget {
  final ChatGeneralData chatGeneralData;

  const ProvidedSafetyNumberPage({super.key, required this.chatGeneralData});

  /// Saves the flag in the core, then refreshes every trust chip.
  Future<bool> _mark(BuildContext context) async {
    final cubit = context.read<SafetyNumberCubit>();
    final listCubit = context.read<ChatGeneralDataListCubit>();
    await cubit.toggleVerified();
    if (cubit.state.status.isFailed) {
      if (context.mounted) {
        showInkToast(
          context,
          message: context.fuzzzyInkLocalizations.safetySaveFailed,
          kind: FuzzzyToastKind.error,
        );
      }
      return false;
    }
    await listCubit.refreshVerification();
    return true;
  }

  Future<void> _same(BuildContext context) async {
    if (!await _mark(context) || !context.mounted) return;
    context.pushReplacement(
      AppRouter.personChecked,
      extra: chatGeneralData,
    );
  }

  Future<void> _unmark(BuildContext context) async {
    if (!await _mark(context) || !context.mounted) return;
    showInkToast(
      context,
      message: context.fuzzzyInkLocalizations
          .safetyNowNotChecked(chatGeneralData.chatName),
      kind: FuzzzyToastKind.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final name = chatGeneralData.chatName;

    return BlocBuilder<SafetyNumberCubit, SafetyNumberState>(
      builder: (context, state) {
        final number = state.safetyNumber;
        final title = localizations.isItReally(name);

        if (number == null) {
          return InkFlowScaffold(
            qaId: 'safety',
            title: title,
            children: [
              SizedBox(height: space.xl),
              if (state.status.isFailed)
                InkNotice(
                  kind: InkNoticeKind.danger,
                  text: localizations.safetyLoadFailed,
                  qaId: 'safety.failed',
                )
              else
                const Center(child: FuzzzyProgressRing(qaId: 'safety')),
            ],
          );
        }

        return InkFlowScaffold(
          qaId: 'safety',
          title: title,
          footer: state.isVerified
              ? FuzzzyButton(
                  qaId: 'safety.unmark',
                  label: localizations.safetyMarkNotChecked,
                  variant: FuzzzyButtonVariant.secondary,
                  onPressed: () => _unmark(context),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FuzzzyButton(
                      qaId: 'safety.same',
                      label: localizations.safetySame,
                      icon: const Icon(Icons.check),
                      onPressed: () => _same(context),
                    ),
                    SizedBox(height: space.s + space.xs / 2),
                    FuzzzyButton(
                      qaId: 'safety.different',
                      label: localizations.safetyDifferent,
                      variant: FuzzzyButtonVariant.secondary,
                      onPressed: () => showMismatchSheet(
                        context,
                        name: name,
                        onRemove: () => removePerson(context, chatGeneralData),
                      ),
                    ),
                  ],
                ),
          children: [
            InkScreenLine(localizations.safetyCompare, center: false),
            SizedBox(height: space.l),
            SafetyNumberGrid(
              qaId: 'safety',
              groups: SafetyNumberGrid.groupsOf(number.digits),
            ),
            SizedBox(height: space.s),
            // The digits compare only between equal versions of the
            // computation, so the version is always shown.
            Text(
              localizations.safetyNumberVersion(number.version),
              key: const ValueKey('safety_number_version'),
              textAlign: TextAlign.center,
              style: context.fuzzzyTextStyles.bodyS.copyWith(
                color: context.fuzzzyColors.inkMute,
              ),
            ),
            SizedBox(height: space.m),
            if (state.isVerified)
              InkNotice(
                kind: InkNoticeKind.ok,
                text: localizations.safetyCheckedBefore(name),
                qaId: 'safety.checkedBefore',
              )
            else
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: WhyLink(
                  topic: InkInfoTopic.checkNumbers,
                  qaId: 'safety.why',
                ),
              ),
          ],
        );
      },
    );
  }
}
