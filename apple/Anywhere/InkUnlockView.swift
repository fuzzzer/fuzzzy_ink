import SwiftUI

/// Fuzzzy Ink is locked: Touch ID or Face ID (the action bar) or the master
/// password. The password goes to Dart once and the field is cleared; the
/// same wrong-password limit as the app's own lock screen applies.
@available(iOS 15.0, macOS 12.0, *)
struct InkUnlockView: View {
  @ObservedObject var model: InkAnywhereModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label {
        Text(model.strings.lockedTitle).font(.headline)
      } icon: {
        Image(systemName: "lock.fill")
          .foregroundColor(InkMark.red)
          .inkBounce(value: model.note, reduceMotion: reduceMotion)
      }
      SecureField(model.strings.masterPassword, text: $model.password)
        .textContentType(.password)
        .textFieldStyle(.roundedBorder)
        .controlSize(.large)
        .disableAutocorrection(true)
        .onSubmit { Task { await model.unlockWithPassword() } }
        .accessibilityLabel(model.strings.masterPassword)
      if let note = model.note {
        Text(note)
          .font(.callout)
          .foregroundColor(.red)
          .fixedSize(horizontal: false, vertical: true)
      }
      if let until = model.waitUntil {
        InkWaitLine(until: until, strings: model.strings)
      }
    }
  }
}

/// "Wait 0:30", counting down to the real end of the wait.
@available(iOS 15.0, macOS 12.0, *)
struct InkWaitLine: View {
  let until: Date
  let strings: InkText

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      let left = max(0, Int(until.timeIntervalSince(context.date).rounded(.up)))
      if left > 0 {
        Text(strings.wait(String(format: "%d:%02d", left / 60, left % 60)))
          .font(.callout.monospacedDigit())
          .foregroundColor(.secondary)
      }
    }
  }
}
