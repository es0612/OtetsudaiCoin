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

    // MARK: - primaryBlue (#151 ダークモード3)

    /// 外観を指定して動的色を解決する (SwiftUI Color は trait 無しでは light で解決される)
    private func resolved(_ color: Color, _ style: UIUserInterfaceStyle) -> Color {
        Color(UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style)))
    }

    // primaryBlue は背景上の文字 (月のまとめの「回」の数字) と図形に使う
    func testPrimaryBlueOnLightBackgroundMeetsAA() {
        let ratio = resolved(AccessibilityColors.primaryBlue, .light).contrastRatio(with: .white)
        XCTAssertGreaterThanOrEqual(ratio, 4.5, "light の白地 (actual: \(ratio))")
    }

    func testPrimaryBlueOnDarkCardBackgroundMeetsAA() {
        // dark のカード背景 = secondarySystemGroupedBackground (#1C1C1E)
        let darkCard = Color(hex: "#1C1C1E")!
        let ratio = resolved(AccessibilityColors.primaryBlue, .dark).contrastRatio(with: darkCard)
        XCTAssertGreaterThanOrEqual(ratio, 4.5, "dark のカード地 (actual: \(ratio))")
    }
}
