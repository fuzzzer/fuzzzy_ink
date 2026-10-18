import 'dart:io';

import 'package:flutter/services.dart';
import 'package:fuzzzy_ink/lib.dart';

/// Keeps the folders the app writes out of iCloud, Finder and Time Machine
/// backups on iOS and macOS (T-0432): a chat's folder holds decrypted files in
/// the clear, and the privacy policy promises nothing leaves the device.
///
/// The native side (`AppDelegate.swift`, `MainFlutterWindow.swift`) marks
/// Application Support, Documents with every folder already in it, and Caches
/// at startup; [exclude] marks each folder the moment it is created. Android
/// needs nothing here — its manifest turns backups off for every domain.
class BackupExclusion {
  const BackupExclusion({bool? isApplePlatform})
      : _isApplePlatform = isApplePlatform;

  static const channel = MethodChannel('com.fuzzzycore.ink/backup');

  final bool? _isApplePlatform;

  bool get _appliesHere =>
      _isApplePlatform ?? (Platform.isIOS || Platform.isMacOS);

  /// Marks [directoryPath] as excluded from backup. Never throws: a folder
  /// that could not be marked is still covered by its marked parent, and a
  /// file operation must not fail over it.
  Future<void> exclude(String directoryPath) async {
    if (!_appliesHere) return;
    try {
      final isMarked = await channel.invokeMethod<bool>(
        'excludeFromBackup',
        {'path': directoryPath},
      );
      if (isMarked != true) {
        logger.w('BACKUP EXCLUSION: could not mark $directoryPath');
      }
    } catch (exception) {
      logger.w('BACKUP EXCLUSION: $directoryPath not marked: $exception');
    }
  }
}
