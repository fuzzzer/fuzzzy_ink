import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuzzzy_seal/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class VaultItemEditorPagePayload {
  final VaultItemType type;
  final VaultItem? existingItem; // null if creating a new item
  final String groupId;

  const VaultItemEditorPagePayload({
    required this.type,
    this.existingItem,
    this.groupId = 'general',
  });
}

class VaultItemEditorPage extends StatefulWidget {
  final VaultItemEditorPagePayload payload;

  const VaultItemEditorPage({super.key, required this.payload});

  @override
  State<VaultItemEditorPage> createState() => _VaultItemEditorPageState();
}

class _VaultItemEditorPageState extends State<VaultItemEditorPage> {
  late VaultItemType _type;
  late final TextEditingController _titleController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _urlController;
  late final TextEditingController _notesController;

  bool _isPasswordVisible = false;
  bool _isSaving = false;
  bool _isDeleting = false;

  List<int>? _pickedFileBytes;
  String? _pickedFileName;
  final List<File> _tempFiles = [];

  @override
  void initState() {
    super.initState();
    _type = widget.payload.type;

    final item = widget.payload.existingItem;
    _titleController = TextEditingController(text: item?.metadata.title ?? '');

    _usernameController =
        TextEditingController(text: item?.passwordContent?.username ?? '');
    _passwordController =
        TextEditingController(text: item?.passwordContent?.password ?? '');
    _urlController =
        TextEditingController(text: item?.passwordContent?.url ?? '');

    // Use notesController for both Password's small notes and Note's full content
    final noteText = _type == VaultItemType.password
        ? item?.passwordContent?.notes ?? ''
        : item?.noteContent?.plainText ?? '';
    _notesController = TextEditingController(text: noteText);

    if (_type == VaultItemType.file && item?.fileContent != null) {
      _pickedFileName = item!.fileContent!.fileName;
      _pickedFileBytes = item.fileContent!.fileBytes;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _urlController.dispose();
    _notesController.dispose();

    // Clean up any unencrypted temp files created for viewing/sharing
    for (final file in _tempFiles) {
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }

    // Clear the FilePicker cache to ensure picked files are removed
    FilePicker.platform.clearTemporaryFiles();

    super.dispose();
  }

  Future<File> _writeTempFile() async {
    final dir = await getTemporaryDirectory();
    final tempFile = File('${dir.path}/$_pickedFileName');
    await tempFile.writeAsBytes(Uint8List.fromList(_pickedFileBytes!));
    _tempFiles.add(tempFile);
    return tempFile;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      setState(() {
        _pickedFileName = result.files.single.name;
        _pickedFileBytes = bytes;
        if (_titleController.text.isEmpty ||
            _titleController.text == currentContextLocalization.vaultUntitled) {
          _titleController.text = _pickedFileName!;
        }
      });
    }
  }

