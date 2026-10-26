import Foundation

#if os(macOS)
  import FlutterMacOS
#else
  import Flutter
#endif

/// [AnywhereCalling] over the Flutter engine's channel. Dart's events
/// (`lockChanged`, `settingsChanged`, `shownClosed`) go to [onEvent].
@available(iOS 15.0, macOS 12.0, *)
@MainActor
final class InkAnywhereChannel: AnywhereCalling {
  static let name = "com.fuzzzycore.ink/anywhere"

  private let channel: FlutterMethodChannel
  var onEvent: ((String, [String: Any]) -> Void)?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: InkAnywhereChannel.name, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      let arguments = call.arguments as? [String: Any] ?? [:]
      MainActor.assumeIsolated {
        self?.onEvent?(call.method, arguments)
      }
      result(nil)
    }
  }

  func call(_ method: String, _ arguments: [String: Any] = [:]) async throws -> [String: Any] {
    var arguments = arguments
    arguments["v"] = 1
    return try await withCheckedThrowingContinuation { continuation in
      channel.invokeMethod(method, arguments: arguments) { answer in
        if let error = answer as? FlutterError {
          let details = error.details as? [String: Any]
          continuation.resume(
            throwing: AnywhereRefusal(
              code: error.code, waitSeconds: details?["waitSeconds"] as? Int ?? 0))
        } else if (answer as AnyObject?) === FlutterMethodNotImplemented {
          continuation.resume(throwing: AnywhereRefusal.notInBuild)
        } else {
          continuation.resume(returning: answer as? [String: Any] ?? [:])
        }
      }
    }
  }
}
