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
    Duration(hours: 1),
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

  /// Settings → "Lock the app after" (DESIGN.md section 4.12), in order:
  /// Right away · 1 minute · 5 minutes (recommended, the standard) · 15
  /// minutes · 1 hour. One choice sets the idle time; leaving the app locks
  /// it after one minute away, or at once with "Right away".
  static const lockAfterChoices = [
    AutoLockSettings(idle: Duration(minutes: 1), background: Duration.zero),
    AutoLockSettings(
      idle: Duration(minutes: 1),
      background: Duration(minutes: 1),
    ),
    standard,
    AutoLockSettings(
      idle: Duration(minutes: 15),
      background: Duration(minutes: 1),
    ),
    AutoLockSettings(
      idle: Duration(hours: 1),
      background: Duration(minutes: 1),
    ),
  ];

  /// Which of [lockAfterChoices] these times are; an older pair reads as
  /// the choice with the nearest idle time.
  int get lockAfterIndex {
    final exact = lockAfterChoices.indexOf(this);
    if (exact >= 0) return exact;
    if (background == Duration.zero) return 0;
    var best = 1;
    for (var i = 1; i < lockAfterChoices.length; i++) {
      final distance = (lockAfterChoices[i].idle - idle).abs();
      if (distance < (lockAfterChoices[best].idle - idle).abs()) best = i;
    }
    return best;
  }

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
