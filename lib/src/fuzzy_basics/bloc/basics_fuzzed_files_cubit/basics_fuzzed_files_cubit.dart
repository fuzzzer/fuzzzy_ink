import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';

part 'basics_fuzzed_files_state.dart';

/// The password containers Basics keeps in the app's Basics folder
/// (`UserFileStore`), newest first: listed, deleted, and handed out from
/// there. They are sealed, so nothing here is ever plain.
class BasicsFuzzedFilesCubit extends Cubit<BasicsFuzzedFilesState> {
  BasicsFuzzedFilesCubit({required this.userFileStore})
      : super(const BasicsFuzzedFilesState());

  final UserFileStore userFileStore;

  Future<void> load() async {
    final files = await userFileStore.basicsFiles();
    if (isClosed) return;
    emit(
      BasicsFuzzedFilesState(
        status: StateStatus.success,
        filePaths: [for (final file in files) file.path],
      ),
    );
  }

  /// Deletes the container at [filePath], which must be in the Basics folder.
  Future<void> delete(String filePath) async {
    if (!state.filePaths.contains(filePath)) return;
    await userFileStore.deleteBasicsFile(filePath);
    await load();
  }
}
