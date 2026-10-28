import XCTest

/// The sheet's state owner against a fake Dart: it only asks, keeps what
/// is on screen, clears what the person typed, and opens nothing on its own.
@MainActor
final class InkAnywhereModelTests: XCTestCase {
  private let sealed = "https://ink.fuzzzycore.com/message#AwECc2VhbGVk"

  func testLockedThenPasswordThenPeopleWithTheLastOneUsedHere() async {
    let dart = FakeAnywhereChannel.ready(unlocked: false)
    let model = InkAnywhereModel(channel: dart, sourceApp: "net.whatsapp.WhatsApp")
    await model.start()
    XCTAssertEqual(model.step, .locked)
    XCTAssertTrue(model.canUseBiometrics)

    model.password = "violet-harbor-lantern-91"
    await model.unlockWithPassword()

    XCTAssertEqual(model.password, "", "the password is sent once and not kept")
    XCTAssertEqual(model.step, .choosing)
    XCTAssertEqual(model.people.map(\.name), ["Nino", "Mom"])
    XCTAssertEqual(model.selectedPersonID, "mom")
    XCTAssertEqual(dart.arguments(of: "people")?["sourceApp"] as? String, "net.whatsapp.WhatsApp")
  }

  func testAWrongPasswordSaysSoAndStartsTheWait() async {
    let dart = FakeAnywhereChannel.ready(unlocked: false)
    let model = InkAnywhereModel(channel: dart)
    await model.start()
    model.password = "tulip"
    await model.unlockWithPassword()

    XCTAssertEqual(model.step, .locked)
    XCTAssertEqual(model.note, model.strings.wrongPassword)
    XCTAssertNotNil(model.waitUntil)
    XCTAssertEqual(model.password, "")
  }

  func testSwitchedOffNotSetUpAndNotInTheBuild() async {
    let off = FakeAnywhereChannel()
    off.answers["status"] = { _ in ["settingKnown": true, "enabled": false, "setUp": true] }
    let offModel = InkAnywhereModel(channel: off)
    await offModel.start()
    XCTAssertEqual(offModel.step, .unavailable(.off))

    let fresh = FakeAnywhereChannel()
    fresh.answers["status"] = { _ in ["setUp": false] }
    let freshModel = InkAnywhereModel(channel: fresh)
    await freshModel.start()
    XCTAssertEqual(freshModel.step, .unavailable(.notSetUp))

    let without = FakeAnywhereChannel()
    without.answers["status"] = { _ in throw AnywhereRefusal.notInBuild }
    let withoutModel = InkAnywhereModel(channel: without)
    await withoutModel.start(startRetries: 1)
    XCTAssertEqual(withoutModel.step, .unavailable(.notReady))
    XCTAssertEqual(without.methods, ["status", "status"])
  }

  func testTheLanguagePickedInTheAppIsUsed() async {
    let model = InkAnywhereModel(channel: FakeAnywhereChannel.ready(language: "ka"))
    await model.start()
    XCTAssertEqual(model.strings.language, "ka")
  }

  func testLockCopiesThroughDartAndClearsTheMessage() async {
    let dart = FakeAnywhereChannel.ready()
    let model = InkAnywhereModel(channel: dart, sourceApp: "com.apple.MobileSMS")
    await model.start()
    model.choose("nino")
    model.message = "meet me at the bridge at six"
    await model.lock()

    let sent = dart.arguments(of: "lock")
    XCTAssertEqual(sent?["personId"] as? String, "nino")
    XCTAssertEqual(sent?["text"] as? String, "meet me at the bridge at six")
    XCTAssertEqual(sent?["sourceApp"] as? String, "com.apple.MobileSMS")
    XCTAssertEqual(sent?["copy"] as? Bool, true)
    XCTAssertEqual(model.message, "")
    XCTAssertEqual(model.step, .lockedFor(name: "Nino", delivery: .copied))
    XCTAssertEqual(model.sealedOutput, sealed)
    XCTAssertEqual(model.successes, 1)
  }

