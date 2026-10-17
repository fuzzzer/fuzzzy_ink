import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// Dart marks each folder it creates (a chat's folder, the vault's) through
  /// this channel (`backup_exclusion.dart`, T-0432).
  static let backupChannel = "com.fuzzzycore.ink/backup"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    excludeAppFoldersFromBackup()
    registerBackupChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Application Support holds the crypto store and the Isar database
  /// (`dependency_injection.dart`, path_provider's `getApplicationSupportDirectory`);
  /// Documents holds every chat's folder — decrypted files in the clear — and
  /// the vault; Caches holds temporary copies. Keep all of it out of iCloud and
  /// Finder backups (THREAT_MODEL.md §2.8 / R34, T-0432). Folders already in
  /// Documents are marked one by one too, so an upgraded install is covered.
  private func excludeAppFoldersFromBackup() {
    for directory: FileManager.SearchPathDirectory in [
      .applicationSupportDirectory, .documentDirectory, .cachesDirectory,
    ] {
      guard let url = FileManager.default.urls(for: directory, in: .userDomainMask).first
      else { continue }
      AppDelegate.excludeFromBackup(url)
      if directory == .documentDirectory {
        AppDelegate.excludeChildFoldersFromBackup(of: url)
      }
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

  private func registerBackupChannel() {
    guard let registrar = registrar(forPlugin: "FuzzzyBackupExclusion") else { return }
    let channel = FlutterMethodChannel(
      name: AppDelegate.backupChannel, binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "excludeFromBackup",
        let arguments = call.arguments as? [String: Any],
        let path = arguments["path"] as? String
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(AppDelegate.excludeFromBackup(URL(fileURLWithPath: path, isDirectory: true)))
    }
  }
}
