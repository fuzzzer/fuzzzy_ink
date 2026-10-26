import Cocoa
import Combine
import SwiftUI

/// The floating Lock/Open panel: it takes the keyboard without bringing
/// Fuzzzy Ink to the front, so the app the person was in stays the active
/// one and ⌘V lands there. Esc closes it. It is left out of screenshots and
/// screen recordings (`sharingType = .none`), as the app's private screens.
@available(macOS 12.0, *)
final class InkPanel: NSPanel {
  init() {
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: InkPanelController.width, height: 220),
      styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
      backing: .buffered, defer: false)
    isFloatingPanel = true
    level = .floating
    becomesKeyOnlyIfNeeded = false
    hidesOnDeactivate = false
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    isMovableByWindowBackground = true
    isReleasedWhenClosed = false
    backgroundColor = .clear
    isOpaque = false
    hasShadow = true
    sharingType = .none
    animationBehavior = .utilityWindow
    collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient]
    for button: NSWindow.ButtonType in [.closeButton, .miniaturizeButton, .zoomButton] {
      standardWindowButton(button)?.isHidden = true
    }
  }

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  override func cancelOperation(_ sender: Any?) {
    close()
  }
}

/// Shows one [InkAnywhereModel] in an [InkPanel] near the pointer and is the
/// model's host. Closing the panel, whatever the reason, ends the use:
/// `relock` goes to Dart.
@available(macOS 12.0, *)
@MainActor
final class InkPanelController: NSObject, AnywhereHost, NSWindowDelegate {
  static let width: CGFloat = 400
  /// About the tallest step (people, a message, the draft note).
  static let roomBelow: CGFloat = 440

  let model: InkAnywhereModel
  private let panel = InkPanel()
  private let onClosed: () -> Void
  private var topLeft: NSPoint = .zero
  private var isClosing = false
  private var stepWatch: AnyCancellable?
  private var contentWatch: AnyCancellable?

  /// How long "Copied, press ⌘V" stays before the panel steps aside, so ⌘V
  /// reaches the app the person was in.
  static let doneDelay: TimeInterval = 1.6

  init(model: InkAnywhereModel, onClosed: @escaping () -> Void) {
    self.model = model
    self.onClosed = onClosed
    super.init()
    let content = InkAnywhereView(model: model, drawsSurface: true)
      .frame(width: InkPanelController.width)
      .fixedSize(horizontal: false, vertical: true)
    let hosting = NSHostingView(rootView: content)
    if #available(macOS 13.0, *) {
      // The panel follows the content itself ([fitContent]).
      hosting.sizingOptions = []
    }
    hosting.autoresizingMask = [.width, .height]
    panel.contentView = hosting
    panel.delegate = self
    model.host = self
    // Every change can change the height (a step, a note, the people):
    // grow or shrink from the top edge once SwiftUI has laid it out.
    contentWatch = model.objectWillChange.sink { [weak self] _ in
      DispatchQueue.main.async { self?.fitContent() }
    }
    stepWatch = model.$step.sink { [weak self] step in
      switch step {
      case .lockedFor(_, .copied), .lockedFor(_, .replaced):
        DispatchQueue.main.asyncAfter(deadline: .now() + InkPanelController.doneDelay) {
          self?.close()
        }
      default:
        break
      }
    }
  }

  /// Near the pointer, kept on the pointer's screen, with room below for
  /// the tallest step (the panel grows downwards).
  func show() {
    let mouse = NSEvent.mouseLocation
    let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    let size = panel.contentView?.fittingSize ?? panel.frame.size
    panel.setContentSize(NSSize(width: InkPanelController.width, height: size.height))
    var top = NSPoint(x: mouse.x - 40, y: mouse.y - 12)
    if let visible = screen?.visibleFrame {
      top.x = min(max(top.x, visible.minX + 8), visible.maxX - panel.frame.width - 8)
      top.y = min(max(top.y, visible.minY + InkPanelController.roomBelow), visible.maxY - 8)
    }
    panel.setFrameTopLeftPoint(top)
    topLeft = top
    panel.makeKeyAndOrderFront(nil)
    Task { await model.start() }
  }

  func close() {
    panel.close()
  }

  /// The panel's height follows the content; its top edge stays put.
  private func fitContent() {
    guard panel.isVisible, let content = panel.contentView else { return }
    content.layoutSubtreeIfNeeded()
    let size = NSSize(width: InkPanelController.width, height: content.fittingSize.height)
    guard abs(panel.contentLayoutRect.height - size.height) > 0.5 else { return }
    var frame = panel.frameRect(forContentRect: NSRect(origin: .zero, size: size))
    frame.origin = NSPoint(x: topLeft.x, y: topLeft.y - frame.height)
    panel.setFrame(frame, display: true, animate: false)
  }

  // MARK: AnywhereHost

  func bringAppForward() {
    if #available(macOS 14.0, *) {
      NSApp.activate()
    } else {
      NSApp.activate(ignoringOtherApps: true)
    }
    let main = NSApp.windows.first { $0 is MainFlutterWindow }
    main?.makeKeyAndOrderFront(nil)
  }

  func finish() {
    close()
  }

  func share(_ sealed: String) {}

  // MARK: NSWindowDelegate

  func windowDidMove(_ notification: Notification) {
    topLeft = NSPoint(x: panel.frame.minX, y: panel.frame.maxY)
  }

  /// A click elsewhere closes it, as Spotlight does, except while a step is
  /// running (the Touch ID prompt takes the keyboard for a moment).
  func windowDidResignKey(_ notification: Notification) {
    switch model.step {
    case .checking, .unlocking, .locking, .opening: return
    default: close()
    }
  }

  func windowWillClose(_ notification: Notification) {
    guard !isClosing else { return }
    isClosing = true
    let model = model
    let onClosed = onClosed
    Task {
      await model.close()
      onClosed()
    }
  }
}
