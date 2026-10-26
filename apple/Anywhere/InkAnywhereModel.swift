import Foundation
import LocalAuthentication
import SwiftUI

/// Lock or Open, the sheet's two jobs.
@available(iOS 15.0, macOS 12.0, *)
enum AnywhereMode: String, CaseIterable, Identifiable {
  case lock, open
  var id: String { rawValue }
}

/// Where the sheet or panel is. Each step has its own small view.
@available(iOS 15.0, macOS 12.0, *)
enum AnywhereStep: Equatable {
  case checking
  /// The feature cannot be used now: say why, offer the app.
  case unavailable(Unavailable)
  case locked
  case unlocking
  /// Lock: a person and a message.
  case choosing
  case locking
  case lockedFor(name: String, delivery: Delivered)
  /// Open: waiting for the locked text.
  case pasting
  /// "Open the message from {name}?"
  case confirming(name: String)
  case opening
  /// The opened message is on Fuzzzy Ink's own private screen now.
  case shown(name: String)
  /// An invite, a reply or a password text: it opens in the app.
  case notForAPerson
  case problem(AnywhereProblem, name: String)

  enum Unavailable: Equatable { case off, notSetUp, notReady }
  enum Delivered: Equatable { case copied, replaced, shareable }
}

/// What the platform does around the model: the Mac panel and the iPhone
/// sheet implement it.
@available(iOS 15.0, macOS 12.0, *)
@MainActor
protocol AnywhereHost: AnyObject {
  /// Brings Fuzzzy Ink's own window forward (before `show` or `openInApp`).
  func bringAppForward()
  /// The use is over: close the panel or sheet.
  func finish()
  /// iPhone: the share sheet for the sealed output.
  func share(_ sealed: String)
}

/// The one state owner of a Lock/Open sheet or panel (native code rules:
/// views only read it and send intents). Every decision about locking,
/// unlocking and opening is Dart's, over [AnywhereCalling]; this keeps only
/// what is on screen. Plain text the person typed lives in [message] until
/// it is sent to `lock`, then it is cleared; opened text never reaches it.
@available(iOS 15.0, macOS 12.0, *)
@MainActor
final class InkAnywhereModel: ObservableObject {
  /// How a sealed result leaves: copied by Dart's copy guard (the panel, the
  /// iPhone sheet), or handed back to the caller (a Mac service replacing
  /// the selection in place).
  enum Delivery {
    case copy
    case returnToCaller((String) -> Void)
  }

  @Published var mode: AnywhereMode
  @Published private(set) var step: AnywhereStep = .checking
  @Published private(set) var strings = InkText()
  @Published private(set) var canUseBiometrics = false
  @Published private(set) var people: [AnywherePerson] = []
  @Published var selectedPersonID: String?
  @Published var message = ""
  @Published var password = ""
  @Published var lockedText = ""
  @Published private(set) var note: String?
  @Published private(set) var waitUntil: Date?
  /// Text that came from another app's selection: show the draft note.
  @Published private(set) var cameFromSelection = false
  /// Counts successes, for the haptic and the symbol bounce.
  @Published private(set) var successes = 0

  let biometryType: LABiometryType
  private let channel: AnywhereCalling
  private let sourceApp: String?
  private let delivery: Delivery
  private var output: String?
  weak var host: AnywhereHost?

  /// [startRetries] covers a cold start: the platform may ask before Dart
  /// has put up its handler.
  init(
    channel: AnywhereCalling, mode: AnywhereMode = .lock, prefill: String? = nil,
    sourceApp: String? = nil, delivery: Delivery = .copy,
    biometryType: LABiometryType = InkAnywhereModel.deviceBiometry()
  ) {
    self.channel = channel
    self.mode = mode
    self.sourceApp = sourceApp
    self.delivery = delivery
    self.biometryType = biometryType
    if let prefill = prefill?.trimmingCharacters(in: .whitespacesAndNewlines), !prefill.isEmpty {
      if mode == .lock {
        message = prefill
        cameFromSelection = true
      } else {
        lockedText = prefill
      }
    }
  }

  nonisolated static func deviceBiometry() -> LABiometryType {
    let context = LAContext()
    var error: NSError?
    _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    return context.biometryType
  }

  var selectedPerson: AnywherePerson? {
    people.first { $0.id == selectedPersonID }
  }

  /// The sealed output, once locked.
  var sealedOutput: String? { output }

  // MARK: - Intents

