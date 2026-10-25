import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ink/rust_bridge/api/core.dart' as rust_core;
import 'package:fuzzzy_ink/rust_bridge/api/files.dart' as rust_files;
import 'package:fuzzzy_ink/rust_bridge/api/formats.dart' as rust_formats;
import 'package:fuzzzy_ink/rust_bridge/api/passwords.dart' as rust_passwords;
import 'package:fuzzzy_ink/rust_bridge/api/safety.dart' as rust_safety;
import 'package:fuzzzy_ink/rust_bridge/api/vault.dart' as rust_vault;
import 'package:fuzzzy_ink/rust_bridge/error.dart';
import 'package:path/path.dart' as path;

export 'components/components.dart';

/// The vault master key as Dart ever holds it: an opaque handle whose bytes
/// stay in the core. `close()` zeroises it (later seal/open calls answer
/// `storeLocked`), `dispose()` frees the handle.
typedef VaultKey = rust_vault.VaultKey;

/// A chat's safety number with the version of the computation that produced
/// it (`version`, `digits`). The app shows both, so two builds that compute it
/// differently show different versions instead of silently different digits.
typedef SafetyNumber = rust_safety.SafetyNumber;

/// The only importer of `package:fuzzzy_ink/rust_bridge/...` besides
/// `initializer.dart`. Owns the single `CryptoCore` handle of the process and
/// maps every `CoreError` onto a [CryptoCoreResponse].
class CryptoCoreService {
  CryptoCoreService({
    required String storeDirectoryPath,
  }) : _storeDirectoryPath = storeDirectoryPath;

  /// uuid-v4 shape, as `store::validate_chat_id` demands — a blob's chat id
  /// is a path component on the Rust side and must never be trusted before
  /// this check.
  static final _chatIdShape =
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

  /// The benchmark's file is written and checked in 1 MiB blocks — one
  /// container chunk each — under a password that protects nothing.
  static const _benchmarkBlockSize = 1024 * 1024;
  static const _benchmarkPassword = 'fuzzy-bench';

  final String _storeDirectoryPath;

  rust_core.CryptoCore? _core;

  /// Argon2id needs 64 MiB per run; the store-key calls queue behind each other
  /// so only one derivation is in flight at a time.
  Future<void> _argon2Queue = Future<void>.value();

  bool get isOpen => _core != null;

  /// First run: draws the master key, the store key and a recovery key in
  /// the core and opens the store. The answer carries the four blobs the app
  /// keeps and the recovery key to show once. An empty
  /// password is `wrongPassword`. Two Argon2id runs, queued.
  Future<CryptoCoreResponse<CryptoCoreMasterKeySetup>> createMasterKey(
    String password,
  ) {
    return _serialized(() async {
      final setup = await rust_core.createMasterKey(
        storeDir: _storeDirectoryPath,
        password: password,
      );
      await _closeNow();
      _core = setup.core;
      return CryptoCoreMasterKeySetup(
        passwordWrap: setup.passwordWrap,
        recoveryWrap: setup.recoveryWrap,
        storeWrap: setup.storeWrap,
        recoveryLock: setup.recoveryLock,
        recoveryKey: setup.recoveryKey,
      );
    });
  }

  /// Opens the store with the master [password]: the master key from
  /// [passwordWrap], the store key from [storeWrap]. A handle that is
  /// already open stays in place until the new one exists, then is closed —
  /// a wrong password never closes an open store, and callers only ever see
  /// one handle.
  Future<CryptoCoreResponse<void>> openStore({
    required Uint8List passwordWrap,
    required Uint8List storeWrap,
    required String password,
  }) {
    return _serialized(() async {
      final core = await rust_core.openStore(
        storeDir: _storeDirectoryPath,
        passwordWrap: passwordWrap,
        storeWrap: storeWrap,
        password: password,
      );
      await _closeNow();
      _core = core;
    });
  }

  /// Re-wraps the master key under [newPassword]; the answer replaces
  /// [passwordWrap] and nothing else changes.
  Future<CryptoCoreResponse<Uint8List>> changeMasterPassword({
    required Uint8List passwordWrap,
    required String oldPassword,
    required String newPassword,
  }) {
    return _serialized(
      () => rust_core.changeMasterPassword(
        passwordWrap: passwordWrap,
        oldPassword: oldPassword,
        newPassword: newPassword,
      ),
    );
  }

