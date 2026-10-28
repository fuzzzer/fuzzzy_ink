#if INK_ANYWHERE
  import AppIntents

  /// "Lock a message" (experimental): opens Fuzzzy Ink with the native Lock
  /// sheet. In Shortcuts, Siri, Spotlight and on the Action button. Built
  /// only into the development flavour for now (`INK_ANYWHERE` is set for its
  /// configurations alone); the sheet itself still asks Dart whether the
  /// build has the feature and Settings → Lock from other apps is on.
  ///
  /// The intent carries no text and returns none: the person types in the
  /// sheet, inside Fuzzzy Ink.
  @available(iOS 16.0, *)
  struct LockMessageIntent: AppIntent {
    static var title = LocalizedStringResource("anywhereNativeLockTitle", table: "Anywhere")
    static var description = IntentDescription(
      LocalizedStringResource("anywhereNativeLockIntentDescription", table: "Anywhere"))
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
      InkAnywhereIOS.shared.present(mode: .lock)
      return .result()
    }
  }

  @available(iOS 17.0, *)
  struct InkAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
      AppShortcut(
        intent: LockMessageIntent(),
        phrases: ["Lock a message with \(.applicationName)"],
        shortTitle: LocalizedStringResource("anywhereNativeLockTitle", table: "Anywhere"),
        systemImageName: "lock.fill")
    }
  }
#endif
