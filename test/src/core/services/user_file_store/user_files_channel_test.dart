import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';

/// The Dart side of Android's save dialog and share sheet (`UserFiles.kt`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.fuzzzycore.ink/user_files');
  final calls = <MethodCall>[];
  Object? answer;

  setUp(() {
    calls.clear();
    answer = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return answer;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('saveAs proposes the name and reports whether the user saved', () async {
    answer = 'saved';
    expect(
      await const UserFilesChannel().saveAs(
        '/data/files/handoff/1/report.pdf',
        fileName: 'report.pdf',
      ),
      isTrue,
    );
    expect(calls.single.method, 'saveAs');
    expect(calls.single.arguments, {
      'path': '/data/files/handoff/1/report.pdf',
      'fileName': 'report.pdf',
      'mimeType': null,
    });

    answer = 'cancelled';
    expect(
      await const UserFilesChannel().saveAs(
        '/data/files/handoff/2/a.fuzz',
        fileName: 'a.fuzz',
        mimeType: 'application/octet-stream',
      ),
      isFalse,
    );
  });

  test('shareFile passes the path and the type', () async {
    await const UserFilesChannel().shareFile(
      '/data/files/handoff/1/a.fuzz',
      mimeType: 'application/octet-stream',
    );
    expect(calls.single.method, 'shareFile');
    expect(calls.single.arguments, {
      'path': '/data/files/handoff/1/a.fuzz',
      'mimeType': 'application/octet-stream',
    });
  });
}
