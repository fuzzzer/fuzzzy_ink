import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

class _MockCrypto extends Mock implements CryptoCoreService {}

class _MockMessages extends Mock implements MessageDataRepository {}

class _MockStore extends Mock implements UserFileStore {}

class _MockQueue extends MockCubit<FileProcessingState>
    implements FileProcessingCubit<FileEncryptionOption> {}

const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';
final _nino = ChatGeneralData(
  chatId: _chatId,
  chatName: 'Nino',
  setupStatus: ChatSetupStatus.connected,
  didAcceptInvitation: false,
);
const _goodPassword = 'violet-harbor-lantern-91';

MessageData _row() => MessageData(
      id: 0,
      chatId: _chatId,
      type: MessageType.text,
      encryptedMessage: '',
      decryptedMessage: '',
      sentAt: DateTime(2026),
      isSent: true,
    );

void main() {
  late _MockCrypto crypto;
  late _MockMessages messages;
  late _MockStore store;
  late _MockQueue queue;
  late StreamController<NewMessageAdded> added;
  late Directory dir;
  late String picked;

  setUpAll(() => registerFallbackValue(_row()));

  setUp(() {
    crypto = _MockCrypto();
    messages = _MockMessages();
    store = _MockStore();
    queue = _MockQueue();
    added = StreamController<NewMessageAdded>.broadcast();
    when(() => messages.newMessageUpdates).thenAnswer((_) => added.stream);
    when(() => queue.state).thenReturn(const FileProcessingState());
    dir = Directory.systemTemp.createTempSync('lock_flow_');
    picked = path.join(dir.path, 'beach-photo.jpg');
    File(picked).writeAsBytesSync(List.filled(2048, 7));
    when(() => store.basicsFolder()).thenAnswer((_) async => dir.path);
    when(() => store.resolve(any())).thenAnswer(
      (call) => path.join(dir.path, call.positionalArguments[0] as String),
    );
    when(() => store.discardPickedCopy(any())).thenAnswer((_) async {});
  });

  tearDown(() async {
    await added.close();
    dir.deleteSync(recursive: true);
  });

  LockFlowCubit cubitFor(LockTarget target) => LockFlowCubit(
        target: target,
        cryptoCoreService: crypto,
        messageDataRepository: messages,
        userFileStore: store,
        passwordStrengthService: PasswordStrengthService(),
        chatFileQueue: queue,
      );

  group('a message for a person', () {
    test('is locked on their session and kept in their history', () async {
      when(() => crypto.encryptText(chatId: _chatId, text: 'see you at 6'))
          .thenAnswer((_) async => const CryptoCoreSuccess('Fuzz/AwEC'));
      when(() => messages.addMessage(any(), notifyListeners: true))
          .thenAnswer((_) async => 42);

      final cubit = cubitFor(LockTarget.person(_nino));
      await cubit.lock(text: 'see you at 6');

      expect(cubit.state.phase, LockPhase.locked);
      expect(cubit.state.item!.lockedText, 'Fuzz/AwEC');
      expect(cubit.state.item!.historyRowId, 42);
      final row = verify(
        () => messages.addMessage(captureAny(), notifyListeners: true),
      ).captured.single as MessageData;
      expect(row.isSent, isTrue);
      expect(row.encryptedMessage, 'AwEC');
      expect(row.decryptedMessage, 'see you at 6');
      await cubit.close();
    });

    test('an empty one asks for something first and spends nothing', () async {
      final cubit = cubitFor(LockTarget.person(_nino));
      await cubit.lock(text: '   ');
      expect(cubit.state.failure, LockFailure.writeSomethingFirst);
      expect(cubit.state.phase, LockPhase.what);
      verifyNever(
        () => crypto.encryptText(
          chatId: any(named: 'chatId'),
          text: any(named: 'text'),
        ),
      );
      await cubit.close();
    });

    test('a core failure stays on What with one line', () async {
      when(
        () => crypto.encryptText(
          chatId: any(named: 'chatId'),
          text: any(named: 'text'),
        ),
      ).thenAnswer(
        (_) async => const CryptoCoreFailure(CryptoCoreFailureType.internal),
      );
      final cubit = cubitFor(LockTarget.person(_nino));
      await cubit.lock(text: 'hi');
      expect(cubit.state.phase, LockPhase.what);
      expect(cubit.state.failure, LockFailure.failed);
      expect(cubit.state.isBusy, isFalse);
      await cubit.close();
    });

    test('Share finished moves Share back and Done forward', () async {
      when(
        () => crypto.encryptText(
          chatId: any(named: 'chatId'),
          text: any(named: 'text'),
        ),
      ).thenAnswer((_) async => const CryptoCoreSuccess('Fuzz/AwEC'));
      when(() => messages.addMessage(any(), notifyListeners: true))
          .thenAnswer((_) async => 1);
      final cubit = cubitFor(LockTarget.person(_nino));
      cubit.markShared();
      expect(cubit.state.isShared, isFalse, reason: 'nothing locked yet');
      await cubit.lock(text: 'hi');
      cubit.markShared();
      expect(cubit.state.isShared, isTrue);
      expect(cubit.state.sharedByCopy, isFalse);
      cubit.markShared(copied: true);
      expect(cubit.state.sharedByCopy, isTrue);
      await cubit.close();
    });
  });

  group('with a password', () {
    test('a password below Good is refused before the core', () async {
      final cubit = cubitFor(const LockTarget.password());
      await cubit.lock(text: 'hello', password: 'abc');
      expect(cubit.state.failure, LockFailure.passwordNotGood);
      verifyNever(
        () => crypto.passwordSealText(
          password: any(named: 'password'),
          text: any(named: 'text'),
        ),
      );
      await cubit.close();
    });

    test('text is sealed and kept in no history', () async {
      when(
        () => crypto.passwordSealText(password: _goodPassword, text: 'hello'),
      ).thenAnswer((_) async => const CryptoCoreSuccess('Fuzz/BQ'));
      final cubit = cubitFor(const LockTarget.password());
      await cubit.lock(text: 'hello', password: _goodPassword);
      expect(cubit.state.phase, LockPhase.locked);
      expect(cubit.state.item!.lockedText, 'Fuzz/BQ');
      expect(cubit.state.item!.historyRowId, isNull);
      verifyNever(() => messages.addMessage(any(), notifyListeners: true));
      await cubit.close();
    });

    test('a file goes to the sealed Basics folder with real progress',
        () async {
      final events = StreamController<FileProcessingProgress>();
      var paused = 0;
      var resumed = 0;
      when(
        () => crypto.encryptFileWithPassword(
          password: _goodPassword,
          inputPath: picked,
          outputPath: any(named: 'outputPath'),
        ),
      ).thenAnswer(
        (_) async => CryptoCoreSuccess(
          FileProcessingHandler(
            progressStream: events.stream,
            pause: () => paused++,
            resume: () => resumed++,
            cancel: () {},
          ),
        ),
      );

      final cubit = cubitFor(const LockTarget.password());
      await cubit.chooseFile(picked);
      expect(cubit.state.kind, LockKind.file);
      expect(cubit.state.file!.size, 2048);
      await cubit.lock(password: _goodPassword);
      expect(cubit.state.phase, LockPhase.working);

      events.add(FileProcessingProgress(progress: 0.4));
      await pumpEventQueue();
      expect(cubit.state.progress, 0.4);
      cubit.pause();
      expect(cubit.state.isPaused, isTrue);
      cubit.resume();
      expect((paused, resumed), (1, 1));

      events.add(FileProcessingProgress(progress: 1, isComplete: true));
      await pumpEventQueue();
      expect(cubit.state.phase, LockPhase.locked);
      expect(
        cubit.state.item!.lockedFilePath,
        path.join(dir.path, 'beach-photo.jpg.fuzz'),
      );
      expect(cubit.state.item!.fileName, 'beach-photo.jpg');
      verify(() => store.discardPickedCopy(picked)).called(1);
      await events.close();
      await cubit.close();
    });

    test('a cancelled file says nothing was kept', () async {
      final events = StreamController<FileProcessingProgress>();
      when(
        () => crypto.encryptFileWithPassword(
          password: any(named: 'password'),
          inputPath: any(named: 'inputPath'),
          outputPath: any(named: 'outputPath'),
        ),
      ).thenAnswer(
        (_) async => CryptoCoreSuccess(
          FileProcessingHandler(
            progressStream: events.stream,
            pause: () {},
            resume: () {},
            cancel: () => events.add(
              FileProcessingProgress(progress: 0.2, isCancelled: true),
            ),
          ),
        ),
      );
      final cubit = cubitFor(const LockTarget.password());
      await cubit.chooseFile(picked);
      await cubit.lock(password: _goodPassword);
      cubit.cancel();
      await pumpEventQueue();
      expect(cubit.state.phase, LockPhase.what);
      expect(cubit.state.failure, LockFailure.stopped);
      await events.close();
      await cubit.close();
    });
  });

  group('a file for a person', () {
    test('joins the file queue, follows it, and catches its history row',
        () async {
      final queueStates = StreamController<FileProcessingState>();
      whenListen(queue, queueStates.stream);
      final data = FileProcessingData(
        chatId: _chatId,
        chatName: 'Nino',
        inputFilePath: picked,
        encryptionStartTime: DateTime(2026),
      );

      final cubit = cubitFor(LockTarget.person(_nino));
      await cubit.chooseFile(picked);
      await cubit.lock();
      expect(cubit.state.phase, LockPhase.working);
      verify(
        () => queue.addFilesToProcess(
          chatId: _chatId,
          chatName: 'Nino',
          filePaths: [picked],
        ),
      ).called(1);

      queueStates.add(
        FileProcessingState(currentProcessingFile: data, progress: 0.5),
      );
      await pumpEventQueue();
      expect(cubit.state.progress, 0.5);

      cubit.pause();
      verify(() => queue.pauseFile()).called(1);
      cubit.resume();
      verify(() => queue.resumeFile()).called(1);

      const stored = 'chats/Nino (x)/beach-photo.jpg.fuzz';
      queueStates.add(
        FileProcessingState(
          processedFiles: [
            data.copyWith(
              status: FileProcessingStatus.completed,
              outputFilePath: stored,
            ),
          ],
        ),
      );
      await pumpEventQueue();
      expect(cubit.state.phase, LockPhase.locked);
      expect(cubit.state.item!.lockedFilePath, path.join(dir.path, stored));

      added.add(
        NewMessageAdded(
          message: _row().copyWith(
            id: 7,
            type: MessageType.file,
            encryptedMessage: stored,
          ),
        ),
      );
      await pumpEventQueue();
      expect(cubit.state.item!.historyRowId, 7);
      await queueStates.close();
      await cubit.close();
    });

    test('a stopped file goes back to What', () async {
      final queueStates = StreamController<FileProcessingState>();
      whenListen(queue, queueStates.stream);
      final cubit = cubitFor(LockTarget.person(_nino));
      await cubit.chooseFile(picked);
      await cubit.lock();
      cubit.cancel();
      verify(() => queue.cancelFile()).called(1);
      queueStates.add(
        FileProcessingState(
          processedFiles: [
            FileProcessingData(
              chatId: _chatId,
              chatName: 'Nino',
              inputFilePath: picked,
              encryptionStartTime: DateTime(2026),
              status: FileProcessingStatus.canceled,
            ),
          ],
        ),
      );
      await pumpEventQueue();
      expect(cubit.state.phase, LockPhase.what);
      expect(cubit.state.failure, LockFailure.stopped);
      await queueStates.close();
      await cubit.close();
    });

    test('no file chosen asks for one', () async {
      final cubit = cubitFor(LockTarget.person(_nino))
        ..chooseKind(LockKind.file);
      await cubit.lock();
      expect(cubit.state.failure, LockFailure.chooseFileFirst);
      await cubit.close();
    });
  });
}
