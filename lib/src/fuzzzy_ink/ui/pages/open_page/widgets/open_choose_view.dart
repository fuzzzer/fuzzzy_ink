import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// "Open what you got": Paste it (the clipboard is read only on this tap;
/// on iPhone the system's own Paste button pastes without asking), Choose a
/// file (or drop one on a computer), and the tip that links and QR
/// codes open here by themselves.
///
/// Paste it never opens the whole clipboard: it shows a box with only the
/// locked part found in what was copied, to check, change or replace by
/// pasting by hand, and opens on Open (owner, 2026-10-28). When it found
/// more than one, it says how many and shows them one at a time
/// (owner, 2026-10-30).
class OpenChooseView extends StatefulWidget {
  const OpenChooseView({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<OpenChooseView> createState() => _OpenChooseViewState();
}

/// What the clipboard held when the paste box opened.
enum _Copied { found, nothingLocked, empty }

class _OpenChooseViewState extends State<OpenChooseView> {
  final _pasted = TextEditingController();
  bool _isPicking = false;

  /// Null while choosing; set while the paste box is shown.
  _Copied? _copied;

  /// Every locked part found in what was copied, and the one in the box.
  List<String> _found = const [];
  int _shownIndex = 0;

  @override
  void dispose() {
    _pasted.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    _showPasteBox(data?.text ?? '');
  }

  void _showPasteBox(String copied) {
    final found = FuzzyLinkParser.findAll(copied);
    _pasted.text = found.firstOrNull ?? '';
    setState(() {
      _found = found;
      _shownIndex = 0;
      _copied = found.isNotEmpty
          ? _Copied.found
          : copied.trim().isEmpty
              ? _Copied.empty
              : _Copied.nothingLocked;
    });
  }

  void _showNextFound() {
    setState(() => _shownIndex = (_shownIndex + 1) % _found.length);
    _pasted.text = _found[_shownIndex];
  }

  Future<void> _openPasted() async {
    final text = _pasted.text.trim();
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

  Widget _pasteBox(BuildContext context, _Copied copied) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;

    return FlowScaffold(
      qaId: 'open.pasteBox',
      title: localizations.openPasteIt,
      onLeading: () => setState(() => _copied = null),
      footer: ListenableBuilder(
        listenable: _pasted,
        builder: (context, _) => FuzzzyButton(
          qaId: 'open.pasteBox.open',
          label: localizations.open,
          onPressed: _pasted.text.trim().isEmpty ? null : _openPasted,
        ),
      ),
      children: [
        if (copied == _Copied.found)
          InkNotice(
            kind: InkNoticeKind.ok,
            text: _found.length > 1
                ? localizations.openPasteFoundMany(
                    _found.length,
                    _shownIndex + 1,
                  )
                : localizations.openPasteFound,
            qaId: 'open.pasteBox.found',
          )
        else if (copied == _Copied.nothingLocked)
          InkNotice(
            kind: InkNoticeKind.warning,
            text: localizations.openPasteNotFound,
            qaId: 'open.pasteBox.notFound',
          ),
        if (copied != _Copied.empty) SizedBox(height: space.l),
        FuzzzyTextField(
          qaId: 'open.pasteBox.text',
          controller: _pasted,
          autofocus: copied != _Copied.found,
          hint: localizations.openPasteBoxHint,
          keyboardType: TextInputType.multiline,
          minLines: 3,
          maxLines: 8,
        ),
        if (copied == _Copied.found && _found.length > 1) ...[
          SizedBox(height: space.m),
          FuzzzyButton(
            qaId: 'open.pasteBox.next',
            label: localizations.openPasteNext,
            variant: FuzzzyButtonVariant.secondary,
            onPressed: _showNextFound,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final copied = _copied;
    if (copied != null) return _pasteBox(context, copied);

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
                trailing: InkPasteButton.isAvailable
                    ? InkPasteButton(qaId: 'open', onPasted: _showPasteBox)
                    : null,
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
