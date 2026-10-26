import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';

/// One My safe item (DESIGN.md section 4.11), a private screen:
///
/// - password: username, the password hidden with an eye, the copy button
///   (while Settings → Copy passwords is on) whose icon becomes a check and
///   whose line counts down "Copied · clears in 30 s" until the copy guard
///   reports "Cleared.", website and notes;
/// - note: its text, shown but never selectable;
/// - file: its card, Open (shown inside the app from memory) and Save (the
///   system's save dialog; "Handed over" once it says saved).
///
/// The header holds Edit and More (Move to a group · Delete); the group row
/// has Move too. The page closes itself when My safe locks.
class VaultItemPage extends StatefulWidget {
  const VaultItemPage({super.key, required this.item});

  final VaultItem item;

  @override
  State<VaultItemPage> createState() => _VaultItemPageState();
}

class _VaultItemPageState extends State<VaultItemPage> {
  late VaultItem _item = widget.item;
  late final SafeCopyCountdown _copy = SafeCopyCountdown();
  List<VaultGroupData> _groups = const [];
  bool _showsPassword = false;
  final List<String> _plainCopies = [];

  VaultRepository get _repository => sl.get<VaultRepository>();
  UserFileStore get _store => sl.get<UserFileStore>();

  /// The copy button shows only while both the copy rule and the Settings
  /// switch allow it.
  bool get _canCopy =>
      allowVaultPasswordCopy && sl.get<PreferencesService>().vaultPasswordCopy;

  @override
  void initState() {
    super.initState();
    unawaited(_loadGroups());
  }

  @override
  void dispose() {
    _copy.dispose();
    for (final path in _plainCopies) {
      unawaited(_store.wipe(path));
    }
    super.dispose();
  }

  Future<void> _loadGroups() async {
    final res = await _repository.getAllGroups();
    if (!mounted || res is! VaultSuccess<List<VaultGroupData>>) return;
    setState(() => _groups = res.data);
  }

  String? get _groupName {
    final id = _item.metadata.groupId;
    if (id == VaultGroupData.generalGroupId) return null;
    for (final group in _groups) {
      if (group.id == id) return group.name;
    }
    return null;
  }

  // ---------------------------------------------------------------- copy

