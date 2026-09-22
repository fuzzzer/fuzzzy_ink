import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';

class FileDecriptionCubitBuilder extends StatelessWidget {
  const FileDecriptionCubitBuilder({
    super.key,
    required this.builder,
  });

  final Widget Function(BuildContext, FileProcessingState) builder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FileProcessingCubit<FileDecryptionOption>,
        FileProcessingState>(
      builder: builder,
    );
  }
}
