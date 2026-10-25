import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:path/path.dart' as path;

/// "Erase everything" also removes the sealed files the app keeps and any
/// hand-off copy; nothing else in the support folder is its business.
void main() {
  late Directory support;

  setUp(() {
    support = Directory.systemTemp.createTempSync('app_reset_');
  });

  tearDown(() {
    if (support.existsSync()) support.deleteSync(recursive: true);
  });

  File write(String relativePath) => File(path.join(support.path, relativePath))
    ..createSync(recursive: true)
    ..writeAsStringSync('x');

  test('deleteSealedFiles removes sealed_files and handoff only', () async {
    final chatContainer = write('sealed_files/chats/Nino (6f1e9b2c)/a.fuzz');
    final basicsContainer = write('sealed_files/basics/b.jpg.fuzz');
    final handoffCopy = write('handoff/1_0/b.jpg');
    final other = write('other.txt');

    await AppResetLocalDataSource(supportDirectoryPath: support.path)
        .deleteSealedFiles();

    expect(chatContainer.existsSync(), isFalse);
    expect(basicsContainer.existsSync(), isFalse);
    expect(handoffCopy.existsSync(), isFalse);
    expect(other.existsSync(), isTrue);
  });

  test('deleteSealedFiles on a fresh install is a no-op', () async {
    await AppResetLocalDataSource(supportDirectoryPath: support.path)
        .deleteSealedFiles();

    expect(support.listSync(), isEmpty);
  });
}
