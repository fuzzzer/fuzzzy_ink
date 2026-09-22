/// One run of the development-flavor file benchmark: a [sizeBytes] round trip
/// through the password-mode container. MB = 10⁶ bytes, as in the crate's
/// `bench_file` example; the rates cover the chunk stream only, so the
/// Argon2id derivation of each direction is reported apart.
class FileBenchmarkResult {
  final int sizeBytes;
  final double encryptMbPerSecond;
  final double decryptMbPerSecond;
  final Duration encryptKeyDerivation;
  final Duration decryptKeyDerivation;

  const FileBenchmarkResult({
    required this.sizeBytes,
    required this.encryptMbPerSecond,
    required this.decryptMbPerSecond,
    required this.encryptKeyDerivation,
    required this.decryptKeyDerivation,
  });

  @override
  String toString() =>
      'FileBenchmarkResult(sizeBytes: $sizeBytes, encryptMbPerSecond: $encryptMbPerSecond, decryptMbPerSecond: $decryptMbPerSecond, encryptKeyDerivation: $encryptKeyDerivation, decryptKeyDerivation: $decryptKeyDerivation)';
}