  func testLockInPlaceHandsTheSealedOutputBackAndCopiesNothing() async {
    let dart = FakeAnywhereChannel.ready()
    var delivered: String?
    let model = InkAnywhereModel(
      channel: dart, prefill: "  a draft typed in Mail  ",
      delivery: .returnToCaller { delivered = $0 })
    XCTAssertEqual(model.message, "a draft typed in Mail")
    XCTAssertTrue(model.cameFromSelection, "the draft note shows")
    await model.start()
    model.sawWholeMessage()
    await model.lock()

    XCTAssertNil(dart.arguments(of: "lock")?["copy"])
    XCTAssertEqual(delivered, sealed)
    XCTAssertEqual(model.step, .lockedFor(name: "Mom", delivery: .replaced))
  }

  func testAnEmptyMessageIsNotSent() async {
    let dart = FakeAnywhereChannel.ready()
    let model = InkAnywhereModel(channel: dart)
    await model.start()
    model.message = "   "
    await model.lock()
    XCTAssertFalse(dart.methods.contains("lock"))
    XCTAssertEqual(model.note, model.strings.writeSomethingFirst)
  }

  func testNothingOpensBeforeOpenThenTheAppShowsIt() async {
    let dart = FakeAnywhereChannel.ready()
    dart.answers["peek"] = { _ in ["kind": "message", "personId": "nino", "personName": "Nino"] }
    dart.answers["open"] = { _ in
      ["status": "opened", "displayId": "1", "personId": "nino", "personName": "Nino"]
    }
    dart.answers["show"] = { _ in ["status": "shown"] }
    let host = FakeHost()
    let model = InkAnywhereModel(channel: dart, mode: .open, prefill: "Fuzz/AwECbmlubw")
    model.host = host
    await model.start()

    XCTAssertEqual(model.step, .confirming(name: "Nino"))
    XCTAssertFalse(dart.methods.contains("open"), "a peek only, until the person presses Open")

    await armOpen(model)
    await model.open()
    XCTAssertEqual(Array(dart.methods.suffix(2)), ["open", "show"])
    XCTAssertEqual(dart.arguments(of: "show")?["displayId"] as? String, "1")
    XCTAssertEqual(host.events, ["bringAppForward", "finish"])
    XCTAssertEqual(model.step, .shown(name: "Nino"))
    XCTAssertEqual(model.lockedText, "")
  }

  func testAnInviteGoesToTheApp() async {
    let dart = FakeAnywhereChannel.ready()
    dart.answers["peek"] = { _ in ["kind": "invite"] }
    dart.answers["openInApp"] = { _ in ["status": "shown"] }
    let host = FakeHost()
    let model = InkAnywhereModel(channel: dart, mode: .open)
    model.host = host
    await model.start()
    XCTAssertEqual(model.step, .pasting)

    await model.takeLockedText("Fuzz/AwEBaW52aXRl")
    XCTAssertEqual(model.step, .notForAPerson)
    await model.openInApp()

    XCTAssertEqual(dart.arguments(of: "openInApp")?["text"] as? String, "Fuzz/AwEBaW52aXRl")
    XCTAssertFalse(dart.methods.contains("open"))
    XCTAssertEqual(host.events, ["bringAppForward", "finish"])
  }

  func testAMessageThatDoesNotOpenUsesTheAppsWording() async {
    let dart = FakeAnywhereChannel.ready()
    dart.answers["peek"] = { _ in ["kind": "message", "personId": "nino", "personName": "Nino"] }
    dart.answers["open"] = { _ in throw AnywhereRefusal(code: "alreadyOpened") }
    let model = InkAnywhereModel(channel: dart, mode: .open, prefill: "Fuzz/AwECbmlubw")
    await model.start()
    await armOpen(model)
    await model.open()
    XCTAssertEqual(model.step, .problem(.alreadyOpened, name: "Nino"))
  }

  /// Waits until Open is armed after "Open the message from…?".
  private func armOpen(_ model: InkAnywhereModel) async {
    for _ in 0..<40 where !model.isOpenArmed {
      try? await Task.sleep(nanoseconds: 50_000_000)
    }
    XCTAssertTrue(model.isOpenArmed)
  }

