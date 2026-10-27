import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:path/path.dart' as path;
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The save panel of a computer (the test host is macOS or Linux): it
/// answers [answer] and records the name it was offered.
class _FakeFilePicker extends FilePicker with MockPlatformInterfaceMixin {
  String? answer;
  String? offeredName;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    offeredName = fileName;
    return answer;
  }
}

/// The app never opens a plain file in another app or shows its folder: a
/// file reaches the user through the save dialog or the share sheet only.
void main() {
  late Directory folder;
  late _FakeFilePicker picker;
  late UserFileStore store;

  setUp(() {
    folder = Directory.systemTemp.createTempSync('device_file_interactor_');
    picker = _FakeFilePicker();
    FilePicker.platform = picker;
    store = UserFileStore(
      supportDirectoryPath: path.join(folder.path, 'support'),
      temporaryDirectoryPath: path.join(folder.path, 'tmp'),
      documentsDirectoryPath: path.join(folder.path, 'documents'),
    );
  });

  tearDown(() => folder.deleteSync(recursive: true));

  group('DeviceFileInteractor.saveFile on a computer', () {
    test('copies the file to the place the user picked', () async {
      final plain = File(path.join(folder.path, 'report.pdf'))
        ..writeAsStringSync('plain');
      final target = path.join(folder.path, 'Desktop', 'mine.pdf');
      Directory(path.dirname(target)).createSync();
      picker.answer = target;

      expect(
        await DeviceFileInteractor.saveFile(
          plain.path,
          fileName: 'report.pdf',
          store: store,
        ),
        isTrue,
      );
      expect(File(target).readAsStringSync(), 'plain');
      expect(picker.offeredName, 'report.pdf');
    });

    test('a cancelled dialog writes nothing', () async {
      final plain = File(path.join(folder.path, 'report.pdf'))
        ..writeAsStringSync('plain');
      picker.answer = null;

      expect(
        await DeviceFileInteractor.saveFile(
          plain.path,
          fileName: 'report.pdf',
          store: store,
        ),
        isFalse,
      );
    });

    test(
        'the offered name is shown in its real order and is one every save '
        'panel accepts', () async {
      final plain = File(path.join(folder.path, 'x'))..writeAsStringSync('x');
      await DeviceFileInteractor.saveFile(
        plain.path,
        fileName: 'invoice\u{202E}fdp.exe',
        store: store,
      );
      expect(picker.offeredName, 'invoicefdp.exe');

      await DeviceFileInteractor.saveFile(
        plain.path,
        fileName: 'a:b?.txt',
        store: store,
      );
      expect(picker.offeredName, 'a_b_.txt');
    });

    test('a missing file throws before any dialog', () async {
      await expectLater(
        DeviceFileInteractor.saveFile(
          path.join(folder.path, 'gone.pdf'),
          fileName: 'gone.pdf',
          store: store,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(picker.offeredName, isNull);
    });
  });

  test('a .fuzz container travels as a plain binary', () {
    expect(
      DeviceFileInteractor.explicitMimeType('a.pdf.fuzz'),
      'application/octet-stream',
    );
    expect(DeviceFileInteractor.explicitMimeType('a.pdf'), isNull);
  });
}
