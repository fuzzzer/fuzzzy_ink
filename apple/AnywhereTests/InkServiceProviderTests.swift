import AppKit
import XCTest

/// The Mac Services provider on a private pasteboard: Lock replaces the
/// selection with sealed output only, after the panel's own Lock; a closed
/// panel writes nothing; Open never writes anything back.
@MainActor
final class InkServiceProviderTests: XCTestCase {
  private var pasteboard: NSPasteboard!

  override func setUp() async throws {
    pasteboard = NSPasteboard.withUniqueName()
  }

  override func tearDown() async throws {
    pasteboard.releaseGlobally()
  }

  private func provider(
    dart: FakeAnywhereChannel, onPresent: @escaping (InkAnywhereModel, @escaping () -> Void) -> Void
  ) -> InkServiceProvider {
    InkServiceProvider(
      makeModel: { mode, text, delivery in
        InkAnywhereModel(channel: dart, mode: mode, prefill: text, delivery: delivery)
      },
      present: onPresent)
  }

  func testLockReplacesTheSelectionWithTheSealedOutput() {
    pasteboard.clearContents()
    pasteboard.setString("meet me at the bridge at six", forType: .string)
    let dart = FakeAnywhereChannel.ready()
    var shown: InkAnywhereModel?
    // The person's part, while the provider waits in its run loop.
    let provider = provider(dart: dart) { model, _ in
      shown = model
      Task { @MainActor in
        await model.start()
        model.selectedPersonID = "nino"
        await model.lock()
      }
    }

    let refusal = provider.lockInPlace(pasteboard)

    XCTAssertNil(refusal)
    XCTAssertEqual(shown?.mode, .lock)
    XCTAssertEqual(dart.arguments(of: "lock")?["text"] as? String, "meet me at the bridge at six")
    XCTAssertEqual(
      pasteboard.string(forType: .string), "https://ink.fuzzzycore.com/message#AwECc2VhbGVk")
  }

  func testAClosedPanelLeavesTheSelectionAsItWas() {
    pasteboard.clearContents()
    pasteboard.setString("not now", forType: .string)
    let provider = provider(dart: FakeAnywhereChannel.ready()) { _, closed in
      DispatchQueue.main.async { closed() }
    }

    XCTAssertEqual(provider.lockInPlace(pasteboard), "Nothing was locked.")
    XCTAssertEqual(pasteboard.string(forType: .string), "not now")
  }

  func testNoSelectionNoPanel() {
    pasteboard.clearContents()
    var presented = false
    let provider = provider(dart: FakeAnywhereChannel.ready()) { _, _ in presented = true }
    XCTAssertEqual(provider.lockInPlace(pasteboard), "No text was selected.")
    XCTAssertFalse(presented)
  }

  func testATimedOutPanelWritesNothing() {
    pasteboard.clearContents()
    pasteboard.setString("slow", forType: .string)
    let provider = provider(dart: FakeAnywhereChannel.ready()) { _, _ in }
    provider.timeout = 0.2
    XCTAssertEqual(provider.lockInPlace(pasteboard), "Nothing was locked.")
    XCTAssertEqual(pasteboard.string(forType: .string), "slow")
  }

  func testOpenShowsThePanelAndWritesNothingBack() {
    pasteboard.clearContents()
    pasteboard.setString("Fuzz/AwECbmlubw", forType: .string)
    let changeCount = pasteboard.changeCount
    var shown: InkAnywhereModel?
    let provider = provider(dart: FakeAnywhereChannel.ready()) { model, _ in shown = model }
    var error: NSString?
    provider.openText(pasteboard, userData: nil, error: &error)

    XCTAssertNil(error)
    XCTAssertEqual(shown?.mode, .open)
    XCTAssertEqual(shown?.lockedText, "Fuzz/AwECbmlubw")
    XCTAssertEqual(pasteboard.changeCount, changeCount)
  }
}
