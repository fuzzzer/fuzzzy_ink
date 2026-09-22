import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fuzzzy_ink/lib.dart';
import 'package:fuzzzy_ui_kit/fuzzzy_ui_kit.dart';
import 'package:permission_handler/permission_handler.dart';

class FileSelectorWidget extends StatefulWidget {
  final void Function(List<String> filePaths) onSelected;
  final List<String>? selectedFilePaths;
  final bool allowMultiple;

  const FileSelectorWidget({
    super.key,
    required this.onSelected,
    required this.selectedFilePaths,
    this.allowMultiple = false,
  });

  @override
  State<FileSelectorWidget> createState() => _FileSelectorWidgetState();
}

class _FileSelectorWidgetState extends State<FileSelectorWidget> {
  bool _isRequesting = false;

  bool get hasSelectedFiles =>
      widget.selectedFilePaths != null && widget.selectedFilePaths!.isNotEmpty;

  Future<bool> _requestStoragePermissionByPlatform() async {
    bool isGranted = true;

    if (Platform.isIOS || Platform.isAndroid) {
      isGranted = await _requestStoragePermission();
    }

    if (!isGranted) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            currentContextLocalization.storagePermissionDenied,
          ),
        ),
      );
      return false;
    }

    return isGranted;
  }

  Future<bool> _requestStoragePermission() async {
    final status = await Permission.storage.request();
    return status.isGranted || status.isLimited;
  }

  Future<void> _pickFiles() async {
    setState(() => _isRequesting = true);

    try {
      await _requestStoragePermissionByPlatform();

      final result = await FilePicker.platform.pickFiles(
        allowMultiple: widget.allowMultiple,
      );
      if (result != null && result.files.isNotEmpty) {
        final paths = turnPlatformFilesToPaths(result.files);
        if (paths.isNotEmpty) {
          widget.onSelected(paths);
        }
      }
    } catch (e) {
      debugPrint('File selection error: $e');
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            currentContextLocalization.errorPickingFiles,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRequesting = false);
      }
    }
  }

  Future<void> _clearFiles() async {
    widget.onSelected([]);
  }

  List<String> turnPlatformFilesToPaths(List<PlatformFile> files) {
    return files.where((f) => f.path != null).map((f) => f.path!).toList();
  }

  @override
  Widget build(BuildContext context) {
    final fuzzzyTextStyles = context.fuzzzyTextStyles;
    final fuzzzyColors = context.fuzzzyColors;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _isRequesting
          ? null
          : hasSelectedFiles
              ? _clearFiles
              : _pickFiles,
      child: Container(
        width: 50,
        height: 70,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: fuzzzyColors.inkFaint,
          ),
        ),
        child: Center(
          child: _isRequesting
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fuzzzyColors.inkFaint,
                  ),
                )
              : hasSelectedFiles
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.close,
                          size: 30,
                          color: fuzzzyColors.inkFaint,
                        ),
                        Text(
                          widget.selectedFilePaths?.length.toString() ?? '',
                          style: fuzzzyTextStyles.bodyS.copyWith(
                            fontWeight: FontWeight.w600,
                            color: fuzzzyColors.ink,
                          ),
                        ),
                      ],
                    )
                  : Icon(
                      Icons.upload,
                      size: 30,
                      color: fuzzzyColors.inkFaint,
                    ),
        ),
      ),
    );
  }
}
