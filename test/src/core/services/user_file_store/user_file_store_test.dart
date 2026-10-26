import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:path/path.dart' as path;

/// The app keeps sealed files only, in private storage; a plain copy lives
/// for one use in the hand-off folder and is wiped after it and at launch.
void main() {
  const chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';

  late Directory root;
  late String support;
  late String temporary;
  late String documents;
  late int pickerClears;
  late String processTmp;

  setUp(() {
    root = Directory.systemTemp.createTempSync('user_file_store_');
    support = path.join(root.path, 'support');
    temporary = path.join(root.path, 'tmp');
    documents = path.join(root.path, 'documents');
    processTmp = path.join(root.path, 'process_tmp');
    for (final folder in [support, temporary, documents, processTmp]) {
      Directory(folder).createSync();
    }
    pickerClears = 0;
  });

  tearDown(() => root.deleteSync(recursive: true));

  UserFileStore storeOn(TargetPlatform platform) => UserFileStore(
        supportDirectoryPath: support,
        temporaryDirectoryPath: temporary,
        documentsDirectoryPath: documents,
        systemTemporaryDirectoryPath: processTmp,
        platform: platform,
        clearPickerCache: () async => pickerClears++,
        backupExclusion: const BackupExclusion(isApplePlatform: false),
      );

  File write(String filePath, [String content = 'x']) => File(filePath)
    ..createSync(recursive: true)
    ..writeAsStringSync(content);

  group('sealed folders', () {
    test('one folder per chat, one for Basics, all under sealed_files',
        () async {
      final store = storeOn(TargetPlatform.android);
      final chat = await store.chatFolder(chatName: 'Bob', chatId: chatId);
      expect(
        chat,
        path.join(support, 'sealed_files', 'chats', 'Bob (6f1e9b2c)'),
      );
      expect(Directory(chat).existsSync(), isTrue);
      expect(
        await store.basicsFolder(),
        path.join(support, 'sealed_files', 'basics'),
      );
    });

    test('a hostile chat name stays inside its own folder', () async {
      final store = storeOn(TargetPlatform.windows);
      final chat = await store.chatFolder(chatName: '../../x', chatId: chatId);
      expect(
        path.isWithin(path.join(support, 'sealed_files', 'chats'), chat),
        isTrue,
      );
    });

    test('rows keep paths relative to sealed_files', () async {
      final store = storeOn(TargetPlatform.iOS);
      final chat = await store.chatFolder(chatName: 'Bob', chatId: chatId);
      final kept = path.join(chat, 'photo.jpg.fuzz');
      final stored = store.storedPathOf(kept);
      expect(stored, path.join('chats', 'Bob (6f1e9b2c)', 'photo.jpg.fuzz'));
      expect(store.resolve(stored), kept);
      expect(store.resolve('/old/absolute.fuzz'), '/old/absolute.fuzz');
    });

    test('Basics files are listed and deleted, nothing outside is touched',
        () async {
      final store = storeOn(TargetPlatform.macOS);
      final basics = await store.basicsFolder();
      final a = write(path.join(basics, 'a.txt.fuzz'));
      write(path.join(basics, 'b.txt.fuzz.part'));
      final outside = write(path.join(support, 'keep.fuzz'));

      expect(
        (await store.basicsFiles()).map((file) => file.path),
        [a.path],
      );
      await store.deleteBasicsFile(outside.path);
      expect(outside.existsSync(), isTrue);
      await store.deleteBasicsFile(a.path);
      expect(await store.basicsFiles(), isEmpty);
    });
  });

  group('deleting a chat', () {
    test(
        "deletes the folder of its name and of every row's file, never "
        'another chat or anything outside', () async {
      final store = storeOn(TargetPlatform.linux);
      final current = await store.chatFolder(chatName: 'Bob', chatId: chatId);
      final renamed =
          await store.chatFolder(chatName: 'Robert', chatId: chatId);
      final other = await store.chatFolder(
        chatName: 'Ann',
        chatId: '0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d',
      );
      write(path.join(current, 'a.fuzz'));
      final oldRow = write(path.join(renamed, 'b.fuzz'));
      write(path.join(other, 'c.fuzz'));
      final outside = write(path.join(support, 'vault', 'vault.meta'));

      await store.deleteChatFiles(
        chatName: 'Bob',
        chatId: chatId,
        storedPaths: [
          store.storedPathOf(oldRow.path),
          '../vault/vault.meta',
          outside.path,
        ],
      );

      expect(Directory(current).existsSync(), isFalse);
      expect(Directory(renamed).existsSync(), isFalse);
      expect(Directory(other).existsSync(), isTrue);
      expect(outside.existsSync(), isTrue);
    });
  });

  group('hand-off copies', () {
    test('each use gets its own folder, so the name is kept', () async {
      final store = storeOn(TargetPlatform.android);
      final first = await store.newHandoffPath('report.pdf');
      final second = await store.newHandoffPath('../report.pdf');
      expect(path.basename(first), 'report.pdf');
      expect(path.basename(second), 'report.pdf');
      expect(path.dirname(first), isNot(path.dirname(second)));
      expect(store.isHandoff(first), isTrue);
      expect(store.isHandoff(second), isTrue);
      expect(path.isWithin(path.join(support, 'handoff'), second), isTrue);
    });

    test('wipe removes the copy and its folder, and only hand-off copies',
        () async {
      final store = storeOn(TargetPlatform.android);
      final copy = write(await store.newHandoffPath('plain.txt'));
      final sealed = write(
        path.join(
          await store.chatFolder(chatName: 'Bob', chatId: chatId),
          'a.fuzz',
        ),
      );

      await store.wipe(copy.path);
      await store.wipe(sealed.path);

      expect(copy.existsSync(), isFalse);
      expect(copy.parent.existsSync(), isFalse);
      expect(sealed.existsSync(), isTrue);
    });

    test('wipePending wipes what wipeWhenBack holds', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final store = storeOn(TargetPlatform.android);
      final shared = write(await store.newHandoffPath('shared.jpg'));
      store.wipeWhenBack(shared.path);
      expect(shared.existsSync(), isTrue);

      await store.wipePending();
      expect(shared.existsSync(), isFalse);
    });

    test("a phone picker's cache copy is discarded, a computer's file never",
        () async {
      final picked = write(path.join(temporary, 'file_picker', '1', 'a.pdf'));
      final mine = write(path.join(documents, 'mine.pdf'));

      await storeOn(TargetPlatform.android).discardPickedCopy(mine.path);
      await storeOn(TargetPlatform.macOS).discardPickedCopy(picked.path);
      expect(picked.existsSync(), isTrue);
      expect(mine.existsSync(), isTrue);

      await storeOn(TargetPlatform.android).discardPickedCopy(picked.path);
      expect(picked.existsSync(), isFalse);
    });

    test(
        "an iPhone picker's copy in the app's tmp/ is discarded too "
        '(security review 2026-10-26)', () async {
      final picked = write(
        path.join(processTmp, 'com.fuzzzycore.ink-Inbox', 'photo.jpg'),
      );
      final store = storeOn(TargetPlatform.iOS);
      expect(store.isPickedCopy(picked.path), isTrue);
      expect(
        storeOn(TargetPlatform.android).isPickedCopy(picked.path),
        isFalse,
      );
      await store.discardPickedCopy(picked.path);
      expect(picked.existsSync(), isFalse);
    });
  });

  group('the lock sweep (security review 2026-10-26)', () {
    test('hand-off copies and picker copies go; sealed files stay', () async {
      final store = storeOn(TargetPlatform.iOS);
      final handoff = write(await store.newHandoffPath('plain.jpg'));
      store.wipeWhenBack(handoff.path);
      final inbox = write(path.join(processTmp, 'x-Inbox', 'a.pdf'));
      final sealed = write(
        path.join(
          await store.chatFolder(chatName: 'Bob', chatId: chatId),
          'a.fuzz',
        ),
      );

      await store.wipeAtLock();

      expect(handoff.existsSync(), isFalse);
      expect(inbox.existsSync(), isFalse);
      expect(Directory(processTmp).existsSync(), isTrue);
      expect(pickerClears, 1);
      expect(sealed.existsSync(), isTrue);
    });

    test("on a computer the user's files are never touched", () async {
      final store = storeOn(TargetPlatform.macOS);
      final handoff = write(await store.newHandoffPath('plain.jpg'));
      final mine = write(path.join(processTmp, 'mine.pdf'));
      await store.wipeAtLock();
      expect(handoff.existsSync(), isFalse);
      expect(mine.existsSync(), isTrue);
      expect(pickerClears, 0);
    });
  });

  group('the launch sweep', () {
    late File handoff;
    late File archive;
    late File otherSupport;
    late List<File> androidStaging;
    late File workingFolder;
    late File sealed;

    Future<void> leaveCopies(UserFileStore store) async {
      handoff = write(await store.newHandoffPath('plain.jpg'));
      archive = write(path.join(support, 'chat_archive_$chatId.jsonl'));
      otherSupport = write(path.join(support, 'notes.jsonl'));
      androidStaging = [
        for (final staging in ['file_picker', 'user_files', 'share_plus'])
          write(path.join(temporary, staging, 'a.pdf')),
      ];
      workingFolder = write(path.join(documents, 'Working Folder', 'a.pdf'));
      sealed = write(
        path.join(
          await store.chatFolder(chatName: 'Bob', chatId: chatId),
          'a.fuzz',
        ),
      );
    }

    test('on Android every plain copy a previous run left is wiped', () async {
      final store = storeOn(TargetPlatform.android);
      await leaveCopies(store);

      await store.wipeTemporaryPlainCopies();

      expect(handoff.existsSync(), isFalse);
      expect(archive.existsSync(), isFalse);
      for (final staged in androidStaging) {
        expect(staged.existsSync(), isFalse, reason: staged.path);
      }
      expect(workingFolder.parent.existsSync(), isFalse);
      expect(pickerClears, 1);
      expect(sealed.existsSync(), isTrue, reason: 'sealed files stay');
      expect(otherSupport.existsSync(), isTrue);
    });

    test(
        "on a computer the user's own Documents and cache are left alone; "
        'the hand-off folder and the archive working file go', () async {
      final store = storeOn(TargetPlatform.windows);
      await leaveCopies(store);

      await store.wipeTemporaryPlainCopies();

      expect(handoff.existsSync(), isFalse);
      expect(archive.existsSync(), isFalse);
      for (final staged in androidStaging) {
        expect(staged.existsSync(), isTrue, reason: staged.path);
      }
      expect(workingFolder.existsSync(), isTrue);
      expect(pickerClears, 0);
      expect(sealed.existsSync(), isTrue);
    });

    test('never throws, even when the folders do not exist', () async {
      root.deleteSync(recursive: true);
      await storeOn(TargetPlatform.android).wipeTemporaryPlainCopies();
      root.createSync();
    });
  });
}