  /// The forgotten-password path: [recoveryKey] opens [recoveryWrap], the
  /// master key is wrapped under [newPassword] (the answer, which replaces
  /// the password wrap) and the store opens. A typo in the key is `corrupt`,
  /// another device's key `wrongPassword`.
  Future<CryptoCoreResponse<Uint8List>> recoverMasterPassword({
    required Uint8List recoveryWrap,
    required Uint8List storeWrap,
    required String recoveryKey,
    required String newPassword,
  }) {
    return _serialized(() async {
      final recovered = await rust_core.recoverMasterPassword(
        storeDir: _storeDirectoryPath,
        recoveryWrap: recoveryWrap,
        storeWrap: storeWrap,
        recoveryKey: recoveryKey,
        newPassword: newPassword,
      );
      await _closeNow();
      _core = recovered.core;
      return recovered.passwordWrap;
    });
  }

  /// A new recovery key, the master key's wrap under it and its lock
  /// (sealed under the open store's key), once [password] opens
  /// [passwordWrap]; storing the new wrap ends the old key. A closed store
  /// is `storeLocked`.
  Future<CryptoCoreResponse<CryptoCoreRecoveryKey>> newRecoveryKey({
    required Uint8List passwordWrap,
    required String password,
  }) {
    return _serializedWithCore((core) async {
      final created = await rust_core.newRecoveryKey(
        core: core,
        passwordWrap: passwordWrap,
        password: password,
      );
      return CryptoCoreRecoveryKey(
        recoveryKey: created.recoveryKey,
        recoveryWrap: created.recoveryWrap,
        recoveryLock: created.recoveryLock,
      );
    });
  }

  /// Zeroises the store key and every cached state; later calls on the core
  /// fail with [CryptoCoreFailureType.storeLocked]. Queued behind any
  /// in-flight store-key call so a lock never races an open.
  Future<CryptoCoreResponse<void>> close() {
    return _serialized(_closeNow);
  }

  Future<void> _closeNow() async {
    final core = _core;
    if (core == null) return;
    _core = null;
    await core.close();
    core.dispose();
  }

  /// The chat id a pasted invitation or acceptance names — a routing hint
  /// only: nothing is authenticated until [acceptInvitation] /
  /// [completeHandshake] verify the signature against it.
  CryptoCoreResponse<String> peekChatId(String text) {
    final chatIdRes = _guardedSync(() => rust_formats.peekChatId(text: text));
    if (chatIdRes is CryptoCoreSuccess<String> &&
        !_chatIdShape.hasMatch(chatIdRes.data)) {
      return const CryptoCoreFailure(CryptoCoreFailureType.corrupt);
    }
    return chatIdRes;
  }

  /// A (inviter): the chat's Olm account and its signed invitation. A
  /// pending chat regenerates; a connected one is `internal`.
  Future<CryptoCoreResponse<CryptoCoreInvitation>> createInvitation(
    String chatId,
  ) {
    return _withCore((core) async {
      final content = await core.createInvitation(chatId: chatId);
      return CryptoCoreInvitation(chatId: chatId, content: content);
    });
  }

  Future<CryptoCoreResponse<CryptoCoreInvitation>> currentInvitation(
    String chatId,
  ) {
    return _withCore((core) async {
      final content = await core.currentInvitation(chatId: chatId);
      return CryptoCoreInvitation(chatId: chatId, content: content);
    });
  }

  /// B (accepter): verifies [invitation], establishes the session and
  /// returns the signed acceptance. [chatId] must be the id the invitation
  /// names (`wrongChat` otherwise); a chat that already has state is
  /// `internal`.
  Future<CryptoCoreResponse<CryptoCoreAcceptance>> acceptInvitation({
    required String chatId,
    required String invitation,
  }) {
    return _withCore((core) async {
      final content = await core.acceptInvitation(
        chatId: chatId,
        invitation: invitation,
      );
      return CryptoCoreAcceptance(chatId: chatId, content: content);
    });
  }

  Future<CryptoCoreResponse<CryptoCoreAcceptance>> currentAcceptance(
    String chatId,
  ) {
    return _withCore((core) async {
      final content = await core.currentAcceptance(chatId: chatId);
      return CryptoCoreAcceptance(chatId: chatId, content: content);
    });
  }

  /// A (inviter): verifies [acceptance] and completes the handshake. The
  /// one-time key is consumed exactly once, so a second acceptance of the
  /// same invitation is `invitationAlreadyUsed`.
  Future<CryptoCoreResponse<void>> completeHandshake({
    required String chatId,
    required String acceptance,
  }) {
    return _withCore(
      (core) => core.completeHandshake(chatId: chatId, acceptance: acceptance),
    );
  }

