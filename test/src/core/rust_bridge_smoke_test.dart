import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/rust_bridge/api/core.dart';
import 'package:fuzzzy_ink/rust_bridge/api/files.dart';
import 'package:fuzzzy_ink/rust_bridge/api/formats.dart';
import 'package:fuzzzy_ink/rust_bridge/api/health.dart';
import 'package:fuzzzy_ink/rust_bridge/api/pairing.dart';
import 'package:fuzzzy_ink/rust_bridge/api/passwords.dart';
import 'package:fuzzzy_ink/rust_bridge/api/vault.dart';
import 'package:fuzzzy_ink/rust_bridge/error.dart';

import '../../helpers/crypto_core_test_init.dart';

const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';

/// `Fuzz/` + base64url without padding — the text envelope of plan §B.4.
String _fuzzText(List<int> blob) =>
    'Fuzz/${base64Url.encode(blob).replaceAll('=', '')}';

/// `FUZZ · 0x01 · type` followed by [payload].
List<int> _blob(int type, List<int> payload) =>
    [0x46, 0x55, 0x5A, 0x5A, 0x01, type, ...payload];

/// Invitation payload: `chat_id_len · chat_id · curve 32 · ed 32 · otk 32 · sig 64`.
List<int> _invitationBlob() => _blob(0x01, [
      _chatId.length,
      ...utf8.encode(_chatId),
      ...List.filled(32, 0x11),
      ...List.filled(32, 0x22),
      ...List.filled(32, 0x33),
      ...List.filled(64, 0x44),
    ]);