  func start(startRetries: Int = 8) async {
    step = .checking
    var tries = 0
    while true {
      do {
        let status = AnywhereStatus(try await channel.call("status", [:]))
        strings = InkText(language: status.language)
        canUseBiometrics = status.canUseBiometrics
        if !status.isSetUp {
          step = .unavailable(.notSetUp)
        } else if status.isSettingKnown && !status.isEnabled {
          step = .unavailable(.off)
        } else if !status.isUnlocked {
          step = .locked
        } else {
          await afterUnlock()
        }
        return
      } catch let refusal as AnywhereRefusal where refusal == .notInBuild && tries < startRetries {
        tries += 1
        try? await Task.sleep(nanoseconds: 400_000_000)
      } catch {
        step = .unavailable(.notReady)
        return
      }
    }
  }

  func unlockWithBiometrics() async {
    await unlock("unlock", [:])
  }

  func unlockWithPassword() async {
    guard !password.isEmpty else { return }
    let typed = password
    // Sent once, never kept.
    password = ""
    await unlock("unlockWithPassword", ["password": typed])
  }

  func switchMode(to mode: AnywhereMode) async {
    guard mode != self.mode else { return }
    self.mode = mode
    note = nil
    guard isPastUnlock else { return }
    await afterUnlock()
  }

