#if os(macOS)
  import AppKit
  import SwiftUI

  /// [InkSealedTextBox] on the Mac: an [InkSealedNSTextView] in a scroll view.
  @available(macOS 12.0, *)
  struct InkSealedTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var contentHeight: CGFloat
    let accessibilityLabel: String
    let onReturn: () -> Bool
    let onSeenToTheEnd: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
      let textView = InkSealedNSTextView(frame: .zero)
      textView.delegate = context.coordinator
      textView.string = text
      textView.setAccessibilityLabel(accessibilityLabel)
      let scroll = NSScrollView()
      scroll.drawsBackground = false
      scroll.borderType = .noBorder
      scroll.hasVerticalScroller = true
      scroll.autohidesScrollers = true
      scroll.documentView = textView
      scroll.contentView.postsBoundsChangedNotifications = true
      NotificationCenter.default.addObserver(
        context.coordinator, selector: #selector(Coordinator.scrolled(_:)),
        name: NSView.boundsDidChangeNotification, object: scroll.contentView)
      context.coordinator.scroll = scroll
      return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
      context.coordinator.parent = self
      guard let textView = scroll.documentView as? InkSealedNSTextView else { return }
      if textView.string != text { textView.string = text }
      context.coordinator.measure()
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
      var parent: InkSealedTextView
      weak var scroll: NSScrollView?
      private var hasReportedEnd = false

      init(_ parent: InkSealedTextView) { self.parent = parent }

      func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        parent.text = textView.string
        measure()
      }

      /// Return locks when the panel says so; Option-Return is always a new line.
      func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        selector == #selector(NSResponder.insertNewline(_:)) && parent.onReturn()
      }

      @objc func scrolled(_ notification: Notification) { checkEnd() }

      /// The text's height for the box, after layout; then whether all of it is in view.
      func measure() {
        guard let textView = scroll?.documentView as? NSTextView,
          let container = textView.textContainer, let layout = textView.layoutManager
        else { return }
        layout.ensureLayout(for: container)
        let height = ceil(layout.usedRect(for: container).height + textView.textContainerInset.height * 2)
        DispatchQueue.main.async { [weak self] in
          guard let self else { return }
          if abs(self.parent.contentHeight - height) > 0.5 { self.parent.contentHeight = height }
          self.checkEnd()
        }
      }

      private func checkEnd() {
        guard !hasReportedEnd, let scroll, scroll.window != nil,
          let textView = scroll.documentView
        else { return }
        let visible = scroll.contentView.bounds
        guard
          InkSealedText.isAtEnd(
            visibleMaxY: visible.maxY, visibleHeight: visible.height,
            contentHeight: textView.frame.height)
        else { return }
        hasReportedEnd = true
        parent.onSeenToTheEnd()
      }
    }
  }

  /// A plain-text view whose words stay in it: its menu is Paste only, it
  /// writes nothing to any pasteboard (Copy, Cut, a drag, a service), gives
  /// no service its text, and has no Look Up, Writing Tools, spelling,
  /// autocorrection, text replacement or inline prediction.
  @available(macOS 12.0, *)
  final class InkSealedNSTextView: NSTextView {
    override init(frame: NSRect) {
      super.init(frame: frame)
      configure()
    }

    override init(frame: NSRect, textContainer: NSTextContainer?) {
      super.init(frame: frame, textContainer: textContainer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not from a nib") }

    private func configure() {
      isRichText = false
      importsGraphics = false
      allowsImageEditing = false
      usesFindBar = false
      allowsUndo = true
      drawsBackground = false
      font = .preferredFont(forTextStyle: .body)
      textColor = .labelColor
      textContainerInset = InkSealedText.inset
      textContainer?.lineFragmentPadding = InkSealedText.linePadding
      isVerticallyResizable = true
      isHorizontallyResizable = false
      autoresizingMask = [.width]
      maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
      textContainer?.widthTracksTextView = true
      isContinuousSpellCheckingEnabled = false
      isGrammarCheckingEnabled = false
      isAutomaticSpellingCorrectionEnabled = false
      isAutomaticTextReplacementEnabled = false
      isAutomaticQuoteSubstitutionEnabled = false
      isAutomaticDashSubstitutionEnabled = false
      isAutomaticDataDetectionEnabled = false
      isAutomaticLinkDetectionEnabled = false
      isAutomaticTextCompletionEnabled = false
      if #available(macOS 14.0, *) { inlinePredictionType = .no }
      if #available(macOS 15.0, *) { writingToolsBehavior = .none }
    }

    /// Straight to the keyboard when the panel shows.
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      guard let window else { return }
      DispatchQueue.main.async { [weak self] in
        guard let self, window.firstResponder === window else { return }
        window.makeFirstResponder(self)
      }
    }

    /// Paste only, under the system's own name for it.
    override func menu(for event: NSEvent) -> NSMenu? {
      let menu = NSMenu()
      menu.allowsContextMenuPlugIns = false
      if #available(macOS 15.2, *) { menu.automaticallyInsertsWritingToolsItems = false }
      let paste =
        super.menu(for: event)?.items.first { $0.action == #selector(paste(_:)) }?.title ?? "Paste"
      menu.addItem(withTitle: paste, action: #selector(paste(_:)), keyEquivalent: "")
      return menu
    }

    override func copy(_ sender: Any?) {}
    override func cut(_ sender: Any?) {}

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
      if InkSealedNSTextView.refused.contains(where: { $0 == item.action }) { return false }
      return super.validateUserInterfaceItem(item)
    }

    private static let refused: [Selector] = [
      #selector(copy(_:)), #selector(cut(_:)),
      #selector(NSTextView.startSpeaking(_:)),
    ]

    /// No service is offered the text (the Services menu, a shortcut).
    override func validRequestor(
      forSendType sendType: NSPasteboard.PasteboardType?,
      returnType: NSPasteboard.PasteboardType?
    ) -> Any? { nil }

    override func writeSelection(to pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
      false
    }

    override func writeSelection(to pboard: NSPasteboard, types: [NSPasteboard.PasteboardType])
      -> Bool
    { false }

    override var writablePasteboardTypes: [NSPasteboard.PasteboardType] { [] }

    override func dragSelection(with event: NSEvent, offset mouseOffset: NSSize, slideBack: Bool)
      -> Bool
    { false }

    /// Force click and Look Up.
    override func quickLook(with event: NSEvent) {}
    override func quickLookPreviewItems(_ sender: Any?) {}
  }
#endif
