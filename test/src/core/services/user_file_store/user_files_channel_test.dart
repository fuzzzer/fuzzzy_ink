import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// Android's native side (`UserFiles.kt`) builds
/// `Downloads/Fuzzzy Ink/<chat folder>/` from the name it is given, so it is
/// only ever given the cleaned phone folder name, never the raw chat name.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.fuzzzycore.ink/user_files');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return {'path': '/storage/emulated/0/Download/x', 'uri': null};
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<Object?> sentChatName(String chatName) async {
    await const UserFilesChannel().saveToDownloads(
      sourcePath: '/data/files/a.pdf',
      chatName: chatName,
    );
    return (calls.last.arguments as Map<Object?, Object?>)['chatName'];
  }

  test('an ordinary chat name goes to the native side as it is', () async {
    expect(await sentChatName('Work'), 'Work');
    expect(await sentChatName('Mom & Dad?'), 'Mom & Dad?');
  });

  test('an unsafe chat name is cleaned before the native side sees it',
      () async {
    expect(await sentChatName('..'), 'Chat');
    expect(await sentChatName('.'), 'Chat');
    expect(await sentChatName('a/b'), 'a_b');
    expect(await sentChatName('../../Pictures'), '_.._Pictures');
  });
}
