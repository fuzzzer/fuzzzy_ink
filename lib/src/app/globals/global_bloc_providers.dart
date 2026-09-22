import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';

class GlobalBlocProviders extends StatelessWidget {
  const GlobalBlocProviders({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<FuzzyAuthStore>.value(
          value: sl.get<FuzzyAuthStore>()..checkAuthStatus(),
        ),
        BlocProvider<LocalizationCubit>(
          create: (_) => LocalizationCubit(),
        ),
        BlocProvider<ThemeCubit>(
          create: (_) => ThemeCubit(),
        ),
        BlocProvider<ChatGeneralDataListCubit>(
          create: (context) => ChatGeneralDataListCubit(
            chatRepository: sl.get<ChatGeneralDataListRepository>(),
            cryptoCoreService: sl.get<CryptoCoreService>(),
          )..fetchChats(),
        ),
        BlocProvider<FileProcessingCubit<FileEncryptionOption>>(
          create: (_) => FileProcessingCubit<FileEncryptionOption>(
            processingOption: const FileEncryptionOption(),
            cryptoCoreService: sl.get<CryptoCoreService>(),
            userFileStore: sl.get<UserFileStore>(),
          ),
        ),
        BlocProvider<FileProcessingCubit<FileDecryptionOption>>(
          create: (_) => FileProcessingCubit<FileDecryptionOption>(
            processingOption: const FileDecryptionOption(),
            cryptoCoreService: sl.get<CryptoCoreService>(),
            userFileStore: sl.get<UserFileStore>(),
          ),
        ),
        BlocProvider<ChatFileInjectorCubit>(
          create: (_) => ChatFileInjectorCubit(
            messageDataRepository: sl.get<MessageDataRepository>(),
          ),
        ),
        BlocProvider<VaultAuthCubit>(
          create: (context) => sl.get<VaultAuthCubit>()..checkVaultStatus(),
          lazy: false,
        ),
      ],
      child: child,
    );
  }
}
