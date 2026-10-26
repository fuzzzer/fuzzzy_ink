import Foundation

/// The native end of `com.fuzzzycore.ink/anywhere`, contract version 1
/// (`documents/fuzz_anywhere/CHANNEL.md`). Swift only asks; Dart owns the
/// store, the unlock and every lock and open. Nothing Swift sends or gets
/// back holds opened text or a key; the only text that comes back is sealed
/// output and a person's name.
@available(iOS 15.0, macOS 12.0, *)
@MainActor
protocol AnywhereCalling: AnyObject {
  func call(_ method: String, _ arguments: [String: Any]) async throws -> [String: Any]
}

/// A refusal from Dart: its code (CHANNEL.md section 4), and a wait for the
/// password limits. `notInBuild` means Dart has no handler: the build has no
/// "Lock from other apps", or Dart has not started yet.
@available(iOS 15.0, macOS 12.0, *)
struct AnywhereRefusal: Error, Equatable {
  let code: String
  var waitSeconds: Int = 0

  static let notInBuild = AnywhereRefusal(code: "notInBuild")
}

@available(iOS 15.0, macOS 12.0, *)
struct AnywhereStatus: Equatable {
  var isEnabled: Bool
  var isSettingKnown: Bool
  var isUnlocked: Bool
  var isSetUp: Bool
  var canUseBiometrics: Bool
  var language: String?

  init(_ answer: [String: Any]) {
    isEnabled = answer["enabled"] as? Bool ?? false
    isSettingKnown = answer["settingKnown"] as? Bool ?? false
    isUnlocked = answer["unlocked"] as? Bool ?? false
    isSetUp = answer["setUp"] as? Bool ?? false
    canUseBiometrics = answer["biometric"] as? String == "on"
    language = answer["language"] as? String
  }
}

@available(iOS 15.0, macOS 12.0, *)
struct AnywherePerson: Identifiable, Equatable {
  let id: String
  let name: String
  let isChecked: Bool
  let isLastUsedHere: Bool

  init(id: String, name: String, isChecked: Bool, isLastUsedHere: Bool = false) {
    self.id = id
    self.name = name
    self.isChecked = isChecked
    self.isLastUsedHere = isLastUsedHere
  }

  init?(_ answer: Any) {
    guard let map = answer as? [String: Any], let id = map["id"] as? String,
      let name = map["name"] as? String
    else { return nil }
    self.init(
      id: id, name: name, isChecked: map["verified"] as? Bool ?? false,
      isLastUsedHere: map["lastUsedHere"] as? Bool ?? false)
  }
}

/// What `peek` says a text is.
@available(iOS 15.0, macOS 12.0, *)
enum AnywherePeekKind: String {
  case message, invite, reply, passwordText, newerApp, damaged, notFuzzzy
}

/// Why a message from outside did not open (the app's Open wording).
@available(iOS 15.0, macOS 12.0, *)
enum AnywhereProblem: Equatable {
  case alreadyOpened, notFromYourPeople, damaged, tooOld, newerApp, notFuzzzy, failed

  init(code: String) {
    switch code {
    case "alreadyOpened": self = .alreadyOpened
    case "notFromYourPeople": self = .notFromYourPeople
    case "damaged": self = .damaged
    case "tooOld": self = .tooOld
    case "newerApp": self = .newerApp
    case "notFuzzzy": self = .notFuzzzy
    default: self = .failed
    }
  }
}
