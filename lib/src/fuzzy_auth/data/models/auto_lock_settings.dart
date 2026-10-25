/// When the whole app locks by itself: after [idle] without a touch or a
/// key press, and once it has been in the background for [background].
class AutoLockSettings {
  const AutoLockSettings({
    required this.idle,
    required this.background,
  });

  /// The choices the settings offer; a stored value outside them is refused.
  static const idleChoices = [
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
  ];
  static const backgroundChoices = [
    Duration.zero,
    Duration(minutes: 1),
    Duration(minutes: 5),
  ];

  /// Five idle minutes; one minute away from the app — long enough to paste
  /// a sealed message into another app and come back.
  static const standard = AutoLockSettings(
    idle: Duration(minutes: 5),
    background: Duration(minutes: 1),
  );

  final Duration idle;
  final Duration background;

  /// `null` when the map is not a pair of offered choices.
  static AutoLockSettings? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final idleSeconds = json['idleSeconds'];
    final backgroundSeconds = json['backgroundSeconds'];
    if (idleSeconds is! int || backgroundSeconds is! int) return null;
    final idle = Duration(seconds: idleSeconds);
    final background = Duration(seconds: backgroundSeconds);
    if (!idleChoices.contains(idle) ||
        !backgroundChoices.contains(background)) {
      return null;
    }
    return AutoLockSettings(idle: idle, background: background);
  }

  Map<String, int> toJson() => {
        'idleSeconds': idle.inSeconds,
        'backgroundSeconds': background.inSeconds,
      };

  AutoLockSettings copyWith({Duration? idle, Duration? background}) {
    return AutoLockSettings(
      idle: idle ?? this.idle,
      background: background ?? this.background,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AutoLockSettings &&
      other.idle == idle &&
      other.background == background;

  @override
  int get hashCode => Object.hash(idle, background);
}
