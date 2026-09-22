import 'package:flutter/material.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:go_router/go_router.dart';

class BasicEncryptionNavigatorAction extends StatelessWidget {
  const BasicEncryptionNavigatorAction({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        context.push(AppRouter.basics);
      },
      icon: const Icon(Icons.key),
    );
  }
}