  /// Zeroises and unlinks the chat's state; a chat the store never had is
  /// not an error.
  Future<CryptoCoreResponse<void>> deleteChat(String chatId) {
    return _withCore((core) => core.deleteChat(chatId: chatId));
  }

  /// Fuzzes [text] on the chat's live Olm session; the ratcheted session is
  /// on disk before the `Fuzz/` blob comes back. A chat that is not
  /// connected is `internal`.
  Future<CryptoCoreResponse<String>> encryptText({
    required String chatId,
    required String text,
  }) {
    return _withCore((core) => core.encryptText(chatId: chatId, text: text));
  }

  /// Unfuzzes a pasted `Fuzz/` message [blob] against the chat's session. A
  /// blob decrypts once: a second paste is `replay`, one for another chat
  /// `wrongChat`, one behind the window `tooOld`, garbage `corrupt` /
  /// `unsupportedFormat`. Nothing is persisted on failure.
  Future<CryptoCoreResponse<String>> decryptText({
    required String chatId,
    required String blob,
  }) {
    return _withCore((core) => core.decryptText(chatId: chatId, blob: blob));
  }

  /// Fuzzes the file at [inputPath] for [chatId] into the chat-mode container
  /// at [outputPath]. The file key rides in one Olm message — one ratchet
  /// step, taken under the core lock and persisted before this returns — and
  /// the chunks then stream without the core, so a running (or paused) file
  /// never blocks a text message or a lock. Progress, pause/resume/cancel and
  /// the `.part` rules arrive through the handler; a run failure is the
  /// terminal event's `errorMessage` (a [CryptoCoreFailureType] name) with
  /// `isComplete` set — check `errorMessage` first.
  Future<CryptoCoreResponse<FileProcessingHandler>> encryptFileForChat({
    required String chatId,
    required String inputPath,
    required String outputPath,
  }) {
    return _withCore((core) async {
      final ticket =
          await core.prepareFileSend(chatId: chatId, input: inputPath);
      return _startFileJob(
        (job) =>
            rust_files.runFileJob(ticket: ticket, output: outputPath, job: job),
      );
    });
  }

  /// Unfuzzes the chat-mode container at [inputPath] for [chatId] into
  /// [outputDirectoryPath] under the sender's original file name, or
  /// `name (1).ext`, `name (2).ext`, … when that name is taken — an existing
  /// file is never replaced (`UserFileNames.uniqueOutputPath`). The
  /// container's key message is consumed here (a second attempt is `replay`;
  /// `wrongChat`, `tooOld`, and `corrupt` for a truncated or tampered header
  /// leave nothing consumed), so a run failure after a success here is
  /// terminal for that container — the sender has to send it again. Never
  /// call this on a file that is still being written.
  ///
  /// The answer carries [CryptoCoreReceivedFile.keptKey]: the file key sealed
  /// under the chat's history key (`PROTOCOL.md` §9.6), with which
  /// [openKeptFileForChat] opens the same container again — the app keeps
  /// the container, never the plaintext.
  Future<CryptoCoreResponse<CryptoCoreReceivedFile>> decryptFileForChat({
    required String chatId,
    required String inputPath,
    required String outputDirectoryPath,
  }) {
    return _withCore((core) async {
      final ticket =
          await core.prepareFileReceive(chatId: chatId, input: inputPath);
      // Before the run: a running job holds the ticket's write lock, and the
      // run consumes the key.
      final keptKey =
          await core.keepReceivedFile(chatId: chatId, ticket: ticket);
      final outputPath = await UserFileNames.uniqueOutputPath(
        path.join(outputDirectoryPath, await ticket.originalName()),
      );
      final handler = await _startFileJob(
        (job) =>
            rust_files.runFileJob(ticket: ticket, output: outputPath, job: job),
      );
      return CryptoCoreReceivedFile(
        outputPath: outputPath,
        handler: handler,
        keptKey: keptKey,
      );
    });
  }

  /// Unfuzzes a container the app kept after [decryptFileForChat] again, to
  /// [outputPath], from its [keptKey]. No message is spent and no state is
  /// written, so this can run any number of times while the chat exists;
  /// another chat's key is `corrupt`, a deleted chat `unknownChat`, a key
  /// that is not this container's ends the run with `corrupt`.
  Future<CryptoCoreResponse<FileProcessingHandler>> openKeptFileForChat({
    required String chatId,
    required String inputPath,
    required Uint8List keptKey,
    required String outputPath,
  }) {
    return _withCore((core) async {
      final ticket = await core.reopenKeptFile(
        chatId: chatId,
        input: inputPath,
        keptKey: keptKey,
      );
      return _startFileJob(
        (job) =>
            rust_files.runFileJob(ticket: ticket, output: outputPath, job: job),
      );
    });
  }

