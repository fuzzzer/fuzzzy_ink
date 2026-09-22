import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:path_provider/path_provider.dart';

part 'file_benchmark_state.dart';

/// Development flavor only: one run of the core's file benchmark in the
/// app's temporary directory, for the settings tile.
class FileBenchmarkCubit extends Cubit<FileBenchmarkState> {
  FileBenchmarkCubit({
    required this.cryptoCoreService,
  }) : super(const FileBenchmarkState(status: StateStatus.initial));

  final CryptoCoreService cryptoCoreService;

  Future<void> run() async {
    if (state.status.isLoading) return;
    emit(state.copyWith(status: StateStatus.loading));

    final directory = await getTemporaryDirectory();
    final benchmarkRes = await cryptoCoreService.benchmarkFiles(
      directoryPath: directory.path,
    );
    if (benchmarkRes is CryptoCoreFailure<FileBenchmarkResult>) {
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failure: DefaultFailure(),
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: StateStatus.success,
        result: (benchmarkRes as CryptoCoreSuccess<FileBenchmarkResult>).data,
      ),
    );
  }
}
