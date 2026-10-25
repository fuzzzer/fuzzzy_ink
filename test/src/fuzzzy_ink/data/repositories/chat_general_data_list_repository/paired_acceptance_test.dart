import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockChatGeneralDataLocalDataSource extends Mock
    implements ChatGeneralDataLocalDataSource {}

const _chatId = '6f1e9b2c-3d4a-4f5b-8c6d-7e8f9a0b1c2d';
const _acceptance = 'Fuzz/RlVaWgECJDZmMWU5YjJj';

/// The acceptance that paired a chat is remembered so FuzzyLinkHandler can
/// tell the same one arriving again from a second, different one.
void main() {
  late ChatGeneralDataListRepository repository;
  late MockChatGeneralDataLocalDataSource localDataSource;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    localDataSource = MockChatGeneralDataLocalDataSource();
    when(() => localDataSource.deleteChat(any())).thenAnswer((_) async {});
    repository = ChatGeneralDataListRepository(
      localDataSource: localDataSource,
      pairedAcceptanceDataSource: PairedAcceptanceLocalDataSource(
        prefs: await SharedPreferences.getInstance(),
      ),
    );
  });

  test('nothing remembered: any acceptance counts as a different one',
      () async {
    expect(await repository.isPairedAcceptance(_chatId, _acceptance), isFalse);
  });

  test('the remembered acceptance matches, wrapped or not', () async {
    await repository.rememberPairedAcceptance(_chatId, '$_acceptance\n');

    expect(await repository.isPairedAcceptance(_chatId, _acceptance), isTrue);
    expect(
      await repository.isPairedAcceptance(
        _chatId,
        'Fuzz/RlVaWgEC\r\n  JDZmMWU5YjJj',
      ),
      isTrue,
    );
  });

  test('a different acceptance does not match', () async {
    await repository.rememberPairedAcceptance(_chatId, _acceptance);

    expect(
      await repository.isPairedAcceptance(_chatId, '${_acceptance}x'),
      isFalse,
    );
    expect(
      await repository.isPairedAcceptance(
        '00000000-0000-4000-8000-000000000000',
        _acceptance,
      ),
      isFalse,
    );
  });

  test('deleting the chat forgets its acceptance', () async {
    await repository.rememberPairedAcceptance(_chatId, _acceptance);

    await repository.deleteChat(_chatId);

    expect(await repository.isPairedAcceptance(_chatId, _acceptance), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
  });
}