  /// Fuzzes the file at [inputPath] under [password] (Argon2id, fresh salt)
  /// into the password-mode container at [outputPath]; the store is not
  /// involved, so this works with a locked store and never queues a chat call.
  Future<CryptoCoreResponse<FileProcessingHandler>> encryptFileWithPassword({
    required String password,
    required String inputPath,
    required String outputPath,
  }) {
    return _guarded(
      () => _startFileJob(
        (job) => rust_files.encryptFile(
          password: password,
          input: inputPath,
          output: outputPath,
          job: job,
        ),
      ),
    );
  }

  /// Inverse of [encryptFileWithPassword]. A wrong password (or a corrupt
  /// first chunk) ends the stream with `wrongPassword`, any later damage
  /// with `corrupt`; no output and no `.part` exist after a failure.
  Future<CryptoCoreResponse<FileProcessingHandler>> decryptFileWithPassword({
    required String password,
    required String inputPath,
    required String outputPath,
  }) {
    return _guarded(
      () => _startFileJob(
        (job) => rust_files.decryptFile(
          password: password,
          input: inputPath,
          output: outputPath,
          job: job,
        ),
      ),
    );
  }

  /// Fuzzes [text] under [password] (Argon2id, fresh salt and nonce) as a
  /// paste-able `Fuzz/` 0x05 blob; like the password-mode file calls the
  /// store is not involved, so this works with a locked store.
  Future<CryptoCoreResponse<String>> passwordSealText({
    required String password,
    required String text,
  }) {
    return _guarded(
      () => rust_passwords.passwordSealText(password: password, text: text),
    );
  }

  /// Inverse of [passwordSealText]. A wrong password and a tampered blob are
  /// both `wrongPassword` (the AEAD cannot tell them apart); a pasted string
  /// that is not a 0x05 blob is `unsupportedFormat`, a malformed one
  /// `corrupt`.
  Future<CryptoCoreResponse<String>> passwordOpenText({
    required String password,
    required String blob,
  }) {
    return _guarded(
      () => rust_passwords.passwordOpenText(password: password, blob: blob),
    );
  }

  /// One `FileJob` per file — a cancelled job is spent. Rust events map 1:1
  /// onto [FileProcessingProgress]; the terminal event's error text becomes
  /// the matching [CryptoCoreFailureType] name so no Rust string leaves here.
  Future<FileProcessingHandler> _startFileJob(
    Stream<rust_files.FileProgress> Function(rust_files.FileJob job) start,
  ) async {
    final job = await rust_files.newFileJob();
    return FileProcessingHandler(
      progressStream: start(job).map(
        (event) => FileProcessingProgress(
          progress: event.progress,
          isComplete: event.isComplete,
          isCancelled: event.isCancelled,
          errorMessage: switch (event.errorMessage) {
            null => null,
            final text => _failureTypeOfText(text).name,
          },
        ),
      ),
      pause: job.pause,
      resume: job.resume,
      cancel: job.cancel,
    );
  }

  /// Development-flavor benchmark behind the settings tile: [sizeMiB] (≥ 2)
  /// of random bytes under [directoryPath] go through the password-mode
  /// container and back under a throwaway password, the round trip is
  /// checked byte for byte and the three files are deleted. Each rate counts
  /// the chunk stream only — first chunk event to terminal event, over the
  /// bytes those chunks carry — so the Argon2id run before the first chunk is
  /// reported on its own (one chunk's share taken off). Any failure, the
  /// core's or the disk's, is `internal`: nothing here is a user error.
  Future<CryptoCoreResponse<FileBenchmarkResult>> benchmarkFiles({
    required String directoryPath,
    int sizeMiB = 64,
  }) {
    return _guarded(() async {
      final inputPath = path.join(directoryPath, 'fuzzy_bench.bin');
      final fuzzedPath = '$inputPath.$fuzzedFileIdentificator';
      final restoredPath = '$inputPath.unfuzzed';
      final random = Random();
      final block = Uint8List.fromList(
        List<int>.generate(_benchmarkBlockSize, (_) => random.nextInt(256)),
      );
      final sizeBytes = sizeMiB * _benchmarkBlockSize;
      try {
        // Flushed to disk before the clock starts, so the input's writeback
        // never competes with the encrypt job it feeds.
        final input = await File(inputPath).open(mode: FileMode.write);
        for (var i = 0; i < sizeMiB; i++) {
          await input.writeFrom(block);
        }
        await input.flush();
        await input.close();

        final encrypt = await _timeFileJob(
          sizeBytes,
          (job) => rust_files.encryptFile(
            password: _benchmarkPassword,
            input: inputPath,
            output: fuzzedPath,
            job: job,
          ),
        );
        final decrypt = await _timeFileJob(
          sizeBytes,
          (job) => rust_files.decryptFile(
            password: _benchmarkPassword,
            input: fuzzedPath,
            output: restoredPath,
            job: job,
          ),
        );
        if (!await _isRepetitionOf(block, restoredPath, sizeMiB)) {
          throw StateError('benchmark round trip mismatch');
        }

        return FileBenchmarkResult(
          sizeBytes: sizeBytes,
          encryptMbPerSecond: encrypt.mbPerSecond,
          decryptMbPerSecond: decrypt.mbPerSecond,
          encryptKeyDerivation: encrypt.keyDerivation,
          decryptKeyDerivation: decrypt.keyDerivation,
        );
      } finally {
        for (final filePath in [inputPath, fuzzedPath, restoredPath]) {
          final file = File(filePath);
          if (file.existsSync()) file.deleteSync();
        }
      }
    });
  }

