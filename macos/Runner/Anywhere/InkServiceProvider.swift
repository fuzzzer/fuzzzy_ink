import Cocoa

/// Right-click → Services → "Lock with Fuzzzy Ink" / "Open with Fuzzzy Ink"
/// (`NSServices`, declared in the development flavour only for now, see
/// `Services-development.plist`). macOS hands over the selected text on a
/// private pasteboard; nothing else of the other app is read.
///
/// Lock replaces the selection in place: the service returns plain text, so
/// macOS waits (up to `NSTimeout`, 120 s) while the panel runs in a nested
/// event loop; the sealed output is written back on the same pasteboard and
/// the other app puts it where the selection was. If the person closes the
/// panel, nothing is written and the selection stays as it was.
///
/// Open never writes anything back: the panel peeks, and the message opens
/// only on Open, on Fuzzzy Ink's own private screen.
@available(macOS 12.0, *)
@MainActor
final class InkServiceProvider: NSObject {
  /// Shows a model in a panel; calls the closure when the panel has closed.
  /// Answers a way to close that panel.
  typealias Present = (InkAnywhereModel, @escaping () -> Void) -> () -> Void

  private let makeModel: (AnywhereMode, String, InkAnywhereModel.Delivery) -> InkAnywhereModel
  private let present: Present
  /// A little under the declared 120 s, so the answer is never too late.
  var timeout: TimeInterval = 115
  private var isBusy = false

  init(
    makeModel: @escaping (AnywhereMode, String, InkAnywhereModel.Delivery) -> InkAnywhereModel,
    present: @escaping Present
  ) {
    self.makeModel = makeModel
    self.present = present
  }

  /// `NSMessage` `lockText`.
  @objc(lockText:userData:error:)
  func lockText(
    _ pasteboard: NSPasteboard, userData: String?,
    error: AutoreleasingUnsafeMutablePointer<NSString?>
  ) {
    if let refusal = lockInPlace(pasteboard) { error.pointee = refusal as NSString }
  }

  /// `NSMessage` `openText`.
  @objc(openText:userData:error:)
  func openText(
    _ pasteboard: NSPasteboard, userData: String?,
    error: AutoreleasingUnsafeMutablePointer<NSString?>
  ) {
    guard let text = InkServiceProvider.text(on: pasteboard) else {
      error.pointee = "No text was selected." as NSString
      return
    }
    _ = present(makeModel(.open, text, .copy)) {}
  }

  /// Runs the Lock panel for the selected text and, once locked, puts the
  /// sealed output on [pasteboard]. Answers an error line for macOS when
  /// nothing was locked.
  func lockInPlace(_ pasteboard: NSPasteboard) -> String? {
    guard !isBusy else { return "Fuzzzy Ink is already locking a text." }
    guard let text = InkServiceProvider.text(on: pasteboard) else { return "No text was selected." }
    isBusy = true
    defer { isBusy = false }

    var sealed: String?
    var isClosed = false
    let model = makeModel(.lock, text, .returnToCaller { sealed = $0 })
    let closePanel = present(model) { isClosed = true }

    // A nested event loop: the panel's clicks and keys, Flutter's channel
    // answers and Swift's main-actor work all go on while macOS waits.
    // (A bare run loop would draw the panel but never hand it an event.)
    let app = NSApplication.shared
    let deadline = Date().addingTimeInterval(timeout)
    while sealed == nil && !isClosed && Date() < deadline {
      if let event = app.nextEvent(
        matching: .any, until: Date().addingTimeInterval(0.05), inMode: .default, dequeue: true)
      {
        app.sendEvent(event)
      }
    }
    guard let sealed else {
      // Out of time: the selection stays; the panel goes too.
      if !isClosed { closePanel() }
      return "Nothing was locked."
    }
    InkServiceProvider.write(sealed, to: pasteboard)
    return nil
  }

  static func text(on pasteboard: NSPasteboard) -> String? {
    guard let text = pasteboard.string(forType: .string),
      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { return nil }
    return text
  }

  /// Sealed output only: it is what replaces the selection.
  static func write(_ sealed: String, to pasteboard: NSPasteboard) {
    pasteboard.clearContents()
    pasteboard.setString(sealed, forType: .string)
  }
}
