import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';

/// The one Share action for a sealed invitation, acceptance or message: as a
/// link (system share sheet), as a QR code on screen, or as a text file.
/// Only what [content] can do is offered. Copying stays with the copy
/// actions; this sheet never touches the clipboard.
Future<void> showSealedShareSheet(
  BuildContext context, {
  required SealedShareContent content,
}) {
  return FuzzzyBottomSheet.show<void>(
    context,
    qaId: 'share',
    builder: (sheetContext) {
      final localizations = sheetContext.fuzzzyInkLocalizations;

      void choose(Future<void> Function() action) {
        Navigator.of(sheetContext).pop();
        action();
      }

      final link = content.link;

      return FuzzzyBottomSheet(
        qaId: 'share',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (link != null)
              _ShareOption(
                qaId: 'share.link',
                icon: Icons.link,
                title: localizations.shareAsLinkOption,
                hint: localizations.shareAsLinkOptionHint,
                onTap: () =>
                    choose(() => ShareHelper.share(link, context: context)),
              ),
            if (content.canShowQrCode)
              _ShareOption(
                qaId: 'share.qr',
                icon: Icons.qr_code_2,
                title: localizations.shareAsQrCodeOption,
                hint: localizations.shareAsQrCodeOptionHint,
                onTap: () => choose(
                  () => showQrCodeDialog(context, data: content.link!),
                ),
              ),
            if (ShareHelper.canShareFiles)
              _ShareOption(
                qaId: 'share.file',
                icon: Icons.description_outlined,
                title: localizations.shareAsFileOption,
                hint: localizations.shareAsFileOptionHint,
                divider: false,
                onTap: () => choose(
                  () => ShareHelper.shareTextAsFile(
                    content.sealedText,
                    fileName: content.fileName,
                    context: context,
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// [data] as a QR code for another phone's camera.
Future<void> showQrCodeDialog(BuildContext context, {required String data}) {
  final localizations = context.fuzzzyInkLocalizations;

  return FuzzzyDialog.showBuilder<void>(
    context,
    builder: (dialogContext) => FuzzzyDialog(
      qaId: 'share.qr',
      title: localizations.shareAsQrCodeOption,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Square, and short enough that the hint and the button still fit
          // on a phone held sideways.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.45,
            ),
            child: QrCodeView(
              data: data,
              semanticLabel: localizations.shareAsQrCodeOption,
            ),
          ),
          SizedBox(height: dialogContext.fuzzzySpace.m),
          Text(localizations.qrCodeHint),
        ],
      ),
      actions: [
        FuzzzyButton(
          qaId: 'share.qr.close',
          label: localizations.close,
          variant: FuzzzyButtonVariant.secondary,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
      ],
    ),
  );
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.qaId,
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
    this.divider = true,
  });

  final String qaId;
  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;

    return FuzzzyListTile(
      qaId: qaId,
      leading: Icon(icon, color: colors.ink),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          Text(
            hint,
            style: context.fuzzzyTextStyles.bodyS.copyWith(
              color: colors.inkMute,
            ),
          ),
        ],
      ),
      chevron: true,
      divider: divider,
      onTap: onTap,
    );
  }
}
