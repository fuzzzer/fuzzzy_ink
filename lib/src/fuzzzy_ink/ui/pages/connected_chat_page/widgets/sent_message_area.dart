import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:path/path.dart' as path;

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
    required FuzzzyInkLocalizations localizations,
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
    required FuzzzyInkLocalizations localizations,
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

  /// A sent file row keeps the `.fuzz` container itself — sealed, so it is
  /// shared and saved as it is.
  Future<void> _shareEncryptedFile() {
    final cubit = context.read<ChatFileCubit>();
    return shareFileForUser(
      context,
      filePath: cubit.sealedPathOf(widget.message),
      store: cubit.userFileStore,
    );
  }

  Future<void> _saveEncryptedFile() {
    final cubit = context.read<ChatFileCubit>();
    return saveFileForUser(
      context,
      filePath: cubit.sealedPathOf(widget.message),
      fileName: path.basename(widget.message.encryptedMessage),
      store: cubit.userFileStore,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fuzzzyColors = context.fuzzzyColors;
    final fuzzzyTextStyles = context.fuzzzyTextStyles;

    final localizations = context.fuzzzyInkLocalizations;

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
              _shareEncryptedFile();
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
                              maxPerRow: 2,
                              actions: isEncryptedFile
                                  ? <TextAction>[
                                      TextAction(
                                        label: localizations.shareFile,
                                        onTap: () {
                                          closeOverlay();
                                          _shareEncryptedFile();
                                        },
                                      ),
                                      TextAction(
                                        label: localizations.saveFile,
                                        onTap: () {
                                          closeOverlay();
                                          _saveEncryptedFile();
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
                            // A file row's text is its stored path: never
                            // copied.
                            if (isEncryptedFile) {
                              _shareEncryptedFile();
                              return;
                            }
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
                                      fileName: UserFileNames.forDisplay(
                                        ChatFileCubit.fileNameOf(
                                          widget.message,
                                        ),
                                      ),
                                      hint: localizations.sentFileHint,
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

/// The file's name over what the user can do with it — never its path.
class _FileLabel extends StatelessWidget {
  const _FileLabel({
    required this.fileName,
    required this.hint,
    required this.color,
  });

  final String fileName;
  final String hint;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fuzzzyTextStyles = context.fuzzzyTextStyles;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          fileName,
          style: fuzzzyTextStyles.body.copyWith(color: color),
        ),
        const SizedBox(height: 2),
        Text(
          hint,
          style: fuzzzyTextStyles.bodyS.copyWith(
            color: color.withValues(alpha: 0.72),
          ),
        ),
      ],
    );
  }
}
