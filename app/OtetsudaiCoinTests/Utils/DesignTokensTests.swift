import XCTest
import SwiftUI
@testable import OtetsudaiCoin

/// デザイントークン（AppRadius / AppSpacing / AppShadow）の値を固定する characterization テスト。
/// トークン値が意図せず変わった場合に検知する安全網。
final class DesignTokensTests: XCTestCase {

    // MARK: - AppRadius

    func testAppRadiusValues() {
        XCTAssertEqual(AppRadius.xSmall, 4)
        XCTAssertEqual(AppRadius.small, 8)
        XCTAssertEqual(AppRadius.medium, 12)
        XCTAssertEqual(AppRadius.large, 16)
        XCTAssertEqual(AppRadius.xLarge, 20)
    }

    func testAppRadiusIsStrictlyAscending() {
        let scale = [AppRadius.xSmall, AppRadius.small, AppRadius.medium, AppRadius.large, AppRadius.xLarge]
        for (prev, next) in zip(scale, scale.dropFirst()) {
            XCTAssertLessThan(prev, next, "AppRadius は昇順で単調増加している必要がある: \(scale)")
        }
        XCTAssertTrue(scale.allSatisfy { $0 > 0 }, "角丸トークンは全て正の値: \(scale)")
    }

    // MARK: - AppSpacing

    func testAppSpacingValues() {
        XCTAssertEqual(AppSpacing.xxs, 2)
        XCTAssertEqual(AppSpacing.xs, 4)
        XCTAssertEqual(AppSpacing.sm, 8)
        XCTAssertEqual(AppSpacing.md, 12)
        XCTAssertEqual(AppSpacing.lg, 16)
        XCTAssertEqual(AppSpacing.xl, 20)
        XCTAssertEqual(AppSpacing.xxl, 24)
    }

    /// xxs(2pt) 以外は 4pt グリッドに乗っている（xxs のみ意図的な半ステップ例外）。
    func testAppSpacingGridMembersAreMultiplesOfFour() {
        let gridMembers: [CGFloat] = [
            AppSpacing.xs, AppSpacing.sm, AppSpacing.md, AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl
        ]
        for value in gridMembers {
            XCTAssertEqual(value.truncatingRemainder(dividingBy: 4), 0, "4pt グリッド上の値のはず: \(value)")
        }
        // xxs は 4pt グリッドの半ステップ例外であることを明示的に固定する。
        XCTAssertEqual(AppSpacing.xxs.truncatingRemainder(dividingBy: 4), 2, "xxs は半ステップ(2pt)例外")
    }

    func testAppSpacingIsStrictlyAscending() {
        let scale = [
            AppSpacing.xxs, AppSpacing.xs, AppSpacing.sm, AppSpacing.md,
            AppSpacing.lg, AppSpacing.xl, AppSpacing.xxl
        ]
        for (prev, next) in zip(scale, scale.dropFirst()) {
            XCTAssertLessThan(prev, next, "AppSpacing は昇順で単調増加している必要がある: \(scale)")
        }
    }

    // MARK: - AppShadow

    /// 影プリセットの radius / x / y を数値で固定する（最も頑健な確認）。
    func testAppShadowNumericFields() {
        XCTAssertEqual(AppShadow.card.radius, 2)
        XCTAssertEqual(AppShadow.card.x, 0)
        XCTAssertEqual(AppShadow.card.y, 1)

        XCTAssertEqual(AppShadow.cardElevated.radius, 4)
        XCTAssertEqual(AppShadow.cardElevated.x, 0)
        XCTAssertEqual(AppShadow.cardElevated.y, 2)

        XCTAssertEqual(AppShadow.floating.radius, 10)
        XCTAssertEqual(AppShadow.floating.x, 0)
        XCTAssertEqual(AppShadow.floating.y, 5)
    }

    /// 影プリセットが HomeView のカード影と同一値であること（採用時の pixel-identical を保証する定数）。
    /// Color の等価比較が SwiftUI 実装依存のため、失敗時に切り分けられるよう観測値を message に含める。
    func testAppShadowMatchesHomeViewLiterals() {
        let expectedCard = AppShadowStyle(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        let expectedElevated = AppShadowStyle(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        let expectedFloating = AppShadowStyle(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)

        XCTAssertEqual(AppShadow.card, expectedCard, "card プリセット: \(AppShadow.card)")
        XCTAssertEqual(AppShadow.cardElevated, expectedElevated, "cardElevated プリセット: \(AppShadow.cardElevated)")
        XCTAssertEqual(AppShadow.floating, expectedFloating, "floating プリセット: \(AppShadow.floating)")
    }

    /// 影の強度が card < cardElevated < floating の順で強くなる（radius と y オフセット）。
    func testAppShadowElevationOrdering() {
        XCTAssertLessThan(AppShadow.card.radius, AppShadow.cardElevated.radius)
        XCTAssertLessThan(AppShadow.cardElevated.radius, AppShadow.floating.radius)
        XCTAssertLessThan(AppShadow.card.y, AppShadow.cardElevated.y)
        XCTAssertLessThan(AppShadow.cardElevated.y, AppShadow.floating.y)
    }
}
