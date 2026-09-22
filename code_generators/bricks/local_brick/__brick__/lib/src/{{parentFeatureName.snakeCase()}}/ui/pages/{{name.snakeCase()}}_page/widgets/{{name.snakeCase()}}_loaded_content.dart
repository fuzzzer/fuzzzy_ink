import 'package:flutter/material.dart';
import 'package:fuzzzy_seal/lib.dart';

class {{name.pascalCase()}}LoadedContent extends StatelessWidget {
  const {{name.pascalCase()}}LoadedContent({
    super.key,
    required this.items,
  });

  final List<{{modelName.pascalCase()}}> items;

  @override
  Widget build(BuildContext context) {
    //TODO implement your empty display
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          // TODO: Display your model's data
          title: Text(item.uid),
          subtitle: Text('Last Updated: ${item.lastUpdated}'),
        );
      },
    );
  }
}
