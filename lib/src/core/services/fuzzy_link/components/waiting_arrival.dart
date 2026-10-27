/// What waits for the unlock (or for My safe's editor to close), so the
/// lock screen can say "A link is waiting" or "A file is waiting".
enum WaitingArrival {
  /// A Fuzzzy Ink link someone tapped.
  link,

  /// A `.fuzz` file another app handed over.
  file,
}
