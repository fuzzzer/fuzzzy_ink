/// Sent after "Erase everything" (from the lock screen, the recovery page or
/// the first run's clean start): the device's storage is empty now, so every
/// list or setting held in memory reads it again instead of showing what was
/// erased until the app restarts.
class AppDataErased {
  const AppDataErased();
}
