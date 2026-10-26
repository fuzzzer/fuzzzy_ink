/// "Lock from other apps" (experimental, owner 2026-10-26): lock text for a
/// person, or open a locked text, from outside the app through
/// `documents/fuzz_anywhere/CHANNEL.md`.
///
/// Off unless the build says `--dart-define=FUZZ_ANYWHERE=true`. Off means
/// no Settings rows, no channel handler and nothing reachable. On, the
/// person still has to turn on Settings → Other apps → Lock from other apps.
const fuzzAnywhereEnabled = bool.fromEnvironment('FUZZ_ANYWHERE');
