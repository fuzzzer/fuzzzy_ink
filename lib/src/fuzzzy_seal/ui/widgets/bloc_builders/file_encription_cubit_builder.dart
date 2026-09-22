import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';

class FileEncriptionCubitBuilder extends StatelessWidget {
  const FileEncriptionCubitBuilder({
    super.key,
    required this.builder,
  });

  final Widget Function(BuildContext, FileProcessingState) builder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FileProcessingCubit<FileEncryptionOption>,
        FileProcessingState>(
      builder: builder,
    );
  }
}
