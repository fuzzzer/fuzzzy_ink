import SwiftUI

/// Lock: who it is for, then the message. The chosen person's name and
/// "Not checked yet" mark are always shown before Lock, even when the person
/// was pre-selected for this app.
@available(iOS 15.0, macOS 12.0, *)
struct InkComposeView: View {
  @ObservedObject var model: InkAnywhereModel

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if model.people.isEmpty {
        InkNoteView(symbol: "person.crop.circle.badge.plus", text: model.strings.addPersonFirst)
      } else {
        Text(model.strings.whoFor).font(.subheadline.weight(.semibold)).foregroundColor(.secondary)
        InkPersonPicker(model: model)
        if let person = model.selectedPerson {
          InkPersonRow(person: person, strings: model.strings)
        }
        InkMessageBox(model: model)
      }
      if model.cameFromSelection {
        Label(model.strings.draftNote, systemImage: "info.circle")
          .font(.footnote)
          .foregroundColor(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      if let note = model.note {
        Text(note).font(.callout).foregroundColor(.red)
      }
    }
  }
}

/// The connected people as glass chips; the selected one is tinted.
@available(iOS 15.0, macOS 12.0, *)
struct InkPersonPicker: View {
  @ObservedObject var model: InkAnywhereModel
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(model.people) { person in
          let isSelected = person.id == model.selectedPersonID
          Button {
            model.selectedPersonID = person.id
          } label: {
            Label(person.name, systemImage: isSelected ? "person.crop.circle.fill" : "person.crop.circle")
              .font(.callout.weight(isSelected ? .semibold : .regular))
              .padding(.horizontal, 12)
              .padding(.vertical, 7)
              .contentShape(Capsule())
          }
          .buttonStyle(.plain)
          .inkChip(isSelected: isSelected, reduceTransparency: reduceTransparency)
          .accessibilityLabel(person.isChecked ? person.name : "\(person.name), \(model.strings.notChecked)")
          .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
      }
      .padding(.vertical, 2)
      .inkGlassGroup(spacing: 8)
    }
  }
}

/// "Only Nino can open it, once." with the "Not checked yet" mark.
@available(iOS 15.0, macOS 12.0, *)
struct InkPersonRow: View {
  let person: AnywherePerson
  let strings: InkText

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(strings.onlyOnce(person.name)).font(.callout)
      if !person.isChecked {
        Label(strings.notChecked, systemImage: "exclamationmark.shield")
          .font(.footnote.weight(.medium))
          .foregroundColor(.orange)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

/// The message, typed here (never in the other app). Return locks on a Mac;
/// Option-Return starts a new line.
@available(iOS 15.0, macOS 12.0, *)
struct InkMessageBox: View {
  @ObservedObject var model: InkAnywhereModel

  var body: some View {
    Group {
      if #available(iOS 16.0, macOS 13.0, *) {
        TextField(model.strings.messageHint, text: $model.message, axis: .vertical)
          .lineLimit(3...8)
        #if os(macOS)
          .onSubmit { Task { await model.lock() } }
        #endif
      } else {
        TextEditor(text: $model.message).frame(minHeight: 72, maxHeight: 160)
      }
    }
    .textFieldStyle(.plain)
    .font(.body)
    .disableAutocorrection(true)
    .padding(10)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.secondary.opacity(0.1)))
    .accessibilityLabel(model.strings.messageHint)
  }
}

/// Locked for Nino: copied (press ⌘V), in place, or ready to share.
@available(iOS 15.0, macOS 12.0, *)
struct InkLockedView: View {
  let name: String
  let delivery: AnywhereStep.Delivered
  @ObservedObject var model: InkAnywhereModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "checkmark.circle.fill")
        .font(.largeTitle)
        .foregroundColor(.green)
        .inkBounce(value: model.successes, reduceMotion: reduceMotion)
      VStack(alignment: .leading, spacing: 4) {
        Text(model.strings.lockedFor(name)).font(.headline)
        Text(line).font(.callout).foregroundColor(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .accessibilityElement(children: .combine)
  }

  private var line: String {
    switch delivery {
    case .replaced: return model.strings.replaced
    case .shareable: return model.strings.nowSendIt
    case .copied:
      #if os(macOS)
        return model.strings.copiedPressPaste
      #else
        return model.strings.copied + " " + model.strings.nowSendIt
      #endif
    }
  }
}
