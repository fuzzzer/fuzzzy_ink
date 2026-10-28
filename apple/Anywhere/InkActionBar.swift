import SwiftUI

/// The step's actions, in one glass group: the main button keeps its glass
/// id from step to step, so Unlock becomes Lock and Lock becomes Open by
/// morphing (iOS 26 / macOS 26), not by swapping. Return presses the main
/// button where that cannot slip: Lock only after the person picked the
/// name, Open only once armed. Esc closes.
@available(iOS 15.0, macOS 12.0, *)
struct InkActionBar: View {
  @ObservedObject var model: InkAnywhereModel
  let glass: Namespace.ID

  private enum GlassID: String, Sendable { case primary, secondary }

  var body: some View {
    HStack(spacing: 10) {
      Spacer(minLength: 0)
      if let secondary {
        Button(action: secondary.action) {
          Label(secondary.title, systemImage: secondary.symbol)
            .frame(minHeight: 22)
        }
        .inkSecondaryButton()
        .controlSize(.large)
        .inkGlassID(GlassID.secondary, in: glass)
      }
      if let primary {
        Button(action: primary.action) {
          Label(primary.title, systemImage: primary.symbol)
            .frame(minWidth: 72, minHeight: 22)
        }
        .inkProminentButton()
        .controlSize(.large)
        .modifier(DefaultAction(isOn: primary.isDefault))
        .disabled(!primary.isEnabled)
        .inkGlassID(GlassID.primary, in: glass)
      }
    }
    .inkGlassGroup(spacing: 12)
  }

  private struct Action {
    let title: String
    let symbol: String
    var isEnabled = true
    /// Return presses it.
    var isDefault = true
    let action: () -> Void
  }

  private struct DefaultAction: ViewModifier {
    let isOn: Bool

    func body(content: Content) -> some View {
      if isOn {
        content.keyboardShortcut(.defaultAction)
      } else {
        content
      }
    }
  }

  private var strings: InkText { model.strings }

  private func run(_ work: @escaping () async -> Void) -> () -> Void {
    { Task { await work() } }
  }

  private var primary: Action? {
    switch model.step {
    case .locked:
      return Action(
        title: strings.unlock, symbol: "lock.open.fill",
        isEnabled: !model.password.isEmpty && !isWaiting,
        action: run(model.unlockWithPassword))
    case .choosing:
      return Action(
        title: strings.lock, symbol: "lock.fill", isEnabled: model.canLock,
        isDefault: model.returnLocks, action: run(model.lock))
    case .pasting:
      // Check only: whose it is. It spends nothing, so it is not "Open".
      return Action(
        title: strings.check, symbol: "magnifyingglass",
        isEnabled: !model.lockedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        action: run { await model.takeLockedText(model.lockedText) })
    case .confirming:
      return Action(
        title: strings.open, symbol: "lock.open.fill", isEnabled: model.isOpenArmed,
        action: run(model.open))
    case .lockedFor, .shown:
      return Action(title: strings.close, symbol: "checkmark", action: finish)
    default:
      return nil
    }
  }

  private var secondary: Action? {
    switch model.step {
    case .locked where model.canUseBiometrics:
      return Action(
        title: biometricTitle, symbol: biometricSymbol, action: run(model.unlockWithBiometrics))
    case .unavailable:
      return Action(title: strings.openApp, symbol: "arrow.up.forward.app", action: openApp)
    case .lockedFor(_, .shareable), .lockedFor(_, .copied):
      #if os(iOS)
        return Action(title: strings.share, symbol: "square.and.arrow.up", action: share)
      #else
        return nil
      #endif
    case .notForAPerson:
      return Action(
        title: strings.openInApp, symbol: "arrow.up.forward.app", action: run(model.openInApp))
    case .problem:
      return Action(
        title: strings.tryAgain, symbol: "arrow.counterclockwise", action: model.startOver)
    default:
      return nil
    }
  }

  private var isWaiting: Bool {
    guard let until = model.waitUntil else { return false }
    return until > Date()
  }

  private var biometricTitle: String {
    model.biometryType == .faceID ? strings.useFaceID : strings.useTouchID
  }

  private var biometricSymbol: String {
    model.biometryType == .faceID ? "faceid" : "touchid"
  }

  private func finish() { model.host?.finish() }

  private func openApp() {
    model.host?.bringAppForward()
    model.host?.finish()
  }

  private func share() {
    if let sealed = model.sealedOutput { model.host?.share(sealed) }
  }
}
