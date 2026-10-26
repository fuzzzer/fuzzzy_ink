import Cocoa
import FlutterMacOS
import LocalAuthentication

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

/// The native side of `ink_device_channel.dart` on a Mac.
///
/// - `hasStrongBiometrics`: Touch ID is there and enrolled. The biometric
///   storage plugin's own check also passes with only the login password.
/// - `printImage`: the system print dialog for one image (the recovery key
///   sheet), instead of the share menu.
/// ("Save as file" already uses the system save panel.)
final class InkDevice {
  static let channelName = "com.fuzzzycore.ink/device"
  static let shared = InkDevice()

  private weak var window: NSWindow?

  func register(window: NSWindow, messenger: FlutterBinaryMessenger) {
    self.window = window
    let channel = FlutterMethodChannel(name: InkDevice.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any]
    switch call.method {
    case "hasStrongBiometrics":
      var error: NSError?
      result(
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error))
    case "printImage":
      guard let path = arguments?["path"] as? String,
        let image = NSImage(contentsOfFile: path)
      else {
        result(FlutterError(code: "badArguments", message: "no image", details: nil))
        return
      }
      printImage(image, jobName: arguments?["jobName"] as? String ?? "", result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func printImage(_ image: NSImage, jobName: String, result: @escaping FlutterResult) {
    let info = NSPrintInfo.shared.copy() as! NSPrintInfo
    info.horizontalPagination = .fit
    info.verticalPagination = .fit
    info.isHorizontallyCentered = true
    info.isVerticallyCentered = false
    let printable = info.imageablePageBounds.size
    let scale = min(1, printable.width / image.size.width, printable.height / image.size.height)
    let view = NSImageView(
      frame: NSRect(
        x: 0, y: 0, width: image.size.width * scale, height: image.size.height * scale))
    view.image = image
    view.imageScaling = .scaleProportionallyUpOrDown
    let operation = NSPrintOperation(view: view, printInfo: info)
    operation.jobTitle = jobName
    operation.showsPrintPanel = true
    operation.showsProgressPanel = true
    guard let window = window else {
      result(operation.run())
      return
    }
    operation.runModal(
      for: window, delegate: PrintDone.shared,
      didRun: #selector(PrintDone.printOperationDidRun(_:success:contextInfo:)),
      contextInfo: Unmanaged.passRetained(PrintDone.Box(result)).toOpaque())
  }

  /// Answers Dart once the sheet-modal print operation ends.
  final class PrintDone: NSObject {
    static let shared = PrintDone()

    final class Box {
      let result: FlutterResult
      init(_ result: @escaping FlutterResult) { self.result = result }
    }

    @objc func printOperationDidRun(
      _ operation: NSPrintOperation, success: Bool, contextInfo: UnsafeMutableRawPointer?
    ) {
      guard let contextInfo = contextInfo else { return }
      let box = Unmanaged<Box>.fromOpaque(contextInfo).takeRetainedValue()
      box.result(success)
    }
  }
}
