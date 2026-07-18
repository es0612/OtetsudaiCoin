import XCTest
import SwiftUI
@testable import OtetsudaiCoin

final class AppButtonStyleTests: XCTestCase {

    func testPrimaryPresetUsesBrandPrimary() {
        XCTAssertEqual(SolidButtonStyle.primary.backgroundColor, AccessibilityColors.brandPrimary)
        XCTAssertFalse(SolidButtonStyle.primary.isDisabled)
    }

    func testSuccessPresetUsesBrandSecondary() {
        XCTAssertEqual(SolidButtonStyle.success.backgroundColor, AccessibilityColors.brandSecondary)
    }

    func testDestructivePresetUsesErrorRed() {
        XCTAssertEqual(SolidButtonStyle.destructive.backgroundColor, AccessibilityColors.errorRed)
    }

    func testDefaultInitIsPrimaryEnabled() {
        let style = SolidButtonStyle()
        XCTAssertEqual(style.backgroundColor, AccessibilityColors.brandPrimary)
        XCTAssertFalse(style.isDisabled)
    }

    func testDisabledFlagIsStored() {
        let style = SolidButtonStyle(backgroundColor: AccessibilityColors.brandPrimary, isDisabled: true)
        XCTAssertTrue(style.isDisabled)
    }
}
