import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:path/path.dart' as path;

import '../../../helpers/crypto_core_test_init.dart';

// ---------------------------------------------------------------------------
// File jobs through CryptoCoreService (real library): password mode for
// fuzzy_basics, the two-step chat mode for the chat cubits.
// ---------------------------------------------------------------------------

const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';
const _password = 'correct horse';

/// 3 MiB of non-repeating bytes: three 1 MiB chunks.
Uint8List _plaintext() {
  var state = 0x2545F491;
  return Uint8List.fromList(
    List<int>.generate(3 * 1024 * 1024, (_) {
      state ^= (state << 13) & 0xFFFFFFFF;
      state ^= state >> 17;
      state ^= (state << 5) & 0xFFFFFFFF;
      return state & 0xFF;
    }),
  );
}

T _dataOf<T>(CryptoCoreResponse<T> res) => (res as CryptoCoreSuccess<T>).data;

CryptoCoreFailureType _failureOf(CryptoCoreResponse<dynamic> res) =>
    (res as CryptoCoreFailure).type;

/// A store of its own, opened with the empty (lock-disabled) password.
class _Device {
  final Directory dir;
  final CryptoCoreService service;

  _Device._(this.dir, this.service);

  static Future<_Device> open() async {
    final dir = Directory.systemTemp.createTempSync('crypto_core_files_');
    final service = CryptoCoreService(storeDirectoryPath: dir.path);
    final wrapped = _dataOf(await service.createStoreKey(''));
    expect(
      await service.openStore(wrapped: wrapped, password: ''),
      isA<CryptoCoreSuccess<void>>(),
    );
    return _Device._(dir, service);
  }

  String pathOf(String name) => path.join(dir.path, name);

