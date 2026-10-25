import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:path/path.dart' as path;

/// The password containers Basics keeps in the app (sealed): Open unfuzzes
/// one under the key typed above, Save and Share hand the container out as
/// it is, Delete removes it.
class BasicsFuzzedFilesList extends StatelessWidget {
  const BasicsFuzzedFilesList({super.key, required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;

    return BlocBuilder<BasicsFuzzedFilesCubit, BasicsFuzzedFilesState>(
      builder: (context, state) {
        if (state.filePaths.isEmpty) return const SizedBox.shrink();
        final cubit = context.read<BasicsFuzzedFilesCubit>();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: space.l),
            Text(
              localizations.basicsFuzzedFilesTitle,
              style: context.fuzzzyTextStyles.bodyS.copyWith(
                color: context.fuzzzyColors.inkMute,
              ),
            ),
            for (final filePath in state.filePaths)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  UserFileNames.forDisplay(path.basename(filePath)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FuzzzyIconButton(
                      icon: const Icon(Icons.lock_open_rounded),
                      semanticLabel: localizations.open,
                      onPressed: () => onOpen(filePath),
                      qaId: 'basics.openFuzzed',
                    ),
                    FuzzzyIconButton(
                      icon: const Icon(Icons.save_alt_rounded),
                      semanticLabel: localizations.saveFile,
                      onPressed: () => saveFileForUser(
                        context,
                        filePath: filePath,
                        fileName: path.basename(filePath),
                        store: cubit.userFileStore,
                      ),
                      qaId: 'basics.saveFuzzed',
                    ),
                    FuzzzyIconButton(
                      icon: const Icon(Icons.share_rounded),
                      semanticLabel: localizations.share,
                      onPressed: () => shareFileForUser(
                        context,
                        filePath: filePath,
                        store: cubit.userFileStore,
                      ),
                      qaId: 'basics.shareFuzzed',
                    ),
                    FuzzzyIconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      semanticLabel: localizations.delete,
                      onPressed: () => cubit.delete(filePath),
                      qaId: 'basics.deleteFuzzed',
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
