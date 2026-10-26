import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_ink/src/src.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:uuid/uuid.dart';

class VaultItemEditorPagePayload {
  final VaultItemType type;
  final VaultItem? existingItem; // null if creating a new item
  final String groupId;

  const VaultItemEditorPagePayload({
    required this.type,
    this.existingItem,
    this.groupId = VaultGroupData.generalGroupId,
  });
}

/// New password · New note · New file, and Edit (DESIGN.md section 4.11),
/// a private screen. Every field holds plaintext: paste works, copy, cut,
/// share and look-up never appear ([VaultPlaintextField]). A file is read
/// into memory and the picker's plain copy is discarded at once; the
/// original stays where it was. Save is the one main button; it closes the
/// page with the saved item. The page closes itself when My safe locks.
class VaultItemEditorPage extends StatefulWidget {
  final VaultItemEditorPagePayload payload;

  const VaultItemEditorPage({super.key, required this.payload});

  @override
  State<VaultItemEditorPage> createState() => _VaultItemEditorPageState();
}

class _VaultItemEditorPageState extends State<VaultItemEditorPage> {
  late final VaultItemType _type = widget.payload.type;
  late final TextEditingController _titleController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _urlController;
  late final TextEditingController _notesController;

  bool _isPasswordVisible = false;
  bool _isSaving = false;
  bool _needsFile = false;

  List<int>? _fileBytes;
  String? _fileName;

  VaultItem? get _existing => widget.payload.existingItem;

  @override
  void initState() {
    super.initState();
    final item = _existing;
    _titleController = TextEditingController(text: item?.metadata.title ?? '');
    _usernameController =
        TextEditingController(text: item?.passwordContent?.username ?? '');
    _passwordController =
        TextEditingController(text: item?.passwordContent?.password ?? '');
    _urlController =
        TextEditingController(text: item?.passwordContent?.url ?? '');
    _notesController = TextEditingController(
      text: _type == VaultItemType.password
          ? item?.passwordContent?.notes ?? ''
          : item?.noteContent?.plainText ?? '',
    );
    _fileName = item?.fileContent?.fileName;
    _fileBytes = item?.fileContent?.fileBytes;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    final picked = result?.files.single;
    final pickedPath = picked?.path;
    if (picked == null || pickedPath == null) return;
    final List<int> bytes;
    try {
      bytes = await File(pickedPath).readAsBytes();
    } on FileSystemException {
      return;
    } finally {
      // The picker's copy is plain: gone as soon as it is read, or failed
      // to be (security review 2026-10-26).
      await sl.get<UserFileStore>().discardPickedCopy(pickedPath);
    }
    if (!mounted) return;
    setState(() {
      _fileName = picked.name;
      _fileBytes = bytes;
      _needsFile = false;
    });
  }

  String _finalTitle() {
    final title = _titleController.text.trim();
    if (title.isNotEmpty) return title;
    final fallback = switch (_type) {
      VaultItemType.password => _usernameController.text.trim(),
      VaultItemType.note => '',
      VaultItemType.file => _fileName ?? '',
    };
    return fallback.isNotEmpty
        ? fallback
        : context.fuzzzyInkLocalizations.vaultUntitled;
  }

