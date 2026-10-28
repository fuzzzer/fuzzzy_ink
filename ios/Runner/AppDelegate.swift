import Flutter
import LocalAuthentication
import UIKit
import UniformTypeIdentifiers

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
    registerDeviceChannel()
    registerPasteButton()
    registerAnywhere()
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

// MARK: - Lock from other apps (experimental)

extension AppDelegate {
  /// The native "Lock a message" sheet (ios/Runner/Anywhere); it asks Dart
  /// whether the build has the feature and the Settings switch is on.
  fileprivate func registerAnywhere() {
    guard let registrar = registrar(forPlugin: "FuzzzyAnywhere") else { return }
    InkAnywhereIOS.shared.register(messenger: registrar.messenger())
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
  private var isSecureForDart = false
  private var nativeSecureHolds = 0
  private var isInactive = false
  private var secureField: SecureCanvasField?
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
    isSecureForDart = secure
    applySecure()
  }

  /// A native sheet that holds typed text ("Lock from other apps") keeps the
  /// protection on while it is up, whatever the Flutter screen under it
  /// asks; each hold is released once.
  func holdSecure(_ hold: Bool) {
    nativeSecureHolds = max(0, nativeSecureHolds + (hold ? 1 : -1))
    applySecure()
  }

  private func applySecure() {
    let secure = isSecureForDart || nativeSecureHolds > 0
    isSecure = secure
    if secure { installSecureLayer() }
    secureField?.isSecureTextEntry = secure
    updateCover()
  }

  /// Moves the window's layer into a secure text field's canvas once; after
  /// that, `isSecureTextEntry` switches the protection on and off.
  ///
  /// The field fills the window and the window's layer sits in a host layer
  /// that cancels the canvas's own offset inside the field ([SecureCanvasField]),
  /// so the app is drawn exactly where UIKit places it: what a person sees
  /// and where a tap lands stay the same on every iPhone size and rotation.
  /// (The first version centred a zero-size field on the window, so the whole
  /// app, sheets included, was drawn from the screen's centre while taps went
  /// to the real places — QA 2026-10-26.)
  private func installSecureLayer() {
    guard secureField == nil, let window = window, let superlayer = window.layer.superlayer
    else { return }
    let field = SecureCanvasField(frame: window.bounds)
    field.isUserInteractionEnabled = false
    field.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(field)
    field.layoutIfNeeded()
    guard let canvas = SecureCanvasField.canvas(of: field) else {
      field.removeFromSuperview()
      return
    }
    superlayer.addSublayer(field.layer)
    field.attach(canvas: canvas, content: window.layer)
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

/// The text field whose secure canvas hides the window from screenshots,
/// screen recordings and mirroring while `isSecureTextEntry` is on.
///
/// The canvas is the field's own text area: its origin inside the field
/// depends on the iOS version and the field's height (a single-line field
/// centres it). The window's layer therefore sits in [host], which is kept
/// at the field's origin whatever the canvas does, and the field is kept the
/// window's size; the window layer's own place is UIKit's, so drawing and
/// hit-testing agree.
final class SecureCanvasField: UITextField {
  private let host = CALayer()
  private weak var canvas: CALayer?

  /// The secure canvas: the layer of the field's text canvas view, found by
  /// its class where possible (iOS 17 moved it from first to last).
  static func canvas(of field: UITextField) -> CALayer? {
    let layers = field.layer.sublayers ?? []
    if let named = layers.first(where: { layer in
      guard let view = layer.delegate as? UIView else { return false }
      return String(describing: type(of: view)).contains("Canvas")
    }) {
      return named
    }
    if #available(iOS 17.0, *) {
      return layers.last
    }
    return layers.first
  }

  func attach(canvas: CALayer, content: CALayer) {
    self.canvas = canvas
    host.masksToBounds = false
    canvas.addSublayer(host)
    host.addSublayer(content)
    syncHost()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    syncHost()
  }

  override var frame: CGRect {
    didSet { syncHost() }
  }

  override var bounds: CGRect {
    didSet { syncHost() }
  }

  /// Puts [host]'s origin on the field's origin, with the field's size.
  private func syncHost() {
    guard let canvas = canvas else { return }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    let canvasOrigin = canvas.convert(CGPoint.zero, to: layer)
    host.frame = CGRect(
      x: -canvasOrigin.x, y: -canvasOrigin.y, width: bounds.width, height: bounds.height)
    CATransaction.commit()
  }
}

// MARK: - Device: biometrics, print, save

extension AppDelegate {
  fileprivate func registerDeviceChannel() {
    guard let registrar = registrar(forPlugin: "FuzzzyDevice") else { return }
    let channel = FlutterMethodChannel(
      name: InkDevice.channelName, binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      InkDevice.shared.handle(call, result: result)
    }
  }
}

/// The native side of `ink_device_channel.dart`.
///
/// - `hasStrongBiometrics`: Face ID or Touch ID is there *and enrolled*. The
///   biometric storage plugin's own check also passes with only a passcode,
///   which offered the fingerprint step on a phone without any (QA
///   2026-10-26).
/// - `biometricKind`: `faceId` or `touchId`, so the app says "Face ID" on a
///   Face ID phone (final regression 2026-10-26); `other` when neither.
/// - `printImage`: the system printer list, then the image (the recovery key
///   sheet) goes straight to the printer chosen. Not the print options
///   sheet: its preview carries a share button (Save to Files, AirDrop,
///   Copy as a PDF) that iOS offers no way to hide (final regression
///   2026-10-26). The app shows its own preview before this.
/// - `exportFile`: the system "Save to Files" dialog for one file (the
///   recovery key as text) — again no share sheet and no clipboard.
final class InkDevice: NSObject, UIDocumentPickerDelegate {
  static let channelName = "com.fuzzzycore.ink/device"
  static let shared = InkDevice()