  /// Runs one file job to its terminal event and splits the wall time at
  /// the first chunk event: what follows it is chunks (and the commit)
  /// only; what precedes it is Argon2id plus one chunk. MB/s is bytes per
  /// microsecond.
  Future<({double mbPerSecond, Duration keyDerivation})> _timeFileJob(
    int sizeBytes,
    Stream<rust_files.FileProgress> Function(rust_files.FileJob job) start,
  ) async {
    final handler = await _startFileJob(start);
    final stopwatch = Stopwatch()..start();
    Duration? firstChunkAt;
    var firstChunkProgress = 0.0;
    await for (final event in handler.progressStream) {
      if (event.errorMessage != null) {
        throw StateError('benchmark job failed: ${event.errorMessage}');
      }
      if (firstChunkAt == null && event.progress > 0) {
        firstChunkAt = stopwatch.elapsed;
        firstChunkProgress = event.progress;
      }
      if (event.isComplete) break;
    }
    if (firstChunkAt == null || firstChunkProgress >= 1) {
      throw StateError('benchmark needs at least two chunks');
    }
    final streamed = stopwatch.elapsed - firstChunkAt;
    final streamedBytes = sizeBytes * (1 - firstChunkProgress);
    final chunkShare =
        streamed * (firstChunkProgress / (1 - firstChunkProgress));
    return (
      mbPerSecond: streamedBytes / streamed.inMicroseconds,
      keyDerivation: firstChunkAt - chunkShare,
    );
  }

  /// Whether the file at [filePath] is exactly [count] copies of [block].
  Future<bool> _isRepetitionOf(
    Uint8List block,
    String filePath,
    int count,
  ) async {
    final file = await File(filePath).open();
    try {
      if (await file.length() != block.length * count) return false;
      for (var i = 0; i < count; i++) {
        final read = await file.read(block.length);
        for (var j = 0; j < block.length; j++) {
          if (read[j] != block[j]) return false;
        }
      }
      return true;
    } finally {
      await file.close();
    }
  }

  /// Seals [bytes] of one [row] of [chatId]'s message history under that
  /// chat's own history key (0x20 blob) for at-rest storage on this device
  /// only. [row] binds the seal to its row (the row's direction byte and
  /// blob text), so it opens nowhere else; a chat the store does not know is
  /// `unknownChat`.
  Future<CryptoCoreResponse<Uint8List>> sealLocal({
    required String chatId,
    required Uint8List row,
    required Uint8List bytes,
  }) {
    return _withCore(
      (core) => core.sealLocal(chatId: chatId, row: row, bytes: bytes),
    );
  }

  /// Inverse of [sealLocal] for the same chat and row; a tampered blob, or
  /// one made for another chat or row, is `corrupt`, a deleted chat's is
  /// `unknownChat`.
  Future<CryptoCoreResponse<Uint8List>> openLocal({
    required String chatId,
    required Uint8List row,
    required Uint8List blob,
  }) {
    return _withCore(
      (core) => core.openLocal(chatId: chatId, row: row, blob: blob),
    );
  }

  /// Seals the app setting [name] under the store key, so a setting that
  /// guards the app (the auto-lock times) cannot be changed by editing a
  /// file. Needs the open store.
  Future<CryptoCoreResponse<Uint8List>> sealSetting({
    required String name,
    required Uint8List bytes,
  }) {
    return _withCore((core) => core.sealSetting(name: name, bytes: bytes));
  }

