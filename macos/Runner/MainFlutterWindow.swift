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
