import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class ShareHelper {
  ShareHelper._();

  static Rect _originFromContext(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    final size = MediaQuery.of(context).size;
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 1,
      height: 1,
    );
  }

  /// Answers whether the system reported the share as done: iOS and macOS
  /// always say; Android only where the platform does (otherwise false). A
  /// cancel is false.
  static Future<bool> share(
    String text, {
    required BuildContext context,
  }) async {
    final result = await Share.share(
      text,
      sharePositionOrigin: _originFromContext(context),
    );
    return result.status == ShareResultStatus.success;
  }

  /// As [share]. [fileNameOverrides] names files made from data.
  static Future<bool> shareXFiles(
    List<XFile> files, {
    required BuildContext context,
    List<String>? fileNameOverrides,
  }) async {
    final result = await Share.shareXFiles(
      files,
      sharePositionOrigin: _originFromContext(context),
      fileNameOverrides: fileNameOverrides,
    );
    return result.status == ShareResultStatus.success;
  }

  /// share_plus has no file sharing on Linux.
  static bool get canShareFiles => !Platform.isLinux;

  /// Shares [text] as a file named [fileName] ([mimeType], plain text by
  /// default). share_plus writes it to the app's temporary folder first;
  /// pass only sealed text. The name goes as an override: a file made from
  /// data has no name of its own, so share_plus named it after its type
  /// (`<random>.so` for a `.fuzz`, which then no longer opened in the app).
  static Future<bool> shareTextAsFile(
    String text, {
    required String fileName,
    required BuildContext context,
    String mimeType = 'text/plain',
  }) {
    return shareXFiles(
      [
        XFile.fromData(
          utf8.encode(text),
          mimeType: mimeType,
          name: fileName,
        ),
      ],
      context: context,
      fileNameOverrides: [fileName],
    );
  }
}
