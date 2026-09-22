import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    excludeApplicationSupportFromBackup()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Application Support holds the crypto store and the Isar database
  /// (`dependency_injection.dart`, path_provider's `getApplicationSupportDirectory`);
  /// keep it out of iCloud and Finder backups (THREAT_MODEL.md §2.8 / R34).
  private func excludeApplicationSupportFromBackup() {
    guard var url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    else { return }
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? url.setResourceValues(values)
  }
}