  /// Inverse of [sealSetting]; a tampered blob or another store's is
  /// `corrupt`.
  Future<CryptoCoreResponse<Uint8List>> openSetting({
    required String name,
    required Uint8List blob,
  }) {
    return _withCore((core) => core.openSetting(name: name, blob: blob));
  }

  /// The chat's 60-digit safety number (12 groups of 5, space-separated)
  /// and the version of its computation — identical on both sides once the
  /// peer's key is known; a chat without a peer yet is `unknownChat`.
  Future<CryptoCoreResponse<SafetyNumber>> safetyNumber(String chatId) {
    return _withCore((core) => core.safetyNumber(chatId: chatId));
  }

  /// Records whether the user compared the safety number with the peer. The
  /// flag lives in the chat's core state, so it resets with the keys on a
  /// re-pair; a chat without a peer is `unknownChat`.
  Future<CryptoCoreResponse<void>> markVerified({
    required String chatId,
    required bool verified,
  }) {
    return _withCore(
      (core) => core.markVerified(chatId: chatId, verified: verified),
    );
  }

  /// The flag [markVerified] set; `false` for a chat that was never marked.
  Future<CryptoCoreResponse<bool>> isVerified(String chatId) {
    return _withCore((core) => core.isVerified(chatId: chatId));
  }

  /// Draws a fresh vault key and wraps it under the master key: the master
  /// [masterPassword] opens [passwordWrap] (one Argon2id run). The default
  /// vault — the master password opens it. Queued with the store-key calls.
  Future<CryptoCoreResponse<CryptoCoreVaultInit>> vaultInitWithMaster({
    required Uint8List passwordWrap,
    required String masterPassword,
  }) {
    return _serialized(() async {
      final created = await rust_vault.vaultInitWithMaster(
        passwordWrap: passwordWrap,
        masterPassword: masterPassword,
      );
      return CryptoCoreVaultInit(key: created.key, wrapped: created.wrapped);
    });
  }

  /// Draws a fresh vault key and wraps it under the vault's own [password]
  /// (a 0x10 blob). With a [recoveryLock] (the 0x20 the app keeps beside the
  /// recovery wrap) the key is also sealed to the recovery lock, so the
  /// recovery key opens this vault. Needs the open store.
  Future<CryptoCoreResponse<CryptoCoreVaultInit>> vaultInit(
    String password, {
    Uint8List? recoveryLock,
  }) {
    return _serializedWithCore((core) async {
      final created = await rust_vault.vaultInit(
        core: core,
        password: password,
        recoveryLock: recoveryLock,
      );
      return CryptoCoreVaultInit(
        key: created.key,
        wrapped: created.wrapped,
        recovery: created.recovery,
      );
    });
  }

  /// Whether the vault whose key is [wrapped] has its own password (`true`)
  /// or opens with the master password (`false`). Reads the blob's type
  /// only.
  CryptoCoreResponse<bool> vaultUsesOwnPassword(Uint8List wrapped) {
    return _guardedSync(
      () => rust_vault.vaultUsesOwnPassword(wrapped: wrapped),
    );
  }

  /// Unwraps a vault key wrapped under its own password; a wrong password
  /// (or a tampered blob) is `wrongPassword`.
  Future<CryptoCoreResponse<VaultKey>> vaultUnlock({
    required Uint8List wrapped,
    required String password,
  }) {
    return _serialized(
      () => rust_vault.vaultUnlock(password: password, wrapped: wrapped),
    );
  }

  /// Unwraps a vault key wrapped under the master key with the master
  /// password; a wrong one is `wrongPassword`.
  Future<CryptoCoreResponse<VaultKey>> vaultUnlockWithMaster({
    required Uint8List passwordWrap,
    required String masterPassword,
    required Uint8List wrapped,
  }) {
    return _serialized(
      () => rust_vault.vaultUnlockWithMaster(
        passwordWrap: passwordWrap,
        masterPassword: masterPassword,
        wrapped: wrapped,
      ),
    );
  }

  /// Re-wraps a vault key under its own password from [oldPassword] to
  /// [newPassword] (fresh salt and nonce). The key does not change, so no
  /// vault item is re-encrypted; the caller stores the returned blob in
  /// place of [wrapped].
  Future<CryptoCoreResponse<Uint8List>> vaultRewrap({
    required Uint8List wrapped,
    required String oldPassword,
    required String newPassword,
  }) {
    return _serialized(
      () => rust_vault.vaultRewrap(
        oldPassword: oldPassword,
        newPassword: newPassword,
        wrapped: wrapped,
      ),
    );
  }

