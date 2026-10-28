import SwiftUI

/// Liquid Glass on iOS 26 and macOS 26, the system materials and bordered
/// buttons before that. Every 26-only call sits here, behind `#available`.
@available(iOS 15.0, macOS 12.0, *)
extension View {
  /// The main action: Lock, Open, Unlock.
  @ViewBuilder func inkProminentButton() -> some View {
    if #available(iOS 26.0, macOS 26.0, *) {
      buttonStyle(.glassProminent)
    } else {
      buttonStyle(.borderedProminent)
    }
  }

  /// Secondary actions: Paste, Share, Open in Fuzzzy Ink, Try again.
  @ViewBuilder func inkSecondaryButton() -> some View {
    if #available(iOS 26.0, macOS 26.0, *) {
      buttonStyle(.glass)
    } else {
      buttonStyle(.bordered)
    }
  }

  /// A round icon button (close).
  @ViewBuilder func inkRoundButton() -> some View {
    if #available(iOS 17.0, macOS 14.0, *) {
      buttonBorderShape(.circle)
    } else {
      self
    }
  }

  /// A floating chip (a person): interactive glass in a capsule; a soft fill
  /// when transparency is reduced or before 26.
  @ViewBuilder func inkChip(isSelected: Bool, reduceTransparency: Bool) -> some View {
    if #available(iOS 26.0, macOS 26.0, *), !reduceTransparency {
      glassEffect(
        isSelected ? .regular.tint(InkMark.red.opacity(0.55)).interactive() : .regular.interactive(),
        in: .capsule)
    } else {
      background(
        Capsule().fill(isSelected ? InkMark.red.opacity(0.25) : Color.secondary.opacity(0.12)))
    }
  }

  /// The panel's own surface on a Mac (an iPhone sheet keeps the system's).
  @ViewBuilder func inkPanelSurface(cornerRadius: CGFloat, reduceTransparency: Bool) -> some View {
    if reduceTransparency {
      background(
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(InkGlass.solidGround))
    } else if #available(iOS 26.0, macOS 26.0, *) {
      glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
    } else {
      background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
  }

  /// Several glass shapes that blend and morph together (26), or as they are.
  @ViewBuilder func inkGlassGroup(spacing: CGFloat) -> some View {
    if #available(iOS 26.0, macOS 26.0, *) {
      GlassEffectContainer(spacing: spacing) { self }
    } else {
      self
    }
  }

  /// Ties a glass shape to [id] so it morphs into the next one with the
  /// same id (26 only; nothing before).
  @ViewBuilder func inkGlassID<ID: Hashable & Sendable>(_ id: ID, in namespace: Namespace.ID)
    -> some View
  {
    if #available(iOS 26.0, macOS 26.0, *) {
      glassEffectID(id, in: namespace)
    } else {
      self
    }
  }

  /// A success tap: `.sensoryFeedback` where there is one (the Mac's
  /// trackpad, the iPhone's taptic engine).
  @ViewBuilder func inkSuccessFeedback<T: Equatable>(trigger: T) -> some View {
    if #available(iOS 17.0, macOS 14.0, *) {
      sensoryFeedback(.success, trigger: trigger)
    } else {
      self
    }
  }

  /// A symbol that bounces each time [value] changes, unless motion is
  /// reduced.
  @ViewBuilder func inkBounce<T: Equatable>(value: T, reduceMotion: Bool) -> some View {
    if #available(iOS 17.0, macOS 14.0, *), !reduceMotion {
      symbolEffect(.bounce, value: value)
    } else {
      self
    }
  }
}

@available(iOS 15.0, macOS 12.0, *)
enum InkGlass {
  #if os(macOS)
    static let solidGround = Color(nsColor: .windowBackgroundColor)
  #else
    static let solidGround = Color(uiColor: .systemBackground)
  #endif

  /// The springs every change of step uses (none when motion is reduced).
  static func spring(reduceMotion: Bool) -> Animation? {
    reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.86)
  }
}
