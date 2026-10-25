import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// A received file: the app keeps it sealed (`PROTOCOL.md` §9.6). Open shows
/// it in the app, Save gives it to the system save dialog, Share to the
/// share sheet; each unfuzzes a short-lived copy that is wiped right after.
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
  String get _fileName => ChatFileCubit.fileNameOf(widget.message);

  Future<void> _open() async {
    final cubit = context.read<ChatFileCubit>();
    final store = cubit.userFileStore;
    final copy = await unfuzzChatFile(context, widget.message);
    if (copy == null || !mounted) return;

    // The viewer is a route of its own: it gets the store, not this context.
    await PlainFileViewerPage.show(
      context,
      fileName: _fileName,
      filePath: copy,
      onSave: (viewerContext) => saveFileForUser(
        viewerContext,
        filePath: copy,
        fileName: _fileName,
        store: store,
      ),
      onShare: (viewerContext) async {
        await shareFileForUser(viewerContext, filePath: copy, store: store);
        cubit.wipeWhenBack(copy);
      },
      onClosed: () => cubit.wipe(copy),
    );
  }

  Future<void> _save() async {
    final cubit = context.read<ChatFileCubit>();
    final copy = await unfuzzChatFile(context, widget.message);
    if (copy == null || !mounted) return;
    await saveFileForUser(
      context,
      filePath: copy,
      fileName: _fileName,
      store: cubit.userFileStore,
    );
    await cubit.wipe(copy);
  }

  Future<void> _share() async {
    final cubit = context.read<ChatFileCubit>();
    final copy = await unfuzzChatFile(context, widget.message);
    if (copy == null || !mounted) return;
    await shareFileForUser(context, filePath: copy, store: cubit.userFileStore);
    cubit.wipeWhenBack(copy);
  }

  @override
  Widget build(BuildContext context) {
    final fuzzzyTextStyles = context.fuzzzyTextStyles;
    final fuzzzyColors = context.fuzzzyColors;

    final localizations = context.fuzzzyInkLocalizations;

    // Read per build: the list has no keys, so this State is reused for
    // whatever file row lands at its index.
    final fileName =
        UserFileNames.forDisplay(ChatFileCubit.fileNameOf(widget.message));

    const borderRadius = BorderRadius.only(
      topLeft: Radius.circular(12),
      topRight: Radius.circular(12),
      bottomLeft: Radius.circular(12),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onLongPress: _open,
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
                      label: localizations.open,
                      onTap: () {
                        closeOverlay();
                        _open();
                      },
                    ),
                    TextAction(
                      label: localizations.saveFile,
                      onTap: () {
                        closeOverlay();
                        _save();
                      },
                    ),
                    TextAction(
                      label: localizations.shareFile,
                      onTap: () {
                        closeOverlay();
                        _share();
                      },
                    ),
                    // A file's path is never copied, and neither is a link
                    // made of it (copy_guard).
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
                      fileName,
                      style: fuzzzyTextStyles.body.copyWith(
                        color: fuzzzyColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      localizations.receivedFileHint,
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
