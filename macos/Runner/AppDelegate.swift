import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// A `.fuzz` file opened from Finder (or dropped on the Dock icon) goes to
  /// Dart's Open flow ([InkIncoming]); anything else to the plugins as before.
  override func application(_ application: NSApplication, open urls: [URL]) {
    let files = urls.filter { $0.isFileURL }
    if !files.isEmpty { InkIncoming.shared.add(files) }
    let others = urls.filter { !$0.isFileURL }
    if !others.isEmpty { super.application(application, open: others) }
  }
}

/// Files the desktop handed to the app, kept until Dart takes them
/// (`incoming_files.dart`): Dart asks with `takePending` when it starts and
/// whenever it is told `changed`. Only the file's URL crosses; Dart reads
/// the file once into its private hand-off folder and never runs it.
final class InkIncoming {
  static let channelName = "com.fuzzzycore.ink/incoming"
  static let shared = InkIncoming()

  private var pending: [String] = []
  private var channel: FlutterMethodChannel?

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: InkIncoming.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "takePending", let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self.takePending())
    }
    self.channel = channel
  }

  func add(_ urls: [URL]) {
    pending.append(contentsOf: urls.filter { $0.isFileURL }.map { $0.absoluteString })
    channel?.invokeMethod("changed", arguments: nil)
  }

  /// Everything queued so far, once.
  func takePending() -> [String] {
    let taken = pending
    pending = []
    return taken
  }
}
