import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// Shows an unfuzzed file inside the app — an image or plain text
/// ([PlainFileKind]) — with Save and Share; any other file shows only its
/// name and Save. Text is shown, never selectable. The plain copy belongs to
/// the caller, who wipes it in [onClosed].
class PlainFileViewerPage extends StatefulWidget {
  const PlainFileViewerPage({
    super.key,
    required this.fileName,
    required this.onSave,
    this.filePath,
    this.bytes,
    this.onShare,
    this.onClosed,
  }) : assert(
          (filePath == null) != (bytes == null),
          'Exactly one of filePath and bytes',
        );

  final String fileName;
  final String? filePath;
  final Uint8List? bytes;
  final Future<void> Function(BuildContext context) onSave;
  final Future<void> Function(BuildContext context)? onShare;
  final VoidCallback? onClosed;

  /// Pushes the viewer; completes when it is closed. The viewer shows
  /// plaintext, so it is a [SensitiveScreen] of its own: the screen it covers
  /// stops protecting the window once it is hidden.
  static Future<void> show(
    BuildContext context, {
    required String fileName,
    required Future<void> Function(BuildContext context) onSave,
    String? filePath,
    Uint8List? bytes,
    Future<void> Function(BuildContext context)? onShare,
    VoidCallback? onClosed,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SensitiveScreen(
          child: PlainFileViewerPage(
            fileName: fileName,
            filePath: filePath,
            bytes: bytes,
            onSave: onSave,
            onShare: onShare,
            onClosed: onClosed,
          ),
        ),
      ),
    );
  }

  @override
  State<PlainFileViewerPage> createState() => _PlainFileViewerPageState();
}

class _PlainFileViewerPageState extends State<PlainFileViewerPage> {
  late final PlainFileKind _kind = PlainFileKind.of(widget.fileName);
  late final Future<String?> _text = _readText();

  Future<String?> _readText() async {
    if (_kind != PlainFileKind.text) return null;
    final bytes = widget.bytes ?? await File(widget.filePath!).readAsBytes();
    if (bytes.length > PlainFileKind.maxTextBytes) return null;
    return utf8.decode(bytes, allowMalformed: true);
  }

  @override
  void dispose() {
    widget.onClosed?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final displayName = UserFileNames.forDisplay(widget.fileName);

    return FuzzyScaffold(
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: space.gutter),
        child: Column(
          children: [
            FuzzzyAppBar(
              title: displayName,
              qaId: 'plainFileViewer.appbar',
            ),
            SizedBox(height: space.m),
            Expanded(child: _buildContent(context, displayName)),
            SizedBox(height: space.m),
            Row(
              children: [
                Expanded(
                  child: FuzzzyButton(
                    label: localizations.saveFile,
                    icon: const Icon(Icons.save_alt_rounded),
                    onPressed: () => widget.onSave(context),
                    qaId: 'plainFileViewer.save',
                  ),
                ),
                if (widget.onShare != null) ...[
                  SizedBox(width: space.m),
                  Expanded(
                    child: FuzzzyButton(
                      label: localizations.share,
                      icon: const Icon(Icons.share_rounded),
                      variant: FuzzzyButtonVariant.secondary,
                      onPressed: () => widget.onShare!(context),
                      qaId: 'plainFileViewer.share',
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: space.l),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, String displayName) {
    final noPreview = FuzzzyEmptyState(
      title: displayName,
      message: context.fuzzzyInkLocalizations.fileNoPreview,
      qaId: 'plainFileViewer.noPreview',
    );

    switch (_kind) {
      case PlainFileKind.image:
        Widget errorBuilder(BuildContext _, Object __, StackTrace? ___) =>
            noPreview;
        return InteractiveViewer(
          child: Center(
            child: widget.bytes != null
                ? Image.memory(widget.bytes!, errorBuilder: errorBuilder)
                : Image.file(
                    File(widget.filePath!),
                    errorBuilder: errorBuilder,
                  ),
          ),
        );
      case PlainFileKind.text:
        return FutureBuilder<String?>(
          future: _text,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: FuzzzyProgressRing());
            }
            final text = snapshot.data;
            if (text == null) return noPreview;
            return SingleChildScrollView(
              child: Text(
                text,
                style: context.fuzzzyTextStyles.body.copyWith(
                  color: context.fuzzzyColors.ink,
                ),
              ),
            );
          },
        );
      case PlainFileKind.none:
        return noPreview;
    }
  }
}
