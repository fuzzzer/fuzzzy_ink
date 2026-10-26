import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';

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
            final localizations = FuzzzyInkLocalizations.of(
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
            // Unlocked: one light buzz; the shell lifts in (LiftIn).
            unawaited(InkHaptics.light());
            final router = AppRouter.routerInstance;
            if (router != null) {
              final currentLocation =
                  router.routerDelegate.currentConfiguration.uri.toString();
              if (currentLocation == AppRouter.chatUnlock ||
                  currentLocation == AppRouter.recover ||
                  currentLocation == AppRouter.setup) {
                router.go(AppRouter.home);
              }
            }

            // Verified flags live in the store, which only now is open.
            context.read<ChatGeneralDataListCubit>().refreshVerification();
            // A first run, a recovery or an erase may have changed the vault.
            context.read<VaultAuthCubit>().checkVaultStatus();

            final handler = sl.get<FuzzyLinkHandler>();
            if (handler.hasPendingPayload) {
              handler.processPendingPayload();
            }
          },
        ),
        BlocListener<FuzzyAuthStore, FuzzyAuthState>(
          listenWhen: (previous, current) =>
              previous.status.hasAccess && !current.status.hasAccess,
          // The whole app locks: the vault's key is wiped with the store's,
          // the app's copy leaves the clipboard and every plain hand-off or
          // picker copy goes (security review 2026-10-26).
          listener: (context, __) {
            context.read<VaultAuthCubit>().lock();
            unawaited(CopyGuard.clearOnLock());
            if (sl.isRegistered<UserFileStore>()) {
              unawaited(sl.get<UserFileStore>().wipeAtLock());
            }
          },
        ),
        BlocListener<FuzzyAuthStore, FuzzyAuthState>(
          listenWhen: (previous, current) =>
              previous.status != current.status &&
              (current.status.isLocked ||
                  current.status.isStorageUnavailable ||
                  current.status.isSetupRequired),
          listener: (context, state) {
            final router = AppRouter.routerInstance;
            if (router == null) return;
            if (state.status.isSetupRequired) {
              context.read<VaultAuthCubit>().checkVaultStatus();
              router.go(AppRouter.setup);
              return;
            }
            final currentLocation =
                router.routerDelegate.currentConfiguration.uri.toString();
            // The recovery page is the locked app's own way in.
            if (currentLocation != AppRouter.recover) {
              router.go(AppRouter.chatUnlock);
            }
          },
        ),
      ],
      child: child,
    );
  }
}
