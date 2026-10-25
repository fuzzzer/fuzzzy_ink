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

  static Future<void> share(
    String text, {
    required BuildContext context,
  }) {
    return Share.share(
      text,
      sharePositionOrigin: _originFromContext(context),
    );
  }

  static Future<void> shareXFiles(
    List<XFile> files, {
    required BuildContext context,
  }) {
    return Share.shareXFiles(
      files,
      sharePositionOrigin: _originFromContext(context),
    );
  }

  /// share_plus has no file sharing on Linux.
  static bool get canShareFiles => !Platform.isLinux;

  /// Shares [text] as a plain-text file named [fileName]. share_plus writes
  /// it to the app's temporary folder first; pass only sealed text.
  static Future<void> shareTextAsFile(
    String text, {
    required String fileName,
    required BuildContext context,
  }) {
    return shareXFiles(
      [
        XFile.fromData(
          utf8.encode(text),
          mimeType: 'text/plain',
          name: fileName,
        ),
      ],
      context: context,
    );
  }
}