  /// Gives a vault the master password opens its own [newPassword]; the
  /// answer's `wrapped` replaces [wrapped]. With a [recoveryLock] the answer
  /// also carries the key sealed to the recovery lock. Needs the open store.
  Future<CryptoCoreResponse<CryptoCoreVaultWrapping>> vaultUseOwnPassword({
    required Uint8List passwordWrap,
    required String masterPassword,
    required Uint8List wrapped,
    required String newPassword,
    Uint8List? recoveryLock,
  }) {
    return _serializedWithCore((core) async {
      final changed = await rust_vault.vaultUseOwnPassword(
        core: core,
        passwordWrap: passwordWrap,
        masterPassword: masterPassword,
        wrapped: wrapped,
        newPassword: newPassword,
        recoveryLock: recoveryLock,
      );
      return CryptoCoreVaultWrapping(
        wrapped: changed.wrapped,
        recovery: changed.recovery,
      );
    });
  }

  /// Seals the key of a vault with its own password to [recoveryLock] (a new
  /// recovery key's lock): [vaultPassword] opens [wrapped]. A wrong password
  /// is `wrongPassword`; a vault under the master key `unsupportedFormat`.
  Future<CryptoCoreResponse<Uint8List>> vaultSealForRecovery({
    required Uint8List recoveryLock,
    required Uint8List wrapped,
    required String vaultPassword,
  }) {
    return _serializedWithCore(
      (core) => rust_vault.vaultSealForRecovery(
        core: core,
        recoveryLock: recoveryLock,
        wrapped: wrapped,
        vaultPassword: vaultPassword,
      ),
    );
  }

  /// The recovery key opens the vault's [recovery] copy and gives the vault
  /// [newPassword]; the answer's `wrapped` replaces the stored wrapping. A
  /// typo is `corrupt`, another device's key `wrongPassword`.
  Future<CryptoCoreResponse<CryptoCoreVaultInit>> vaultRecover({
    required Uint8List recovery,
    required String recoveryKey,
    required String newPassword,
  }) {
    return _serialized(() async {
      final recovered = await rust_vault.vaultRecover(
        recovery: recovery,
        recoveryKey: recoveryKey,
        newPassword: newPassword,
      );
      return CryptoCoreVaultInit(
        key: recovered.key,
        wrapped: recovered.wrapped,
      );
    });
  }

  /// The recovery key opens the vault's [recovery] copy and the master key
  /// ([recoveryWrap]), and puts the vault back under the master key.
  Future<CryptoCoreResponse<CryptoCoreVaultInit>> vaultRecoverToMaster({
    required Uint8List recoveryWrap,
    required Uint8List recovery,
    required String recoveryKey,
  }) {
    return _serialized(() async {
      final recovered = await rust_vault.vaultRecoverToMaster(
        recoveryWrap: recoveryWrap,
        recovery: recovery,
        recoveryKey: recoveryKey,
      );
      return CryptoCoreVaultInit(
        key: recovered.key,
        wrapped: recovered.wrapped,
      );
    });
  }

  /// Puts a vault with its own password back under the master key; the
  /// answer replaces [wrapped].
  Future<CryptoCoreResponse<Uint8List>> vaultUseMasterPassword({
    required Uint8List wrapped,
    required String vaultPassword,
    required Uint8List passwordWrap,
    required String masterPassword,
  }) {
    return _serialized(
      () => rust_vault.vaultUseMasterPassword(
        wrapped: wrapped,
        vaultPassword: vaultPassword,
        passwordWrap: passwordWrap,
        masterPassword: masterPassword,
      ),
    );
  }

  /// Seals version [version] of the item [itemId] under [key] (0x20 blob,
  /// AAD `vault-item` ‖ version ‖ id); a closed handle answers `storeLocked`.
  Future<CryptoCoreResponse<Uint8List>> vaultSeal({
    required VaultKey key,
    required String itemId,
    required int version,
    required Uint8List bytes,
  }) {
    return _guarded(
      () => rust_vault.vaultSeal(
        key: key,
        itemId: itemId,
        version: version,
        bytes: bytes,
      ),
    );
  }

  /// Inverse of [vaultSeal] for the same item and version; a tampered or
  /// foreign blob — another item's or another version's — is `corrupt`.
  Future<CryptoCoreResponse<Uint8List>> vaultOpen({
    required VaultKey key,
    required String itemId,
    required int version,
    required Uint8List blob,
  }) {
    return _guarded(
      () => rust_vault.vaultOpen(
        key: key,
        itemId: itemId,
        version: version,
        blob: blob,
      ),
    );
  }