  Future<void> _openFile(BuildContext context) async {
    if (_pickedFileBytes == null || _pickedFileName == null) return;
    try {
      final tempFile = await _writeTempFile();
      await DeviceFileInteractor.openFile(tempFile.path);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open file: $e')),
        );
      }
    }
  }

  Future<void> _shareFile(BuildContext context) async {
    if (_pickedFileBytes == null || _pickedFileName == null) return;
    try {
      final tempFile = await _writeTempFile();
      if (context.mounted) {
        await DeviceFileInteractor.shareFile(tempFile.path, context: context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share file: $e')),
        );
      }
    }
  }

  Future<void> _revealFile(BuildContext context) async {
    if (_pickedFileBytes == null || _pickedFileName == null) return;
    try {
      final tempFile = await _writeTempFile();
      if (context.mounted) {
        await DeviceFileInteractor.revealFile(tempFile.path, context: context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not reveal file: $e')),
        );
      }
    }
  }

  Future<void> _onSave(BuildContext context) async {
    String finalTitle = _titleController.text.trim();
    if (_type == VaultItemType.password) {
      if (_usernameController.text.trim().isNotEmpty) {
        finalTitle = _usernameController.text.trim();
      } else {
        finalTitle = widget.payload.existingItem?.metadata.title ??
            currentContextLocalization.vaultUntitled;
        if (finalTitle.isEmpty) {
          finalTitle = currentContextLocalization.vaultUntitled;
        }
      }
    }

    if (finalTitle.isEmpty) {
      finalTitle = currentContextLocalization.vaultUntitled;
    }

    final now = DateTime.now();
    final metadata = widget.payload.existingItem?.metadata.copyWith(
          title: finalTitle,
          updatedAt: now,
          contentVersion:
              (widget.payload.existingItem?.metadata.contentVersion ?? 0) + 1,
        ) ??
        VaultItemMetadata(
          id: const Uuid().v4(),
          title: finalTitle,
          type: _type,
          groupId: widget.payload.groupId,
          tags: [],
          isFavorite: false,
          hasCustomPassword: false,
          createdAt: now,
          updatedAt: now,
          contentVersion: 1,
        );

    VaultPasswordContent? pwdContent;
    VaultNoteContent? noteContent;
    VaultFileContent? fileContent;

    if (_type == VaultItemType.password) {
      pwdContent = VaultPasswordContent(
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
        url: _urlController.text.trim().isEmpty
            ? null
            : _urlController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
    } else if (_type == VaultItemType.note) {
      noteContent = VaultNoteContent(
        delta: [],
        plainText: _notesController.text.trim(),
      );
    } else if (_type == VaultItemType.file) {
      if (_pickedFileName == null || _pickedFileBytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a file first')),
          );
        }
        return;
      }
      fileContent = VaultFileContent(
        fileName: _pickedFileName!,
        fileBytes: _pickedFileBytes!,
      );
    }

    final item = VaultItem(
      metadata: metadata,
      passwordContent: pwdContent,
      noteContent: noteContent,
      fileContent: fileContent,
    );

    final masterKey = context.read<VaultAuthCubit>().state.masterKey;
    if (masterKey == null) return;

    final repo = sl.get<VaultRepository>();

    setState(() => _isSaving = true);

    try {
      if (widget.payload.existingItem == null) {
        await repo.createItem(item, masterKey);
      } else {
        await repo.updateItem(item, masterKey);
      }

      if (context.mounted) {
        if (_type == VaultItemType.file) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(currentContextLocalization.vaultFileSaveWarning),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _onDelete(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.fuzzzyColors.surface,
          title: Text(
            'Delete Item',
            style: TextStyle(color: context.fuzzzyColors.ink),
          ),
          content: Text(
            'Are you sure you want to delete this item? This action cannot be undone.',
            style: TextStyle(color: context.fuzzzyColors.ink),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                currentContextLocalization.cancel,
                style: TextStyle(color: context.fuzzzyColors.ink),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Delete',
                style: TextStyle(color: context.fuzzzyColors.destructiveText),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    try {
      if (!context.mounted) return;
      final repo = sl.get<VaultRepository>();
      await repo.deleteItem(widget.payload.existingItem!.metadata.id);

      if (context.mounted) {
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () =>
            _onSave(context),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            _onSave(context),
      },
      child: Focus(
        autofocus: true,
        child: FuzzyScaffold(
          hasAutomaticBackButton: false,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FuzzzyAppBar(
                  title: widget.payload.existingItem == null
                      ? (_type == VaultItemType.password
                          ? currentContextLocalization.vaultNewPassword
                          : _type == VaultItemType.note
                              ? currentContextLocalization.vaultNewNote
                              : currentContextLocalization.vaultFileLabel)
                      : currentContextLocalization.vaultEditItem,
                  leading: FuzzzyIconButton(
                    icon: const Icon(Icons.arrow_back),
                    variant: FuzzzyIconButtonVariant.filled,
                    semanticLabel: 'Back',
                    onPressed: () => context.goBack(),
                  ),
                  actions: widget.payload.existingItem != null
                      ? [
                          if (_isDeleting)
                            const Padding(
                              padding: EdgeInsets.only(right: 16),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            )
                          else
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: context.fuzzzyColors.destructiveText,
                              ),
                              onPressed: () => _onDelete(context),
                            ),
                        ]
                      : null,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_type != VaultItemType.password) ...[
                          FuzzzyTextField(
                            controller: _titleController,
                            label: currentContextLocalization.vaultTitle,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_type == VaultItemType.password) ...[
                          FuzzzyTextField(
                            controller: _usernameController,
                            label:
                                currentContextLocalization.vaultUsernameEmail,
                          ),
                          const SizedBox(height: 16),
                          FuzzzyTextField(
                            controller: _passwordController,
                            label:
                                currentContextLocalization.vaultPasswordLabel,
                            obscure: !_isPasswordVisible,
                            suffix: IconButton(
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: context.fuzzzyColors.inkMute,
                              ),
                              onPressed: () => setState(
                                () => _isPasswordVisible = !_isPasswordVisible,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FuzzzyTextField(
                            controller: _urlController,
                            label: currentContextLocalization.vaultUrlWebsite,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_type == VaultItemType.file) ...[
                          if (_pickedFileName != null) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: context.fuzzzyColors.surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.file_present_rounded,
                                        color: context.fuzzzyColors.ink,
                                        size: 32,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _pickedFileName!,
                                              style: TextStyle(
                                                color: context.fuzzzyColors.ink,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (_pickedFileBytes != null)
                                              Text(
                                                _formatFileSize(
                                                  _pickedFileBytes!.length,
                                                ),
                                                style: TextStyle(
                                                  color: context
                                                      .fuzzzyColors.inkMute,
                                                  fontSize: 12,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (widget.payload.existingItem != null) ...[
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _FileActionButton(
                                            icon: Icons.open_in_new_rounded,
                                            label:
                                                currentContextLocalization.open,
                                            onTap: () => _openFile(context),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _FileActionButton(
                                            icon: Icons.share_rounded,
                                            label: currentContextLocalization
                                                .shareFile,
                                            onTap: () => _shareFile(context),
                                          ),
                                        ),
                                        // On mobile revealing is the share
                                        // sheet, so "Show" would duplicate
                                        // "Share File".
                                        if (DeviceFileInteractor
                                            .canRevealFile) ...[
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _FileActionButton(
                                              icon: Icons.folder_open_rounded,
                                              label: currentContextLocalization
                                                  .show,
                                              onTap: () => _revealFile(context),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          FuzzzyButton(
                            label: _pickedFileName != null
                                ? currentContextLocalization.vaultEditItem
                                : 'Select File',
                            onPressed: _pickFile,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_type != VaultItemType.file) ...[
                          FuzzzyTextField(
                            controller: _notesController,
                            label: _type == VaultItemType.password
                                ? currentContextLocalization.vaultNotesOptional
                                : currentContextLocalization.vaultSecureNote,
                            minLines: _type == VaultItemType.password ? 1 : 15,
                            maxLines:
                                _type == VaultItemType.password ? 3 : null,
                          ),
                        ],
                        const SizedBox(height: 40),
                        if (_isSaving)
                          const Center(child: CircularProgressIndicator())
                        else
                          FuzzzyButton(
                            label: currentContextLocalization.vaultSave,
                            onPressed: () => _onSave(context),
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
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _FileActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FileActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.fuzzzyColors.ground,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: context.fuzzzyColors.ink),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: context.fuzzzyColors.ink,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
