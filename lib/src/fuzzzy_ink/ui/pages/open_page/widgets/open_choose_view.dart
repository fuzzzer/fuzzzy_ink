import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// "Open what you got": Paste it (the clipboard is read only on this tap),
/// Choose a file (or drop one on a computer), and the tip that links and QR
/// codes open here by themselves.
class OpenChooseView extends StatefulWidget {
  const OpenChooseView({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<OpenChooseView> createState() => _OpenChooseViewState();
}

class _OpenChooseViewState extends State<OpenChooseView> {
  bool _isPicking = false;

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;
    if (text.isEmpty) {
      showInkToast(
        context,
        message: context.fuzzzyInkLocalizations.openNothingToPaste,
        kind: FuzzzyToastKind.info,
        qaId: 'open.nothingToPaste',
      );
      return;
    }
    await context.read<OpenFlowCubit>().open(OpenPastedText(text));
  }

  Future<void> _choose() async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      final result = await FilePicker.platform.pickFiles();
      final picked = result?.files.firstOrNull?.path;
      if (picked != null && mounted) {
        await context.read<OpenFlowCubit>().open(OpenChosenFile(picked));
      }
    } catch (error) {
      logger.w('OPEN: could not pick a file: $error');
      if (mounted) {
        FuzzzyToast.show(
          context,
          message: context.fuzzzyInkLocalizations.errorPickingFiles,
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;

    return FileDropArea(
      onDropped: (paths) {
        if (paths.isNotEmpty) {
          context.read<OpenFlowCubit>().open(OpenChosenFile(paths.first));
        }
      },
      child: FlowScaffold(
        qaId: 'open',
        title: localizations.open,
        onLeading: widget.onClose,
        leading: FlowLeading.close,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  localizations.openWhatYouGot,
                  style: context.fuzzzyTextStyles.titleL.copyWith(
                    color: context.fuzzzyColors.ink,
                  ),
                ),
              ),
              SizedBox(height: space.m),
              SheetDoorRow(
                qaId: 'open.paste',
                icon: Icons.content_paste,
                emphasised: true,
                title: localizations.openPasteIt,
                hint: localizations.openPasteItHint,
                onTap: _paste,
              ),
              SheetDoorRow(
                qaId: 'open.file',
                icon: Icons.insert_drive_file_outlined,
                title: localizations.openChooseFile,
                hint: localizations.openChooseFileHint,
                divider: false,
                onTap: _isPicking ? null : _choose,
              ),
              SizedBox(height: space.m),
              TipLine(
                icon: Icons.link,
                text: localizations.openLinksTip,
                qaId: 'open.links',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// While the paste or the file is recognised (and a message opened).
class OpenReadingView extends StatelessWidget {
  const OpenReadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return FlowScaffold(
      leading: FlowLeading.none,
      qaId: 'open.reading',
      children: [
        Padding(
          padding: EdgeInsets.only(top: context.fuzzzySpace.xxl),
          child: Column(
            children: [
              const FuzzzyProgressRing(qaId: 'open.reading'),
              SizedBox(height: context.fuzzzySpace.m),
              Semantics(
                liveRegion: true,
                child: Text(
                  context.fuzzzyInkLocalizations.openReading,
                  style: context.fuzzzyTextStyles.body.copyWith(
                    color: context.fuzzzyColors.inkMute,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
