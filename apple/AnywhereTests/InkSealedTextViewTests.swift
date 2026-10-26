import AppKit
import XCTest

/// The Mac message box: what the person types there leaves only through
/// Lock (security review 2026-10-26).
@MainActor
final class InkSealedTextViewTests: XCTestCase {
  private func box(_ text: String = "meet me at the bridge at six") -> InkSealedNSTextView {
    let view = InkSealedNSTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 80))
    view.string = text
    view.selectAll(nil)
    return view
  }

  func testTheMenuIsPasteOnly() throws {
    let view = box()
    let click = try XCTUnwrap(
      NSEvent.mouseEvent(
        with: .rightMouseDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
        context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
    let menu = try XCTUnwrap(view.menu(for: click))
    XCTAssertEqual(menu.items.map(\.action), [#selector(NSText.paste(_:))])
    XCTAssertFalse(menu.allowsContextMenuPlugIns)
  }

  func testNothingLeavesThroughAPasteboardOrAService() {
    let view = box()
    let pasteboard = NSPasteboard.withUniqueName()
    defer { pasteboard.releaseGlobally() }
    XCTAssertFalse(view.writeSelection(to: pasteboard, types: [.string]))
    XCTAssertFalse(view.writeSelection(to: pasteboard, type: .string))
    XCTAssertTrue(view.writablePasteboardTypes.isEmpty)
    XCTAssertNil(view.validRequestor(forSendType: .string, returnType: nil))
    XCTAssertNil(view.validRequestor(forSendType: .string, returnType: .string))

    let general = NSPasteboard.general.changeCount
    view.copy(nil)
    view.cut(nil)
    XCTAssertEqual(NSPasteboard.general.changeCount, general, "Copy and Cut write nothing")
    XCTAssertEqual(view.string, "meet me at the bridge at six", "Cut removes nothing")

    let copyItem = NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    XCTAssertFalse(view.validateUserInterfaceItem(copyItem))
  }

  func testNoSpellingCorrectionPredictionOrWritingTools() {
    let view = box()
    XCTAssertFalse(view.isRichText)
    XCTAssertFalse(view.isContinuousSpellCheckingEnabled)
    XCTAssertFalse(view.isAutomaticSpellingCorrectionEnabled)
    XCTAssertFalse(view.isAutomaticTextReplacementEnabled)
    XCTAssertFalse(view.isAutomaticTextCompletionEnabled)
    if #available(macOS 14.0, *) { XCTAssertEqual(view.inlinePredictionType, .no) }
    if #available(macOS 15.0, *) { XCTAssertEqual(view.writingToolsBehavior, .none) }
  }

  func testTheEndIsSeenOnlyWhenNothingIsLeftBelow() {
    XCTAssertTrue(InkSealedText.isAtEnd(visibleMaxY: 80, visibleHeight: 80, contentHeight: 60))
    XCTAssertFalse(InkSealedText.isAtEnd(visibleMaxY: 170, visibleHeight: 170, contentHeight: 900))
    XCTAssertTrue(InkSealedText.isAtEnd(visibleMaxY: 900, visibleHeight: 170, contentHeight: 900))
    XCTAssertFalse(
      InkSealedText.isAtEnd(visibleMaxY: 0, visibleHeight: 0, contentHeight: 0),
      "not laid out yet is not seen")
  }
}
