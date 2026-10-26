import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// Locked text shared as a file keeps its `.fuzz` name (seen live on the
/// iPhone simulator 2026-10-26: Share → File saved `<random>.so`, which the
/// app could no longer open from Files).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  final sharedPaths = <String>[];

  setUp(() {
    temp = Directory.systemTemp.createTempSync('share_helper_test');
    sharedPaths.clear();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => temp.path,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (call) async {
        final args = call.arguments as Map<Object?, Object?>;
        sharedPaths.addAll((args['paths']! as List).cast<String>());
        return 'dev.fluttercommunity.plus/share/success';
      },
    );
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      null,
    );
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  testWidgets('locked text goes as a file with its own .fuzz name',
      (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox();
          },
        ),
      ),
    );

    late bool done;
    await tester.runAsync(() async {
      done = await ShareHelper.shareTextAsFile(
        'Fuzz/sealed',
        fileName: 'fuzzzy-ink-message.fuzz',
        mimeType: 'application/octet-stream',
        context: context,
      );
    });

    expect(done, isTrue);
    expect(sharedPaths, hasLength(1));
    expect(sharedPaths.single.split('/').last, 'fuzzzy-ink-message.fuzz');
    expect(File(sharedPaths.single).readAsStringSync(), 'Fuzz/sealed');
  });
}
