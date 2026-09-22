import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

import 'package:vibration/vibration.dart';

class SentMessageArea extends StatefulWidget {
  final MessageData message;

  const SentMessageArea({required this.message, super.key});

  @override
  State<SentMessageArea> createState() => _SentMessageAreaState();
}

class _SentMessageAreaState extends State<SentMessageArea> {
  // Read from the widget, not cached in initState: the list has no keys, so
  // this State is reused for whatever message lands at its index.
  bool get isEncryptedFile => widget.message.type.isFile;

  bool hasJustCopied = false;
  bool isExpanded = false;
  bool isExpandable = false;
  bool showEncrypted = true;

  String _prepareEncrypredMessage(String encryptedMessage) =>
      '$fuzzIdentificator$encryptedMessage';

  @override
  void didChangeDependencies() {
    _checkIfIsExpandable(widget.message.encryptedMessage);
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(SentMessageArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.encryptedMessage != widget.message.encryptedMessage) {
      _checkIfIsExpandable(widget.message.encryptedMessage);
    }
  }

  void _checkIfIsExpandable(String message) {
    final textPainter = TextPainter(
      text: TextSpan(text: message),
      maxLines: 4,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: MediaQuery.of(context).size.width * 0.75);

    setState(() {
      // A file bubble shows a name and a place, never a long text.
      isExpandable = !isEncryptedFile && textPainter.didExceedMaxLines;
    });
  }

  void _toggleExpand() {
    setState(() {
      isExpanded = !isExpanded;
    });
  }

  void _toggleHide(bool status) {
    setState(() {
      showEncrypted = status;
    });
  }

