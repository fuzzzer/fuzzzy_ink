import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Deleting only what is there.
///
/// On Apple platforms the plugin deletes an entry twice, once as an
/// iCloud-synced item and once as a local one. A development Mac build is
/// unsigned and has no keychain entitlements, so the system refuses the
/// synced half ("A required entitlement isn't present", -34018); when the
/// entry does not exist the plugin reports that refusal as the result, and
/// "erase everything" failed on a Mac with nothing to erase (QA 2026-10-26:
/// "Your keys could not be created"). Asking first, without reading the
/// value, avoids the refused call; an entry that is there is deleted by its
/// local half and succeeds.
extension SecureStorageDeleteIfPresent on FlutterSecureStorage {
  Future<void> deleteIfPresent(String key) async {
    if (await containsKey(key: key)) await delete(key: key);
  }
}
