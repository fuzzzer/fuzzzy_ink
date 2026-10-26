import SwiftUI

/// A short wait (checking, unlocking, locking, opening).
@available(iOS 15.0, macOS 12.0, *)
struct InkWorkingView: View {
  let label: String?

  var body: some View {
    HStack(spacing: 10) {
      ProgressView().controlSize(.small)
      if let label { Text(label).font(.callout).foregroundColor(.secondary) }
    }
    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

/// One line with a symbol.
@available(iOS 15.0, macOS 12.0, *)
struct InkNoteView: View {
  let symbol: String
  let text: String

  var body: some View {
    Label {
      Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
    } icon: {
      Image(systemName: symbol).foregroundColor(InkMark.red)
    }
  }
}

/// Why it cannot be used now: switched off, not set up, or the app is not
/// ready. The action bar offers to open Fuzzzy Ink.
@available(iOS 15.0, macOS 12.0, *)
struct InkUnavailableView: View {
  let reason: AnywhereStep.Unavailable
  let strings: InkText

  var body: some View {
    switch reason {
    case .off:
      InkNoteView(symbol: "switch.2", text: strings.turnOn)
    case .notSetUp:
      InkNoteView(symbol: "key.fill", text: strings.setUpFirst)
    case .notReady:
      InkNoteView(symbol: "hourglass", text: strings.openApp)
    }
  }
}