void main() {
  setUpAll(initCryptoCoreForTests);

  group('rust bridge smoke', () {
    test('coreVersion crosses the FFI', () async {
      final version = await coreVersion();

      expect(version, isNotEmpty);
    });

    test('roundTrip reverses bytes across the FFI', () async {
      final result = await roundTrip(bytes: [1, 2, 3]);

      expect(result, [3, 2, 1]);
    });
  });

  group('formats (sync)', () {
    test('blobTypeOf classifies a hand-built Fuzz/ string', () {
      expect(
        blobTypeOf(text: _fuzzText(_invitationBlob())),
        BlobType.invitation,
      );
      expect(blobTypeOf(text: 'Fuzz/RlVaWgEDAd6tvu8'), BlobType.message);
      expect(
        blobTypeOf(text: 'Fuzz/RlVa\r\n WgEDAd6tvu8'),
        BlobType.message,
        reason: 'ASCII whitespace from wrapping is ignored',
      );
    });

    test('blobTypeOf is unknown for storage-only kinds and garbage', () {
      expect(blobTypeOf(text: _fuzzText(_blob(0x10, [0]))), BlobType.unknown);
      expect(blobTypeOf(text: _fuzzText(_blob(0x20, [0]))), BlobType.unknown);
      expect(blobTypeOf(text: 'Fuzz/RlVaWgEDAA=='), BlobType.unknown);
      expect(blobTypeOf(text: 'not a blob'), BlobType.unknown);
    });

    test('peekChatId reads the clear chat id of an invitation', () {
      expect(peekChatId(text: _fuzzText(_invitationBlob())), _chatId);
    });

    test('peekChatId throws CoreError for other kinds and broken payloads', () {
      expect(
        () => peekChatId(text: 'Fuzz/RlVaWgEDAd6tvu8'),
        throwsA(CoreError.unsupportedFormat),
      );
      final truncated = _invitationBlob().sublist(0, 100);
      expect(
        () => peekChatId(text: _fuzzText(truncated)),
        throwsA(CoreError.corrupt),
      );
    });
  });

  group('store (async, opaque handle)', () {
    late Directory storeDir;

    setUp(() {
      storeDir = Directory.systemTemp.createTempSync('fuzzy_crypto_core_');
    });

    tearDown(() {
      if (storeDir.existsSync()) storeDir.deleteSync(recursive: true);
    });

    test('createStoreKey → openStore → sealLocal/openLocal → close', () async {
      final wrapped = await createStoreKey(password: 'pw');
      expect(wrapped.length, 103, reason: '0x10 blob: 6 + 16 + 9 + 24 + 48');
      expect(wrapped.sublist(0, 6), [0x46, 0x55, 0x5A, 0x5A, 0x01, 0x10]);

      final core = await openStore(
        storeDir: storeDir.path,
        wrapped: wrapped,
        password: 'pw',
      );
      expect(await core.storeDir(), storeDir.path);
      expect(
        Directory('${storeDir.path}/fuzzy_crypto_store').existsSync(),
        isTrue,
      );

      // History is sealed per chat: the chat's key exists from its invitation.
      await expectLater(
        core.sealLocal(chatId: _chatId, bytes: utf8.encode('history')),
        throwsA(CoreError.unknownChat),
      );
      await core.createInvitation(chatId: _chatId);
      final sealed = await core.sealLocal(
        chatId: _chatId,
        bytes: utf8.encode('history'),
      );
      expect(sealed.sublist(0, 6), [0x46, 0x55, 0x5A, 0x5A, 0x01, 0x20]);
      expect(
        utf8.decode(await core.openLocal(chatId: _chatId, blob: sealed)),
        'history',
      );

      final tampered = List<int>.of(sealed)..[40] ^= 1;
      await expectLater(
        core.openLocal(chatId: _chatId, blob: tampered),
        throwsA(CoreError.corrupt),
      );

      await core.close();
      await expectLater(
        core.sealLocal(chatId: _chatId, bytes: [1]),
        throwsA(CoreError.storeLocked),
      );
      await expectLater(
        core.deleteChat(chatId: _chatId),
        throwsA(CoreError.storeLocked),
      );
      core.dispose();
    });

    test('wrong password and rewrap', () async {
      final wrapped = await createStoreKey(password: 'pw');

      await expectLater(
        openStore(storeDir: storeDir.path, wrapped: wrapped, password: 'px'),
        throwsA(CoreError.wrongPassword),
      );

      final rewrapped = await rewrapStoreKey(
        wrapped: wrapped,
        oldPassword: 'pw',
        newPassword: '',
      );
      expect(rewrapped, isNot(wrapped));
      await expectLater(
        rewrapStoreKey(wrapped: wrapped, oldPassword: 'nope', newPassword: 'x'),
        throwsA(CoreError.wrongPassword),
      );

      final core = await openStore(
        storeDir: storeDir.path,
        wrapped: rewrapped,
        password: '',
      );
      await core.close();
      core.dispose();
    });
  });

  group('pairing (async, two stores)', () {
    late Directory aDir;
    late Directory bDir;
    late CryptoCore a;
    late CryptoCore b;

    Future<CryptoCore> open(Directory dir) async => openStore(
          storeDir: dir.path,
          wrapped: await createStoreKey(password: ''),
          password: '',
        );

    setUp(() async {
      aDir = Directory.systemTemp.createTempSync('fuzzy_crypto_core_a_');
      bDir = Directory.systemTemp.createTempSync('fuzzy_crypto_core_b_');
      a = await open(aDir);
      b = await open(bDir);
    });

    tearDown(() async {
      await a.close();
      await b.close();
      a.dispose();
      b.dispose();
      for (final dir in [aDir, bDir]) {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      }
    });

    test('A invites → B accepts → A completes → both connected', () async {
      final invitation = await a.createInvitation(chatId: _chatId);
      expect(invitation, startsWith('Fuzz/'));
      expect(blobTypeOf(text: invitation), BlobType.invitation);
      expect(peekChatId(text: invitation), _chatId);
      expect(await a.chatStatus(chatId: _chatId), ChatStatus.invited);

      final acceptance = await b.acceptInvitation(
        chatId: _chatId,
        invitation: invitation,
      );
      expect(blobTypeOf(text: acceptance), BlobType.acceptance);
      expect(await b.chatStatus(chatId: _chatId), ChatStatus.connected);

      await a.completeHandshake(chatId: _chatId, acceptance: acceptance);
      expect(await a.chatStatus(chatId: _chatId), ChatStatus.connected);

      expect(await a.currentInvitation(chatId: _chatId), invitation);
      expect(await b.currentAcceptance(chatId: _chatId), acceptance);

      // The one-time key is gone: the same acceptance cannot be completed twice.
      await expectLater(
        a.completeHandshake(chatId: _chatId, acceptance: acceptance),
        throwsA(CoreError.invitationAlreadyUsed),
      );
    });

    test('tampered and foreign blobs are CoreError values, no state written',
        () async {
      final invitation = await a.createInvitation(chatId: _chatId);
      final blob =
          base64Url.decode(base64Url.normalize(invitation.substring(5)));
      final tampered = List<int>.of(blob)..[100] ^= 1;

      await expectLater(
        b.acceptInvitation(chatId: _chatId, invitation: _fuzzText(tampered)),
        throwsA(CoreError.invalidSignature),
      );
      await expectLater(
        b.acceptInvitation(
          chatId: '0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d',
          invitation: invitation,
        ),
        throwsA(CoreError.wrongChat),
      );
      await expectLater(
        b.acceptInvitation(chatId: _chatId, invitation: 'Fuzz/RlVaWgEDAd6tvu8'),
        throwsA(CoreError.unsupportedFormat),
      );
      await expectLater(
        b.chatStatus(chatId: _chatId),
        throwsA(CoreError.unknownChat),
      );
    });

    test('text messages round-trip A→B and B→A; a replay throws', () async {
      final invitation = await a.createInvitation(chatId: _chatId);
      final acceptance = await b.acceptInvitation(
        chatId: _chatId,
        invitation: invitation,
      );
      await a.completeHandshake(chatId: _chatId, acceptance: acceptance);

      // A → B.
      final aBlob = await a.encryptText(chatId: _chatId, text: 'hi from a');
      expect(aBlob, startsWith('Fuzz/'));
      expect(blobTypeOf(text: aBlob), BlobType.message);
      expect(await b.decryptText(chatId: _chatId, blob: aBlob), 'hi from a');

      // B → A.
      final bBlob = await b.encryptText(chatId: _chatId, text: 'hi from b');
      expect(await a.decryptText(chatId: _chatId, blob: bBlob), 'hi from b');

      // Re-pasting a consumed blob throws Replay across the FFI.
      await expectLater(
        b.decryptText(chatId: _chatId, blob: aBlob),
        throwsA(CoreError.replay),
      );
    });

    test('safety number is identical on both sides; markVerified round-trips',
        () async {
      // Nothing to compare before the pairing.
      await expectLater(
        a.safetyNumber(chatId: _chatId),
        throwsA(CoreError.unknownChat),
      );

      final invitation = await a.createInvitation(chatId: _chatId);
      final acceptance = await b.acceptInvitation(
        chatId: _chatId,
        invitation: invitation,
      );
      await a.completeHandshake(chatId: _chatId, acceptance: acceptance);

      final onA = await a.safetyNumber(chatId: _chatId);
      final onB = await b.safetyNumber(chatId: _chatId);
      expect(onA, onB);
      expect(onA, matches(RegExp(r'^\d{5}( \d{5}){11}$')));
      expect(onA.replaceAll(' ', ''), hasLength(60));

      expect(await a.isVerified(chatId: _chatId), isFalse);
      await a.markVerified(chatId: _chatId, verified: true);
      expect(await a.isVerified(chatId: _chatId), isTrue);
      expect(await b.isVerified(chatId: _chatId), isFalse);
      await a.markVerified(chatId: _chatId, verified: false);
      expect(await a.isVerified(chatId: _chatId), isFalse);
    });
  });

  group('files (async, StreamSink + FileJob)', () {
    late Directory dir;
    late CryptoCore core;
    late File plain;
    late String sealedPath;
    late String openedPath;

    /// 3 MiB of non-repeating bytes: three 1 MiB chunks.
    List<int> plaintext() {
      var state = 0x2545F491;
      return List<int>.generate(3 * 1024 * 1024, (_) {
        state ^= (state << 13) & 0xFFFFFFFF;
        state ^= state >> 17;
        state ^= (state << 5) & 0xFFFFFFFF;
        return state & 0xFF;
      });
    }

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('fuzzy_crypto_core_files_');
      core = await openStore(
        storeDir: dir.path,
        wrapped: await createStoreKey(password: ''),
        password: '',
      );
      plain = File('${dir.path}/plain.bin')..writeAsBytesSync(plaintext());
      sealedPath = '${dir.path}/sealed.fuzz';
      openedPath = '${dir.path}/opened.bin';
    });

    tearDown(() async {
      await core.close();
      core.dispose();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    void expectNoOutput() {
      expect(File(openedPath).existsSync(), isFalse, reason: 'no output');
      expect(
        File('$openedPath.part').existsSync(),
        isFalse,
        reason: 'no .part',
      );
    }

    test('encryptFile streams one event per chunk, decryptFile restores bytes',
        () async {
      final encryptJob = await newFileJob();
      final encrypted = await encryptFile(
        password: 'pw',
        input: plain.path,
        output: sealedPath,
        job: encryptJob,
      ).toList();
      expect(encrypted.length, greaterThanOrEqualTo(3));
      expect(encrypted.last.isComplete, isTrue);
      expect(encrypted.last.isCancelled, isFalse);
      expect(encrypted.last.errorMessage, isNull);
      expect(encrypted.last.progress, 1.0);
      final fractions = encrypted.map((e) => e.progress).toList();
      expect(fractions, orderedEquals([...fractions]..sort()));
      expect(File('$sealedPath.part').existsSync(), isFalse);
      final sealed = File(sealedPath).readAsBytesSync();
      expect(sealed.sublist(0, 7), [0x46, 0x55, 0x5A, 0x5A, 0x01, 0x04, 0x02]);
      expect(sealed.length, 55 + 3 * 1024 * 1024 + 3 * 16);

      final decrypted = await decryptFile(
        password: 'pw',
        input: sealedPath,
        output: openedPath,
        job: await newFileJob(),
      ).toList();
      expect(decrypted.last.isComplete, isTrue);
      expect(decrypted.last.errorMessage, isNull);
      expect(File(openedPath).readAsBytesSync(), plain.readAsBytesSync());
      expect(File('$openedPath.part').existsSync(), isFalse);
    });

    test('wrong password and a tampered chunk fail with no output file',
        () async {
      await encryptFile(
        password: 'pw',
        input: plain.path,
        output: sealedPath,
        job: await newFileJob(),
      ).toList();

      final wrong = await decryptFile(
        password: 'nope',
        input: sealedPath,
        output: openedPath,
        job: await newFileJob(),
      ).toList();
      expect(wrong.last.errorMessage, 'wrong password');
      expect(wrong.last.isCancelled, isFalse);
      expectNoOutput();

      // Flip a byte in chunk 1 of 3: chunk 0 is written to the .part and then
      // discarded with it.
      final sealed = File(sealedPath);
      final tampered = sealed.readAsBytesSync();
      tampered[55 + (1024 * 1024 + 16) + 4321] ^= 0x01;
      sealed.writeAsBytesSync(tampered);
      final corrupt = await decryptFile(
        password: 'pw',
        input: sealedPath,
        output: openedPath,
        job: await newFileJob(),
      ).toList();
      expect(corrupt.last.errorMessage, 'corrupt');
      expect(
        corrupt.first.progress,
        closeTo(1 / 3, 1e-9),
        reason: 'chunk 0 opened before chunk 1 failed',
      );
      expectNoOutput();
    });

    test('cancel emits isCancelled and removes the .part', () async {
      final job = await newFileJob();
      final stream = encryptFile(
        password: 'pw',
        input: plain.path,
        output: sealedPath,
        job: job,
      );
      // Sync calls from Dart while the job runs on the Rust pool.
      job.pause();
      job.cancel();
      final events = await stream.toList();
      expect(events.last.isCancelled, isTrue);
      expect(events.last.isComplete, isFalse);
      expect(events.last.errorMessage, isNull);
      expect(File(sealedPath).existsSync(), isFalse);
      expect(File('$sealedPath.part').existsSync(), isFalse);
    });
  });

  group('chat files (async, two stores + tickets)', () {
    late Directory aDir;
    late Directory bDir;
    late CryptoCore a;
    late CryptoCore b;

    Future<CryptoCore> open(Directory dir) async => openStore(
          storeDir: dir.path,
          wrapped: await createStoreKey(password: ''),
          password: '',
        );

    /// 2.5 MiB of non-repeating bytes: three 1 MiB chunks.
    List<int> plaintext() {
      var state = 0x2545F491;
      return List<int>.generate(5 * 1024 * 1024 ~/ 2, (_) {
        state ^= (state << 13) & 0xFFFFFFFF;
        state ^= state >> 17;
        state ^= (state << 5) & 0xFFFFFFFF;
        return state & 0xFF;
      });
    }

    setUp(() async {
      aDir = Directory.systemTemp.createTempSync('fuzzy_crypto_core_cfa_');
      bDir = Directory.systemTemp.createTempSync('fuzzy_crypto_core_cfb_');
      a = await open(aDir);
      b = await open(bDir);
      final invitation = await a.createInvitation(chatId: _chatId);
      final acceptance =
          await b.acceptInvitation(chatId: _chatId, invitation: invitation);
      await a.completeHandshake(chatId: _chatId, acceptance: acceptance);
    });

    tearDown(() async {
      await a.close();
      await b.close();
      a.dispose();
      b.dispose();
      for (final dir in [aDir, bDir]) {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      }
    });

    test('A prepares + runs encrypt, B prepares + runs decrypt, bytes equal',
        () async {
      final bytes = plaintext();
      final input = File('${aDir.path}/report.pdf')..writeAsBytesSync(bytes);
      final sealedPath = '${aDir.path}/report.pdf.fuzz';

      // Send side: prepare under the lock (the file key rides in an Olm
      // message in the header), then stream the chunks.
      final sendTicket =
          await a.prepareFileSend(chatId: _chatId, input: input.path);
      expect(await sendTicket.originalName(), 'report.pdf');
      final sent = await runFileJob(
        ticket: sendTicket,
        output: sealedPath,
        job: await newFileJob(),
      ).toList();
      expect(sent.last.isComplete, isTrue);
      expect(sent.last.errorMessage, isNull);
      final sealed = File(sealedPath).readAsBytesSync();
      // FUZZ · 01 · 04 · key_mode 01 (chat).
      expect(sealed.sublist(0, 7), [0x46, 0x55, 0x5A, 0x5A, 0x01, 0x04, 0x01]);

      // Receive side: prepare (Olm decrypt + checks) yields the original name,
      // then stream the plaintext.
      final openedPath = '${bDir.path}/received.bin';
      final recvTicket =
          await b.prepareFileReceive(chatId: _chatId, input: sealedPath);
      expect(await recvTicket.originalName(), 'report.pdf');
      final received = await runFileJob(
        ticket: recvTicket,
        output: openedPath,
        job: await newFileJob(),
      ).toList();
      expect(received.last.isComplete, isTrue);
      expect(received.last.errorMessage, isNull);
      expect(File(openedPath).readAsBytesSync(), bytes);
      expect(File('$openedPath.part').existsSync(), isFalse);
    });

    test('replaying the same container throws Replay, no output', () async {
      final bytes = plaintext();
      final input = File('${aDir.path}/once.bin')..writeAsBytesSync(bytes);
      final sealedPath = '${aDir.path}/once.fuzz';
      final sendTicket =
          await a.prepareFileSend(chatId: _chatId, input: input.path);
      await runFileJob(
        ticket: sendTicket,
        output: sealedPath,
        job: await newFileJob(),
      ).toList();

      final out1 = '${bDir.path}/out1.bin';
      final t1 = await b.prepareFileReceive(chatId: _chatId, input: sealedPath);
      await runFileJob(ticket: t1, output: out1, job: await newFileJob())
          .toList();
      expect(File(out1).readAsBytesSync(), bytes);

      // The file's Olm message was consumed: a second prepare is a replay, and
      // nothing is written for the second output.
      final out2 = '${bDir.path}/out2.bin';
      await expectLater(
        b.prepareFileReceive(chatId: _chatId, input: sealedPath),
        throwsA(CoreError.replay),
      );
      expect(File(out2).existsSync(), isFalse);
      expect(File('$out2.part').existsSync(), isFalse);
    });

    test('prepare on a closed store throws storeLocked', () async {
      await a.close();
      final input = File('${aDir.path}/x.bin')..writeAsBytesSync([1, 2, 3]);
      await expectLater(
        a.prepareFileSend(chatId: _chatId, input: input.path),
        throwsA(CoreError.storeLocked),
      );
    });
  });

  group('passwords (async, 0x05 text blobs)', () {
    test('seal/open text with a password; wrong password throws', () async {
      final blob = await passwordSealText(password: 'pw', text: 'hello 🔐');
      expect(blob, startsWith('Fuzz/'));
      final raw = base64Url.decode(base64Url.normalize(blob.substring(5)));
      expect(raw.sublist(0, 6), [0x46, 0x55, 0x5A, 0x5A, 0x01, 0x05]);
      expect(
        raw.sublist(22, 31),
        [0, 1, 0, 0, 0, 0, 0, 4, 1],
        reason: 'Argon2id m=65536 t=4 p=1 recorded in the header',
      );

      expect(await passwordOpenText(password: 'pw', blob: blob), 'hello 🔐');
      expect(
        await passwordOpenText(
          password: 'pw',
          blob: blob.replaceRange(20, 20, '\r\n '),
        ),
        'hello 🔐',
        reason: 'whitespace from wrapping is ignored',
      );
      await expectLater(
        passwordOpenText(password: 'px', blob: blob),
        throwsA(CoreError.wrongPassword),
      );
      await expectLater(
        passwordOpenText(password: 'pw', blob: 'Fuzz/RlVaWgEQAA'),
        throwsA(CoreError.unsupportedFormat),
        reason: 'a 0x10 blob is not a password-sealed text',
      );

      final bytes = await passwordSealBytes(password: 'pw', bytes: [0, 255, 7]);
      expect(bytes.sublist(0, 6), [0x46, 0x55, 0x5A, 0x5A, 0x01, 0x05]);
      expect(await passwordOpenBytes(password: 'pw', blob: bytes), [0, 255, 7]);
      await expectLater(
        passwordOpenBytes(password: '', blob: bytes),
        throwsA(CoreError.wrongPassword),
      );
    });
  });

  group('vault (async, opaque VaultKey)', () {
    test('init → unlock → seal/open → rewrap → old password rejected',
        () async {
      final created = await vaultInit(password: 'pw');
      expect(
        created.wrapped.length,
        103,
        reason: '0x10 blob like the store key',
      );
      expect(
        created.wrapped.sublist(0, 6),
        [0x46, 0x55, 0x5A, 0x5A, 0x01, 0x10],
      );

      final item =
          await vaultSeal(key: created.key, bytes: utf8.encode('secret'));
      expect(item.sublist(0, 6), [0x46, 0x55, 0x5A, 0x5A, 0x01, 0x20]);
      expect(
        utf8.decode(await vaultOpen(key: created.key, blob: item)),
        'secret',
      );

      final unlocked =
          await vaultUnlock(password: 'pw', wrapped: created.wrapped);
      expect(utf8.decode(await vaultOpen(key: unlocked, blob: item)), 'secret');
      await expectLater(
        vaultUnlock(password: 'px', wrapped: created.wrapped),
        throwsA(CoreError.wrongPassword),
      );

      final rewrapped = await vaultRewrap(
        oldPassword: 'pw',
        newPassword: 'new',
        wrapped: created.wrapped,
      );
      expect(rewrapped, isNot(created.wrapped));
      await expectLater(
        vaultUnlock(password: 'pw', wrapped: rewrapped),
        throwsA(CoreError.wrongPassword),
        reason: 'the old password no longer opens the new blob',
      );
      final reopened = await vaultUnlock(password: 'new', wrapped: rewrapped);
      expect(
        utf8.decode(await vaultOpen(key: reopened, blob: item)),
        'secret',
        reason: 'the master key is unchanged — no item re-encryption',
      );

      final tampered = List<int>.of(item)..[35] ^= 1;
      await expectLater(
        vaultOpen(key: reopened, blob: tampered),
        throwsA(CoreError.corrupt),
      );

      await reopened.close();
      await expectLater(
        vaultSeal(key: reopened, bytes: [1]),
        throwsA(CoreError.storeLocked),
      );
      await expectLater(
        vaultOpen(key: reopened, blob: item),
        throwsA(CoreError.storeLocked),
      );
      for (final key in [created.key, unlocked, reopened]) {
        key.dispose();
      }
    });
  });
}
