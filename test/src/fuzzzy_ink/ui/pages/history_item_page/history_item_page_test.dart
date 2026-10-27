import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/people_harness.dart';

class _MockUserFileStore extends Mock implements UserFileStore {}

class _FakeSecureClipboard extends SecureClipboard {
  final writes = <String>[];

  @override
  Future<void> write(
    String text, {
    required bool sensitive,
    required Duration clearAfter,
  }) async =>
      writes.add(text);

  @override
  Future<ClipboardClearResult> clearIfStillOurs() async =>
      ClipboardClearResult.cleared;
}

MessageData _message({
  required bool isSent,
  MessageType type = MessageType.text,
  bool isUnreadable = false,
}) =>
    MessageData(
      id: 9,
      chatId: peopleChatId,
      type: type,
      encryptedMessage:
          type.isFile ? 'files/beach-photo.jpg.fuzz' : 'AwECsealed',
      decryptedMessage: type.isFile
          ? 'files/beach-photo.jpg.fuzz'
          : (isUnreadable ? '' : 'The keys are under the blue pot.'),
      sentAt: DateTime(2026, 10, 26, 9, 20),
      isSent: isSent,
      isUnreadable: isUnreadable,
    );

void main() {
  late MockChatFileCubit files;

  setUp(() {
    HistoryFormat.now = () => DateTime(2026, 10, 26, 12);
    files = MockChatFileCubit();
    when(() => files.state).thenReturn(const ChatFileState());
    when(() => files.sealedPathOf(any())).thenReturn('/kept/beach.jpg.fuzz');
    when(() => files.userFileStore).thenReturn(_MockUserFileStore());
  });

  setUpAll(() => registerFallbackValue(_message(isSent: true)));
  tearDown(() => HistoryFormat.now = DateTime.now);

  Future<void> pumpItem(
    WidgetTester tester,
    MessageData message, {
    FuzzzySkin skin = FuzzzySkin.night,
  }) async {
    await pumpPeople(
      tester,
      BlocProvider<ChatFileCubit>.value(
        value: files,
        child: ProvidedHistoryItemPage(
          payload: HistoryItemPagePayload(
            chat: personChat(),
            message: message,
            fileSize: '3.1 MB',
          ),
        ),
      ),
      skin: skin,
    );
  }

  for (final skin in [FuzzzySkin.paper, FuzzzySkin.night]) {
    testWidgets(
        'your locked message: private, your text with "No copy", the locked '
        'version, Share again and Copy locked ($skin)', (tester) async {
      await pumpItem(tester, _message(isSent: true), skin: skin);

      expect(find.byType(SensitiveScreen), findsOneWidget);
      expect(find.text('For Nino'), findsOneWidget);
      expect(find.text('You locked this · Today · 09:20'), findsOneWidget);
      expect(find.text('The keys are under the blue pot.'), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);
      expect(find.byKey(const Key('tag.item.noCopy')), findsOneWidget);
      expect(find.byKey(const Key('locked_preview.item')), findsOneWidget);
      expect(find.text('Share again'), findsOneWidget);
      expect(find.text('Copy locked'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Copy locked copies only the locked text and says "Copied"',
      (tester) async {
    final clipboard = _FakeSecureClipboard();
    final previous = CopyGuard.clipboardGuard;
    final guard = ClipboardGuard(clipboard: clipboard);
    CopyGuard.clipboardGuard = guard;
    addTearDown(() => CopyGuard.clipboardGuard = previous);

    await pumpItem(tester, _message(isSent: true));
    await tester.tap(find.text('Copy locked'));
    await tester.pump();
    await tester.pump();

    expect(clipboard.writes, ['${fuzzIdentificator}AwECsealed']);
    expect(find.text('Copied'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('Copy locked'), findsOneWidget);

    // The clipboard's own clear timer belongs to the guard.
    guard.dispose();
  });

  testWidgets('a message that cannot be read says so', (tester) async {
    await pumpItem(tester, _message(isSent: true, isUnreadable: true));
    expect(
      find.text("This message can't be read on this phone."),
      findsOneWidget,
    );
  });

  testWidgets(
      'your locked file: not private, the .fuzz card, Share again, '
      'Save', (tester) async {
    await pumpItem(tester, _message(isSent: true, type: MessageType.file));

    expect(find.byType(SensitiveScreen), findsNothing);
    expect(find.text('beach-photo.jpg.fuzz'), findsOneWidget);
    expect(find.text('3.1 MB · Locked'), findsOneWidget);
    expect(find.text('Only the locked copy is kept.'), findsOneWidget);
    expect(find.text('Share again'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('an opened message: private, the text and "No copy", Done',
      (tester) async {
    await pumpItem(tester, _message(isSent: false));

    expect(find.byType(SensitiveScreen), findsOneWidget);
    expect(find.text('From Nino'), findsOneWidget);
    expect(find.text('Opened Today · 09:20'), findsOneWidget);
    expect(find.text('The keys are under the blue pot.'), findsOneWidget);
    expect(find.byKey(const Key('tag.opened.nocopy')), findsOneWidget);
    expect(find.text('Copy locked'), findsNothing);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('an opened file: private, its card, Open and Save',
      (tester) async {
    await pumpItem(tester, _message(isSent: false, type: MessageType.file));

    expect(find.byType(SensitiveScreen), findsOneWidget);
    expect(find.text('beach-photo.jpg'), findsOneWidget);
    expect(find.text('Opened Today · 09:20'), findsOneWidget);
    expect(find.textContaining('3.1 MB'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(
      find.text("Save gives you a normal copy. Then it's yours."),
      findsOneWidget,
    );
  });
}
