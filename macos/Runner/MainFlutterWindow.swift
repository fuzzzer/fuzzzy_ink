import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Dart marks each folder it creates (a chat's folder, the vault's) through
  /// this channel (`backup_exclusion.dart`, T-0432).
  static let backupChannel = "com.fuzzzycore.ink/backup"

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    excludeAppFoldersFromBackup()
    RegisterGeneratedPlugins(registry: flutterViewController)
    registerBackupChannel(messenger: flutterViewController.engine.binaryMessenger)
    InkGuard.shared.register(
      window: self, messenger: flutterViewController.engine.binaryMessenger)
    InkIncoming.shared.register(messenger: flutterViewController.engine.binaryMessenger)
    InkDevice.shared.register(
      window: self, messenger: flutterViewController.engine.binaryMessenger)
    // "Lock from other apps" (experimental): the Services menu, the
    // shortcut and the menu bar panel; all off until the build and the
    // person's Settings switch say so. Development flavour only.
    #if INK_ANYWHERE
      if #available(macOS 12.0, *) {
        InkAnywhereMac.shared.register(messenger: flutterViewController.engine.binaryMessenger)
      }
    #endif

    super.awakeFromNib()
  }

  /// Application Support/<bundle id> holds the crypto store and the Isar database
  /// (`dependency_injection.dart`, path_provider's `getApplicationSupportDirectory`);
  /// Documents holds every chat's folder — decrypted files in the clear — and
  /// the vault; Caches holds temporary copies. Keep all of it out of Time
  /// Machine (THREAT_MODEL.md §2.8 / R34, T-0432). Folders already in Documents
  /// are marked one by one too, so an upgraded install is covered.
  ///
  /// Documents and Caches are the sandbox container's own; outside the sandbox
  /// they would be the user's shared folders, so they are only marked inside it.
  private func excludeAppFoldersFromBackup() {
    let fileManager = FileManager.default
    if let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
      let bundleId = Bundle.main.bundleIdentifier
    {
      MainFlutterWindow.excludeFromBackup(base.appendingPathComponent(bundleId))
    }

    guard ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil else { return }
    if let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
      MainFlutterWindow.excludeFromBackup(documents)
      MainFlutterWindow.excludeChildFoldersFromBackup(of: documents)
    }
    if let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
      MainFlutterWindow.excludeFromBackup(caches)
    }
  }

  /// Creates [url] if missing and sets `isExcludedFromBackup`, which also
  /// covers everything inside it. Answers whether the mark was set.
  @discardableResult
  static func excludeFromBackup(_ url: URL) -> Bool {
    var url = url
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    do {
      try url.setResourceValues(values)
      return true
    } catch {
      return false
    }
  }

  static func excludeChildFoldersFromBackup(of url: URL) {
    let children = (try? FileManager.default.contentsOfDirectory(
      at: url, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
    for child in children
    where (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
      excludeFromBackup(child)
    }
  }

  private func registerBackupChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: MainFlutterWindow.backupChannel, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "excludeFromBackup",
        let arguments = call.arguments as? [String: Any],
        let path = arguments["path"] as? String
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(MainFlutterWindow.excludeFromBackup(URL(fileURLWithPath: path, isDirectory: true)))
    }
  }
}

/// The native side of the screen and copy guard (`screen_guard.dart`,
/// `copy_guard.dart`).
///
/// - `setSecure`: the window's sharing type is none while a sensitive screen
///   is visible, which leaves it out of screenshots and screen recordings that
///   respect it.
/// - `copy`: a sensitive copy is marked concealed and transient (the
///   nspasteboard.org convention), so clipboard managers hide it and do not
///   keep it.
/// - `clearIfOurs`: empties the pasteboard only while it still holds that
///   copy, judged by its change count, so another app's text is never read.
final class InkGuard {
  static let shared = InkGuard()

  private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
  private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

  private weak var window: NSWindow?
  private var channel: FlutterMethodChannel?
  private var ourChangeCount: Int?
  private var ourCopyIsSensitive = false

  func register(window: NSWindow, messenger: FlutterBinaryMessenger) {
    self.window = window
    let channel = FlutterMethodChannel(
      name: "com.fuzzzycore.ink/guard", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    self.channel = channel
    NotificationCenter.default.addObserver(
      forName: NSApplication.willTerminateNotification, object: nil, queue: .main
    ) { [weak self] _ in
      self?.clearSensitiveCopy()
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setSecure":
      let isSecure = call.arguments as? Bool ?? false
      window?.sharingType = isSecure ? .none : .readOnly
      result(true)
    case "copy":
      guard let arguments = call.arguments as? [String: Any],
        let text = arguments["text"] as? String
      else {
        result(FlutterError(code: "badArguments", message: "text is missing", details: nil))
        return
      }
      copy(text, isSensitive: arguments["sensitive"] as? Bool ?? false)
      result(true)
    case "clearIfOurs":
      result(clearIfOurs())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func copy(_ text: String, isSensitive: Bool) {
    let pasteboard = NSPasteboard.general
    var types: [NSPasteboard.PasteboardType] = [.string]
    if isSensitive {
      types += [InkGuard.concealedType, InkGuard.transientType]
    }
    pasteboard.declareTypes(types, owner: nil)
    pasteboard.setString(text, forType: .string)
    if isSensitive {
      pasteboard.setData(Data(), forType: InkGuard.concealedType)
      pasteboard.setData(Data(), forType: InkGuard.transientType)
    }
    ourChangeCount = pasteboard.changeCount
    ourCopyIsSensitive = isSensitive
  }

  /// The app is quitting: a sensitive copy (a safe password) does not
  /// outlive it, timer or not (security review 2026-10-26).
  func clearSensitiveCopy() {
    if ourCopyIsSensitive { _ = clearIfOurs() }
  }

  /// Answers `cleared` or `notOurs` (see `ClipboardClearResult`).
  private func clearIfOurs() -> String {
    guard let count = ourChangeCount else { return "notOurs" }
    ourChangeCount = nil
    ourCopyIsSensitive = false
    guard NSPasteboard.general.changeCount == count else { return "notOurs" }
    NSPasteboard.general.clearContents()
    return "cleared"
  }
}
