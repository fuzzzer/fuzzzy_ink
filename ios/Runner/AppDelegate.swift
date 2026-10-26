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
    registerGuardChannel()
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

// MARK: - Screen and copy guard

extension AppDelegate {
  fileprivate func registerGuardChannel() {
    guard let registrar = registrar(forPlugin: "FuzzzyGuard") else { return }
    let channel = FlutterMethodChannel(
      name: InkGuard.channelName, binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      InkGuard.shared.handle(call, result: result)
    }
  }
}

/// The native side of the screen and copy guard (`screen_guard.dart`,
/// `copy_guard.dart`).
///
/// - App switcher: on every screen, a cover (the look's ground and the Ink
///   mark, DESIGN.md section 4.2) hides the window while the app is inactive,
///   so the app switcher snapshot never shows the content.
/// - `setCover`: the look the cover takes (ground colour, mark asset); Dart
///   sends it whenever the look changes. Until then it follows the system.
/// - `setSecure`: while a sensitive screen is visible the Flutter content is
///   drawn inside a secure text field's layer, which iOS leaves out of
///   screenshots, screen recordings and mirroring; a blur covers the window
///   while the screen is being recorded or mirrored.
/// - `copy`: a sensitive copy stays on this device (no Universal Clipboard);
///   every copy expires on its own after the time Dart gives.
/// - `clearIfOurs`: empties the pasteboard only while it still holds that
///   copy, judged by its change count, so another app's text is never read.
final class InkGuard: NSObject {
  static let channelName = "com.fuzzzycore.ink/guard"
  static let shared = InkGuard()

  /// What covers the window: the brand cover (app switcher) or a blur
  /// (a sensitive screen being recorded or mirrored).
  enum Cover: Equatable {
    case brand
    case blur
  }

  /// The cover for a state; the brand cover wins while inactive.
  static func cover(isInactive: Bool, isSecure: Bool, isCaptured: Bool) -> Cover? {
    if isInactive { return .brand }
    if isSecure && isCaptured { return .blur }
    return nil
  }

  /// The mark's side on the cover, in points (DESIGN.md section 11).
  static let coverMarkSize: CGFloat = 64

  private var isSecure = false
  private var isInactive = false
  private var secureField: UITextField?
  private var cover: UIView?
  private var coverKind: Cover?
  private var coverGround: UIColor?
  private var coverMarkAsset: String?
  private var ourChangeCount: Int?

  private override init() {
    super.init()
    let center = NotificationCenter.default
    center.addObserver(
      self, selector: #selector(willResignActive),
      name: UIApplication.willResignActiveNotification, object: nil)
    center.addObserver(
      self, selector: #selector(didBecomeActive),
      name: UIApplication.didBecomeActiveNotification, object: nil)
    center.addObserver(
      self, selector: #selector(captureChanged),
      name: UIScreen.capturedDidChangeNotification, object: nil)
  }

  private var window: UIWindow? {
    UIApplication.shared.delegate?.window ?? nil
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setSecure":
      setSecure(call.arguments as? Bool ?? false)
      result(true)
    case "setCover":
      guard let arguments = call.arguments as? [String: Any],
        let ground = arguments["ground"] as? Int,
        let mark = arguments["mark"] as? String
      else {
        result(FlutterError(code: "badArguments", message: "ground or mark is missing", details: nil))
        return
      }
      coverGround = InkGuard.color(argb: ground)
      coverMarkAsset = mark
      result(true)
    case "copy":
      guard let arguments = call.arguments as? [String: Any],
        let text = arguments["text"] as? String
      else {
        result(FlutterError(code: "badArguments", message: "text is missing", details: nil))
        return
      }
      copy(
        text, isSensitive: arguments["sensitive"] as? Bool ?? false,
        expiresInMs: arguments["expiresInMs"] as? Int ?? 0)
      result(true)
    case "clearIfOurs":
      result(clearIfOurs())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func setSecure(_ secure: Bool) {
    isSecure = secure
    if secure { installSecureLayer() }
    secureField?.isSecureTextEntry = secure
    updateCover()
  }

  /// Moves the window's layer into a secure text field's canvas once; after
  /// that, `isSecureTextEntry` switches the protection on and off.
  private func installSecureLayer() {
    guard secureField == nil, let window = window, let superlayer = window.layer.superlayer
    else { return }
    let field = UITextField()
    field.isUserInteractionEnabled = false
    field.translatesAutoresizingMaskIntoConstraints = false
    window.addSubview(field)
    field.centerXAnchor.constraint(equalTo: window.centerXAnchor).isActive = true
    field.centerYAnchor.constraint(equalTo: window.centerYAnchor).isActive = true
    superlayer.addSublayer(field.layer)
    let canvas: CALayer?
    if #available(iOS 17.0, *) {
      canvas = field.layer.sublayers?.last
    } else {
      canvas = field.layer.sublayers?.first
    }
    guard let canvas = canvas else {
      field.layer.removeFromSuperlayer()
      field.removeFromSuperview()
      return
    }
    canvas.addSublayer(window.layer)
    secureField = field
  }

