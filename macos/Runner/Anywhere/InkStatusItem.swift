import Cocoa

/// The menu bar item: Fuzzzy Ink's mark as a template image (it follows the
/// menu bar's light and dark), with Lock, Open and the app.
@available(macOS 12.0, *)
@MainActor
final class InkStatusItem: NSObject {
  private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
  private weak var owner: InkAnywhereMac?

  init(owner: InkAnywhereMac) {
    self.owner = owner
    super.init()
    if let button = item.button {
      button.image = InkStatusItem.templateMark()
      button.imagePosition = .imageOnly
    }
  }

  func update(strings: InkText) {
    item.button?.setAccessibilityLabel("Fuzzzy Ink")
    item.button?.toolTip = strings.lockTitle
    let menu = NSMenu()
    let lock = NSMenuItem(title: strings.lockTitle + "…", action: #selector(lock), keyEquivalent: "l")
    lock.keyEquivalentModifierMask = [.control, .option, .command]
    lock.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)
    let open = NSMenuItem(title: strings.openTitle + "…", action: #selector(open), keyEquivalent: "")
    open.image = NSImage(systemSymbolName: "lock.open.fill", accessibilityDescription: nil)
    let app = NSMenuItem(title: strings.showApp, action: #selector(showApp), keyEquivalent: "")
    for entry in [lock, open, app] { entry.target = self }
    menu.items = [lock, open, .separator(), app]
    item.menu = menu
  }

  func remove() {
    NSStatusBar.system.removeStatusItem(item)
  }

  @objc private func lock() { owner?.showPanel(mode: .lock) }
  @objc private func open() { owner?.showPanel(mode: .open) }
  @objc private func showApp() { owner?.showApp() }

  /// The drop in the sun from the app's assets, drawn by its shape only.
  private static func templateMark() -> NSImage? {
    let image =
      InkMark.load("assets/logo/2.0x/ink_mark.png")?.copy() as? NSImage
      ?? NSImage(systemSymbolName: "drop.circle.fill", accessibilityDescription: "Fuzzzy Ink")
    image?.size = NSSize(width: 18, height: 18)
    image?.isTemplate = true
    return image
  }
}
