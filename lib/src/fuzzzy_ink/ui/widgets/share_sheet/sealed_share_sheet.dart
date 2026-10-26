import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:share_plus/share_plus.dart';

/// What the person did in the Share sheet.
enum SealedShareAction { link, qrCode, file, copied }

/// The Share sheet's outcome: which way it went and, for the system share,
/// whether the system reported it finished (iOS and macOS always say;
/// Android only where the platform does). "Share again" and the next step
/// swap in only when [isDone].
class SealedShareResult {
  const SealedShareResult(this.action, {required this.isDone});

  final SealedShareAction action;
  final bool isDone;
}

/// The one Share button (DESIGN.md section 4.10): "Share invite" (or reply,
/// locked message) with one line under it, then Send a link · Show a QR code
/// · Send as a file · Copy as text. What [content] cannot do is left out, or
/// shown off with its reason ("Too big. Send it as a file."). Copy as text
/// confirms in its row ("Copied. It stays locked."), then the sheet closes;
/// it copies only the locked text, through the copy guard.
///
/// [personName] fills "Only Tamar can open it." for a message. Answers what
/// happened, or null when the sheet was closed.
Future<SealedShareResult?> showSealedShareSheet(
  BuildContext context, {
  required SealedShareContent content,
  String? personName,
}) async {
  final picked = await FuzzzyBottomSheet.show<_Pick>(
    context,
    qaId: 'share',
    builder: (sheetContext) => FuzzzyBottomSheet(
      qaId: 'share',
      child: _ShareSheetBody(content: content, personName: personName),
    ),
  );
  if (picked == null || !context.mounted) return null;

  switch (picked) {
    case _Pick.copied:
      return const SealedShareResult(SealedShareAction.copied, isDone: true);
    case _Pick.qrCode:
      await showSealedQrCode(context, content: content, personName: personName);
      return const SealedShareResult(SealedShareAction.qrCode, isDone: true);
    case _Pick.link:
      final done = await ShareHelper.share(content.link!, context: context);
      if (done) unawaited(InkHaptics.light());
      return SealedShareResult(SealedShareAction.link, isDone: done);
    case _Pick.file:
      final done = await _shareAsFile(context, content);
      if (done) unawaited(InkHaptics.light());
      return SealedShareResult(SealedShareAction.file, isDone: done);
  }
}

enum _Pick { link, qrCode, file, copied }

/// Locked text goes as a small `.fuzz` file of that text; a locked file as
/// itself. Android hands a file over only from the hand-off folder and says
/// nothing about the result, so there it never counts as done.
Future<bool> _shareAsFile(
  BuildContext context,
  SealedShareContent content,
) async {
  final filePath = content.filePath;
  if (filePath == null) {
    return ShareHelper.shareTextAsFile(
      content.sealedText,
      fileName: content.fileName,
      mimeType: DeviceFileInteractor.explicitMimeType(content.fileName) ??
          'text/plain',
      context: context,
    );
  }
  try {
    if (Platform.isAndroid) {
      await DeviceFileInteractor.shareFile(
        filePath,
        store: sl.get<UserFileStore>(),
        context: context,
      );
      return false;
    }
    return await ShareHelper.shareXFiles(
      [
        XFile(
          filePath,
          mimeType: DeviceFileInteractor.explicitMimeType(filePath),
        ),
      ],
      context: context,
    );
  } catch (error) {
    logger.w('SHARE: could not share the locked file: $error');
    if (context.mounted) {
      FuzzzyToast.show(
        context,
        message: context.fuzzzyInkLocalizations.couldNotOpenFile,
      );
    }
    return false;
  }
}

class _ShareSheetBody extends StatefulWidget {
  const _ShareSheetBody({required this.content, this.personName});

  final SealedShareContent content;
  final String? personName;

  @override
  State<_ShareSheetBody> createState() => _ShareSheetBodyState();
}

class _ShareSheetBodyState extends State<_ShareSheetBody> {
  bool _isCopied = false;
  Timer? _close;

