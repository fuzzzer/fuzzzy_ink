import 'package:fuzzzy_ink/src/src.dart';

/// What a call from another app's entry point answered: done with a value,
/// or refused with one [AnywhereFailure].
sealed class AnywhereResult<T> {
  const AnywhereResult();
}

final class AnywhereDone<T> extends AnywhereResult<T> {
  const AnywhereDone(this.value);

  final T value;
}

final class AnywhereRefused<T> extends AnywhereResult<T> {
  const AnywhereRefused(this.failure, {this.wait = Duration.zero});

  final AnywhereFailure failure;

  /// Time left before another password may be tried; zero when none.
  final Duration wait;
}
