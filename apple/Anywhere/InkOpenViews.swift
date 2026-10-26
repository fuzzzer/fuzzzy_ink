import SwiftUI

/// Open: the person brings the locked text. The system Paste button reads
/// the clipboard only on that press (no "Allow Paste" question, nothing read
/// before); the box takes a paste or a drop too. Nothing opens until Open.
@available(iOS 15.0, macOS 12.0, *)
struct InkPasteView: View {
  @ObservedObject var model: InkAnywhereModel

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(model.strings.pasteHint).font(.subheadline.weight(.semibold)).foregroundColor(.secondary)
      HStack(spacing: 10) {
        TextField(model.strings.paste, text: $model.lockedText)
          .textFieldStyle(.roundedBorder)
          .disableAutocorrection(true)
          .onSubmit { Task { await model.takeLockedText(model.lockedText) } }
          .accessibilityLabel(model.strings.pasteHint)
        if #available(iOS 16.0, macOS 13.0, *) {
          PasteButton(payloadType: String.self) { strings in
            guard let text = strings.first else { return }
            Task { @MainActor in await model.takeLockedText(text) }
          }
          .labelStyle(.iconOnly)
        }
      }
    }
  }
}

/// "Open the message from Nino?" Open spends it: it opens once, here.
@available(iOS 15.0, macOS 12.0, *)
struct InkConfirmOpenView: View {
  let name: String
  let strings: InkText

  var body: some View {
    Label {
      Text(strings.openFrom(name)).font(.headline)
    } icon: {
      Image(systemName: "envelope.fill").foregroundColor(InkMark.red)
    }
  }
}

/// The message is open on Fuzzzy Ink's own private screen now.
@available(iOS 15.0, macOS 12.0, *)
struct InkShownView: View {
  let name: String
  let strings: InkText
  let successes: Int
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "lock.open.fill")
        .font(.largeTitle)
        .foregroundColor(InkMark.red)
        .inkBounce(value: successes, reduceMotion: reduceMotion)
      VStack(alignment: .leading, spacing: 4) {
        Text(strings.shownInApp).font(.headline)
        Text(strings.inHistory(name)).font(.callout).foregroundColor(.secondary)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

/// A message that did not open, in the app's Open wording.
@available(iOS 15.0, macOS 12.0, *)
struct InkProblemView: View {
  let text: (title: String, line: String)

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "exclamationmark.triangle.fill").font(.title2).foregroundColor(.orange)
      VStack(alignment: .leading, spacing: 4) {
        Text(text.title).font(.headline)
        Text(text.line).font(.callout).foregroundColor(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .accessibilityElement(children: .combine)
  }
}