  @objc private func willResignActive() {
    isInactive = true
    updateCover()
  }

  @objc private func didBecomeActive() {
    isInactive = false
    updateCover()
  }

  @objc private func captureChanged() {
    updateCover()
  }

  private func updateCover() {
    let wanted = InkGuard.cover(
      isInactive: isInactive, isSecure: isSecure, isCaptured: UIScreen.main.isCaptured)
    guard wanted != coverKind else { return }
    cover?.removeFromSuperview()
    cover = nil
    coverKind = nil
    guard let wanted = wanted, let window = window else { return }
    let view: UIView
    switch wanted {
    case .brand:
      view = brandCover(frame: window.bounds, traits: window.traitCollection)
    case .blur:
      view = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
      view.frame = window.bounds
    }
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(view)
    cover = view
    coverKind = wanted
  }

  /// The look's ground with the Ink mark in the middle.
  private func brandCover(frame: CGRect, traits: UITraitCollection) -> UIView {
    let isDark = traits.userInterfaceStyle == .dark
    let view = UIView(frame: frame)
    view.backgroundColor =
      coverGround ?? InkGuard.color(argb: isDark ? 0xFF12_1417 : 0xFFF2_F0E9)
    let asset =
      coverMarkAsset
      ?? (isDark ? "assets/logo/3.0x/ink_mark.png" : "assets/logo/3.0x/ink_mark_paper.png")
    if let path = Bundle.main.path(
      forResource: FlutterDartProject.lookupKey(forAsset: asset), ofType: nil),
      let image = UIImage(contentsOfFile: path)
    {
      let mark = UIImageView(image: image)
      mark.contentMode = .scaleAspectFit
      mark.frame = CGRect(
        x: 0, y: 0, width: InkGuard.coverMarkSize, height: InkGuard.coverMarkSize)
      mark.center = CGPoint(x: frame.midX, y: frame.midY)
      mark.autoresizingMask = [
        .flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin,
      ]
      view.addSubview(mark)
    }
    return view
  }

  static func color(argb: Int) -> UIColor {
    UIColor(
      red: CGFloat((argb >> 16) & 0xFF) / 255,
      green: CGFloat((argb >> 8) & 0xFF) / 255,
      blue: CGFloat(argb & 0xFF) / 255,
      alpha: CGFloat((argb >> 24) & 0xFF) / 255)
  }

  private func copy(_ text: String, isSensitive: Bool, expiresInMs: Int) {
    var options: [UIPasteboard.OptionsKey: Any] = [:]
    if isSensitive {
      options[.localOnly] = true
    }
    if expiresInMs > 0 {
      options[.expirationDate] = Date().addingTimeInterval(Double(expiresInMs) / 1000)
    }
    UIPasteboard.general.setItems([["public.utf8-plain-text": text]], options: options)
    ourChangeCount = UIPasteboard.general.changeCount
  }

  /// Answers `cleared` or `notOurs` (see `ClipboardClearResult`).
  private func clearIfOurs() -> String {
    guard let count = ourChangeCount else { return "notOurs" }
    ourChangeCount = nil
    guard UIPasteboard.general.changeCount == count else { return "notOurs" }
    UIPasteboard.general.items = []
    return "cleared"
  }
}
