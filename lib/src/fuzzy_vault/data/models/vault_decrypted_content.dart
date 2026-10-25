/// An opened item and the version its sealed file is bound to — one ahead
/// of the index when the app stopped between writing the file and the index.
class VaultDecryptedContent {
  const VaultDecryptedContent({required this.content, required this.version});

  final dynamic content;
  final int version;
}
