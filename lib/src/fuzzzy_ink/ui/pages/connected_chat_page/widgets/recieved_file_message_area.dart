import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

class ReceivedFileMessageArea extends StatefulWidget {
  final MessageData message;

  const ReceivedFileMessageArea({
    required this.message,
    super.key,
  });

  @override
  State<ReceivedFileMessageArea> createState() =>
      _ReceivedFileMessageAreaState();
}

class _ReceivedFileMessageAreaState extends State<ReceivedFileMessageArea> {
  Future<void> _openDecryptedFileDirectory({
    required String encryptedMessage,
    required FuzzzyInkLocalizations localizations,
  }) async {
    final filePath = encryptedMessage.replaceAll(fuzzIdentificator, '');

    try {
      await DeviceFileInteractor.revealFile(filePath, context: context);
    } catch (_) {
      if (!mounted) return;
      FuzzzyToast.show(context, message: localizations.couldNotOpenFile);
    }
  }

  Future<void> _openDecryptedFile({
    required String encryptedMessage,
    required FuzzzyInkLocalizations localizations,
  }) async {
    final filePath = encryptedMessage.replaceAll(fuzzIdentificator, '');

    try {
      await DeviceFileInteractor.openFile(filePath);
    } catch (_) {
      if (!mounted) return;
      FuzzzyToast.show(context, message: localizations.couldNotOpenFile);
    }
  }

  Future<void> _shareDecryptedFile({
    required String encryptedMessage,
    required FuzzzyInkLocalizations localizations,
  }) async {
    final filePath = encryptedMessage.replaceAll(fuzzIdentificator, '');

    try {
      await DeviceFileInteractor.shareFile(filePath, context: context);
    } catch (_) {
      if (!mounted) return;
      FuzzzyToast.show(context, message: localizations.couldNotOpenFile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fuzzzyTextStyles = context.fuzzzyTextStyles;
    final fuzzzyColors = context.fuzzzyColors;

    final localizations = context.fuzzzyInkLocalizations;

    // Read per build: the list has no keys, so this State is reused for
    // whatever file row lands at its index.
    final fileLocation = UserFileLocation.of(widget.message.encryptedMessage);

    const borderRadius = BorderRadius.only(
      topLeft: Radius.circular(12),
      topRight: Radius.circular(12),
      bottomLeft: Radius.circular(12),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onLongPress: () {
          _openDecryptedFile(
            encryptedMessage: widget.message.encryptedMessage,
            localizations: localizations,
          );
        },
        child: SizedBox(
          width: double.maxFinite,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FuzzyOverlaySpawner(
              splashColor: fuzzzyColors.ground,
              splashRadius: borderRadius,
              // Hangs from the bubble's top-left and grows rightwards.
              followerAnchor: Alignment.bottomLeft,
              offset: const Offset(0, 16),
              spawnedChildBuilder: (context, closeOverlay) {
                return FuzzyActionPill(
                  actions: [
                    TextAction(
                      label: localizations.show,
                      onTap: () {
                        _openDecryptedFileDirectory(
                          encryptedMessage: widget.message.encryptedMessage,
                          localizations: localizations,
                        );
                        closeOverlay();
                      },
                    ),
                    TextAction(
                      label: localizations.open,
                      onTap: () {
                        _openDecryptedFile(
                          encryptedMessage: widget.message.encryptedMessage,
                          localizations: localizations,
                        );
                        closeOverlay();
                      },
                    ),
                    TextAction(
                      label: localizations.shareFile,
                      onTap: () {
                        _shareDecryptedFile(
                          encryptedMessage: widget.message.encryptedMessage,
                          localizations: localizations,
                        );
                        closeOverlay();
                      },
                    ),
                    TextAction(
                      label: '🔗',
                      onTap: () {
                        final link = FuzzyLinkGenerator.generateFuzzLink(
                          widget.message.chatId,
                          widget.message.encryptedMessage,
                        );
                        final preparedFuzz =
                            '$fuzzIdentificator${widget.message.encryptedMessage}';
                        final shareable =
                            FuzzyLinkGenerator.generateShareableContent(
                          link: link,
                          rawFuzz: preparedFuzz,
                          type: FuzzyLinkType.fuzz,
                        );
                        ShareHelper.share(shareable, context: context);
                        closeOverlay();
                      },
                    ),
                    TextAction(
                      label: localizations.copyAsLink,
                      onTap: () {
                        final link = FuzzyLinkGenerator.generateFuzzLink(
                          widget.message.chatId,
                          widget.message.encryptedMessage,
                        );
                        Clipboard.setData(ClipboardData(text: link));
                        FuzzzyToast.show(
                          context,
                          message: localizations.linkCopiedToClipboard,
                        );
                        closeOverlay();
                      },
                    ),
                    TextAction(
                      label: localizations.copy,
                      onTap: () {
                        final filePath = widget.message.encryptedMessage
                            .replaceAll(fuzzIdentificator, '');
                        Clipboard.setData(ClipboardData(text: filePath));
                        FuzzzyToast.show(
                          context,
                          message: localizations.copiedToTheClipboard,
                        );
                        closeOverlay();
                      },
                    ),
                  ],
                );
              },
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: fuzzzyColors.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileLocation.fileName,
                      style: fuzzzyTextStyles.body.copyWith(
                        color: fuzzzyColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fileLocation.folderLine,
                      style: fuzzzyTextStyles.bodyS.copyWith(
                        color: fuzzzyColors.inkMute,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
