import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

/// TutorialTaskCardView (RecordTutorialView.swift 内宣言) のコンポーネントテスト。
///
/// `find(viewWithAccessibilityIdentifier:)` は ViewInspector 0.10.2 + iOS 26 SDK で
/// systematic に効かない既知回帰があるため (CLAUDE.md「SwiftUI View テスト戦略」節)、
/// findAll(ViewType.Text.self) / findAll(ViewType.Shape.self) ベースで検証する。
/// TaskCardViewTests と同型 (#148 で確立したパターンの Tutorial 版、#177 項目1)。
@MainActor
final class TutorialTaskCardViewTests: XCTestCase {

    private func makeTask(name: String = "お風呂を入れる", icon: String? = nil) -> HelpTask {
        HelpTask(id: UUID(), name: name, isActive: true, coinRate: 10, sortOrder: 0, icon: icon)
    }

    private func renderedTexts(_ view: TutorialTaskCardView) throws -> [String] {
        try view.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
    }

    func testRendersExplicitIconEmoji() throws {
        let view = TutorialTaskCardView(task: makeTask(icon: "🧹"), isSelected: false, onTap: {})
        let texts = try renderedTexts(view)
        XCTAssertTrue(texts.contains("🧹"), "rendered: \(texts)")
    }

    func testDefaultTaskRendersDictionaryEmoji() throws {
        let view = TutorialTaskCardView(task: makeTask(name: "お風呂を入れる"), isSelected: false, onTap: {})
        let texts = try renderedTexts(view)
        XCTAssertTrue(texts.contains("🛁"), "rendered: \(texts)")
    }

    func testUnknownNameFallsBackToSparkle() throws {
        let view = TutorialTaskCardView(task: makeTask(name: "辞書に無い独自タスク"), isSelected: false, onTap: {})
        let texts = try renderedTexts(view)
        XCTAssertTrue(texts.contains("✨"), "rendered: \(texts)")
    }

    func testSelectedCardUsesBrandPrimaryShapes() throws {
        let view = TutorialTaskCardView(task: makeTask(), isSelected: true, onTap: {})
        let fills = try view.inspect().findAll(ViewType.Shape.self).compactMap { try? $0.fillShapeStyle(Color.self) }
        // アイコン円 (brandPrimary 0.15) かカード背景 (brandPrimary 0.1) のどちらかが取得できること
        let expected: [Color] = [
            AccessibilityColors.brandPrimary.opacity(0.15),
            AccessibilityColors.brandPrimary.opacity(0.1)
        ]
        XCTAssertTrue(fills.contains { expected.contains($0) }, "observed fills: \(fills)")
    }
}
