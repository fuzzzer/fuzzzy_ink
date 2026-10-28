#if os(iOS)
  import SwiftUI
  import UIKit

  /// [InkSealedTextBox] on the iPhone: an [InkSealedUITextView]. Return is a
  /// new line here; Lock is the button.
  @available(iOS 15.0, *)
  struct InkSealedTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var contentHeight: CGFloat
    let accessibilityLabel: String
    let onReturn: () -> Bool
    let onSeenToTheEnd: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> InkSealedUITextView {
      let textView = InkSealedUITextView()
      textView.delegate = context.coordinator
      textView.text = text
      textView.accessibilityLabel = accessibilityLabel
      textView.onLayout = { [weak coordinator = context.coordinator] view in
        coordinator?.measure(view)
      }
      return textView
    }

    func updateUIView(_ textView: InkSealedUITextView, context: Context) {
      context.coordinator.parent = self
      if textView.text != text { textView.text = text }
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
      var parent: InkSealedTextView
      private var hasReportedEnd = false

      init(_ parent: InkSealedTextView) { self.parent = parent }

      func textViewDidChange(_ textView: UITextView) {
        parent.text = textView.text
      }

      func scrollViewDidScroll(_ scrollView: UIScrollView) { checkEnd(scrollView) }

      /// The text's height for the box; then whether all of it is in view.
      func measure(_ textView: UITextView) {
        let width = textView.bounds.width
        guard width > 0 else { return }
        let height = ceil(
          textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
        DispatchQueue.main.async { [weak self] in
          guard let self else { return }
          if abs(self.parent.contentHeight - height) > 0.5 { self.parent.contentHeight = height }
          self.checkEnd(textView)
        }
      }

      private func checkEnd(_ scrollView: UIScrollView) {
        guard !hasReportedEnd, scrollView.window != nil else { return }
        let visibleMaxY = scrollView.contentOffset.y + scrollView.bounds.height
        guard
          InkSealedText.isAtEnd(
            visibleMaxY: visibleMaxY, visibleHeight: scrollView.bounds.height,
            contentHeight: scrollView.contentSize.height)
        else { return }
        hasReportedEnd = true
        parent.onSeenToTheEnd()
      }
    }
  }

  /// A plain-text view whose words stay in it: its edit menu has only
  /// Paste, Select and Select All; Copy, Cut, Share, Look Up, Translate,
  /// Writing Tools and the rest are refused, the copy shortcuts do nothing
  /// and the text cannot be dragged out. No autocorrection, spelling, smart
  /// punctuation or inline prediction.
  @available(iOS 15.0, *)
  final class InkSealedUITextView: UITextView {
    var onLayout: ((UITextView) -> Void)?

    init() {
      super.init(frame: .zero, textContainer: nil)
      backgroundColor = .clear
      font = .preferredFont(forTextStyle: .body)
      adjustsFontForContentSizeCategory = true
      textContainerInset = UIEdgeInsets(
        top: InkSealedText.inset.height, left: InkSealedText.inset.width,
        bottom: InkSealedText.inset.height, right: InkSealedText.inset.width)
      textContainer.lineFragmentPadding = InkSealedText.linePadding
      allowsEditingTextAttributes = false
      dataDetectorTypes = []
      autocorrectionType = .no
      spellCheckingType = .no
      smartQuotesType = .no
      smartDashesType = .no
      smartInsertDeleteType = .no
      autocapitalizationType = .sentences
      textDragInteraction?.isEnabled = false
      if #available(iOS 16.0, *) { isFindInteractionEnabled = false }
      if #available(iOS 17.0, *) { inlinePredictionType = .no }
      if #available(iOS 18.0, *) { writingToolsBehavior = .none }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not from a nib") }

    override func layoutSubviews() {
      super.layoutSubviews()
      onLayout?(self)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
      guard InkSealedUITextView.allowed.contains(action) else { return false }
      return super.canPerformAction(action, withSender: sender)
    }

    private static let allowed: Set<Selector> = [
      #selector(UIResponderStandardEditActions.paste(_:)),
      #selector(UIResponderStandardEditActions.select(_:)),
      #selector(UIResponderStandardEditActions.selectAll(_:)),
      #selector(UIResponderStandardEditActions.delete(_:)),
    ]

    override func copy(_ sender: Any?) {}
    override func cut(_ sender: Any?) {}
  }
#endif
