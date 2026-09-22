import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';

part '{{name.snakeCase()}}_state.dart';

class {{name.pascalCase()}}Cubit extends Cubit<{{name.pascalCase()}}State> {
  final {{modelName.pascalCase()}}Repository _{{modelName.camelCase()}}Repository;

  {{name.pascalCase()}}Cubit({
    required {{modelName.pascalCase()}}Repository {{modelName.camelCase()}}Repository,
  })  : _{{modelName.camelCase()}}Repository = {{modelName.camelCase()}}Repository,
        super(const {{name.pascalCase()}}State());

  Future<void> {{functionName.camelCase()}}() async {
    emit(state.copyWith(status: StateStatus.loading));
    try {
      // Logic to fetch the single data entity
      final item = await _{{modelName.camelCase()}}Repository.get{{modelName.pascalCase()}}();
      emit(
        state.copyWith(
          status: StateStatus.success,
          item: item,
        ),
      );
    } catch (e) {
      // TODO: Implement proper failure handling
      emit(
        state.copyWith(
          status: StateStatus.failed,
          failure: DefaultFailure(message: e.toString()),
        ),
      );
    }
  }
}
