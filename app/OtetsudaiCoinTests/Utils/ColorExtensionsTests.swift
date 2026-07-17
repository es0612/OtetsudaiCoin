import XCTest
import SwiftUI
@testable import OtetsudaiCoin

final class ColorExtensionsTests: XCTestCase {

    func testContrastRatioWhiteVsBlackIs21() {
        let ratio = Color.white.contrastRatio(with: .black)
        XCTAssertEqual(ratio, 21.0, accuracy: 0.1, "white/black は WCAG 定義で 21:1 (actual: \(ratio))")
    }

    func testContrastRatioIsSymmetric() {
        let a = Color(hex: "#E8590C")!
        let ratio1 = a.contrastRatio(with: .white)
        let ratio2 = Color.white.contrastRatio(with: a)
        XCTAssertEqual(ratio1, ratio2, accuracy: 0.001)
    }

    func testContrastRatioKnownValue() {
        // #767676 は白背景で 4.54:1 の既知の WCAG 境界色
        let gray = Color(hex: "#767676")!
        let ratio = gray.contrastRatio(with: .white)
        XCTAssertEqual(ratio, 4.54, accuracy: 0.05, "actual: \(ratio)")
    }
}
