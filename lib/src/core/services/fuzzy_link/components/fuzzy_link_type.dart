/// What a link carries; [path] is the link's whole path on the link page's
/// host (`https://ink.fuzzzycore.com/<path>#<payload>`).
enum FuzzyLinkType {
  invitation('/invite'),
  acceptance('/accept'),
  message('/message');

  const FuzzyLinkType(this.path);

  final String path;

  static FuzzyLinkType? fromPath(String path) {
    for (final type in FuzzyLinkType.values) {
      if (type.path == path) return type;
    }
    return null;
  }
}
