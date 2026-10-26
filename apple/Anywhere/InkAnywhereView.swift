import SwiftUI

/// The Lock/Open sheet (iPhone) and panel (Mac): a header, the current
/// step, and one action bar whose glass buttons morph from step to step.
@available(iOS 15.0, macOS 12.0, *)
struct InkAnywhereView: View {
  @ObservedObject var model: InkAnywhereModel
  /// The Mac panel draws its own glass surface; the iPhone sheet keeps the
  /// system's.
  var drawsSurface = false

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Namespace private var glass

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      InkAnywhereHeader(model: model)
      stepView
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(reduceMotion ? .identity : .opacity.combined(with: .scale(scale: 0.98)))
      InkActionBar(model: model, glass: glass)
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .modifier(Surface(isOn: drawsSurface, reduceTransparency: reduceTransparency))
    .animation(InkGlass.spring(reduceMotion: reduceMotion), value: model.step)
    .animation(InkGlass.spring(reduceMotion: reduceMotion), value: model.mode)
    .inkSuccessFeedback(trigger: model.successes)
    .tint(InkMark.red)
  }

  @ViewBuilder private var stepView: some View {
    switch model.step {
    case .checking:
      InkWorkingView(label: nil)
    case .unavailable(let reason):
      InkUnavailableView(reason: reason, strings: model.strings)
    case .locked:
      InkUnlockView(model: model)
    case .unlocking:
      InkWorkingView(label: model.strings.unlock)
    case .choosing:
      InkComposeView(model: model)
    case .locking:
      InkWorkingView(label: model.strings.locking)
    case .lockedFor(let name, let delivery):
      InkLockedView(name: name, delivery: delivery, model: model)
    case .pasting:
      InkPasteView(model: model)
    case .confirming(let name):
      InkConfirmOpenView(name: name, strings: model.strings)
    case .opening:
      InkWorkingView(label: model.strings.opening)
    case .shown(let name):
      InkShownView(name: name, strings: model.strings, successes: model.successes)
    case .notForAPerson:
      InkNoteView(symbol: "envelope.open", text: model.strings.notForAPerson)
    case .problem(let problem, let name):
      InkProblemView(text: model.strings.problem(problem, name: name))
    }
  }

  private struct Surface: ViewModifier {
    let isOn: Bool
    let reduceTransparency: Bool

    func body(content: Content) -> some View {
      if isOn {
        content.inkPanelSurface(cornerRadius: 26, reduceTransparency: reduceTransparency)
      } else {
        content
      }
    }
  }
}

/// The mark, Lock | Open, and close.
@available(iOS 15.0, macOS 12.0, *)
struct InkAnywhereHeader: View {
  @ObservedObject var model: InkAnywhereModel

  var body: some View {
    HStack(spacing: 12) {
      InkMarkView(size: 24)
      Picker("", selection: modeBinding) {
        Label(model.strings.lock, systemImage: "lock.fill").tag(AnywhereMode.lock)
        Label(model.strings.open, systemImage: "lock.open.fill").tag(AnywhereMode.open)
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .fixedSize()
      .disabled(!canSwitch)
      Spacer(minLength: 0)
      Button {
        model.host?.finish()
      } label: {
        Image(systemName: "xmark")
          .font(.body.weight(.semibold))
          .frame(width: 22, height: 22)
      }
      .inkSecondaryButton()
      .inkRoundButton()
      .keyboardShortcut(.cancelAction)
      .accessibilityLabel(model.strings.close)
    }
  }

  private var canSwitch: Bool {
    switch model.step {
    case .checking, .unavailable, .locking, .opening, .unlocking: return false
    default: return true
    }
  }

  private var modeBinding: Binding<AnywhereMode> {
    Binding(
      get: { model.mode },
      set: { mode in Task { await model.switchMode(to: mode) } })
  }
}
