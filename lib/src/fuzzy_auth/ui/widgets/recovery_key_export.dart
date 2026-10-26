import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a recovery key to the person, off this phone (DESIGN.md section
/// 13, item 9): "Save as file" through the system save dialog, "Print" as a
/// one-page sheet through the system print dialog (on iPhone the printer
/// list, then straight to the printer: the print options sheet has its own
/// share button). On iPhone and Mac neither goes through the share menu,
/// whose Copy put the whole key on the clipboard (and Universal Clipboard) —
/// QA 2026-10-26; Android still prints through its share menu. Both go through the app's hand-off folder and the
/// copy is wiped as soon as the system call returns (security review
/// 2026-10-26) — on Android, whose share menu returns before the other app
/// has read the file, when the app is back in front — and in every case when
/// the app locks, so no copy stays on the device. No print package: none is
/// offline-only.
class RecoveryKeyExport {
  const RecoveryKeyExport({this.device = const InkDeviceChannel()});

  /// The iOS and macOS print and save dialogs.
  final InkDeviceChannel device;

  static const textFileName = 'fuzzzy-ink-recovery-key.txt';
  static const printFileName = 'fuzzzy-ink-recovery-key.png';

  /// share_plus has no file sharing on Linux, so no Print there.
  bool get canPrint => ShareHelper.canShareFiles;

  /// `true` once the system says the file was saved; `false` when the
  /// person backed out. Throws when the file could not be written.
  Future<bool> saveAsFile(
    BuildContext context, {
    required String text,
    required String dialogTitle,
  }) async {
    final store = sl.get<UserFileStore>();
    final filePath = await store.newHandoffPath(textFileName);
    try {
      await File(filePath).writeAsString(text, flush: true);
      if (!context.mounted) return false;
      if (Platform.isIOS) return await device.exportFile(filePath);
      return await DeviceFileInteractor.saveFile(
        filePath,
        fileName: textFileName,
        store: store,
        dialogTitle: dialogTitle,
        context: context,
      );
    } finally {
      // Every save dialog has made its copy once it answers.
      await store.wipe(filePath);
    }
  }

  /// Draws the print sheet under [sheetKey] (a [RepaintBoundary]) to an
  /// image and opens the share menu with it. `true` when the menu was shown
  /// (and, where the system says, used). Throws when it could not be made.
  Future<bool> printSheet(
    BuildContext context, {
    required GlobalKey sheetKey,
  }) async {
    final jobName = context.fuzzzyInkLocalizations.accessPrintSheetTitle;
    final boundary =
        sheetKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) throw StateError('no image');

    final store = sl.get<UserFileStore>();
    final filePath = await store.newHandoffPath(printFileName);
    try {
      await File(filePath)
          .writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      if (!context.mounted) return false;
      if (InkDeviceChannel.isAvailable) {
        return await device.printImage(filePath, jobName: jobName);
      }
      if (Platform.isAndroid) {
        await DeviceFileInteractor.shareFile(
          filePath,
          store: store,
          context: context,
        );
        return true;
      }
      return await ShareHelper.shareXFiles(
        [XFile(filePath, mimeType: 'image/png')],
        context: context,
      );
    } finally {
      // Android's share menu returns before the target has read the image;
      // everywhere else it returns once the person is done with it.
      if (Platform.isAndroid) {
        store.wipeWhenBack(filePath);
      } else {
        await store.wipe(filePath);
      }
    }
  }
}

/// The one-page print sheet (DESIGN.md section 4.1, "Print sheet"): the
/// mark, the key in its groups and the three numbered lines, on paper in
/// both looks.
class RecoveryKeyPrintSheet extends StatelessWidget {
  const RecoveryKeyPrintSheet({
    super.key,
    required this.recoveryKey,
    required this.madeOn,
  });

  final String recoveryKey;
  final DateTime madeOn;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final date = MaterialLocalizations.of(context).formatFullDate(madeOn);

