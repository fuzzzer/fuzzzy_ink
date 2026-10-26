import Foundation

/// The native sheets' words, read from `Anywhere.strings`, which
/// `tools/native_strings/apple_strings.dart` writes from the app's `.arb` files.
/// The language is the one the person picked in Fuzzzy Ink's Settings (the
/// `language` in `status`), else the device's, else English.
@available(iOS 15.0, macOS 12.0, *)
struct InkText {
  static let languages = ["en", "ka"]

  let language: String
  private let bundle: Bundle

  init(language picked: String? = nil, bundle base: Bundle = .main) {
    let language =
      picked.flatMap { InkText.languages.contains($0) ? $0 : nil }
      ?? Bundle.preferredLocalizations(
        from: InkText.languages, forPreferences: Locale.preferredLanguages
      ).first
      ?? "en"
    self.language = language
    bundle =
      base.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)) ?? base
  }

  private func word(_ key: String) -> String {
    bundle.localizedString(forKey: key, value: key, table: "Anywhere")
  }

  private func word(_ key: String, _ name: String) -> String {
    String(format: word(key), name)
  }

  var lock: String { word("lockAction") }
  var open: String { word("open") }
  var close: String { word("close") }
  var share: String { word("share") }
  var tryAgain: String { word("tryAgain") }

  var lockTitle: String { word("anywhereNativeLockTitle") }
  var openTitle: String { word("anywhereNativeOpenTitle") }
  var lockIntentDescription: String { word("anywhereNativeLockIntentDescription") }
  var showApp: String { word("anywhereNativeShowApp") }
  var openApp: String { word("anywhereSheetOpenApp") }

  var lockedTitle: String { word("accessLockedTitle") }
  var unlock: String { word("anywhereNativeUnlock") }
  var useTouchID: String { word("anywhereNativeUseTouchId") }
  var useFaceID: String { word("anywhereNativeUseFaceId") }
  var masterPassword: String { word("masterPassword") }
  var wrongPassword: String { word("accessWrongPassword") }
  var tooManyTries: String { word("accessTooManyTries") }
  var biometricChanged: String { word("accessBioChanged") }
  func wait(_ time: String) -> String { word("lockoutWaitLeft", time) }

  var setUpFirst: String { word("anywhereSheetSetUpLine") }
  var turnOn: String { word("anywhereNativeTurnOn") }

  var whoFor: String { word("lockWhoTitle") }
  var addPersonFirst: String { word("lockAddPersonFirst") }
  var notChecked: String { word("personMenuNotCheckedYet") }
  var messageHint: String { word("lockWriteMessageHint") }
  var writeSomethingFirst: String { word("lockWriteSomethingFirst") }
  func onlyOnce(_ name: String) -> String { word("lockOnlyNameOnce", name) }
  var lockFailed: String { word("lockFailed") }
  var locking: String { word("workingLocking") }
  func lockedFor(_ name: String) -> String { word("lockedForName", name) }
  var nowSendIt: String { word("lockedNowSendIt") }
  var copied: String { word("copiedToTheClipboard") }
  var copiedPressPaste: String { word("anywhereNativeCopiedPressPaste") }
  var replaced: String { word("anywhereSheetPutInPlace") }
  var draftNote: String { word("infoOtherAppsLine3") }

  var paste: String { word("openPasteIt") }
  var pasteHint: String { word("openPasteItHint") }
  func openFrom(_ name: String) -> String { word("openLinkTitle", name) }
  var opening: String { word("workingOpening") }
  func inHistory(_ name: String) -> String { word("openedInHistoryNow", name) }
  var shownInApp: String { word("anywhereNativeShownInApp") }
  var openInApp: String { word("anywhereSheetOpenInInkAction") }
  var notForAPerson: String { word("anywhereSheetOpenInInkLine") }
  var openFailed: String { word("openFailed") }

  /// The app's Open wording for a message that does not open.
  func problem(_ problem: AnywhereProblem, name: String) -> (title: String, line: String) {
    switch problem {
    case .alreadyOpened:
      return (word("openErrorAlreadyTitle"), word("openErrorAlreadyLine", name))
    case .notFromYourPeople:
      return (word("openErrorNotYoursTitle"), word("openErrorNotYoursLine"))
    case .damaged:
      return (word("openErrorDamagedTitle"), word("openErrorDamagedLine"))
    case .tooOld:
      return (word("openErrorOldTitle"), word("openErrorOldLine", name))
    case .newerApp:
      return (word("openErrorNewerTitle"), word("openErrorNewerLine"))
    case .notFuzzzy:
      return (word("openErrorNotFuzzzyTitle"), word("openErrorNotFuzzzyLine"))
    case .failed:
      return (word("openErrorDamagedTitle"), word("openFailed"))
    }
  }
}