  Future<void> _copyPassword() async {
    final password = _item.passwordContent?.password ?? '';
    if (password.isEmpty) return;
    final isCopied = await CopyGuard.copyQuietly(
      text: password,
      content: CopyContent.vaultPassword,
    );
    if (!isCopied || !mounted) return;
    _copy.start(
      copyId: CopyGuard.lastCopyId,
      clearAfter: CopyPolicy.vaultPasswordClearAfter,
    );
    unawaited(InkHaptics.light());
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        context.fuzzzyInkLocalizations.confirmCopied,
        Directionality.of(context),
      ),
    );
  }

  // ---------------------------------------------------------------- files

  /// A short-lived plain copy in the app's private hand-off folder, wiped
  /// when this page closes (and at the next launch at the latest).
  Future<String> _writePlainCopy() async {
    final file = _item.fileContent!;
    final path = await _store.newHandoffPath(file.fileName);
    await File(path).writeAsBytes(Uint8List.fromList(file.fileBytes));
    _plainCopies.add(path);
    return path;
  }

  /// The system save dialog; `true` once it says the file was saved.
  Future<bool> _save() async {
    final file = _item.fileContent;
    if (file == null) return false;
    final path = await _writePlainCopy();
    try {
      if (!mounted) return false;
      return await DeviceFileInteractor.saveFile(
        path,
        fileName: file.fileName,
        store: _store,
        dialogTitle: context.fuzzzyInkLocalizations.saveFile,
        context: context,
      );
    } catch (error) {
      logger.w('MY SAFE: could not save a file: $error');
      if (mounted) {
        showInkToast(
          context,
          message: context.fuzzzyInkLocalizations.couldNotSaveFile,
          kind: FuzzzyToastKind.error,
        );
      }
      return false;
    } finally {
      _plainCopies.remove(path);
      await _store.wipe(path);
    }
  }

  Future<void> _open() async {
    final file = _item.fileContent;
    if (file == null) return;
    await PlainFileViewerPage.show(
      context,
      fileName: file.fileName,
      bytes: Uint8List.fromList(file.fileBytes),
      onSave: (_) => _save(),
      onShare: _share,
    );
  }

  Future<void> _share(BuildContext context) async {
    final path = await _writePlainCopy();
    if (!context.mounted) return;
    await shareFileForUser(context, filePath: path, store: _store);
    _store.wipeWhenBack(path);
  }

  // ---------------------------------------------------------- edit, more

  Future<void> _edit() async {
    final saved = await context.push<VaultItem>(
      AppRouter.vaultItemEditor,
      extra: VaultItemEditorPagePayload(
        type: _item.metadata.type,
        existingItem: _item,
        groupId: _item.metadata.groupId,
      ),
    );
    if (saved == null || !mounted) return;
    setState(() => _item = saved);
    showInkToast(
      context,
      message: context.fuzzzyInkLocalizations.safeSaved,
      qaId: 'safe.saved',
    );
  }

  Future<void> _more() async {
    final choice = await showSafeItemMenu(context);
    if (!mounted) return;
    switch (choice) {
      case SafeItemMenuChoice.move:
        await _move();
      case SafeItemMenuChoice.delete:
        await _delete();
      case null:
        return;
    }
  }

  Future<void> _move() async {
    if (_groups.isEmpty) await _loadGroups();
    if (!mounted) return;
    final groupId = await showSafeMoveSheet(
      context,
      groups: _groups,
      currentGroupId: _item.metadata.groupId,
    );
    if (groupId == null || groupId == _item.metadata.groupId || !mounted) {
      return;
    }
    final res = await _repository.moveItemToGroup(_item.metadata.id, groupId);
    if (!mounted) return;
    final localizations = context.fuzzzyInkLocalizations;
    if (res is! VaultSuccess) {
      showInkToast(
        context,
        message: localizations.safeSaveFailed,
        kind: FuzzzyToastKind.error,
      );
      return;
    }
    setState(() {
      _item = _item.copyWith(
        metadata: _item.metadata.copyWith(groupId: groupId),
      );
    });
    final name = _groupName;
    showInkToast(
      context,
      message: name == null
          ? localizations.safeMovedOut
          : localizations.safeMovedTo(name),
    );
  }

  Future<void> _delete() async {
    final localizations = context.fuzzzyInkLocalizations;
    final confirmed = await FuzzzyDialog.show<bool>(
      context,
      qaId: 'safe.delete',
      title: localizations.safeDeleteTitle(_item.metadata.title),
      content: Text(localizations.safeDeleteLine),
      actions: [
        Builder(
          builder: (dialogContext) => FuzzzyButton(
            label: localizations.cancel,
            variant: FuzzzyButtonVariant.secondary,
            size: FuzzzyButtonSize.s,
            qaId: 'safe.delete.cancel',
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
        ),
        Builder(
          builder: (dialogContext) => FuzzzyButton(
            label: localizations.delete,
            variant: FuzzzyButtonVariant.destructive,
            size: FuzzzyButtonSize.s,
            qaId: 'safe.delete.confirm',
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    final res = await _repository.deleteItem(_item.metadata.id);
    if (!mounted) return;
    if (res is! VaultSuccess) {
      showInkToast(
        context,
        message: localizations.safeSaveFailed,
        kind: FuzzzyToastKind.error,
      );
      return;
    }
    showInkToast(
      context,
      message: localizations.safeDeleted,
      kind: FuzzzyToastKind.info,
      qaId: 'safe.deleted',
    );
    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;

    return BlocListener<VaultAuthCubit, VaultAuthState>(
      listenWhen: (_, current) => current.authState != VaultAuthEnum.unlocked,
      // Locked: everything of this item above the safe closes.
      listener: (context, _) {
        final navigator = Navigator.of(context);
        final route = ModalRoute.of(context);
        if (route == null) return;
        navigator.popUntil((r) => r == route);
        navigator.pop();
      },
      child: Scaffold(
        backgroundColor: context.fuzzzyColors.ground,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FuzzzyAppBar(
                qaId: 'safe.item',
                title: _item.metadata.title,
                leading: FuzzzyIconButton(
                  icon: const Icon(Icons.arrow_back),
                  semanticLabel:
                      MaterialLocalizations.of(context).backButtonTooltip,
                  qaId: 'safe.item.back',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                actions: [
                  FuzzzyIconButton(
                    icon: const Icon(Icons.edit_outlined),
                    semanticLabel: localizations.safeEdit,
                    qaId: 'safe.item.edit',
                    onPressed: _edit,
                  ),
                  SizedBox(width: space.xs),
                  FuzzzyIconButton(
                    icon: const Icon(Icons.more_horiz),
                    semanticLabel:
                        localizations.safeMoreFor(_item.metadata.title),
                    qaId: 'safe.item.more',
                    onPressed: _more,
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding:
                      EdgeInsets.fromLTRB(space.l, space.s, space.l, space.xl),
                  children: [
                    ...switch (_item.metadata.type) {
                      VaultItemType.password => _password(context),
                      VaultItemType.note => _note(context),
                      VaultItemType.file => _file(context),
                    },
                    SafeField(
                      label: localizations.safeGroup,
                      value: _groupName ?? localizations.safeNoGroup,
                      qaId: 'group',
                      actions: [
                        FuzzzyButton(
                          label: localizations.safeMove,
                          variant: FuzzzyButtonVariant.ghost,
                          size: FuzzzyButtonSize.s,
                          qaId: 'safe.item.move',
                          onPressed: _move,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _password(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final content = _item.passwordContent;
    final password = content?.password ?? '';
    final website = content?.url ?? '';
    final notes = content?.notes ?? '';
    final canCopy = _canCopy;

    return [
      SafeField(
        label: localizations.safeUsername,
        value: content?.username ?? '',
        qaId: 'username',
      ),
      ListenableBuilder(
        listenable: _copy,
        builder: (context, _) {
          final isCopied = _copy.phase == SafeCopyPhase.copied;
          return SafeField(
            label: localizations.vaultPasswordLabel,
            value: _showsPassword ? password : '•' * 12,
            mono: true,
            qaId: 'password',
            actions: [
              FuzzzyIconButton(
                icon: Icon(
                  _showsPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                semanticLabel: _showsPassword
                    ? localizations.safeHidePassword
                    : localizations.safeShowPassword,
                qaId: 'safe.item.show',
                onPressed: () =>
                    setState(() => _showsPassword = !_showsPassword),
              ),
              if (canCopy) ...[
                SizedBox(width: context.fuzzzySpace.xs),
                FuzzzyIconButton(
                  icon: isCopied
                      ? CheckDraw(
                          key: ValueKey(CopyGuard.lastCopyId),
                          size: context.fuzzzyIconSize.m,
                        )
                      : const Icon(Icons.copy_outlined),
                  semanticLabel: localizations.vaultCopyPassword,
                  qaId: 'safe.item.copy',
                  onPressed: password.isEmpty ? null : _copyPassword,
                ),
              ],
            ],
          );
        },
      ),
      if (website.isNotEmpty)
        SafeField(
          label: localizations.safeWebsite,
          value: website,
          qaId: 'website',
        ),
      if (notes.isNotEmpty)
        SafeField(
          label: localizations.safeNotes,
          value: notes,
          qaId: 'notes',
        ),
      SizedBox(height: context.fuzzzySpace.m),
      ListenableBuilder(
        listenable: _copy,
        builder: (context, _) => Semantics(
          liveRegion: true,
          child: TipLine(
            icon: canCopy ? Icons.schedule : Icons.content_copy_outlined,
            text: _copyLine(context, canCopy),
            qaId: 'safe.copyLine',
          ),
        ),
      ),
      SizedBox(height: context.fuzzzySpace.m),
    ];
  }

  String _copyLine(BuildContext context, bool canCopy) {
    final localizations = context.fuzzzyInkLocalizations;
    final rule = localizations.safeCopyRule(
      CopyPolicy.vaultPasswordClearAfter.inSeconds,
    );
    if (!canCopy) return localizations.safeCopyOff;
    return switch (_copy.phase) {
      SafeCopyPhase.idle => rule,
      SafeCopyPhase.copied => localizations.safeCopiedClearsIn(
          _copy.secondsLeft,
        ),
      SafeCopyPhase.cleared => '${localizations.safeCleared} $rule',
    };
  }

  List<Widget> _note(BuildContext context) {
    final colors = context.fuzzzyColors;
    final space = context.fuzzzySpace;
    return [
      SizedBox(height: space.s),
      Container(
        key: const Key('safe.item.note'),
        padding: context.fuzzzyDensity.panel,
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.line),
          borderRadius: BorderRadius.circular(context.fuzzzyRadius.l),
        ),
        // Shown, never selectable: a note stays inside the app.
        child: Text(
          _item.noteContent?.plainText ?? '',
          style: context.fuzzzyTextStyles.body.copyWith(color: colors.ink),
        ),
      ),
      SizedBox(height: space.s),
      KeyTag(
        label: context.fuzzzyInkLocalizations.tagNoCopy,
        qaId: 'safe.noCopy',
      ),
      SizedBox(height: space.m),
    ];
  }

  List<Widget> _file(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    final file = _item.fileContent;
    if (file == null) return const [];
    return [
      SizedBox(height: space.s),
      FileCard(
        name: file.fileName,
        size: formatSafeFileSize(file.fileBytes.length),
        state: FileCardState.keptInSafe,
        qaId: 'safe.item',
      ),
      SizedBox(height: space.m),
      Row(
        children: [
          Expanded(
            child: FuzzzyButton(
              label: localizations.open,
              icon: const Icon(Icons.visibility_outlined),
              qaId: 'safe.item.open',
              onPressed: _open,
            ),
          ),
          SizedBox(width: space.s),
          Expanded(
            child: InPlaceConfirmButton(
              label: localizations.saveFile,
              confirmedLabel: localizations.confirmHandedOver,
              icon: const Icon(Icons.save_alt),
              hold: InkMotionTiming.handedOverHold,
              qaId: 'safe.item.save',
              onPressed: _save,
            ),
          ),
        ],
      ),
      SizedBox(height: space.m),
      TipLine(
        icon: Icons.lock_outline,
        text: localizations.safeSaveTip,
        trailing: const WhyLink(topic: InkInfoTopic.files, qaId: 'safe.files'),
        qaId: 'safe.saveTip',
      ),
      SizedBox(height: space.m),
    ];
  }
}

/// "640 KB", "3.1 MB".
String formatSafeFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