  @override
  void dispose() {
    _close?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    final content = widget.content;
    final copied = await CopyGuard.copyQuietly(
      text: content.sealedText,
      content: content.kind.copyContent,
    );
    if (!mounted) return;
    final localizations = context.fuzzzyInkLocalizations;
    if (!copied) {
      FuzzzyToast.show(context, message: localizations.copyRefused);
      return;
    }
    setState(() => _isCopied = true);
    unawaited(InkHaptics.light());
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        localizations.shareCopiedStaysLocked,
        Directionality.of(context),
      ),
    );
    _close = Timer(InkMotionTiming.sheetCloseAfterCopy, () {
      if (mounted) Navigator.of(context).pop(_Pick.copied);
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final colors = context.fuzzzyColors;
    final type = context.fuzzzyTextStyles;
    final content = widget.content;
    final name = widget.personName;
    final link = content.link;

    final title = switch (content.kind) {
      SealedShareKind.invitation => localizations.shareTitleInvite,
      SealedShareKind.acceptance => localizations.shareTitleReply,
      SealedShareKind.message ||
      SealedShareKind.passwordText =>
        localizations.shareTitleMessage,
      SealedShareKind.file => localizations.shareTitleFile,
    };
    final line = switch (content.kind) {
      SealedShareKind.invitation => localizations.shareLineInvite,
      SealedShareKind.acceptance => localizations.shareLineReply,
      SealedShareKind.passwordText => localizations.shareLinePassword,
      SealedShareKind.message =>
        name == null ? null : localizations.shareLineForName(name),
      // A file without a person is a password file.
      SealedShareKind.file => name == null
          ? localizations.shareLinePassword
          : localizations.shareLineForName(name),
    };

    void pick(_Pick value) => Navigator.of(context).pop(value);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: type.titleL.copyWith(color: colors.ink)),
        ),
        if (line != null) ...[
          SizedBox(height: context.fuzzzySpace.xs),
          Text(line, style: type.bodyS.copyWith(color: colors.inkMute)),
        ],
        SizedBox(height: context.fuzzzySpace.m),
        if (link != null)
          _ShareRow(
            qaId: 'share.link',
            icon: Icons.link,
            emphasised: true,
            title: localizations.shareSendLink,
            hint: localizations.shareSendLinkHint,
            onTap: () => pick(_Pick.link),
          ),
        _ShareRow(
          qaId: 'share.qr',
          icon: Icons.qr_code_2,
          title: localizations.shareShowQr,
          hint: content.canShowQrCode
              ? localizations.shareShowQrHint
              : localizations.shareTooBig,
          onTap: content.canShowQrCode ? () => pick(_Pick.qrCode) : null,
        ),
        if (ShareHelper.canShareFiles)
          _ShareRow(
            qaId: 'share.file',
            icon: Icons.description_outlined,
            title: localizations.shareSendFile,
            hint: localizations.shareSendFileHint,
            onTap: () => pick(_Pick.file),
          ),
        if (!content.isFile)
          _ShareRow(
            qaId: 'share.copy',
            icon: _isCopied ? null : Icons.copy_outlined,
            confirmed: _isCopied,
            title: _isCopied
                ? localizations.shareCopiedStaysLocked
                : localizations.shareCopyText,
            hint: _isCopied ? null : localizations.shareCopyTextHint,
            onTap: _isCopied ? () {} : _copy,
            divider: false,
          ),
      ],
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.qaId,
    required this.title,
    required this.onTap,
    this.icon,
    this.hint,
    this.emphasised = false,
    this.confirmed = false,
    this.divider = true,
  });

  final String qaId;
  final IconData? icon;
  final String title;
  final String? hint;

  /// Null shows the row switched off (its hint says why).
  final VoidCallback? onTap;
  final bool emphasised;
  final bool confirmed;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final colors = context.fuzzzyColors;
    final type = context.fuzzzyTextStyles;
    final space = context.fuzzzySpace;
    final isOff = onTap == null;
    final inverted = emphasised || confirmed;
    final hint = this.hint;

    final box = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: inverted ? colors.actionPrimaryBg : colors.surface,
        border: Border.all(
          color: inverted ? colors.actionPrimaryBg : colors.line,
        ),
        borderRadius: BorderRadius.circular(context.fuzzzyRadius.m),
      ),
      child: confirmed
          ? CheckDraw(
              size: context.fuzzzyIconSize.l,
              color: colors.actionPrimaryFg,
            )
          : Icon(
              icon,
              size: context.fuzzzyIconSize.l,
              color: inverted ? colors.actionPrimaryFg : colors.ink,
            ),
    );

    return Semantics(
      identifier: qaId,
      button: true,
      enabled: !isOff,
      container: true,
      liveRegion: confirmed,
      child: Opacity(
        opacity: isOff ? 0.5 : 1,
        child: FuzzzyTappable(
          key: Key(qaId),
          onTap: onTap,
          focusRingInset: true,
          builder: (context, active) => Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: EdgeInsets.symmetric(vertical: space.m),
            decoration: BoxDecoration(
              color: active ? colors.surface : null,
              border: divider
                  ? Border(bottom: BorderSide(color: colors.line))
                  : null,
            ),
            child: Row(
              children: [
                ExcludeSemantics(child: box),
                SizedBox(width: space.m + space.xs / 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: type.titleS.copyWith(color: colors.ink),
                      ),
                      if (hint != null)
                        Text(
                          hint,
                          style: type.bodyS.copyWith(color: colors.inkMute),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The QR code on its own screen: a white card with the code, the mark above
/// it, who should scan it and whether it is safe to show. For a friend's
/// camera; the code is the same link "Send a link" shares.
Future<void> showSealedQrCode(
  BuildContext context, {
  required SealedShareContent content,
  String? personName,
}) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      transitionDuration: context.fuzzzyMotion.standard,
      reverseTransitionDuration: context.fuzzzyMotion.standard,
      pageBuilder: (routeContext, _, __) =>
          SealedQrCodePage(content: content, personName: personName),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// The full-screen QR code (DESIGN.md section 4.10).
class SealedQrCodePage extends StatelessWidget {
  const SealedQrCodePage({super.key, required this.content, this.personName});

  final SealedShareContent content;
  final String? personName;

  /// The code's size on a phone (DESIGN.md: 220; 280 on wide screens).
  static double codeSizeFor(double width) => width >= 600 ? 280 : 220;

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final colors = context.fuzzzyColors;
    final type = context.fuzzzyTextStyles;
    final space = context.fuzzzySpace;
    final name = personName;
    final isInvite = content.kind == SealedShareKind.invitation;
    final label = switch (content.kind) {
      SealedShareKind.invitation => localizations.qrLabelInvite,
      SealedShareKind.acceptance => localizations.qrLabelReply,
      SealedShareKind.message ||
      SealedShareKind.passwordText ||
      SealedShareKind.file =>
        localizations.qrLabelMessage,
    };
    final codeSize = codeSizeFor(MediaQuery.sizeOf(context).width);

    return Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: context.fuzzzyDensity.screen,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const InkMark(qaId: 'qr'),
                  SizedBox(height: space.m),
                  Text(
                    label.toUpperCase(),
                    style: type.label.copyWith(color: colors.inkMute),
                  ),
                  SizedBox(height: space.l),
                  // The quiet zone is white in both looks: cameras expect
                  // dark modules on light.
                  Container(
                    key: const Key('share.qr.card'),
                    padding: EdgeInsets.all(space.l),
                    decoration: BoxDecoration(
                      color: FuzzzyPalette.raised,
                      borderRadius:
                          BorderRadius.circular(context.fuzzzyRadius.l),
                      border: Border.all(color: colors.line),
                    ),
                    child: SizedBox.square(
                      dimension: codeSize,
                      child: Theme(
                        data: FuzzzyTheme.build(),
                        child: QrCodeView(
                          data: content.link!,
                          semanticLabel: localizations.shareShowQr,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: space.l),
                  Text(
                    name == null
                        ? localizations.qrLetThemScan
                        : localizations.qrLetNameScan(name),
                    textAlign: TextAlign.center,
                    style: type.titleS.copyWith(color: colors.ink),
                  ),
                  SizedBox(height: space.xs),
                  Text(
                    isInvite
                        ? localizations.qrSafeToShowAnyone
                        : localizations.qrOnlyRightPerson,
                    textAlign: TextAlign.center,
                    style: type.bodyS.copyWith(color: colors.inkMute),
                  ),
                  SizedBox(height: space.xl),
                  FuzzzyButton(
                    label: localizations.close,
                    variant: FuzzzyButtonVariant.secondary,
                    qaId: 'share.qr.close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
