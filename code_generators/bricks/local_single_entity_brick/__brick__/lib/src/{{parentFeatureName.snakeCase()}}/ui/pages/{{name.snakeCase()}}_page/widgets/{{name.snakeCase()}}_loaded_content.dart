import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/lib.dart';

class {{name.pascalCase()}}LoadedContent extends StatelessWidget {
  const {{name.pascalCase()}}LoadedContent({
    super.key,
    required this.item,
  });

  final {{modelName.pascalCase()}} item;

  @override
  Widget build(BuildContext context) {
    //TODO implement your loaded display for the single item
    return ListTile(
      // TODO: Display your model's data
      title: Text(item.name),
      subtitle: Text('Last Updated: ${item.lastUpdated}'),
    );
  }
}
