import XCTest
import SwiftUI
@testable import OtetsudaiCoin

final class BrandColorsTests: XCTestCase {

    // ボタンラベルは 17pt semibold = WCAG large text 基準 (3.0:1)
    func testBrandPrimaryContrastOnWhiteTextMeetsLargeTextAA() {
        let ratio = AccessibilityColors.brandPrimary.contrastRatio(with: .white)
        XCTAssertGreaterThanOrEqual(ratio, 3.0, "brandPrimary は白文字ボタン地に使う (actual: \(ratio))")
    }

    func testBrandSecondaryContrastOnWhiteTextMeetsLargeTextAA() {
        let ratio = AccessibilityColors.brandSecondary.contrastRatio(with: .white)
        XCTAssertGreaterThanOrEqual(ratio, 3.0, "brandSecondary は白文字ボタン地に使う (actual: \(ratio))")
    }

    func testBrandPrimaryDarkContrastOnWhiteMeetsAA() {
        let ratio = AccessibilityColors.brandPrimaryDark.contrastRatio(with: .white)
        XCTAssertGreaterThanOrEqual(ratio, 4.5, "押下状態・強調用は AA (actual: \(ratio))")
    }

    func testBrandSurfaceWarmIsLightBackground() {
        // 淡背景は黒文字が AA (4.5:1) で載ること
        let ratio = AccessibilityColors.brandSurfaceWarm.contrastRatio(with: .black)
        XCTAssertGreaterThanOrEqual(ratio, 4.5, "brandSurfaceWarm は淡背景 (actual: \(ratio))")
    }
}