  void _copyMessage({
    required String encryptedMessage,
    required FuzzzySealLocalizations localizations,
  }) {
    if (hasJustCopied) return;

    setState(() {
      hasJustCopied = true;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          hasJustCopied = false;
        });
      }
    });

    Clipboard.setData(
      ClipboardData(text: _prepareEncrypredMessage(encryptedMessage)),
    ).then((_) async {
      if (!mounted) return;
      FuzzzyToast.show(context, message: localizations.copiedToTheClipboard);

      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        await Vibration.vibrate();
      }
    });
  }

  void _copyFuzzLink({
    required String encryptedMessage,
    required FuzzzySealLocalizations localizations,
  }) {
    final link = FuzzyLinkGenerator.generateFuzzLink(
      widget.message.chatId,
      encryptedMessage,
    );
    Clipboard.setData(ClipboardData(text: link));
    FuzzzyToast.show(context, message: localizations.linkCopiedToClipboard);
  }

  void _shareFuzzLink(String encryptedMessage) {
    final link = FuzzyLinkGenerator.generateFuzzLink(
      widget.message.chatId,
      encryptedMessage,
    );
    final shareable = FuzzyLinkGenerator.generateShareableContent(
      link: link,
      rawFuzz: _prepareEncrypredMessage(encryptedMessage),
      type: FuzzyLinkType.fuzz,
    );
    ShareHelper.share(shareable, context: context);
  }

  Future<void> _openEncryptedFileDirectory({
    required String encryptedMessage,
    required FuzzzySealLocalizations localizations,
  }) async {
    final filePath = encryptedMessage.replaceAll(fuzzIdentificator, '');

    try {
      await DeviceFileInteractor.revealFile(filePath, context: context);
    } catch (_) {
      if (!mounted) return;
      FuzzzyToast.show(context, message: localizations.couldNotOpenFile);
    }
  }

  Future<void> _shareEncryptedFile({
    required String encryptedMessage,
    required FuzzzySealLocalizations localizations,
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
    final fuzzzyColors = context.fuzzzyColors;
    final fuzzzyTextStyles = context.fuzzzyTextStyles;

    final localizations = context.fuzzzySealLocalizations;

    const borderRadius = BorderRadius.only(
      topLeft: Radius.circular(12),
      topRight: Radius.circular(12),
      bottomLeft: Radius.circular(12),
    );

    final encryptedMessage = widget.message.encryptedMessage;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onPanUpdate: (details) {
          final swipedLeftToRight = details.delta.dx > 0;
          final swipedRightToLeft = details.delta.dx < 0;
          if (swipedLeftToRight) {
            _toggleHide(true);
          } else if (swipedRightToLeft) {
            _toggleHide(false);
          }
        },
        child: InkWell(
          splashColor: fuzzzyColors.ground,
          onLongPress: () {
            if (isEncryptedFile) {
              _openEncryptedFileDirectory(
                encryptedMessage: encryptedMessage,
                localizations: localizations,
              );
            } else {
              _copyMessage(
                encryptedMessage: encryptedMessage,
                localizations: localizations,
              );
            }
          },
          child: SizedBox(
            width: double.maxFinite,
            child: Align(
              alignment: Alignment.centerRight,
              child: Material(
                color: Colors.transparent,
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: borderRadius,
                    color: fuzzzyColors.actionPrimaryBg,
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: isExpandable
                            ? const EdgeInsets.only(bottom: 12)
                            : EdgeInsets.zero,
                        child: FuzzyOverlaySpawner(
                          splashColor: fuzzzyColors.ground,
                          splashRadius: borderRadius,
                          // Hangs from the bubble's top-right and grows
                          // leftwards, so it never leaves the screen.
                          targetAnchor: Alignment.topRight,
                          followerAnchor: Alignment.bottomRight,
                          offset: const Offset(0, 16),
                          spawnedChildBuilder: (context, closeOverlay) {
                            return FuzzyActionPill(
                              alignment: CrossAxisAlignment.end,
                              maxPerRow: isEncryptedFile ? 3 : 2,
                              actions: isEncryptedFile
                                  ? <TextAction>[
                                      TextAction(
                                        label: localizations.show,
                                        onTap: () {
                                          _openEncryptedFileDirectory(
                                            encryptedMessage: encryptedMessage,
                                            localizations: localizations,
                                          );
                                          closeOverlay();
                                        },
                                      ),
                                      TextAction(
                                        label: localizations.shareFile,
                                        onTap: () {
                                          _shareEncryptedFile(
                                            encryptedMessage: encryptedMessage,
                                            localizations: localizations,
                                          );
                                          closeOverlay();
                                        },
                                      ),
                                      TextAction(
                                        label: localizations.copy,
                                        onTap: () {
                                          final filePath =
                                              encryptedMessage.replaceAll(
                                            fuzzIdentificator,
                                            '',
                                          );
                                          Clipboard.setData(
                                            ClipboardData(text: filePath),
                                          );
                                          FuzzzyToast.show(
                                            context,
                                            message: localizations
                                                .copiedToTheClipboard,
                                          );
                                          closeOverlay();
                                        },
                                      ),
                                      TextAction(
                                        label: '🔗',
                                        onTap: () {
                                          _shareFuzzLink(encryptedMessage);
                                          closeOverlay();
                                        },
                                      ),
                                      TextAction(
                                        label: localizations.copyAsLink,
                                        onTap: () {
                                          _copyFuzzLink(
                                            encryptedMessage: encryptedMessage,
                                            localizations: localizations,
                                          );
                                          closeOverlay();
                                        },
                                      ),
                                    ]
                                  : <TextAction>[
                                      TextAction(
                                        label: localizations.copyFuzz,
                                        onTap: () {
                                          _copyMessage(
                                            encryptedMessage: encryptedMessage,
                                            localizations: localizations,
                                          );

                                          closeOverlay();
                                        },
                                      ),
                                      TextAction(
                                        label: localizations.share,
                                        onTap: () {
                                          final preparedEncryptedMessage =
                                              _prepareEncrypredMessage(
                                            encryptedMessage,
                                          );

                                          ShareHelper.share(
                                            preparedEncryptedMessage,
                                            context: context,
                                          );

                                          closeOverlay();
                                        },
                                      ),
                                      TextAction(
                                        label: localizations.copyAsLink,
                                        onTap: () {
                                          _copyFuzzLink(
                                            encryptedMessage: encryptedMessage,
                                            localizations: localizations,
                                          );
                                          closeOverlay();
                                        },
                                      ),
                                      TextAction(
                                        label: '🔗',
                                        onTap: () {
                                          _shareFuzzLink(encryptedMessage);
                                          closeOverlay();
                                        },
                                      ),
                                    ],
                            );
                          },
                          onLongPress: () {
                            _copyMessage(
                              encryptedMessage: encryptedMessage,
                              localizations: localizations,
                            );
                          },
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            padding: const EdgeInsets.all(12),
                            child: AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeIn,
                              child: isEncryptedFile
                                  ? _FileLabel(
                                      location: UserFileLocation.of(
                                        encryptedMessage,
                                      ),
                                      color: fuzzzyColors.actionPrimaryFg,
                                    )
                                  : Text(
                                      showEncrypted
                                          ? encryptedMessage
                                          : widget.message.decryptedMessage,
                                      maxLines: isExpanded ? null : 4,
                                      overflow: isExpanded
                                          ? TextOverflow.visible
                                          : TextOverflow.ellipsis,
                                      style: fuzzzyTextStyles.body.copyWith(
                                        color: fuzzzyColors.actionPrimaryFg,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      if (isExpandable)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: _toggleExpand,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 60,
                                  height: 24,
                                  color: Colors.white.withValues(alpha: 0),
                                ),
                                Icon(
                                  isExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  size: 24,
                                  color: fuzzzyColors.actionPrimaryFg,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The file's name over where the user finds it — never its path (T-0366).
class _FileLabel extends StatelessWidget {
  const _FileLabel({required this.location, required this.color});

  final UserFileLocation location;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fuzzzyTextStyles = context.fuzzzyTextStyles;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          location.fileName,
          style: fuzzzyTextStyles.body.copyWith(color: color),
        ),
        const SizedBox(height: 2),
        Text(
          location.folderLine,
          style: fuzzzyTextStyles.bodyS.copyWith(
            color: color.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}
