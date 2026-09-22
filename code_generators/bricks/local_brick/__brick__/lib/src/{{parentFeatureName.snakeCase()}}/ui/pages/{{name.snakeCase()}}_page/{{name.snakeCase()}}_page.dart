import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';

class {{name.pascalCase()}}Page extends StatelessWidget {
  const {{name.pascalCase()}}Page({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<{{name.pascalCase()}}Cubit>(
      create: (context) => {{name.pascalCase()}}Cubit(
        // TODO: Ensure repository is available via your service locator (like sl.get())
        {{modelName.camelCase()}}Repository: sl.get<{{modelName.pascalCase()}}Repository>(),
      )..{{functionName.camelCase()}}(),
      child: const _Provided{{name.pascalCase()}}Page(),
    );
  }
}

class _Provided{{name.pascalCase()}}Page extends StatelessWidget {
  const _Provided{{name.pascalCase()}}Page();

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with your actual UI components like FuzzyScaffold
    return Scaffold(
      appBar: AppBar(
        title: const Text('{{name.titleCase()}}'),
      ),
      body: BlocBuilder<{{name.pascalCase()}}Cubit, {{name.pascalCase()}}State>(
        builder: (context, state) {
           return StatusBuilder.buildByStatus(
            status: state.status,
            onInitial: DefaultLoadingWidget.new,
            onLoading: DefaultLoadingWidget.new,
            onSuccess: () {
              if (state.items.isEmpty) {
                return const {{name.pascalCase()}}EmptyContent();
              }
              return {{name.pascalCase()}}LoadedContent(
                items: state.items,
              );
            },
            onFailure: () => Center(
              child: Text(
                'Error: ${state.failure?.message ?? 'Unknown error'}',
              ),
            ),
          );
        },
      ),
    );
  }
}
