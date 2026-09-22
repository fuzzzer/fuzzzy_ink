import 'package:flutter_test/flutter_test.dart';
import 'package:fuzzzy_seal/lib.dart';

void main() {
  group('secure storage options (THREAT_MODEL §2.8 / D-8)', () {
    test('iOS keychain items are ThisDeviceOnly', () {
      expect(
        secureStorageIosOptions.toMap()['accessibility'],
        'unlocked_this_device',
      );
    });

    test('macOS keychain items are ThisDeviceOnly', () {
      expect(
        secureStorageMacOsOptions.toMap()['accessibility'],
        'unlocked_this_device',
      );
    });
  });
}