    // Paper whatever the look: it is printed.
    return Theme(
      // The ink pack on its paper skin (the defaults).
      data: FuzzzyTheme.build(),
      child: Builder(
        builder: (context) {
          final colors = context.fuzzzyColors;
          final space = context.fuzzzySpace;
          final type = context.fuzzzyTextStyles;
          final body = type.bodyS.copyWith(color: colors.ink);

          return Container(
            key: const Key('recovery_key.print_sheet'),
            padding: EdgeInsets.all(space.l),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.line),
              borderRadius: BorderRadius.circular(context.fuzzzyRadius.s),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const InkMark(size: 18, qaId: 'print'),
                    SizedBox(width: space.s),
                    Expanded(
                      child: Text(
                        localizations.accessPrintSheetTitle,
                        style: type.titleS.copyWith(color: colors.ink),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: space.m),
                RecoveryKeyBlock(recoveryKey: recoveryKey, showTag: false),
                SizedBox(height: space.m),
                Text('1. ${localizations.accessPrintLine1}', style: body),
                SizedBox(height: space.xs),
                Text(
                  '2. ${localizations.accessPrintLine2}',
                  style: body.copyWith(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: space.xs),
                Text('3. ${localizations.accessPrintLine3}', style: body),
                SizedBox(height: space.s),
                Text(
                  localizations.accessPrintMade(date),
                  style: type.bodyS.copyWith(color: colors.inkMute),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// "Print preview": the sheet as it will print, and Print, which hands it
/// to the share menu. Pops `true` once handed over. A private screen.
class RecoveryKeyPrintPage extends StatefulWidget {
  const RecoveryKeyPrintPage({
    super.key,
    required this.recoveryKey,
    this.export = const RecoveryKeyExport(),
    this.now,
  });

  final String recoveryKey;
  final RecoveryKeyExport export;

  /// The sheet's date; today when null (tests pass one).
  final DateTime? now;

  /// Shows the page; answers whether the sheet was handed over.
  static Future<bool> show(
    BuildContext context, {
    required String recoveryKey,
    RecoveryKeyExport export = const RecoveryKeyExport(),
  }) async {
    final printed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SensitiveScreen(
          child: RecoveryKeyPrintPage(recoveryKey: recoveryKey, export: export),
        ),
      ),
    );
    return printed ?? false;
  }

  @override
  State<RecoveryKeyPrintPage> createState() => _RecoveryKeyPrintPageState();
}

class _RecoveryKeyPrintPageState extends State<RecoveryKeyPrintPage> {
  final _sheetKey = GlobalKey();
  bool _busy = false;

  Future<void> _print() async {
    final localizations = context.fuzzzyInkLocalizations;
    setState(() => _busy = true);
    var printed = false;
    try {
      printed = await widget.export.printSheet(context, sheetKey: _sheetKey);
    } catch (error) {
      logger.w('Recovery key print sheet not made: ${error.runtimeType}');
      if (mounted) {
        showInkToast(
          context,
          message: localizations.accessPrintFailed,
          kind: FuzzzyToastKind.error,
        );
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (printed) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;

    return AccessPage(
      qaId: 'printPreview',
      title: localizations.accessPrintPreview,
      onBack: () => Navigator.of(context).pop(false),
      bottom: [
        FuzzzyButton(
          label: localizations.accessPrint,
          icon: const Icon(Icons.print_outlined),
          loading: _busy,
          qaId: 'printPreview.print',
          onPressed: _busy ? null : _print,
        ),
      ],
      children: [
        RepaintBoundary(
          key: _sheetKey,
          child: RecoveryKeyPrintSheet(
            recoveryKey: widget.recoveryKey,
            madeOn: widget.now ?? DateTime.now(),
          ),
        ),
        SizedBox(height: context.fuzzzySpace.m),
        TipLine(
          icon: Icons.print_outlined,
          text: localizations.accessPrintHint,
        ),
      ],
    );
  }
}