  /// [passwordSealText] for arbitrary bytes, as the binary 0x05 blob — the
  /// vault's optional custom-password layer over a sealed item.
  Future<CryptoCoreResponse<Uint8List>> passwordSealBytes({
    required String password,
    required Uint8List bytes,
  }) {
    return _guarded(
      () => rust_passwords.passwordSealBytes(password: password, bytes: bytes),
    );
  }

  /// Inverse of [passwordSealBytes]; the same error rules as
  /// [passwordOpenText].
  Future<CryptoCoreResponse<Uint8List>> passwordOpenBytes({
    required String password,
    required Uint8List blob,
  }) {
    return _guarded(
      () => rust_passwords.passwordOpenBytes(password: password, blob: blob),
    );
  }

  /// Every chat call: no Argon2, so nothing to queue; a closed store answers
  /// `storeLocked` instead of reaching a null handle.
  Future<CryptoCoreResponse<T>> _withCore<T>(
    Future<T> Function(rust_core.CryptoCore core) call,
  ) {
    final core = _core;
    if (core == null) {
      return Future.value(
        const CryptoCoreFailure(CryptoCoreFailureType.storeLocked),
      );
    }
    return _guarded(() => call(core));
  }

  /// An Argon2id call that also needs the open store: queued like
  /// [_serialized]; the handle is read when the call's turn comes, and a
  /// closed store answers `storeLocked`.
  Future<CryptoCoreResponse<T>> _serializedWithCore<T>(
    Future<T> Function(rust_core.CryptoCore core) call,
  ) {
    return _serialized(() {
      final core = _core;
      if (core == null) return Future<T>.error(CoreError.storeLocked);
      return call(core);
    });
  }

  Future<CryptoCoreResponse<T>> _serialized<T>(Future<T> Function() call) {
    final result = _argon2Queue.then((_) => _guarded(call));
    _argon2Queue = result.then((_) {});
    return result;
  }

  Future<CryptoCoreResponse<T>> _guarded<T>(Future<T> Function() call) async {
    try {
      return CryptoCoreSuccess(await call());
    } on CoreError catch (error) {
      return CryptoCoreFailure(_failureTypeOf(error));
    } catch (ex) {
      logger.e('ERROR: $ex');
      return const CryptoCoreFailure(CryptoCoreFailureType.internal);
    }
  }

  CryptoCoreResponse<T> _guardedSync<T>(T Function() call) {
    try {
      return CryptoCoreSuccess(call());
    } on CoreError catch (error) {
      return CryptoCoreFailure(_failureTypeOf(error));
    } catch (ex) {
      logger.e('ERROR: $ex');
      return const CryptoCoreFailure(CryptoCoreFailureType.internal);
    }
  }

  /// The `CoreError` display text a file job's terminal event carries (frb
  /// runs stream functions unawaited, so an error cannot be thrown to Dart).
  static CryptoCoreFailureType _failureTypeOfText(String text) {
    return switch (text) {
      'wrong password' => CryptoCoreFailureType.wrongPassword,
      'corrupt' => CryptoCoreFailureType.corrupt,
      'unsupported format' => CryptoCoreFailureType.unsupportedFormat,
      'io' => CryptoCoreFailureType.io,
      'store locked' => CryptoCoreFailureType.storeLocked,
      _ => CryptoCoreFailureType.internal,
    };
  }

  static CryptoCoreFailureType _failureTypeOf(CoreError error) {
    return switch (error) {
      CoreError.unsupportedFormat => CryptoCoreFailureType.unsupportedFormat,
      CoreError.invalidSignature => CryptoCoreFailureType.invalidSignature,
      CoreError.invitationAlreadyUsed =>
        CryptoCoreFailureType.invitationAlreadyUsed,
      CoreError.wrongChat => CryptoCoreFailureType.wrongChat,
      CoreError.replay => CryptoCoreFailureType.replay,
      CoreError.tooOld => CryptoCoreFailureType.tooOld,
      CoreError.corrupt => CryptoCoreFailureType.corrupt,
      CoreError.wrongPassword => CryptoCoreFailureType.wrongPassword,
      CoreError.storeLocked => CryptoCoreFailureType.storeLocked,
      CoreError.unknownChat => CryptoCoreFailureType.unknownChat,
      CoreError.io => CryptoCoreFailureType.io,
      CoreError.cancelled => CryptoCoreFailureType.cancelled,
      CoreError.internal => CryptoCoreFailureType.internal,
    };
  }
}
