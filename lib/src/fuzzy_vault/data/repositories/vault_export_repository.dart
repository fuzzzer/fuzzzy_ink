import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:fuzzzy_seal/lib.dart';

class VaultExportRepository {
  const VaultExportRepository({
    required this.fileDataSource,
    required this.itemDataSource,
    required this.groupDataSource,
  });

  final VaultFileDataSource fileDataSource;
  final VaultItemLocalDataSource itemDataSource;
  final VaultGroupLocalDataSource groupDataSource;

  Future<VaultResponse<String>> exportVault(
    List<VaultItemMetadata> itemsToExport,
    List<VaultGroupData> groupsToExport,
    String destinationDirectoryPath,
    String exportPassword,
  ) async {
    try {
      final encoder = ZipFileEncoder();
      final zipPath =
          '$destinationDirectoryPath/fuzzy_vault_export_${DateTime.now().millisecondsSinceEpoch}.fvault';
      encoder.create(zipPath);

      final tempDir =
          Directory('${fileDataSource.vaultDirectoryPath}/.tmp_export');
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
      await tempDir.create();

      // We won't decrypt the items, we just bundle the encrypted blobs along with
      // the metadata DB and vault.meta, OR we create a totally new vault structure
      // using the exportPassword. This is complex. For now, we return failure to be implemented.
      // Or we can just encrypt everything in a new json.
      return const VaultFailure(
        VaultFailureType.exportFailed,
        message: 'Not fully implemented yet',
      );
    } catch (e) {
      return VaultFailure(VaultFailureType.exportFailed, message: e.toString());
    }
  }
}
