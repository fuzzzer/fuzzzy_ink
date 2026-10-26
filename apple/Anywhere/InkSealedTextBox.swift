import SwiftUI

/// The message box of the Lock sheet and panel: the person's own words,
/// which leave only through Lock (RESEARCH native code rule 6, security
/// review 2026-10-26). SwiftUI's text fields cannot say no to the system's
/// text menu, so this is a small AppKit or UIKit text view
/// ([InkSealedNSTextView], [InkSealedUITextView]):
///
/// - its menu offers Paste only (iPhone: Paste, Select and Select All);
///   Copy, Cut, Services, Look Up, Translate, Share and Writing Tools are
///   gone, the copy shortcuts do nothing and the text cannot be dragged out;
/// - no Services provider is ever given the text;
/// - no spelling, autocorrection, text replacement or inline prediction.
///
/// It grows with the text up to [maxHeight], then scrolls; [onSeenToTheEnd]
/// runs once nothing of the text is left below its edge.
@available(iOS 15.0, macOS 12.0, *)
struct InkSealedTextBox: View {
  @Binding var text: String
  let placeholder: String
  var maxHeight: CGFloat = 170
  /// Return was pressed (Mac): answers whether it was used (the box then
  /// inserts no new line).
  var onReturn: () -> Bool = { false }
  var onSeenToTheEnd: () -> Void = {}

  @State private var contentHeight: CGFloat = 0

  private let minHeight: CGFloat = 64

  var body: some View {
    InkSealedTextView(
      text: $text, contentHeight: $contentHeight, accessibilityLabel: placeholder,
      onReturn: onReturn, onSeenToTheEnd: onSeenToTheEnd
    )
    .frame(height: min(max(contentHeight, minHeight), maxHeight))
    .overlay(alignment: .topLeading) {
      if text.isEmpty {
        Text(placeholder)
          .font(.body)
          .foregroundColor(.secondary)
          .padding(.horizontal, InkSealedText.inset.width + InkSealedText.linePadding)
          .padding(.vertical, InkSealedText.inset.height)
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }
    }
  }
}

/// What the AppKit and UIKit text views share.
@available(iOS 15.0, macOS 12.0, *)
enum InkSealedText {
  static let inset = CGSize(width: 2, height: 6)
  static let linePadding: CGFloat = 5

  /// Nothing is left below the visible part (laid out, and in a window).
  static func isAtEnd(visibleMaxY: CGFloat, visibleHeight: CGFloat, contentHeight: CGFloat) -> Bool {
    visibleHeight > 1 && contentHeight > 0 && visibleMaxY >= contentHeight - 2
  }
}
