#if DEBUG
  import SwiftUI

  /// A channel that answers nothing, for previews.
  @available(iOS 15.0, macOS 12.0, *)
  @MainActor
  final class InkPreviewChannel: AnywhereCalling {
    func call(_ method: String, _ arguments: [String: Any]) async throws -> [String: Any] {
      throw AnywhereRefusal(code: "failed")
    }
  }

  @available(iOS 15.0, macOS 12.0, *)
  @MainActor
  enum InkPreview {
    static let people = [
      AnywherePerson(id: "1", name: "Nino", isChecked: false, isLastUsedHere: true),
      AnywherePerson(id: "2", name: "Mom", isChecked: true),
      AnywherePerson(id: "3", name: "Giorgi", isChecked: true),
    ]

    static func model(
      _ step: AnywhereStep, mode: AnywhereMode = .lock, message: String = "",
      note: String? = nil, people: [AnywherePerson]? = nil
    ) -> InkAnywhereModel {
      let model = InkAnywhereModel(channel: InkPreviewChannel(), mode: mode, biometryType: .touchID)
      model.message = message
      model.preview(step, people: people ?? InkPreview.people, note: note)
      return model
    }

    static func panel(_ model: InkAnywhereModel) -> some View {
      #if os(macOS)
        return InkAnywhereView(model: model, drawsSurface: true).frame(width: 400).padding(30)
      #else
        return InkAnywhereView(model: model)
      #endif
    }
  }

  #Preview("Locked") {
    if #available(iOS 15.0, macOS 12.0, *) {
      InkPreview.panel(InkPreview.model(.locked))
    }
  }

  #Preview("Locked, wrong password") {
    if #available(iOS 15.0, macOS 12.0, *) {
      InkPreview.panel(InkPreview.model(.locked, note: InkText().wrongPassword))
    }
  }

  #Preview("Unlocking") {
    if #available(iOS 15.0, macOS 12.0, *) {
      InkPreview.panel(InkPreview.model(.unlocking))
    }
  }

  #Preview("Choosing") {
    if #available(iOS 15.0, macOS 12.0, *) {
      InkPreview.panel(InkPreview.model(.choosing, message: "See you at six by the bridge"))
    }
  }

  #Preview("Choosing, nobody yet") {
    if #available(iOS 15.0, macOS 12.0, *) {
      InkPreview.panel(InkPreview.model(.choosing, people: []))
    }
  }

  #Preview("Locking") {
    if #available(iOS 15.0, macOS 12.0, *) {
      InkPreview.panel(InkPreview.model(.locking))
    }
  }

  #Preview("Done, copied") {
    if #available(iOS 15.0, macOS 12.0, *) {
      InkPreview.panel(InkPreview.model(.lockedFor(name: "Nino", delivery: .copied)))
    }
  }

  #Preview("Open, confirm") {
    if #available(iOS 15.0, macOS 12.0, *) {
      InkPreview.panel(InkPreview.model(.confirming(name: "Nino"), mode: .open))
    }
  }

  #Preview("Open, not for a person") {
    if #available(iOS 15.0, macOS 12.0, *) {
      InkPreview.panel(InkPreview.model(.notForAPerson, mode: .open))
    }
  }

  #Preview("Error") {
    if #available(iOS 15.0, macOS 12.0, *) {
      InkPreview.panel(InkPreview.model(.problem(.alreadyOpened, name: "Nino"), mode: .open))
    }
  }

  #Preview("Switched off") {
    if #available(iOS 15.0, macOS 12.0, *) {
      InkPreview.panel(InkPreview.model(.unavailable(.off)))
    }
  }
#endif
