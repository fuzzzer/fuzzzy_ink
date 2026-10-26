import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

class MockUserFilesChannel extends Mock implements UserFilesChannel {}

/// A `.fuzz` file another app opened in Fuzzzy Ink is read once into the
/// private hand-off folder and nothing else: never run, never handed on.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/incoming');

  late Directory root;
  late String support;
  late String documents;
  late MockUserFilesChannel userFiles;
  late List<String> pending;

  setUp(() {
    root = Directory.systemTemp.createTempSync('incoming_files_');
    support = path.join(root.path, 'support');
    documents = path.join(root.path, 'documents');
    for (final folder in [support, documents]) {
      Directory(folder).createSync();
    }
    userFiles = MockUserFilesChannel();
    pending = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'takePending') return null;
      final taken = List<String>.of(pending);
      pending.clear();
      return taken;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    root.deleteSync(recursive: true);
  });

  UserFileStore store() => UserFileStore(
        supportDirectoryPath: support,
        temporaryDirectoryPath: path.join(root.path, 'tmp'),
        documentsDirectoryPath: documents,
        platform: TargetPlatform.macOS,
        clearPickerCache: () async {},
        backupExclusion: const BackupExclusion(isApplePlatform: false),
      );

  IncomingFiles incoming({
    TargetPlatform platform = TargetPlatform.macOS,
    UserFileStore? userFileStore,
  }) =>
      IncomingFiles(
        userFileStore: userFileStore ?? store(),
        documentsDirectoryPath: documents,
        userFilesChannel: userFiles,
        channel: channel,
        platform: platform,
        systemTemporaryDirectoryPath: path.join(root.path, 'process_tmp'),
      );

  File write(String filePath, [String content = 'Fuzz/AwEC']) => File(filePath)
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  String incomingRoot() => path.join(support, UserFileStore.incomingFolderName);

  test('only file and content URIs are files; links are not', () {
    expect(IncomingFiles.isFileUri(Uri.parse('file:///a/b.fuzz')), isTrue);
    expect(
      IncomingFiles.isFileUri(Uri.parse('content://media/document/7')),
      isTrue,
    );
    expect(
      IncomingFiles.isFileUri(Uri.parse('https://ink.fuzzzycore.com/message')),
      isFalse,
    );
  });

  test('a name keeps its base only, without folders or hidden characters', () {
    expect(IncomingFiles.safeName('note.txt.fuzz'), 'note.txt.fuzz');
    expect(IncomingFiles.safeName('../../etc/passwd'), 'passwd');
    expect(IncomingFiles.safeName(r'..\..\evil.fuzz'), 'evil.fuzz');
    expect(IncomingFiles.safeName('a:b.fuzz'), 'a_b.fuzz');
    final rightToLeft = String.fromCharCode(0x202E);
    expect(IncomingFiles.safeName('${rightToLeft}txt.fuzz'), 'txt.fuzz');
    expect(IncomingFiles.safeName('null-photo.jpg.fuzz'), 'photo.jpg.fuzz');
    for (final unusable in [null, '', '..', '/']) {
      expect(IncomingFiles.safeName(unusable), IncomingFiles.fallbackName);
    }
  });

  group('a file URL (iOS, macOS)', () {
    test('is copied once into a new incoming folder; the original stays',
        () async {
      final source = write(path.join(root.path, 'Downloads', 'beach.jpg.fuzz'));
      final taken = await incoming().take(Uri.file(source.path));

      expect(taken, isNotNull);
      expect(path.isWithin(incomingRoot(), taken!), isTrue);
      expect(path.basename(taken), 'beach.jpg.fuzz');
      expect(File(taken).readAsStringSync(), 'Fuzz/AwEC');
      expect(source.existsSync(), isTrue, reason: "the person's own file");
    });

    test("iOS: the system's own Inbox copy is deleted once taken", () async {
      final inbox = write(path.join(documents, 'Inbox', 'note.fuzz'));
      final taken = await incoming(platform: TargetPlatform.iOS)
          .take(Uri.file(inbox.path));

      expect(taken, isNotNull);
      expect(File(taken!).existsSync(), isTrue);
      expect(inbox.existsSync(), isFalse);
    });

    test("iOS: the system's tmp/<bundle>-Inbox copy is deleted once taken",
        () async {
      final inbox = write(
        path.join(
          root.path,
          'process_tmp',
          'com.fuzzzycore.ink-Inbox',
          'm.fuzz',
        ),
      );
      final taken = await incoming(platform: TargetPlatform.iOS)
          .take(Uri.file(inbox.path));

      expect(taken, isNotNull);
      expect(File(taken!).existsSync(), isTrue);
      expect(inbox.existsSync(), isFalse);
    });

    test('iOS: a file outside the Inbox is never deleted', () async {
      final source = write(path.join(root.path, 'elsewhere', 'note.fuzz'));
      await incoming(platform: TargetPlatform.iOS).take(Uri.file(source.path));
      expect(source.existsSync(), isTrue);
    });

    test('a folder, a link or a missing file is not taken', () async {
      final folder = Directory(path.join(root.path, 'folder.fuzz'))
        ..createSync();
      final target = write(path.join(root.path, 'secret.txt'));
      final link = Link(path.join(root.path, 'link.fuzz'))
        ..createSync(target.path);
      final files = incoming();

      expect(await files.take(Uri.file(folder.path)), isNull);
      expect(await files.take(Uri.file(link.path)), isNull);
      expect(
        await files.take(Uri.file(path.join(root.path, 'gone.fuzz'))),
        isNull,
      );
      expect(Directory(incomingRoot()).existsSync(), isFalse);
    });

    test('a link is not a file to take', () async {
      expect(
        await incoming().take(Uri.parse('https://ink.fuzzzycore.com/message')),
        isNull,
      );
    });

    test('once Open used it, the hand-off copy is wiped', () async {
      final userFileStore = store();
      final source = write(path.join(root.path, 'note.fuzz'));
      final taken = await incoming(userFileStore: userFileStore)
          .take(Uri.file(source.path));

      await userFileStore.discardPickedCopy(taken!);
      expect(File(taken).existsSync(), isFalse);
      expect(Directory(path.dirname(taken)).existsSync(), isFalse);
      expect(source.existsSync(), isTrue);
    });
  });

  group('a content URI (Android)', () {
    const uri = 'content://com.android.providers.downloads/document/7';

    test('is copied by the native side under the name the provider gives',
        () async {
      when(() => userFiles.incomingName(uri))
          .thenAnswer((_) async => '../photo.jpg.fuzz');
      when(() => userFiles.copyIncoming(uri, any())).thenAnswer((_) async {});

      final taken =
          await incoming(platform: TargetPlatform.android).take(Uri.parse(uri));

      expect(path.isWithin(incomingRoot(), taken!), isTrue);
      expect(path.basename(taken), 'photo.jpg.fuzz');
      verify(() => userFiles.copyIncoming(uri, taken)).called(1);
    });

    test('that cannot be read is not taken, and leaves nothing', () async {
      when(() => userFiles.incomingName(uri)).thenAnswer((_) async => null);
      when(() => userFiles.copyIncoming(uri, any()))
          .thenThrow(PlatformException(code: 'notFound'));

      final taken =
          await incoming(platform: TargetPlatform.android).take(Uri.parse(uri));

      expect(taken, isNull);
      final left = Directory(incomingRoot()).existsSync()
          ? Directory(incomingRoot()).listSync()
          : const <FileSystemEntity>[];
      expect(left, isEmpty);
    });
  });

  group('files the desktop hands over (macOS)', () {
    test('those queued before the start, then each one announced', () async {
      pending.addAll(['file:///Users/a/one.fuzz', 'https://not.a/file']);
      final files = incoming();
      final opened = <Uri>[];
      final subscription = files.opened.listen(opened.add);

      await files.start();
      pending.add('file:///Users/a/two.fuzz');
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(const MethodCall('changed')),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);

      expect(opened, [
        Uri.parse('file:///Users/a/one.fuzz'),
        Uri.parse('file:///Users/a/two.fuzz'),
      ]);
      await subscription.cancel();
    });
  });
}