  Future<void> close() async {
    await service.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

void _expectNoOutput(String outputPath) {
  expect(File(outputPath).existsSync(), isFalse, reason: 'no output');
  expect(File('$outputPath.part').existsSync(), isFalse, reason: 'no .part');
}

/// Progress events are monotonic in [0, 1] and only the last one is terminal.
void _expectWellFormed(List<FileProcessingProgress> events) {
  final fractions = events.map((e) => e.progress).toList();
  expect(fractions, orderedEquals([...fractions]..sort()));
  expect(fractions.every((f) => f >= 0 && f <= 1), isTrue);
  for (final event in events.take(events.length - 1)) {
    expect(event.isComplete || event.isCancelled, isFalse);
    expect(event.errorMessage, isNull);
  }
}

void main() {
  setUpAll(initCryptoCoreForTests);

  group('password mode (fuzzy_basics)', () {
    late Directory dir;
    late CryptoCoreService service;
    late File plain;
    late String sealedPath;
    late String openedPath;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('crypto_core_pw_files_');
      // Never opened: password mode must not need the store.
      service = CryptoCoreService(storeDirectoryPath: dir.path);
      plain = File(path.join(dir.path, 'plain.bin'))
        ..writeAsBytesSync(_plaintext());
      sealedPath = path.join(dir.path, 'plain.bin.fuzz');
      openedPath = path.join(dir.path, 'opened.bin');
    });

    tearDown(() async {
      await service.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('encrypt streams ≥ 3 events and decrypt restores the bytes', () async {
      expect(service.isOpen, isFalse);
      final encrypt = _dataOf(
        await service.encryptFileWithPassword(
          password: _password,
          inputPath: plain.path,
          outputPath: sealedPath,
        ),
      );
      final sent = await encrypt.progressStream.toList();
      expect(sent.length, greaterThanOrEqualTo(3));
      _expectWellFormed(sent);
      expect(sent.last.isComplete, isTrue);
      expect(sent.last.errorMessage, isNull);
      expect(sent.last.progress, 1.0);
      expect(File('$sealedPath.part').existsSync(), isFalse);
      final header = File(sealedPath).openSync().readSync(7);
      expect(header, [0x46, 0x55, 0x5A, 0x5A, 0x01, 0x04, 0x02]);

      final decrypt = _dataOf(
        await service.decryptFileWithPassword(
          password: _password,
          inputPath: sealedPath,
          outputPath: openedPath,
        ),
      );
      final received = await decrypt.progressStream.toList();
      expect(received.length, greaterThanOrEqualTo(3));
      _expectWellFormed(received);
      expect(received.last.isComplete, isTrue);
      expect(received.last.errorMessage, isNull);
      expect(File(openedPath).readAsBytesSync(), _plaintext());
      expect(File('$openedPath.part').existsSync(), isFalse);
    });

    test(
        'wrong password and a flipped byte end with errorMessage set and '
        'isComplete true — no output, no .part', () async {
      final encrypt = _dataOf(
        await service.encryptFileWithPassword(
          password: _password,
          inputPath: plain.path,
          outputPath: sealedPath,
        ),
      );
      await encrypt.progressStream.toList();

      final wrong = _dataOf(
        await service.decryptFileWithPassword(
          password: 'nope',
          inputPath: sealedPath,
          outputPath: openedPath,
        ),
      );
      final wrongEvents = await wrong.progressStream.toList();
      expect(wrongEvents.last.errorMessage, 'wrongPassword');
      expect(
        wrongEvents.last.isComplete,
        isTrue,
        reason:
            'a failure is terminal with isComplete set: check errorMessage first',
      );
      _expectNoOutput(openedPath);

      // One byte inside chunk 1 of 3.
      final raf = File(sealedPath).openSync(mode: FileMode.append);
      raf.setPositionSync(55 + (1024 * 1024 + 16) + 100);
      final byte = raf.readSync(1);
      raf.setPositionSync(55 + (1024 * 1024 + 16) + 100);
      raf.writeFromSync([byte[0] ^ 0x01]);
      raf.closeSync();

      final tampered = _dataOf(
        await service.decryptFileWithPassword(
          password: _password,
          inputPath: sealedPath,
          outputPath: openedPath,
        ),
      );
      final tamperedEvents = await tampered.progressStream.toList();
      expect(tamperedEvents.last.errorMessage, 'corrupt');
      expect(tamperedEvents.last.isComplete, isTrue);
      _expectNoOutput(openedPath);
    });

    test('pause holds the job short of complete; resume finishes it', () async {
      final encrypt = _dataOf(
        await service.encryptFileWithPassword(
          password: _password,
          inputPath: plain.path,
          outputPath: sealedPath,
        ),
      );
      final events = <FileProcessingProgress>[];
      final done = encrypt.progressStream.forEach(events.add);
      encrypt.pause();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final seenWhilePaused = events.length;
      expect(events.any((e) => e.isComplete), isFalse, reason: 'paused');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(
        events.length,
        seenWhilePaused,
        reason: 'no progress while paused',
      );
      expect(File(sealedPath).existsSync(), isFalse, reason: 'not renamed');

      encrypt.resume();
      await done;
      expect(events.last.isComplete, isTrue);
      expect(events.last.errorMessage, isNull);
      expect(File(sealedPath).existsSync(), isTrue);
      expect(File('$sealedPath.part').existsSync(), isFalse);
    });

    test('cancel ends with isCancelled and leaves nothing on disk', () async {
      final encrypt = _dataOf(
        await service.encryptFileWithPassword(
          password: _password,
          inputPath: plain.path,
          outputPath: sealedPath,
        ),
      );
      encrypt.cancel();
      final events = await encrypt.progressStream.toList();
      expect(events.last.isCancelled, isTrue);
      expect(events.last.isComplete, isFalse);
      expect(events.last.errorMessage, isNull);
      _expectNoOutput(sealedPath);
    });
  });

  group('chat mode (two paired stores + tickets)', () {
    late _Device a;
    late _Device b;
    late File plain;
    late String sealedPath;

    setUp(() async {
      a = await _Device.open();
      b = await _Device.open();
      final invitation = _dataOf(await a.service.createInvitation(_chatId));
      final acceptance = _dataOf(
        await b.service.acceptInvitation(
          chatId: _chatId,
          invitation: invitation.content,
        ),
      );
      expect(
        await a.service.completeHandshake(
          chatId: _chatId,
          acceptance: acceptance.content,
        ),
        isA<CryptoCoreSuccess<void>>(),
      );
      plain = File(a.pathOf('report.pdf'))..writeAsBytesSync(_plaintext());
      sealedPath = a.pathOf('report.pdf.fuzz');
    });

    tearDown(() async {
      await a.close();
      await b.close();
    });

    Future<List<FileProcessingProgress>> send() async {
      final handler = _dataOf(
        await a.service.encryptFileForChat(
          chatId: _chatId,
          inputPath: plain.path,
          outputPath: sealedPath,
        ),
      );
      return handler.progressStream.toList();
    }

    test(
        'A fuzzes for the chat, B unfuzzes into its folder under the original '
        'name; the container opens once', () async {
      final sent = await send();
      expect(sent.length, greaterThanOrEqualTo(3));
      _expectWellFormed(sent);
      expect(sent.last.isComplete, isTrue);
      expect(sent.last.errorMessage, isNull);
      final header = File(sealedPath).openSync().readSync(7);
      expect(header, [0x46, 0x55, 0x5A, 0x5A, 0x01, 0x04, 0x01]);

      final inbox = Directory(b.pathOf('Alice'))..createSync();
      final received = _dataOf(
        await b.service.decryptFileForChat(
          chatId: _chatId,
          inputPath: sealedPath,
          outputDirectoryPath: inbox.path,
        ),
      );
      expect(received.outputPath, path.join(inbox.path, 'report.pdf'));
      final events = await received.handler.progressStream.toList();
      expect(events.length, greaterThanOrEqualTo(3));
      _expectWellFormed(events);
      expect(events.last.isComplete, isTrue);
      expect(events.last.errorMessage, isNull);
      expect(File(received.outputPath).readAsBytesSync(), _plaintext());
      expect(File('${received.outputPath}.part').existsSync(), isFalse);

      // The key message is spent: a second receive is a replay.
      expect(
        _failureOf(
          await b.service.decryptFileForChat(
            chatId: _chatId,
            inputPath: sealedPath,
            outputDirectoryPath: inbox.path,
          ),
        ),
        CryptoCoreFailureType.replay,
      );
    });

    test(
        'a truncated container is corrupt at prepare and spends nothing; a '
        'tampered chunk fails the run and spends the message', () async {
      await send();
      final pristine = File(sealedPath).readAsBytesSync();
      final inbox = Directory(b.pathOf('Alice'))..createSync();
      final outputPath = path.join(inbox.path, 'report.pdf');

      // Header only (an incomplete transfer): rejected before the Olm step.
      File(sealedPath).writeAsBytesSync(pristine.sublist(0, 200));
      expect(
        _failureOf(
          await b.service.decryptFileForChat(
            chatId: _chatId,
            inputPath: sealedPath,
            outputDirectoryPath: inbox.path,
          ),
        ),
        CryptoCoreFailureType.corrupt,
      );
      _expectNoOutput(outputPath);

      // One byte inside the last chunk: prepare passes, the run rejects,
      // nothing is written — and the message is now spent (replay).
      final tampered = Uint8List.fromList(pristine);
      tampered[tampered.length - 100] ^= 0x01;
      File(sealedPath).writeAsBytesSync(tampered);
      final received = _dataOf(
        await b.service.decryptFileForChat(
          chatId: _chatId,
          inputPath: sealedPath,
          outputDirectoryPath: inbox.path,
        ),
      );
      final events = await received.handler.progressStream.toList();
      expect(events.last.errorMessage, 'corrupt');
      expect(events.last.isComplete, isTrue);
      _expectNoOutput(outputPath);

      File(sealedPath).writeAsBytesSync(pristine);
      expect(
        _failureOf(
          await b.service.decryptFileForChat(
            chatId: _chatId,
            inputPath: sealedPath,
            outputDirectoryPath: inbox.path,
          ),
        ),
        CryptoCoreFailureType.replay,
        reason: 'the sender has to send it again',
      );
    });

    test(
        'a chat the store does not know is unknownChat; a closed store is locked',
        () async {
      await send();
      final inbox = Directory(b.pathOf('Alice'))..createSync();
      const otherChat = '0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d';
      expect(
        _failureOf(
          await b.service.decryptFileForChat(
            chatId: otherChat,
            inputPath: sealedPath,
            outputDirectoryPath: inbox.path,
          ),
        ),
        CryptoCoreFailureType.unknownChat,
      );
      _expectNoOutput(path.join(inbox.path, 'report.pdf'));

      await b.service.close();
      expect(
        _failureOf(
          await b.service.decryptFileForChat(
            chatId: _chatId,
            inputPath: sealedPath,
            outputDirectoryPath: inbox.path,
          ),
        ),
        CryptoCoreFailureType.storeLocked,
      );
    });

    test('pause/resume reach a chat send; cancel leaves no container',
        () async {
      // Chat mode has no Argon2 window before the first chunk, so a 3 MiB
      // send can finish before `pause()` lands on a fast machine; the
      // deterministic "no progress while paused" proof is the password-mode
      // test above. Here: pausing never loses the job, resume completes it.
      final paused = _dataOf(
        await a.service.encryptFileForChat(
          chatId: _chatId,
          inputPath: plain.path,
          outputPath: sealedPath,
        ),
      );
      final events = <FileProcessingProgress>[];
      final done = paused.progressStream.forEach(events.add);
      paused.pause();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final seenWhilePaused = events.length;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(events.length, seenWhilePaused, reason: 'no progress');
      paused.resume();
      await done;
      _expectWellFormed(events);
      expect(events.last.isComplete, isTrue);
      expect(events.last.errorMessage, isNull);
      expect(File(sealedPath).existsSync(), isTrue);
      expect(File('$sealedPath.part').existsSync(), isFalse);

      final cancelledPath = a.pathOf('cancelled.fuzz');
      final cancelled = _dataOf(
        await a.service.encryptFileForChat(
          chatId: _chatId,
          inputPath: plain.path,
          outputPath: cancelledPath,
        ),
      );
      cancelled.cancel();
      final cancelEvents = await cancelled.progressStream.toList();
      expect(cancelEvents.last.isCancelled, isTrue);
      expect(cancelEvents.last.isComplete, isFalse);
      _expectNoOutput(cancelledPath);
    });
  });
}