  /// The hardware's kind; `biometryType` is set only once a policy was
  /// evaluated, enrolled or not.
  static func biometricKind() -> String {
    let context = LAContext()
    var error: NSError?
    _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    switch context.biometryType {
    case .faceID: return "faceId"
    case .touchID: return "touchId"
    default: return "other"
    }
  }

  private var pendingExport: FlutterResult?

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any]
    switch call.method {
    case "hasStrongBiometrics":
      var error: NSError?
      result(
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error))
    case "biometricKind":
      result(InkDevice.biometricKind())
    case "printImage":
      guard let path = arguments?["path"] as? String,
        let image = UIImage(contentsOfFile: path)
      else {
        result(FlutterError(code: "badArguments", message: "no image", details: nil))
        return
      }
      printImage(image, jobName: arguments?["jobName"] as? String ?? "", result: result)
    case "exportFile":
      guard let path = arguments?["path"] as? String else {
        result(FlutterError(code: "badArguments", message: "path is missing", details: nil))
        return
      }
      exportFile(URL(fileURLWithPath: path), result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private var topController: UIViewController? {
    var top = UIApplication.shared.delegate?.window??.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }

  /// The printer picked last in this run, offered first next time.
  private var lastPrinter: UIPrinter?

  private func printImage(_ image: UIImage, jobName: String, result: @escaping FlutterResult) {
    let picker = UIPrinterPickerController(initiallySelectedPrinter: lastPrinter)
    let picked: UIPrinterPickerController.CompletionHandler = { [weak self] picker, didSelect, error in
      guard error == nil, didSelect, let printer = picker.selectedPrinter else {
        result(false)
        return
      }
      self?.lastPrinter = printer
      InkDevice.send(image, jobName: jobName, to: printer, result: result)
    }
    if UIDevice.current.userInterfaceIdiom == .pad, let view = topController?.view {
      let anchor = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
      picker.present(from: anchor, in: view, animated: true, completionHandler: picked)
    } else {
      picker.present(animated: true, completionHandler: picked)
    }
  }

  /// Prints [image] on [printer] with no further sheet. `true` once queued.
  /// The shared print controller lets go of the recovery key's image as
  /// soon as the job is handed over, failed or cancelled (security review
  /// 2026-10-26), so it is not kept until the next print.
  private static func send(
    _ image: UIImage, jobName: String, to printer: UIPrinter, result: @escaping FlutterResult
  ) {
    let controller = UIPrintInteractionController.shared
    let info = UIPrintInfo(dictionary: nil)
    info.outputType = .general
    info.jobName = jobName
    controller.printInfo = info
    controller.printingItem = image
    var answered = false
    let finish = { (printed: Bool) in
      release(controller)
      guard !answered else { return }
      answered = true
      result(printed)
    }
    let started = controller.print(to: printer) { _, completed, error in
      finish(error == nil && completed)
    }
    if !started {
      finish(false)
    }
  }

  /// Drops everything the shared print controller holds from the last job.
  private static func release(_ controller: UIPrintInteractionController) {
    controller.printingItem = nil
    controller.printingItems = nil
    controller.printPageRenderer = nil
    controller.printFormatter = nil
    controller.printInfo = nil
  }

  private func exportFile(_ url: URL, result: @escaping FlutterResult) {
    guard pendingExport == nil, let top = topController else {
      result(FlutterError(code: "busy", message: "a save is already open", details: nil))
      return
    }
    let picker = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
    picker.delegate = self
    pendingExport = result
    top.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    pendingExport?(!urls.isEmpty)
    pendingExport = nil
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pendingExport?(false)
    pendingExport = nil
  }
}

// MARK: - Paste button

extension AppDelegate {
  fileprivate func registerPasteButton() {
    guard #available(iOS 16.0, *),
      let registrar = registrar(forPlugin: "FuzzzyPasteButton")
    else { return }
    registrar.register(
      InkPasteButtonFactory(messenger: registrar.messenger()),
      withId: InkPasteButtonFactory.viewType)
  }
}

/// The system Paste button (`UIPasteControl`, iOS 16 and later) for
/// `ink_paste_button.dart`. A paste through it is the person's own tap on a
/// button the system draws, so iOS reads the clipboard without asking
/// "Allow Paste?" every time (final regression 2026-10-26). Dart passes the
/// colours and the corner radius; each button answers on its own channel
/// (`…/paste_button/<view id>`, method `pasted` with the text, or null when
/// the clipboard held no text).
@available(iOS 16.0, *)
final class InkPasteButtonFactory: NSObject, FlutterPlatformViewFactory {
  static let viewType = "com.fuzzzycore.ink/paste_button"

  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?
  ) -> FlutterPlatformView {
    let channel = FlutterMethodChannel(
      name: "\(InkPasteButtonFactory.viewType)/\(viewId)", binaryMessenger: messenger)
    return InkPasteButton(
      frame: frame, arguments: args as? [String: Any] ?? [:], channel: channel)
  }
}

