import Carbon

/// One global keyboard shortcut through Carbon's `RegisterEventHotKey`: the
/// only way that needs no permission (no Input Monitoring, no Accessibility)
/// and works in the sandbox. It sees only its own key combination, never
/// other typing.
///
/// Default: Control-Option-Command-L (⌃⌥⌘L). Option-Command-L alone is
/// Downloads in Safari and Finder, so the shortcut adds Control.
@available(macOS 12.0, *)
final class InkHotKey {
  static let defaultKeyCode = UInt32(kVK_ANSI_L)
  static let defaultModifiers = UInt32(controlKey | optionKey | cmdKey)
  /// "Ink!" as a four-character code, to recognise our own key.
  private static let signature: OSType = 0x496E_6B21

  private var hotKey: EventHotKeyRef?
  private var handler: EventHandlerRef?
  private let onPress: () -> Void

  init(onPress: @escaping () -> Void) {
    self.onPress = onPress
  }

  deinit { unregister() }

  var isRegistered: Bool { hotKey != nil }

  @discardableResult
  func register(
    keyCode: UInt32 = InkHotKey.defaultKeyCode, modifiers: UInt32 = InkHotKey.defaultModifiers
  ) -> Bool {
    guard hotKey == nil else { return true }
    var pressed = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    let installed = InstallEventHandler(
      GetApplicationEventTarget(),
      { _, event, context in
        guard let event, let context else { return OSStatus(eventNotHandledErr) }
        var id = EventHotKeyID()
        GetEventParameter(
          event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
          MemoryLayout<EventHotKeyID>.size, nil, &id)
        guard id.signature == InkHotKey.signature else { return OSStatus(eventNotHandledErr) }
        let me = Unmanaged<InkHotKey>.fromOpaque(context).takeUnretainedValue()
        DispatchQueue.main.async { me.onPress() }
        return noErr
      }, 1, &pressed, Unmanaged.passUnretained(self).toOpaque(), &handler)
    guard installed == noErr else { return false }
    let id = EventHotKeyID(signature: InkHotKey.signature, id: 1)
    let status = RegisterEventHotKey(
      keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKey)
    if status != noErr { unregister() }
    return status == noErr
  }

  func unregister() {
    if let hotKey { UnregisterEventHotKey(hotKey) }
    if let handler { RemoveEventHandler(handler) }
    hotKey = nil
    handler = nil
  }
}
