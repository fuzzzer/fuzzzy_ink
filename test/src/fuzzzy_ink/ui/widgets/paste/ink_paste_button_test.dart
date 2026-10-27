import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_ink/src/src.dart';

void main() {
  test("reads iOS's major version; 16 and later have the system button", () {
    expect(InkPasteButton.iosMajorVersion('Version 26.5 (Build 23F77)'), 26);
    expect(InkPasteButton.iosMajorVersion('Version 15.8.3 (Build 19H386)'), 15);
    expect(InkPasteButton.iosMajorVersion('16.0'), 16);
    expect(InkPasteButton.iosMajorVersion('unknown'), 0);
  });

  test('not on this computer, where the tests run', () {
    expect(InkPasteButton.isAvailable, isFalse);
  });
}
