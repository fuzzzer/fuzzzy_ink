import Cocoa
import FlutterMacOS

/// "Lock from other apps" on a Mac (experimental): the Services menu, a
/// global shortcut (⌃⌥⌘L) and a menu bar item, each opening the Lock/Open
/// panel. Every entry point is off until the build has the feature
/// (`--dart-define=FUZZ_ANYWHERE=true`, Dart answers `status`) and the person
/// turned on Settings → Other apps → Lock from other apps.
///
/// The switch is sealed in the store, so it is known only after the first
/// unlock of a run. Until then the shortcut and the menu bar item stay off.
/// The Services entries are declared in the development flavour's
/// Info.plist, so macOS can start the app for them: their provider is set at
/// launch (it shows the panel, which offers only Unlock until the switch is
/// known) and removed as soon as the switch is known to be off.
///
/// Below macOS 12 none of it exists, and none of it is compiled outside the
/// development flavour (`INK_ANYWHERE`, set only in its three
/// configurations; MainFlutterWindow does not register it otherwise).
@available(macOS 12.0, *)
@MainActor
final class InkAnywhereMac {
  static let shared = InkAnywhereMac()

  private var channel: InkAnywhereChannel?
  private var services: InkServiceProvider?
  private var hotKey: InkHotKey?
  private var statusItem: InkStatusItem?
  private var panel: InkPanelController?
  private var language: String?
  private var isOn = false

  /// Info.plist declares the Services entries (the development flavour).
  private var declaresServices: Bool {
    Bundle.main.object(forInfoDictionaryKey: "NSServices") != nil
  }

  func register(messenger: FlutterBinaryMessenger) {
    let channel = InkAnywhereChannel(messenger: messenger)
    channel.onEvent = { [weak self] event, arguments in self?.handle(event, arguments) }
    self.channel = channel
    if declaresServices {
      // macOS does not say which app asked for a service (any app can,
      // with NSPerformService), so a service remembers no person.
      let provider = InkServiceProvider(
        makeModel: { [unowned self] mode, text, delivery in
          self.makeModel(mode: mode, prefill: text, sourceApp: nil, delivery: delivery)
        },
        present: { [unowned self] model, onClosed in
          let controller = self.present(model, onClosed: onClosed)
          return { [weak controller] in controller?.close() }
        })
      services = provider
      NSApp.servicesProvider = provider
    }
    NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.refresh() }
    }
    // Dart puts up its side after the first frame; ask once it is likely up.
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in self?.refresh() }
  }

  /// Opens the panel (the shortcut, the menu bar item).
  func showPanel(mode: AnywhereMode) {
    guard panel == nil else { return }
    present(
      makeModel(
        mode: mode, prefill: nil, sourceApp: InkAnywhereMac.frontmostApp(), delivery: .copy)
    ) {}
  }

  func showApp() {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.windows.first { $0 is MainFlutterWindow }?.makeKeyAndOrderFront(nil)
  }

  // MARK: - State

  private func handle(_ event: String, _ arguments: [String: Any]) {
    panel?.model.handle(event: event, arguments)
    switch event {
    case "settingsChanged":
      apply(isOn: arguments["enabled"] as? Bool ?? false, isKnown: true)
    case "lockChanged":
      refresh()
    default:
      break
    }
  }

  /// Asks Dart where things stand and switches the entry points to match.
  private func refresh() {
    guard let channel else { return }
    Task {
      do {
        let status = AnywhereStatus(try await channel.call("status", [:]))
        language = status.language
        apply(isOn: status.isEnabled, isKnown: status.isSettingKnown)
      } catch let refusal as AnywhereRefusal where refusal == .notInBuild {
        apply(isOn: false, isKnown: true)
      } catch {}
    }
  }

  private func apply(isOn: Bool, isKnown: Bool) {
    self.isOn = isOn
    if isOn {
      if hotKey == nil {
        let hotKey = InkHotKey { [weak self] in self?.showPanel(mode: .lock) }
        hotKey.register()
        self.hotKey = hotKey
      }
      if statusItem == nil { statusItem = InkStatusItem(owner: self) }
      statusItem?.update(strings: InkText(language: language))
      if declaresServices, let services { NSApp.servicesProvider = services }
    } else {
      hotKey?.unregister()
      hotKey = nil
      statusItem?.remove()
      statusItem = nil
      if isKnown { NSApp.servicesProvider = nil }
    }
  }

  // MARK: - Panel

  private func makeModel(
    mode: AnywhereMode, prefill: String?, sourceApp: String?,
    delivery: InkAnywhereModel.Delivery
  ) -> InkAnywhereModel {
    InkAnywhereModel(
      channel: channel ?? InkUnavailableChannel(), mode: mode, prefill: prefill,
      sourceApp: sourceApp, delivery: delivery)
  }

  @discardableResult
  private func present(_ model: InkAnywhereModel, onClosed: @escaping () -> Void)
    -> InkPanelController
  {
    panel?.close()
    let controller = InkPanelController(model: model) { [weak self] in
      if self?.panel?.model === model { self?.panel = nil }
      onClosed()
    }
    panel = controller
    controller.show()
    return controller
  }

  /// The app the person is in when they press the shortcut or the menu bar
  /// item (its bundle id, no permission needed), for the person last used
  /// there. Never Fuzzzy Ink itself. Not used for a service request.
  static func frontmostApp() -> String? {
    guard let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
      id != Bundle.main.bundleIdentifier
    else { return nil }
    return id
  }
}

/// Before the engine is there: every call is "not in this build".
@available(macOS 12.0, *)
@MainActor
private final class InkUnavailableChannel: AnywhereCalling {
  func call(_ method: String, _ arguments: [String: Any]) async throws -> [String: Any] {
    throw AnywhereRefusal.notInBuild
  }
}
