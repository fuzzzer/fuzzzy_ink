import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';

class GlobalBlocListeners extends StatelessWidget {
  const GlobalBlocListeners({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<FileProcessingCubit<FileEncryptionOption>,
            FileProcessingState>(
          listenWhen: (previous, current) =>
              previous.processedFiles.length != current.processedFiles.length,
          listener: (context, state) {
            if (state.processedFiles.isNotEmpty == true) {
              final readProcessedFiles = state.processedFiles;

              context.read<ChatFileInjectorCubit>().injectProcessedFile(
                    processedFiles: state.processedFiles,
                    filesAreEncrypted: true,
                  );

              context
                  .read<FileProcessingCubit<FileEncryptionOption>>()
                  .markProcessedFilesAsReadAndClear(
                    readProcessedFiles: readProcessedFiles,
                  );
            }
          },
        ),
        BlocListener<FileProcessingCubit<FileDecryptionOption>,
            FileProcessingState>(
          listenWhen: (previous, current) =>
              previous.processedFiles.length != current.processedFiles.length,
          listener: (context, state) {
            if (state.processedFiles.isNotEmpty == true) {
              final readProcessedFiles = state.processedFiles;

              context.read<ChatFileInjectorCubit>().injectProcessedFile(
                    processedFiles: state.processedFiles,
                    filesAreEncrypted: false,
                  );

              context
                  .read<FileProcessingCubit<FileDecryptionOption>>()
                  .markProcessedFilesAsReadAndClear(
                    readProcessedFiles: readProcessedFiles,
                  );
            }
          },
        ),
        BlocListener<ChatFileInjectorCubit, ChatFileInjectorState>(
          // Every injected batch is a fresh list, so a new instance means a
          // new batch; a length compare skipped every single-file failure
          // (T-0334). The empty list of a clean batch never shows.
          listenWhen: (previous, current) =>
              !identical(
                previous.failedToAddProcessedFiles,
                current.failedToAddProcessedFiles,
              ) &&
              current.failedToAddProcessedFiles?.isNotEmpty == true,
          listener: (_, state) {
            final localizations = FuzzzySealLocalizations.of(
              navigatorKey.currentContext!,
            )!;

            scaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                content: Text(
                  ' ${localizations.failedToProcessFiles}: ${state.failedToAddProcessedFiles?.map(
                    (file) {
                      final name = file.inputFilePath.split('/').last;
                      final reason =
                          file.failure?.type.toUiMessage(localizations);
                      return reason == null ? name : '$name ($reason)';
                    },
                  ).toList()}',
                ),
              ),
            );
          },
        ),
        BlocListener<FuzzyAuthStore, FuzzyAuthState>(
          listenWhen: (previous, current) =>
              !previous.status.hasAccess && current.status.hasAccess,
          listener: (context, __) {
            final router = AppRouter.routerInstance;
            if (router != null) {
              final currentLocation =
                  router.routerDelegate.currentConfiguration.uri.toString();
              if (currentLocation == AppRouter.chatUnlock) {
                router.go(AppRouter.home);
              }
            }

            final handler = sl.get<FuzzyLinkHandler>();
            if (handler.hasPendingPayload) {
              handler.processPendingPayload();
            }
          },
        ),
        BlocListener<FuzzyAuthStore, FuzzyAuthState>(
          listenWhen: (previous, current) =>
              !previous.status.isLocked && current.status.isLocked,
          listener: (context, __) {
            final router = AppRouter.routerInstance;
            if (router != null) {
              router.go(AppRouter.chatUnlock);
            }
          },
        ),
      ],
      child: child,
    );
  }
}