  String? _optional(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _onSave() async {
    if (_isSaving) return;
    if (_type == VaultItemType.file &&
        (_fileBytes == null || _fileName == null)) {
      setState(() => _needsFile = true);
      return;
    }
    final masterKey = context.read<VaultAuthCubit>().state.masterKey;
    if (masterKey == null) return;

    final now = DateTime.now();
    final existing = _existing;
    final metadata = existing?.metadata.copyWith(
          title: _finalTitle(),
          updatedAt: now,
          contentVersion: existing.metadata.contentVersion + 1,
        ) ??
        VaultItemMetadata(
          id: const Uuid().v4(),
          title: _finalTitle(),
          type: _type,
          groupId: widget.payload.groupId,
          tags: const [],
          isFavorite: false,
          hasCustomPassword: false,
          createdAt: now,
          updatedAt: now,
          contentVersion: 1,
        );

    final item = VaultItem(
      metadata: metadata,
      passwordContent: _type == VaultItemType.password
          ? VaultPasswordContent(
              username: _usernameController.text.trim(),
              password: _passwordController.text,
              url: _optional(_urlController),
              notes: _optional(_notesController),
            )
          : null,
      noteContent: _type == VaultItemType.note
          ? VaultNoteContent(delta: const [], plainText: _notesController.text)
          : null,
      fileContent: _type == VaultItemType.file
          ? VaultFileContent(fileName: _fileName!, fileBytes: _fileBytes!)
          : null,
    );

    setState(() => _isSaving = true);
    final repository = sl.get<VaultRepository>();
    final res = existing == null
        ? await repository.createItem(item, masterKey)
        : await repository.updateItem(item, masterKey);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (res is VaultSuccess<VaultItem>) {
      Navigator.of(context).pop(res.data);
      return;
    }
    showInkToast(
      context,
      message: context.fuzzzyInkLocalizations.safeSaveFailed,
      kind: FuzzzyToastKind.error,
    );
  }

  String _title(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    if (_existing != null) return localizations.safeEdit;
    return switch (_type) {
      VaultItemType.password => localizations.safeNewPasswordTitle,
      VaultItemType.note => localizations.safeNewNoteTitle,
      VaultItemType.file => localizations.safeNewFileTitle,
    };
  }

  String _titleHint(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    return switch (_type) {
      VaultItemType.password => localizations.safeTitleHintPassword,
      VaultItemType.note => localizations.safeTitleHintNote,
      VaultItemType.file => localizations.safeTitleHintFile,
    };
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;

    return BlocListener<VaultAuthCubit, VaultAuthState>(
      listenWhen: (_, current) => current.authState != VaultAuthEnum.unlocked,
      listener: (context, _) => Navigator.of(context).maybePop(),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _onSave,
          const SingleActivator(LogicalKeyboardKey.keyS, control: true):
              _onSave,
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: context.fuzzzyColors.ground,
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FuzzzyAppBar(
                    qaId: 'safe.editor',
                    title: _title(context),
                    leading: FuzzzyIconButton(
                      icon: Icon(
                        _existing == null ? Icons.close : Icons.arrow_back,
                      ),
                      semanticLabel: _existing == null
                          ? MaterialLocalizations.of(context).closeButtonTooltip
                          : MaterialLocalizations.of(context).backButtonTooltip,
                      qaId: 'safe.editor.close',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        space.l,
                        space.s,
                        space.l,
                        space.xl,
                      ),
                      children: [
                        VaultPlaintextField(
                          controller: _titleController,
                          label: localizations.safeTitle,
                          hint: _titleHint(context),
                          qaId: 'safe.editor.title',
                        ),
                        SizedBox(height: space.l),
                        ...switch (_type) {
                          VaultItemType.password => _passwordFields(context),
                          VaultItemType.note => _noteFields(context),
                          VaultItemType.file => _fileFields(context),
                        },
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      space.l,
                      space.s,
                      space.l,
                      space.l,
                    ),
                    child: FuzzzyButton(
                      label: localizations.vaultSave,
                      qaId: 'safe.editor.save',
                      loading: _isSaving,
                      onPressed: _isSaving ? null : _onSave,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _passwordFields(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final space = context.fuzzzySpace;
    return [
      VaultPlaintextField(
        controller: _usernameController,
        label: localizations.safeUsername,
        keyboardType: TextInputType.emailAddress,
        qaId: 'safe.editor.username',
      ),
      SizedBox(height: space.l),
      VaultPlaintextField(
        controller: _passwordController,
        label: localizations.vaultPasswordLabel,
        obscure: !_isPasswordVisible,
        qaId: 'safe.editor.password',
        suffix: FuzzzyIconButton(
          icon: Icon(
            _isPasswordVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
          semanticLabel: _isPasswordVisible
              ? localizations.safeHidePassword
              : localizations.safeShowPassword,
          qaId: 'safe.editor.show',
          onPressed: () =>
              setState(() => _isPasswordVisible = !_isPasswordVisible),
        ),
      ),
      SizedBox(height: space.l),
      VaultPlaintextField(
        controller: _urlController,
        label: localizations.safeWebsite,
        hint: localizations.safeOptional,
        keyboardType: TextInputType.url,
        qaId: 'safe.editor.website',
      ),
      SizedBox(height: space.l),
      VaultPlaintextField(
        controller: _notesController,
        label: localizations.safeNotes,
        hint: localizations.safeOptional,
        minLines: 3,
        maxLines: 6,
        qaId: 'safe.editor.notes',
      ),
    ];
  }

  List<Widget> _noteFields(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    return [
      VaultPlaintextField(
        controller: _notesController,
        label: localizations.vaultNoteLabel,
        hint: localizations.safeNoteHint,
        minLines: 8,
        maxLines: null,
        qaId: 'safe.editor.note',
      ),
    ];
  }

  List<Widget> _fileFields(BuildContext context) {
    final localizations = context.fuzzzyInkLocalizations;
    final colors = context.fuzzzyColors;
    final type = context.fuzzzyTextStyles;
    final space = context.fuzzzySpace;
    final name = _fileName;
    final bytes = _fileBytes;

    if (name != null && bytes != null) {
      return [
        FileCard(
          name: name,
          size: formatSafeFileSize(bytes.length),
          qaId: 'safe.editor',
          trailing: FuzzzyButton(
            label: localizations.safeChangeFile,
            variant: FuzzzyButtonVariant.ghost,
            size: FuzzzyButtonSize.s,
            qaId: 'safe.editor.change',
            onPressed: _isSaving ? null : _pickFile,
          ),
        ),
        SizedBox(height: space.m),
        TipLine(
          icon: Icons.lock_outline,
          text: localizations.safeOriginalStays,
          qaId: 'safe.editor.original',
        ),
      ];
    }

    return [
      Semantics(
        identifier: 'safe.editor.choose',
        button: true,
        container: true,
        child: FuzzzyTappable(
          key: const Key('safe.editor.choose'),
          onTap: _pickFile,
          builder: (context, active) => FuzzzyDropZone(
            dragging: active,
            hint: localizations.safeChooseFile,
            qaId: 'safe.editor.drop',
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: space.xl),
              child: Column(
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.upload_file_outlined,
                      size: context.fuzzzyIconSize.l * 1.4,
                      color: colors.ink,
                    ),
                  ),
                  SizedBox(height: space.s),
                  Text(
                    localizations.safeChooseFile,
                    style: type.titleS.copyWith(color: colors.ink),
                  ),
                  Text(
                    localizations.safeOriginalStays,
                    style: type.bodyS.copyWith(color: colors.inkMute),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      if (_needsFile) ...[
        SizedBox(height: space.s),
        Text(
          localizations.safeChooseFileFirst,
          key: const Key('safe.editor.needsFile'),
          style: type.bodyS.copyWith(color: colors.errorText),
        ),
      ],
    ];
  }
}
