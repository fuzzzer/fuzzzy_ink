import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/rust_bridge/frb_generated.dart';
import 'package:fuzzzy_ink/src/core/dependency_injection.dart';

class Initializer {
  static Future<void> preAppInit() async {
    WidgetsFlutterBinding.ensureInitialized();

    await FuzzyCryptoCoreLib.init();
    await DependencyInjection.inject();
  }
}
