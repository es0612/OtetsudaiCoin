import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

/// `ChildCardView`（ホームの子どもカード）のコンポーネントテスト。
///
/// `accessibilityIdentifier` は ViewInspector 0.10.2 + iOS 26 SDK で解決不能なため、
/// 図形の色は `findAll(ViewType.Shape.self)` + `fillShapeStyle(Color.self)` で確認する
/// (CLAUDE.md § SwiftUI View テスト戦略「findAll fallback」)。
@MainActor
final class ChildCardViewTests: XCTestCase {

    private func makeChild(themeColor: String = "#FF6B6B") -> Child {
        Child(id: UUID(), name: "さくら", themeColor: themeColor)
    }

    /// #151: 未選択カードの背景はダークモードで消えない適応色を使う。
    ///
    /// 修正前は `Color.gray.opacity(0.05)` の極薄塗りで、黒地ではほぼ見えず
    /// カードの境界が失われていた。
    func testUnselectedCardBackgroundUsesAdaptiveColor() throws {
        let view = ChildCardView(child: makeChild(), isSelected: false, onTap: {})
        let fills = try view.inspect().findAll(ViewType.Shape.self).compactMap { try? $0.fillShapeStyle(Color.self) }

        XCTAssertTrue(
            fills.contains(AccessibilityColors.systemBackgroundSecondary),
            "未選択カードの背景が適応色でない / observed fills: \(fills)"
        )
        XCTAssertFalse(
            fills.contains(Color.gray.opacity(0.05)),
            "ダークモードで消える gray.opacity(0.05) が残っている / observed fills: \(fills)"
        )
    }

    /// 選択時はテーマカラーの淡色が背景になる（適応色化で選択表現まで消していないこと）。
    func testSelectedCardBackgroundUsesThemeColor() throws {
        let themeHex = "#FF6B6B"
        let view = ChildCardView(child: makeChild(themeColor: themeHex), isSelected: true, onTap: {})
        let fills = try view.inspect().findAll(ViewType.Shape.self).compactMap { try? $0.fillShapeStyle(Color.self) }

        let expected = (Color(hex: themeHex) ?? .blue).opacity(0.1)
        XCTAssertTrue(
            fills.contains(expected),
            "選択カードの背景がテーマカラーの淡色でない / observed fills: \(fills)"
        )
    }
}