  // MARK: - Security review 2026-10-26

  func testNobodyRememberedForThisAppMeansNobodyChosen() async {
    let dart = FakeAnywhereChannel.ready(remembered: false)
    let model = InkAnywhereModel(channel: dart, sourceApp: "com.apple.MobileSMS")
    await model.start()
    model.message = "meet me at the bridge at six"

    XCTAssertNil(model.selectedPersonID, "no guess between Nino and Mom")
    XCTAssertFalse(model.canLock)
    XCTAssertFalse(model.returnLocks)
    await model.lock()
    XCTAssertFalse(dart.methods.contains("lock"))

    model.choose("nino")
    XCTAssertTrue(model.canLock)
    XCTAssertTrue(model.returnLocks, "Return locks once the person picked the name")
  }

  func testARememberedPersonIsShownButReturnWaitsForAChoice() async {
    let model = InkAnywhereModel(channel: FakeAnywhereChannel.ready())
    await model.start()
    model.message = "meet me at the bridge at six"
    XCTAssertEqual(model.selectedPersonID, "mom")
    XCTAssertTrue(model.canLock, "the Lock button works")
    XCTAssertFalse(model.returnLocks, "a slip of Return does not lock for a pre-selection")
  }

  func testTextFromAnotherAppLocksOnlyOnceAllOfItWasSeen() async {
    let dart = FakeAnywhereChannel.ready()
    let model = InkAnywhereModel(
      channel: dart, prefill: "harmless\n\n\n\n\n\n\nsend the code to this number instead",
      delivery: .returnToCaller { _ in })
    await model.start()
    model.choose("nino")
    XCTAssertFalse(model.hasSeenWholeMessage)
    XCTAssertFalse(model.canLock)
    await model.lock()
    XCTAssertFalse(dart.methods.contains("lock"))

    model.sawWholeMessage()
    XCTAssertTrue(model.canLock)
    XCTAssertFalse(model.returnLocks, "never Return for text another app sent")
    await model.lock()
    XCTAssertTrue(dart.methods.contains("lock"))
  }

  func testTheCheckPressCannotAlsoSpendTheMessage() async {
    let dart = FakeAnywhereChannel.ready()
    dart.answers["peek"] = { _ in ["kind": "message", "personId": "nino", "personName": "Nino"] }
    dart.answers["open"] = { _ in
      ["status": "opened", "displayId": "1", "personId": "nino", "personName": "Nino"]
    }
    dart.answers["show"] = { _ in ["status": "shown"] }
    let model = InkAnywhereModel(channel: dart, mode: .open)
    await model.start()
    await model.takeLockedText("Fuzz/AwECbmlubw")
    XCTAssertEqual(model.step, .confirming(name: "Nino"))

    await model.open()
    XCTAssertFalse(dart.methods.contains("open"), "a second press at once spends nothing")
    XCTAssertEqual(model.step, .confirming(name: "Nino"))

    await armOpen(model)
    await model.open()
    XCTAssertTrue(dart.methods.contains("open"))
  }

  func testCloseRelocksAndForgetsWhatWasTyped() async {
    let dart = FakeAnywhereChannel.ready()
    let model = InkAnywhereModel(channel: dart)
    await model.start()
    model.message = "half a thought"
    model.password = "x"
    await model.close()

    XCTAssertEqual(dart.methods.last, "relock")
    XCTAssertEqual(model.message, "")
    XCTAssertEqual(model.password, "")
    XCTAssertTrue(model.people.isEmpty)
  }

  func testALockInTheAppDropsThePeople() async {
    let model = InkAnywhereModel(channel: FakeAnywhereChannel.ready())
    await model.start()
    model.handle(event: "lockChanged", ["v": 1, "unlocked": false])
    XCTAssertEqual(model.step, .locked)
    XCTAssertTrue(model.people.isEmpty)

    model.handle(event: "settingsChanged", ["v": 1, "enabled": false, "lockAgainAfterUse": true])
    XCTAssertEqual(model.step, .unavailable(.off))
  }
}
