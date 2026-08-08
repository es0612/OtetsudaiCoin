import XCTest
import SwiftUI
@testable import OtetsudaiCoin

final class AppButtonStyleTests: XCTestCase {

    // MARK: - プリセット

    func testPrimaryPresetUsesBrandPrimary() {
        XCTAssertEqual(SolidButtonStyle.primary.backgroundColor, AccessibilityColors.brandPrimary)
    }

    func testSuccessPresetUsesBrandSecondary() {
        XCTAssertEqual(SolidButtonStyle.success.backgroundColor, AccessibilityColors.brandSecondary)
    }

    func testDestructivePresetUsesErrorRed() {
        XCTAssertEqual(SolidButtonStyle.destructive.backgroundColor, AccessibilityColors.errorRed)
    }

    func testDefaultInitIsPrimary() {
        let style = SolidButtonStyle()
        XCTAssertEqual(style.backgroundColor, AccessibilityColors.brandPrimary)
    }

    // MARK: - 有効/無効の見た目マッピング (#175 Finding 4)
    // isDisabled stored flag を廃止し @Environment(\.isEnabled) 駆動に変えたため、
    // 環境値 → 見た目の対応は pure helper で担保する (environment 注入は
    // ViewInspector でテスト不可のため、#125 の pure 関数抽出パターンを踏襲)。

    func testBackgroundKeepsColorWhenEnabled() {
        XCTAssertEqual(
            SolidButtonStyle.background(for: AccessibilityColors.brandSecondary, isEnabled: true),
            AccessibilityColors.brandSecondary
        )
    }

    func testBackgroundTurnsGrayWhenDisabled() {
        XCTAssertEqual(
            SolidButtonStyle.background(for: AccessibilityColors.brandPrimary, isEnabled: false),
            Color.gray.opacity(0.6)
        )
    }

    func testOpacityMapping() {
        XCTAssertEqual(SolidButtonStyle.opacity(isEnabled: true), 1.0)
        XCTAssertEqual(SolidButtonStyle.opacity(isEnabled: false), 0.6)
    }

    func testShadowMapping() {
        XCTAssertEqual(SolidButtonStyle.shadow(isEnabled: true), AppShadow.cardElevated)
        XCTAssertEqual(SolidButtonStyle.shadow(isEnabled: false), AppShadow.none)
    }

    // MARK: - AppShadow.none プリセット (#175 Finding 4)

    func testAppShadowNoneIsInvisible() {
        XCTAssertEqual(AppShadow.none, AppShadowStyle(color: .clear, radius: 0, x: 0, y: 0))
    }
}
