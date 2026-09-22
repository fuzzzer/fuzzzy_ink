import 'crypto_core_failure_type.dart';

sealed class CryptoCoreResponse<T> {
  const CryptoCoreResponse();
}

class CryptoCoreSuccess<T> extends CryptoCoreResponse<T> {
  const CryptoCoreSuccess(this.data);
  final T data;
}

class CryptoCoreFailure<T> extends CryptoCoreResponse<T> {
  const CryptoCoreFailure(this.type);
  final CryptoCoreFailureType type;
}
