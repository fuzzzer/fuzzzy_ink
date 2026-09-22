import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

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

  /// The core's 12 space-separated groups laid out 3 per row, so both
  /// devices show the same shape whatever their width.
  static String _rowsOf(String safetyNumber) {
    final groups = safetyNumber.split(' ');
    final rows = <String>[];
    for (var i = 0; i < groups.length; i += 3) {
      rows.add(groups.sublist(i, math.min(i + 3, groups.length)).join(' '));
    }
    return rows.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final fuzzzyColors = context.fuzzzyColors;
    final fuzzzyTextStyles = context.fuzzzyTextStyles;

    final localizations = context.fuzzzyInkLocalizations;

    return BlocBuilder<SafetyNumberCubit, SafetyNumberState>(
      builder: (context, state) {
        return StatusBuilder.buildByStatus(
          status: state.status,
          onInitial: () => const FuzzyLoadingPagebuilder(),
          onLoading: () => const FuzzyLoadingPagebuilder(),
          onSuccess: () => FuzzyScaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FuzzzyAppBar(
                      title: localizations.safetyNumberTitle,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      chatGeneralData.chatName,
                      textAlign: TextAlign.start,
                      style: fuzzzyTextStyles.body.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: fuzzzyColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      localizations.safetyNumberExplanation,
                      textAlign: TextAlign.start,
                      style: fuzzzyTextStyles.body.copyWith(
                        color: fuzzzyColors.inkMute,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _rowsOf(state.safetyNumber!),
                      textAlign: TextAlign.center,
                      style: fuzzzyTextStyles.dataL.copyWith(
                        color: fuzzzyColors.ink,
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (state.isVerified) ...[
                      Center(
                        child: FuzzzyStatusChip(
                          label: localizations.safetyNumberVerifiedBadge,
                          kind: FuzzzyStatusKind.success,
                          dot: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    FuzzzyButton(
                      key: const ValueKey('verify_mark_button'),
                      label: state.isVerified
                          ? localizations.safetyNumberUnmark
                          : localizations.safetyNumberMarkVerified,
                      variant: state.isVerified
                          ? FuzzzyButtonVariant.secondary
                          : FuzzzyButtonVariant.primary,
                      icon: Icon(
                        state.isVerified
                            ? Icons.shield_outlined
                            : Icons.verified_user,
                      ),
                      onPressed: () =>
                          context.read<SafetyNumberCubit>().toggleVerified(),
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ),
          onFailure: () => FuzzyErrorPageBuilder(
            message: state.failure?.message,
          ),
        );
      },
    );
  }
}
