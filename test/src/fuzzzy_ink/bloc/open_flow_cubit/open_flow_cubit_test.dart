import 'dart:async';
import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as path;

class _MockCrypto extends Mock implements CryptoCoreService {}

class _MockChats extends Mock implements ChatGeneralDataListRepository {}

class _MockMessages extends Mock implements MessageDataRepository {}

class _MockStore extends Mock implements UserFileStore {}

class _MockQueue extends MockCubit<FileProcessingState>
    implements FileProcessingCubit<FileDecryptionOption> {}

const _ninoId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';
const _momId = '0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d';
const _strangerId = '11111111-2222-4333-8444-555555555555';

final _nino = ChatGeneralData(
  chatId: _ninoId,
  chatName: 'Nino',
  setupStatus: ChatSetupStatus.connected,
  didAcceptInvitation: false,
);
final _mom = ChatGeneralData(
  chatId: _momId,
  chatName: 'Mom',
  setupStatus: ChatSetupStatus.invited,
  didAcceptInvitation: false,
);

MessageData _row() => MessageData(
      id: 0,
      chatId: _ninoId,
      type: MessageType.text,
      encryptedMessage: '',
      decryptedMessage: '',
      sentAt: DateTime(2026),
      isSent: false,
    );

void main() {
  late _MockCrypto crypto;
  late _MockChats chats;
  late _MockMessages messages;
  late _MockStore store;
  late _MockQueue queue;
  late StreamController<NewMessageAdded> added;
  late Directory dir;

  setUpAll(() => registerFallbackValue(_row()));

  setUp(() {
    crypto = _MockCrypto();
    chats = _MockChats();
    messages = _MockMessages();
    store = _MockStore();
    queue = _MockQueue();
    added = StreamController<NewMessageAdded>.broadcast();
    dir = Directory.systemTemp.createTempSync('open_flow_');
    when(() => messages.newMessageUpdates).thenAnswer((_) => added.stream);
    when(() => queue.state).thenReturn(const FileProcessingState());
    when(() => chats.getAllChats()).thenAnswer((_) async => [_nino, _mom]);
    when(() => chats.getChatById(_ninoId)).thenAnswer((_) async => _nino);
    when(() => chats.getChatById(_momId)).thenAnswer((_) async => _mom);
    when(() => chats.getChatById(_strangerId)).thenAnswer((_) async => null);
    when(() => store.discardPickedCopy(any())).thenAnswer((_) async {});
    when(() => store.wipe(any())).thenAnswer((_) async {});
    when(() => store.newHandoffPath(any())).thenAnswer(
      (call) async =>
          path.join(dir.path, call.positionalArguments[0] as String),
    );
  });

  tearDown(() async {
    await added.close();
    dir.deleteSync(recursive: true);
  });

  OpenFlowCubit build() => OpenFlowCubit(
        cryptoCoreService: crypto,
        chatRepository: chats,
        messageDataRepository: messages,
        userFileStore: store,
        receiveQueue: queue,
      );

  void peekAnswers(CryptoCorePeek peek) {
    when(
      () => crypto.peekPasted(
        text: any(named: 'text'),
        chatIds: any(named: 'chatIds'),
      ),
    ).thenAnswer((_) async => CryptoCoreSuccess(peek));
  }

  void decryptAnswers(CryptoCoreResponse<String> res) {
    when(
      () => crypto.decryptText(
        chatId: any(named: 'chatId'),
        blob: any(named: 'blob'),
      ),
    ).thenAnswer((_) async => res);
  }

  group('a pasted message', () {
    test('is recognised among connected people only, opened and kept',
        () async {
      peekAnswers(
        const CryptoCorePeek(kind: CryptoCorePeekKind.message, chatId: _ninoId),
      );
      decryptAnswers(const CryptoCoreSuccess('see you at 6'));
      when(() => messages.addMessage(any(), notifyListeners: true))
          .thenAnswer((_) async => 9);

      final cubit = build();
      await cubit.open(const OpenPastedText('  Fuzz/AwEC \n'));

      verify(
        () => crypto.peekPasted(text: 'Fuzz/AwEC', chatIds: [_ninoId]),
      ).called(1);
      verify(() => crypto.decryptText(chatId: _ninoId, blob: 'Fuzz/AwEC'))
          .called(1);
      expect(cubit.state.phase, OpenPhase.openedText);
      expect(cubit.state.openedText, 'see you at 6');
      expect(cubit.state.chat, _nino);
      expect(cubit.state.historyRowId, 9);
      final row = verify(
        () => messages.addMessage(captureAny(), notifyListeners: true),
      ).captured.single as MessageData;
      expect((row.isSent, row.encryptedMessage), (false, 'AwEC'));
      expect(cubit.state.toString(), isNot(contains('see you')));
      await cubit.close();
    });

    for (final (failure, problem) in [
      (CryptoCoreFailureType.replay, OpenProblem.alreadyOpened),
      (CryptoCoreFailureType.tooOld, OpenProblem.tooOld),
      (CryptoCoreFailureType.corrupt, OpenProblem.damaged),
      (CryptoCoreFailureType.wrongChat, OpenProblem.damaged),
      (CryptoCoreFailureType.storeLocked, OpenProblem.failed),
    ]) {
      test('$failure is "$problem", with the person', () async {
        peekAnswers(
          const CryptoCorePeek(
            kind: CryptoCorePeekKind.message,
            chatId: _ninoId,
          ),
        );
        decryptAnswers(CryptoCoreFailure(failure));
        final cubit = build();
        await cubit.open(const OpenPastedText('Fuzz/AwEC'));
        expect(cubit.state.phase, OpenPhase.problem);
        expect(cubit.state.problem, problem);
        expect(cubit.state.chat, _nino);
        verifyNever(() => messages.addMessage(any(), notifyListeners: true));
        await cubit.close();
      });
    }

    test('one from none of your people cannot be opened', () async {
      peekAnswers(const CryptoCorePeek(kind: CryptoCorePeekKind.message));
      final cubit = build();
      await cubit.open(const OpenPastedText('Fuzz/AwEC'));
      expect(cubit.state.problem, OpenProblem.damaged);
      verifyNever(
        () => crypto.decryptText(
          chatId: any(named: 'chatId'),
          blob: any(named: 'blob'),
        ),
      );
      await cubit.close();
    });
  });

  group('a message link (security review 2026-10-26)', () {
    test('for someone not on this phone is "Not from your people"', () async {
      peekAnswers(const CryptoCorePeek(kind: CryptoCorePeekKind.message));
      final cubit = build();
      await cubit.open(const OpenMessageLink(encryptedMessage: 'AwEC'));
      expect(cubit.state.problem, OpenProblem.notFromYourPeople);
      await cubit.close();
    });

    test(
        'for a person: recognised by the peek, nothing opened until Open, '
        'then opened once', () async {
      peekAnswers(
        const CryptoCorePeek(kind: CryptoCorePeekKind.message, chatId: _ninoId),
      );
      decryptAnswers(const CryptoCoreSuccess('hi'));
      when(() => messages.addMessage(any(), notifyListeners: true))
          .thenAnswer((_) async => 3);
      final cubit = build();
      await cubit.open(const OpenMessageLink(encryptedMessage: 'AwEC'));
      expect(cubit.state.phase, OpenPhase.confirmMessage);
      expect(cubit.state.chat, _nino);
      verify(
        () => crypto.peekPasted(text: 'Fuzz/AwEC', chatIds: [_ninoId]),
      ).called(1);
      verifyNever(
        () => crypto.decryptText(
          chatId: any(named: 'chatId'),
          blob: any(named: 'blob'),
        ),
      );

      await cubit.confirmOpen();
      expect(cubit.state.phase, OpenPhase.openedText);
      verify(() => crypto.decryptText(chatId: _ninoId, blob: 'Fuzz/AwEC'))
          .called(1);
      await cubit.close();
    });

    test('anything but a message under /message opens nothing', () async {
      peekAnswers(
        const CryptoCorePeek(
          kind: CryptoCorePeekKind.acceptance,
          chatId: _ninoId,
        ),
      );
      final cubit = build();
      await cubit.open(const OpenMessageLink(encryptedMessage: 'AgE'));
      expect(cubit.state.problem, OpenProblem.damaged);
      expect(cubit.state.route, isNull);
      await cubit.close();
    });

    test('pasted as text: the paste is the action, it opens at once', () async {
      peekAnswers(
        const CryptoCorePeek(kind: CryptoCorePeekKind.message, chatId: _ninoId),
      );
      decryptAnswers(const CryptoCoreSuccess('hi'));
      when(() => messages.addMessage(any(), notifyListeners: true))
          .thenAnswer((_) async => 3);
      final cubit = build();
      await cubit.open(
        const OpenPastedText('https://ink.fuzzzycore.com/message#AwEC'),
      );
      expect(cubit.state.phase, OpenPhase.openedText);
      verify(() => crypto.decryptText(chatId: _ninoId, blob: 'Fuzz/AwEC'))
          .called(1);
      await cubit.close();
    });
  });

  group('invites and replies', () {
    test("someone else's invite goes on to accepting it", () async {
      peekAnswers(
        const CryptoCorePeek(
          kind: CryptoCorePeekKind.invitation,
          chatId: _strangerId,
        ),
      );
      final cubit = build();
      await cubit.open(const OpenPastedText('Fuzz/AQE'));
      expect(cubit.state.route, isA<OpenRouteInvite>());
      expect((cubit.state.route! as OpenRouteInvite).invitation, 'Fuzz/AQE');
      cubit.routeTaken();
      expect(cubit.state.route, isNull);
      await cubit.close();
    });

    test('an invite link is read as its blob', () async {
      peekAnswers(
        const CryptoCorePeek(
          kind: CryptoCorePeekKind.invitation,
          chatId: _strangerId,
        ),
      );
      final cubit = build();
      await cubit.open(
        const OpenPastedText('https://ink.fuzzzycore.com/invite#AQE'),
      );
      verify(
        () => crypto.peekPasted(text: 'Fuzz/AQE', chatIds: [_ninoId]),
      ).called(1);
      expect(cubit.state.route, isA<OpenRouteInvite>());
      await cubit.close();
    });

    test('my own waiting invite, and one already answered', () async {
      peekAnswers(
        const CryptoCorePeek(
          kind: CryptoCorePeekKind.invitation,
          chatId: _momId,
        ),
      );
      final cubit = build();
      await cubit.open(const OpenPastedText('Fuzz/AQE'));
      expect(cubit.state.problem, OpenProblem.ownInvite);

      peekAnswers(
        const CryptoCorePeek(
          kind: CryptoCorePeekKind.invitation,
          chatId: _ninoId,
        ),
      );
      await cubit.startOver();
      await cubit.open(const OpenPastedText('Fuzz/AQE'));
      expect(cubit.state.problem, OpenProblem.alreadyConnected);
      expect(cubit.state.chat, _nino);
      await cubit.close();
    });

    test('the reply to my invite finishes connecting', () async {
      peekAnswers(
        const CryptoCorePeek(
          kind: CryptoCorePeekKind.acceptance,
          chatId: _momId,
        ),
      );
      final cubit = build();
      await cubit.open(const OpenPastedText('Fuzz/AgE'));
      final route = cubit.state.route! as OpenRouteReply;
      expect((route.chat, route.acceptance), (_mom, 'Fuzz/AgE'));
      await cubit.close();
    });

    test('the same reply again, a second reply, a stranger', () async {
      peekAnswers(
        const CryptoCorePeek(
          kind: CryptoCorePeekKind.acceptance,
          chatId: _ninoId,
        ),
      );
      when(() => chats.isPairedAcceptance(_ninoId, 'Fuzz/same'))
          .thenAnswer((_) async => true);
      when(() => chats.isPairedAcceptance(_ninoId, 'Fuzz/other'))
          .thenAnswer((_) async => false);
      when(() => chats.isPairedAcceptance(_ninoId, 'Fuzz/forged'))
          .thenAnswer((_) async => false);
      when(
        () => crypto.checkAcceptance(chatId: _ninoId, acceptance: 'Fuzz/other'),
      ).thenAnswer((_) async => const CryptoCoreSuccess(null));
      when(
        () =>
            crypto.checkAcceptance(chatId: _ninoId, acceptance: 'Fuzz/forged'),
      ).thenAnswer(
        (_) async => const CryptoCoreFailure(CryptoCoreFailureType.wrongChat),
      );
      final cubit = build();
      await cubit.open(const OpenPastedText('Fuzz/same'));
      expect(cubit.state.problem, OpenProblem.alreadyConnected);
      await cubit.startOver();
      await cubit.open(const OpenPastedText('Fuzz/other'));
      expect(cubit.state.route, isA<OpenRouteSecondReply>());
      // A reply that does not answer this chat's invite raises no alarm
      // (security review 2026-10-26).
      cubit.routeTaken();
      await cubit.open(const OpenPastedText('Fuzz/forged'));
      expect(cubit.state.route, isNull);
      expect(cubit.state.problem, OpenProblem.damaged);
      await cubit.startOver();

      peekAnswers(
        const CryptoCorePeek(
          kind: CryptoCorePeekKind.acceptance,
          chatId: _strangerId,
        ),
      );
      cubit.routeTaken();
      await cubit.open(const OpenPastedText('Fuzz/AgE'));
      expect(cubit.state.problem, OpenProblem.notFromYourPeople);
      await cubit.close();
    });
  });

  group('everything else', () {
    for (final (kind, problem) in [
      (CryptoCorePeekKind.newerVersion, OpenProblem.newerApp),
      (CryptoCorePeekKind.notFuzzzy, OpenProblem.notFuzzzy),
      (CryptoCorePeekKind.damaged, OpenProblem.damaged),
    ]) {
      test('$kind is "$problem"', () async {
        peekAnswers(CryptoCorePeek(kind: kind));
        final cubit = build();
        await cubit.open(const OpenPastedText('something'));
        expect(cubit.state.problem, problem);
        await cubit.close();
      });
    }

    test('an empty paste is not Fuzzzy Ink', () async {
      final cubit = build();
      await cubit.open(const OpenPastedText('   '));
      expect(cubit.state.problem, OpenProblem.notFuzzzy);
      await cubit.close();
    });
  });

  group('password items', () {
    test('text asks for its password; a wrong one says so', () async {
      peekAnswers(const CryptoCorePeek(kind: CryptoCorePeekKind.passwordText));
      when(
        () => crypto.passwordOpenText(password: 'wrong', blob: 'Fuzz/BQ'),
      ).thenAnswer(
        (_) async =>
            const CryptoCoreFailure(CryptoCoreFailureType.wrongPassword),
      );
      when(
        () => crypto.passwordOpenText(password: 'right', blob: 'Fuzz/BQ'),
      ).thenAnswer((_) async => const CryptoCoreSuccess('hello'));

      final cubit = build();
      await cubit.open(const OpenPastedText('Fuzz/BQ'));
      expect(cubit.state.phase, OpenPhase.password);
      await cubit.openWithPassword('wrong');
      expect(cubit.state.phase, OpenPhase.password);
      expect(cubit.state.isPasswordWrong, isTrue);
      await cubit.openWithPassword('right');
      expect(cubit.state.phase, OpenPhase.openedText);
      expect(cubit.state.openedText, 'hello');
      expect(cubit.state.chat, isNull);
      verifyNever(() => messages.addMessage(any(), notifyListeners: true));
      await cubit.close();
    });

    test('a file opens into one hand-off copy, wiped when Open closes',
        () async {
      final file = path.join(dir.path, 'notes.txt.fuzz');
      File(file).writeAsStringSync('x');
      when(
        () => crypto.peekFile(
          inputPath: file,
          chatIds: any(named: 'chatIds'),
        ),
      ).thenAnswer(
        (_) async => const CryptoCoreSuccess(
          CryptoCorePeek(kind: CryptoCorePeekKind.passwordFile),
        ),
      );
      final events = StreamController<FileProcessingProgress>();
      when(
        () => crypto.decryptFileWithPassword(
          password: 'pw',
          inputPath: file,
          outputPath: path.join(dir.path, 'notes.txt'),
        ),
      ).thenAnswer(
        (_) async => CryptoCoreSuccess(
          FileProcessingHandler(
            progressStream: events.stream,
            pause: () {},
            resume: () {},
            cancel: () {},
          ),
        ),
      );

      final cubit = build();
      await cubit.open(OpenChosenFile(file));
      expect(cubit.state.phase, OpenPhase.password);
      await cubit.openWithPassword('pw');
      expect(cubit.state.phase, OpenPhase.working);
      events
        ..add(FileProcessingProgress(progress: 0.5))
        ..add(FileProcessingProgress(progress: 1, isComplete: true));
      await pumpEventQueue();
      expect(cubit.state.phase, OpenPhase.openedFile);
      expect(cubit.state.openedFile!.name, 'notes.txt');
      expect(
        cubit.state.openedFile!.plainPath,
        path.join(dir.path, 'notes.txt'),
      );
      await cubit.close();
      verify(() => store.wipe(path.join(dir.path, 'notes.txt'))).called(1);
      await events.close();
    });

    test('a wrong password on a file goes back to the question', () async {
      final file = path.join(dir.path, 'a.fuzz');
      File(file).writeAsStringSync('x');
      when(
        () => crypto.peekFile(
          inputPath: file,
          chatIds: any(named: 'chatIds'),
        ),
      ).thenAnswer(
        (_) async => const CryptoCoreSuccess(
          CryptoCorePeek(kind: CryptoCorePeekKind.passwordFile),
        ),
      );
      when(
        () => crypto.decryptFileWithPassword(
          password: any(named: 'password'),
          inputPath: any(named: 'inputPath'),
          outputPath: any(named: 'outputPath'),
        ),
      ).thenAnswer(
        (_) async => CryptoCoreSuccess(
          FileProcessingHandler(
            progressStream: Stream.value(
              FileProcessingProgress(
                progress: 0,
                isComplete: true,
                errorMessage: CryptoCoreFailureType.wrongPassword.name,
              ),
            ),
            pause: () {},
            resume: () {},
            cancel: () {},
          ),
        ),
      );
      final cubit = build();
      await cubit.open(OpenChosenFile(file));
      await cubit.openWithPassword('nope');
      await pumpEventQueue();
      expect(cubit.state.phase, OpenPhase.password);
      expect(cubit.state.isPasswordWrong, isTrue);
      await cubit.close();
    });
  });

  group('files from people', () {
    late StreamController<FileProcessingState> queueStates;
    late String file;

    setUp(() {
      queueStates = StreamController<FileProcessingState>();
      whenListen(queue, queueStates.stream);
      file = path.join(dir.path, 'lease.pdf.fuzz');
      File(file).writeAsStringSync('x');
      when(
        () => crypto.peekFile(
          inputPath: file,
          chatIds: any(named: 'chatIds'),
        ),
      ).thenAnswer(
        (_) async => const CryptoCoreSuccess(
          CryptoCorePeek(kind: CryptoCorePeekKind.chatFile, chatId: _ninoId),
        ),
      );
    });

    tearDown(() => queueStates.close());

    FileProcessingData data() => FileProcessingData(
          chatId: _ninoId,
          chatName: 'Nino',
          inputFilePath: file,
          encryptionStartTime: DateTime(2026),
        );

    test('join the receive queue; the kept container opens again', () async {
      final cubit = build();
      await cubit.open(OpenChosenFile(file));
      expect(cubit.state.phase, OpenPhase.working);
      verify(
        () => queue.addFilesToProcess(
          chatId: _ninoId,
          chatName: 'Nino',
          filePaths: [file],
        ),
      ).called(1);

      queueStates.add(
        FileProcessingState(currentProcessingFile: data(), progress: 0.3),
      );
      await pumpEventQueue();
      expect(cubit.state.progress, 0.3);

      const stored = 'chats/Nino (x)/lease.pdf.fuzz';
      queueStates.add(
        FileProcessingState(
          processedFiles: [
            data().copyWith(
              status: FileProcessingStatus.completed,
              outputFilePath: stored,
              keptFileKey: 'a2V5',
            ),
          ],
        ),
      );
      await pumpEventQueue();
      expect(cubit.state.phase, OpenPhase.openedFile);
      final opened = cubit.state.openedFile!;
      expect(opened.name, 'lease.pdf');
      expect(opened.keptRow!.keptFileKey, 'a2V5');
      expect(opened.plainPath, isNull, reason: 'no plain copy is kept');

      added.add(
        NewMessageAdded(
          message: _row().copyWith(
            id: 12,
            type: MessageType.file,
            encryptedMessage: stored,
          ),
        ),
      );
      await pumpEventQueue();
      expect(cubit.state.historyRowId, 12);
      expect(cubit.state.openedFile!.keptRow!.id, 12);
      await cubit.close();
    });

    for (final (status, failure, problem) in [
      (
        FileProcessingStatus.failed,
        FileProcessingFailureType.alreadyUnfuzzed,
        OpenProblem.alreadyOpened,
      ),
      (
        FileProcessingStatus.failed,
        FileProcessingFailureType.stillArriving,
        OpenProblem.stillArriving,
      ),
      (
        FileProcessingStatus.failed,
        FileProcessingFailureType.tooOld,
        OpenProblem.tooOld,
      ),
      (
        FileProcessingStatus.failed,
        FileProcessingFailureType.cannotOpenAskResend,
        OpenProblem.askResend,
      ),
      (FileProcessingStatus.canceled, null, OpenProblem.askResend),
    ]) {
      test('$status ${failure?.name} is "$problem"', () async {
        final cubit = build();
        await cubit.open(OpenChosenFile(file));
        queueStates.add(
          FileProcessingState(
            processedFiles: [
              data().copyWith(
                status: status,
                failure: failure == null
                    ? null
                    : FileProcessingFailure(type: failure),
              ),
            ],
          ),
        );
        await pumpEventQueue();
        expect(cubit.state.problem, problem);
        expect(cubit.state.chat, _nino);
        await cubit.close();
      });
    }

    test('Cancel stops the queue', () async {
      final cubit = build();
      await cubit.open(OpenChosenFile(file));
      cubit.cancel();
      verify(() => queue.cancelFile()).called(1);
      await cubit.close();
    });
  });

  test('a .fuzz file of locked text opens like a paste of it', () async {
    final file = path.join(dir.path, 'fuzzzy-ink-message.fuzz');
    File(file).writeAsStringSync('Fuzz/AwEC\n');
    when(
      () => crypto.peekFile(inputPath: file, chatIds: any(named: 'chatIds')),
    ).thenAnswer(
      (_) async => const CryptoCoreSuccess(
        CryptoCorePeek(
          kind: CryptoCorePeekKind.message,
          chatId: _ninoId,
          isTextFile: true,
        ),
      ),
    );
    decryptAnswers(const CryptoCoreSuccess('from a file'));
    when(() => messages.addMessage(any(), notifyListeners: true))
        .thenAnswer((_) async => 5);
    final cubit = build();
    await cubit.open(OpenChosenFile(file));
    verify(() => crypto.decryptText(chatId: _ninoId, blob: 'Fuzz/AwEC'))
        .called(1);
    expect(cubit.state.openedText, 'from a file');
    verify(() => store.discardPickedCopy(file)).called(1);
    await cubit.close();
  });
}
