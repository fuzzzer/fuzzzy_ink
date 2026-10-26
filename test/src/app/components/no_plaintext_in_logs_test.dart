import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// Development and profile builds log state changes; opened text never
/// appears there (security review 2026-10-26).
void main() {
  final row = MessageData(
    id: 1,
    chatId: '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d',
    type: MessageType.text,
    encryptedMessage: 'AwEC',
    decryptedMessage: 'meet me at the bridge',
    sentAt: DateTime(2026),
    isSent: false,
  );

  test('a history row prints no opened text', () {
    expect(row.toString(), isNot(contains('bridge')));
  });

  test("a person's history state prints the number of rows only", () {
    final state = ConnectedChatState(
      status: StateStatus.success,
      messages: [row],
    );
    expect(state.toString(), isNot(contains('bridge')));
    expect(state.toString(), contains('messages: 1'));
  });
}
