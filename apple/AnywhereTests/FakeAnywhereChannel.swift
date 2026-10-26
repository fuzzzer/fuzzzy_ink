import Foundation

/// Dart, as the native side sees it: answers per method, and every call
/// recorded in order.
@MainActor
final class FakeAnywhereChannel: AnywhereCalling {
  var answers: [String: (([String: Any]) throws -> [String: Any])] = [:]
  private(set) var calls: [(method: String, arguments: [String: Any])] = []

  var methods: [String] { calls.map(\.method) }

  func arguments(of method: String) -> [String: Any]? {
    calls.last { $0.method == method }?.arguments
  }

  func call(_ method: String, _ arguments: [String: Any]) async throws -> [String: Any] {
    calls.append((method, arguments))
    guard let answer = answers[method] else { throw AnywhereRefusal(code: "failed") }
    return try answer(arguments)
  }

  /// An app that has the feature, is set up and has two people.
  static func ready(unlocked: Bool = true, language: String? = nil) -> FakeAnywhereChannel {
    let channel = FakeAnywhereChannel()
    var isUnlocked = unlocked
    channel.answers["status"] = { _ in
      var status: [String: Any] = [
        "version": 1, "enabled": isUnlocked, "settingKnown": isUnlocked,
        "lockAgainAfterUse": true, "unlocked": isUnlocked, "setUp": true, "biometric": "on",
      ]
      if let language { status["language"] = language }
      return status
    }
    channel.answers["unlockWithPassword"] = { arguments in
      guard arguments["password"] as? String == "violet-harbor-lantern-91" else {
        throw AnywhereRefusal(code: "wrongPassword", waitSeconds: 30)
      }
      isUnlocked = true
      return ["status": "unlocked"]
    }
    channel.answers["people"] = { _ in
      [
        "people": [
          ["id": "nino", "name": "Nino", "verified": false, "lastUsedHere": false],
          ["id": "mom", "name": "Mom", "verified": true, "lastUsedHere": true],
        ]
      ]
    }
    channel.answers["lock"] = { arguments in
      [
        "output": "https://ink.fuzzzycore.com/message#AwECc2VhbGVk", "kind": "link",
        "copied": arguments["copy"] as? Bool ?? false,
      ]
    }
    channel.answers["relock"] = { _ in ["relocked": true] }
    return channel
  }
}

/// Records what the model asks of its sheet or panel.
@MainActor
final class FakeHost: AnywhereHost {
  private(set) var events: [String] = []
  func bringAppForward() { events.append("bringAppForward") }
  func finish() { events.append("finish") }
  func share(_ sealed: String) { events.append("share") }
}
