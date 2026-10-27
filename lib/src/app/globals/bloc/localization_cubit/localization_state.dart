part of 'localization_cubit.dart';

class LocalizationState {
  final Locale locale;

  /// Language "Like my phone": the app passes no locale of its own and the
  /// phone's language applies. [locale] is then only the last one seen.
  final bool followsPhone;

  LocalizationState({
    required this.locale,
    this.followsPhone = true,
  });

  LocalizationState copyWith({
    Locale? locale,
    bool? followsPhone,
  }) {
    return LocalizationState(
      locale: locale ?? this.locale,
      followsPhone: followsPhone ?? this.followsPhone,
    );
  }

  @override
  String toString() =>
      'LocalizationState(locale: $locale, followsPhone: $followsPhone)';

  @override
  bool operator ==(covariant LocalizationState other) {
    if (identical(this, other)) return true;

    return other.locale == locale && other.followsPhone == followsPhone;
  }

  @override
  int get hashCode => Object.hash(locale, followsPhone);
}