  func lock() async {
    guard let person = selectedPerson else { return }
    let text = message
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      note = strings.writeSomethingFirst
      return
    }
    note = nil
    step = .locking
    var arguments: [String: Any] = ["personId": person.id, "text": text]
    if let sourceApp { arguments["sourceApp"] = sourceApp }
    if case .copy = delivery { arguments["copy"] = true }
    do {
      let answer = try await channel.call("lock", arguments)
      message = ""
      cameFromSelection = false
      guard let sealed = answer["output"] as? String else { throw AnywhereRefusal(code: "failed") }
      output = sealed
      successes += 1
      switch delivery {
      case .returnToCaller(let deliver):
        deliver(sealed)
        step = .lockedFor(name: person.name, delivery: .replaced)
      case .copy:
        let copied = answer["copied"] as? Bool ?? false
        step = .lockedFor(name: person.name, delivery: copied ? .copied : .shareable)
      }
    } catch let refusal as AnywhereRefusal {
      switch refusal.code {
      case "emptyText":
        step = .choosing
        note = strings.writeSomethingFirst
      case "unknownPerson":
        await loadPeople()
      default:
        if !handleAccess(refusal) {
          step = .choosing
          note = strings.lockFailed
        }
      }
    } catch {
      step = .choosing
      note = strings.lockFailed
    }
  }

  /// The person brought locked text (pasted, or selected in another app):
  /// only now is it read, with the peek, which opens and spends nothing.
  func takeLockedText(_ text: String) async {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    lockedText = trimmed
    guard !trimmed.isEmpty else { return }
    do {
      let answer = try await channel.call("peek", ["text": trimmed])
      let kind = AnywherePeekKind(rawValue: answer["kind"] as? String ?? "") ?? .damaged
      switch kind {
      case .message:
        if let name = answer["personName"] as? String {
          step = .confirming(name: name)
        } else {
          step = .problem(.notFromYourPeople, name: "")
        }
      case .invite, .reply, .passwordText:
        step = .notForAPerson
      case .newerApp:
        step = .problem(.newerApp, name: "")
      case .damaged:
        step = .problem(.damaged, name: "")
      case .notFuzzzy:
        step = .problem(.notFuzzzy, name: "")
      }
    } catch let refusal as AnywhereRefusal {
      if !handleAccess(refusal) { step = .problem(.failed, name: "") }
    } catch {
      step = .problem(.failed, name: "")
    }
  }

  /// The person pressed Open: the message is opened by the app (its key
  /// spent, the text kept in that person's history) and shown on the app's
  /// own private screen. The text never comes here.
  func open() async {
    guard case .confirming(let name) = step else { return }
    step = .opening
    do {
      let opened = try await channel.call("open", ["text": lockedText])
      guard let displayId = opened["displayId"] as? String else {
        throw AnywhereRefusal(code: "failed")
      }
      lockedText = ""
      successes += 1
      host?.bringAppForward()
      _ = try await channel.call("show", ["displayId": displayId])
      step = .shown(name: opened["personName"] as? String ?? name)
      host?.finish()
    } catch let refusal as AnywhereRefusal {
      if refusal.code == "notForAPerson" {
        step = .notForAPerson
      } else if !handleAccess(refusal) {
        step = .problem(AnywhereProblem(code: refusal.code), name: name)
      }
    } catch {
      step = .problem(.failed, name: name)
    }
  }

  /// "Open in Fuzzzy Ink" for an invite, a reply or a password text.
  func openInApp() async {
    guard step == .notForAPerson else { return }
    host?.bringAppForward()
    do {
      _ = try await channel.call("openInApp", ["text": lockedText])
      lockedText = ""
      host?.finish()
    } catch let refusal as AnywhereRefusal {
      if !handleAccess(refusal) { step = .problem(.failed, name: "") }
    } catch {
      step = .problem(.failed, name: "")
    }
  }

  func startOver() {
    lockedText = ""
    note = nil
    step = mode == .lock ? .choosing : .pasting
  }

  /// The panel or sheet went away, whatever happened: Dart locks the app
  /// again when this use unlocked it and "Lock again after each use" is on.
  func close() async {
    message = ""
    password = ""
    lockedText = ""
    people = []
    _ = try? await channel.call("relock", [:])
  }

  /// Dart's events, through the platform's channel.
  func handle(event: String, _ arguments: [String: Any]) {
    switch event {
    case "lockChanged" where arguments["unlocked"] as? Bool == false:
      people = []
      password = ""
      switch step {
      case .lockedFor, .shown, .unavailable: break
      default: step = .locked
      }
    case "settingsChanged" where arguments["enabled"] as? Bool == false:
      people = []
      step = .unavailable(.off)
    default:
      break
    }
  }

  #if DEBUG
    /// Previews put the model straight into a step.
    func preview(_ step: AnywhereStep, people: [AnywherePerson] = [], note: String? = nil) {
      self.people = people
      selectedPersonID = people.first?.id
      self.note = note
      if case .lockedFor = step { output = "https://ink.fuzzzycore.com/message#AwEC" }
      self.step = step
    }
  #endif

  // MARK: - Steps

  private var isPastUnlock: Bool {
    switch step {
    case .checking, .unavailable, .locked, .unlocking: return false
    default: return true
    }
  }

  private func unlock(_ method: String, _ arguments: [String: Any]) async {
    note = nil
    step = .unlocking
    do {
      _ = try await channel.call(method, arguments)
      waitUntil = nil
      await afterUnlock()
    } catch let refusal as AnywhereRefusal {
      step = .locked
      switch refusal.code {
      case "wrongPassword":
        note = strings.wrongPassword
        setWait(refusal.waitSeconds)
      case "lockedOut":
        note = strings.tooManyTries
        setWait(refusal.waitSeconds)
      case "biometricOff":
        canUseBiometrics = false
      case "biometricGone":
        canUseBiometrics = false
        note = strings.biometricChanged
      case "notUnlocked":
        break
      default:
        _ = handleAccess(refusal)
      }
    } catch {
      step = .locked
    }
  }

  private func setWait(_ seconds: Int) {
    waitUntil = seconds > 0 ? Date().addingTimeInterval(TimeInterval(seconds)) : nil
  }

  private func afterUnlock() async {
    switch mode {
    case .lock:
      await loadPeople()
    case .open:
      if lockedText.isEmpty {
        step = .pasting
      } else {
        await takeLockedText(lockedText)
      }
    }
  }

  private func loadPeople() async {
    do {
      var arguments: [String: Any] = [:]
      if let sourceApp { arguments["sourceApp"] = sourceApp }
      let answer = try await channel.call("people", arguments)
      people = (answer["people"] as? [Any] ?? []).compactMap(AnywherePerson.init)
      if selectedPerson == nil {
        selectedPersonID = (people.first { $0.isLastUsedHere } ?? people.first)?.id
      }
      step = .choosing
    } catch let refusal as AnywhereRefusal {
      if !handleAccess(refusal) {
        people = []
        step = .choosing
        note = strings.lockFailed
      }
    } catch {
      step = .choosing
      note = strings.lockFailed
    }
  }

  /// The refusals every call can get. Answers whether it was one.
  private func handleAccess(_ refusal: AnywhereRefusal) -> Bool {
    switch refusal.code {
    case "locked":
      people = []
      step = .locked
    case "disabled":
      people = []
      step = .unavailable(.off)
    case "notSetUp":
      step = .unavailable(.notSetUp)
    case "notReady", AnywhereRefusal.notInBuild.code:
      step = .unavailable(.notReady)
    default:
      return false
    }
    return true
  }
}
