import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

export 'components/components.dart';
export 'widgets/widgets.dart';

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

class ProvidedAcceptanceExportPage extends StatelessWidget {
  final AcceptanceExportPagePayload payload;

  const ProvidedAcceptanceExportPage({super.key, required this.payload});

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzySealLocalizations;

    return BlocBuilder<AcceptanceReaderCubit, AcceptanceReaderState>(
      builder: (context, state) {
        return StatusBuilder.buildByStatus(
          status: state.status,
          onInitial: () => const FuzzyScaffold(
            hasAutomaticBackButton: false,
            body: Center(child: FuzzzyProgressRing(size: 32)),
          ),
          onLoading: () => const FuzzyScaffold(
            hasAutomaticBackButton: false,
            body: Center(child: FuzzzyProgressRing(size: 32)),
          ),
          onSuccess: () => AcceptanceContent(
            acceptanceContent: state.acceptance!.content,
            hasBackButton: payload.hasBackButton,
            chatGeneralData: payload.chatGeneralData,
          ),
          onFailure: () => FuzzyErrorPageBuilder(
            message:
                state.failure?.message ?? localizations.failedToReadAcceptance,
          ),
        );
      },
    );
  }
}
