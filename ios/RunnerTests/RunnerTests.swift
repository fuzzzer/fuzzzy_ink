import Flutter
import UIKit
import XCTest

@testable import Runner

class RunnerTests: XCTestCase {

  /// The app switcher never shows the content: inactive always means the
  /// brand cover, on every screen, private or not.
  func testInactiveAlwaysShowsTheBrandCover() {
    for isSecure in [false, true] {
      for isCaptured in [false, true] {
        XCTAssertEqual(
          InkGuard.cover(isInactive: true, isSecure: isSecure, isCaptured: isCaptured), .brand)
      }
    }
  }

  /// A private screen being recorded or mirrored is blurred, as before.
  func testRecordingAPrivateScreenBlursIt() {
    XCTAssertEqual(InkGuard.cover(isInactive: false, isSecure: true, isCaptured: true), .blur)
  }

  func testNoCoverWhileActiveAndNotRecordingAPrivateScreen() {
    XCTAssertNil(InkGuard.cover(isInactive: false, isSecure: false, isCaptured: false))
    XCTAssertNil(InkGuard.cover(isInactive: false, isSecure: false, isCaptured: true))
    XCTAssertNil(InkGuard.cover(isInactive: false, isSecure: true, isCaptured: false))
  }

  func testCoverColourReadsDartsArgb() {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    InkGuard.color(argb: 0xFF12_1417).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    XCTAssertEqual(red, 0x12 / 255, accuracy: 0.001)
    XCTAssertEqual(green, 0x14 / 255, accuracy: 0.001)
    XCTAssertEqual(blue, 0x17 / 255, accuracy: 0.001)
    XCTAssertEqual(alpha, 1, accuracy: 0.001)
  }
}
