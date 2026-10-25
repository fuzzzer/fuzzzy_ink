import 'package:fuzzzy_cast/fuzzzy_cast.dart';

/// The moments Fuzzz reacts to (DESIGN.md section 9) and how.
enum FuzzzyCastMoment {
  /// Locked a message or file: "squares up, one firm nod".
  locked(feeling: CastFeeling.determined, lengthMs: 2600),

  /// Opened a message or file (a toast on the person page; the opened
  /// screen itself is private).
  opened(feeling: CastFeeling.surprised, lengthMs: 2800),

  /// An invite or reply is ready to send: the afterimage act.
  inviteReady(moveId: 'afterimage', lengthMs: 4800),

  /// Connected (reply opened, invite accepted).
  connected(feeling: CastFeeling.happy, lengthMs: 2400),

  /// Checked: the numbers matched.
  checked(feeling: CastFeeling.love, lengthMs: 3600),

  /// Can't open (already opened, too old, damaged…).
  cantOpen(feeling: CastFeeling.sad, lengthMs: 2600),

  /// A big file is working: keeps watch while it runs.
  working(moveId: 'keeps-watch', loops: true),

  /// No people yet: calm, then rest.
  noPeople(lengthMs: 2600),

  /// Fuzzzy Cast was just turned on.
  turnedOn(feeling: CastFeeling.happy, lengthMs: 2400);

  const FuzzzyCastMoment({
    this.feeling = CastFeeling.calm,
    this.moveId,
    this.lengthMs = 0,
    this.loops = false,
  });

  final CastFeeling feeling;

  /// One of Fuzzz's acts instead of a feeling.
  final String? moveId;

  /// How long the reaction plays before Fuzzz rests; 0 while [loops].
  final int lengthMs;
  final bool loops;

  Duration get length => Duration(milliseconds: lengthMs);
}
