import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The app's own small calls into iOS and macOS (`InkDevice` in the
/// runners): whether Face ID or Touch ID is enrolled, the system print
/// dialog for one image, and (iOS) the system "Save to Files" dialog for one
/// file. Elsewhere [isAvailable] is false and callers keep their own way.
class InkDeviceChannel {
  const InkDeviceChannel();

  static const _channel = MethodChannel('com.fuzzzycore.ink/device');

  /// iOS and macOS answer; other platforms have no such channel.
  static bool get isAvailable =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// Face ID or Touch ID present and enrolled; a passcode alone is not.
  Future<bool> hasStrongBiometrics() async =>
      await _channel.invokeMethod<bool>('hasStrongBiometrics') ?? false;

  /// The system print dialog for the image at [path]. `true` once printed
  /// (or queued), `false` when the person backed out.
  Future<bool> printImage(String path, {required String jobName}) async =>
      await _channel.invokeMethod<bool>(
        'printImage',
        {'path': path, 'jobName': jobName},
      ) ??
      false;

  /// iOS only: the system "Save to Files" dialog for the file at [path] (a
  /// copy is saved; [path] stays the caller's). `true` once saved.
  Future<bool> exportFile(String path) async =>
      await _channel.invokeMethod<bool>('exportFile', {'path': path}) ?? false;
}
