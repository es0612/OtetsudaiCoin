import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

/// `TaskRowView` (TaskManagementView.swift 内宣言) のコンポーネントテスト。
///
/// 親の `TaskManagementView` は NavigationStack + List の組み合わせで
/// ViewInspector が traverse できないが、`TaskRowView` はトップレベル struct
/// なので単独で検証できる (HelpRecordRowTests と同じ Component 分離パターン)。
///
/// `find(viewWithAccessibilityIdentifier:)` は ViewInspector 0.10.2 + iOS 26 SDK で
/// systematic に効かないため findAll ベースで検証する (CLAUDE.md「SwiftUI View テスト戦略」)。
@MainActor
final class TaskRowViewTests: XCTestCase {

    private func makeView(
        name: String = "皿洗い",
        icon: String? = nil,
        isActive: Bool = true
    ) -> TaskRowView {
        let task = HelpTask(id: UUID(), name: name, isActive: isActive, coinRate: 10, sortOrder: 0, icon: icon)
        return TaskRowView(task: task, onEdit: {}, onToggle: {}, onDelete: {})
    }

    /// #177 項目5: 行頭アイコンはタスクの displayIcon 絵文字を表示する (#148 の展開)。
    func test_activeRow_rendersExplicitIconEmoji() throws {
        let texts = try makeView(icon: "🧹", isActive: true).renderedTexts()
        XCTAssertTrue(texts.contains("🧹"), "rendered: \(texts)")
    }

    /// 無効タスクでも絵文字自体は表示される (ミュートは opacity で表現、有効/無効の意味は状態 Text が担う)。
    func test_inactiveRow_stillRendersEmoji() throws {
        let texts = try makeView(icon: "🧹", isActive: false).renderedTexts()
        XCTAssertTrue(texts.contains("🧹"), "rendered: \(texts)")
    }

    /// icon 未設定 & 辞書外名は ✨ へフォールバックする。
    func test_unknownName_fallsBackToSparkle() throws {
        let texts = try makeView(name: "辞書に無い独自タスク").renderedTexts()
        XCTAssertTrue(texts.contains("✨"), "rendered: \(texts)")
    }
}