@available(iOS 16.0, *)
final class InkPasteButton: NSObject, FlutterPlatformView {
  private let target: InkPasteTarget

  init(frame: CGRect, arguments: [String: Any], channel: FlutterMethodChannel) {
    target = InkPasteTarget(frame: frame, channel: channel)
    super.init()
    let configuration = UIPasteControl.Configuration()
    configuration.displayMode = .iconAndLabel
    configuration.cornerStyle = .fixed
    configuration.cornerRadius = CGFloat(arguments["cornerRadius"] as? Double ?? 8)
    if let foreground = arguments["foreground"] as? Int {
      configuration.baseForegroundColor = InkGuard.color(argb: foreground)
    }
    if let background = arguments["background"] as? Int {
      configuration.baseBackgroundColor = InkGuard.color(argb: background)
    }
    let control = UIPasteControl(configuration: configuration)
    control.target = target
    control.translatesAutoresizingMaskIntoConstraints = false
    target.addSubview(control)
    NSLayoutConstraint.activate([
      control.leadingAnchor.constraint(equalTo: target.leadingAnchor),
      control.trailingAnchor.constraint(equalTo: target.trailingAnchor),
      control.topAnchor.constraint(equalTo: target.topAnchor),
      control.bottomAnchor.constraint(equalTo: target.bottomAnchor),
    ])
  }

  func view() -> UIView { target }
}

/// What the Paste button pastes into: takes plain text or a link and hands
/// it to Dart; nothing is kept here.
@available(iOS 16.0, *)
final class InkPasteTarget: UIView {
  private let channel: FlutterMethodChannel

  init(frame: CGRect, channel: FlutterMethodChannel) {
    self.channel = channel
    super.init(frame: frame)
    backgroundColor = .clear
    pasteConfiguration = UIPasteConfiguration(acceptableTypeIdentifiers: [
      UTType.plainText.identifier, UTType.url.identifier,
    ])
  }

  required init?(coder: NSCoder) { nil }

  override func paste(itemProviders: [NSItemProvider]) {
    if let provider = itemProviders.first(where: { $0.canLoadObject(ofClass: NSString.self) }) {
      _ = provider.loadObject(ofClass: NSString.self) { [weak self] object, _ in
        self?.send(object as? String)
      }
    } else if let provider = itemProviders.first(where: { $0.canLoadObject(ofClass: NSURL.self) }) {
      _ = provider.loadObject(ofClass: NSURL.self) { [weak self] object, _ in
        self?.send((object as? URL)?.absoluteString)
      }
    } else {
      send(nil)
    }
  }

  private func send(_ text: String?) {
    DispatchQueue.main.async { [channel] in
      channel.invokeMethod("pasted", arguments: text)
    }
  }
}
