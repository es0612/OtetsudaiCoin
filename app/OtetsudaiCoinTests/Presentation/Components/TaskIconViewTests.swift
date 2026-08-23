import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

/// TaskIconView (displayIcon 絵文字 + 選択円塗りの共通 component、#200) のテスト。
/// findAll ベース (CLAUDE.md「SwiftUI View テスト戦略」節) + トークン定数の等価比較。
@MainActor
final class TaskIconViewTests: XCTestCase {

    private func makeTask(name: String = "お風呂を入れる", icon: String? = nil) -> HelpTask {
        HelpTask(id: UUID(), name: name, isActive: true, coinRate: 10, sortOrder: 0, icon: icon)
    }

    func testRendersExplicitIconEmoji() throws {
        let view = TaskIconView(task: makeTask(icon: "🧹"), isSelected: false)
        let texts = try view.renderedTexts()
        XCTAssertTrue(texts.contains("🧹"), "rendered: \(texts)")
    }

    func testUnknownNameFallsBackToSparkle() throws {
        let view = TaskIconView(task: makeTask(name: "辞書に無い独自タスク"), isSelected: false)
        let texts = try view.renderedTexts()
        XCTAssertTrue(texts.contains("✨"), "rendered: \(texts)")
    }

    func testSelectedCircleUsesSelectedFillToken() throws {
        let fills = try TaskIconView(task: makeTask(), isSelected: true).renderedFills()
        XCTAssertTrue(
            fills.contains(AccessibilityColors.taskIconSelectedFill),
            "選択時の円が taskIconSelectedFill でない / observed fills: \(fills)"
        )
    }

    func testUnselectedCircleUsesUnselectedFillToken() throws {
        let fills = try TaskIconView(task: makeTask(), isSelected: false).renderedFills()
        XCTAssertTrue(
            fills.contains(AccessibilityColors.taskIconUnselectedFill),
            "非選択時の円が taskIconUnselectedFill でない / observed fills: \(fills)"
        )
    }
}
