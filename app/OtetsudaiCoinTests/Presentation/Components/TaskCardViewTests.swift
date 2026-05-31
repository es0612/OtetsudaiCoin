import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

@MainActor
final class TaskCardViewTests: XCTestCase {

    private func makeTask(name: String = "皿洗い", coinRate: Int = 10) -> HelpTask {
        HelpTask(id: UUID(), name: name, isActive: true, coinRate: coinRate)
    }

    /// TaskCardView 内の全 Text を列挙して文字列で返す。
    ///
    /// `find(viewWithAccessibilityIdentifier: "existing_count_label")` は
    /// `Image(systemName:)` × 3 (taskIcon / existingCountRow / selectionIndicator) が
    /// `AccessibilityImageLabel` blocker となり該当 Text へ到達できない
    /// (CLAUDE.md「SwiftUI View テスト戦略 § AccessibilityImageLabel blocker」)。
    /// `findAll(ViewType.Text.self)` は blocker を跨いで Text を収集できるためこちらを使う。
    private func renderedTexts(existingCount: Int) throws -> [String] {
        let view = TaskCardView(
            task: makeTask(),
            isSelected: false,
            existingCount: existingCount,
            onTap: {}
        )
        return try view.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
    }

    // MARK: - #73 existingCountRow

    func test_existingCountRow_hidden_whenCountIsZero() throws {
        let view = TaskCardView(
            task: makeTask(),
            isSelected: false,
            existingCount: 0,
            onTap: {}
        )
        // 0 件のときは label が描画されない
        XCTAssertThrowsError(try view.inspect().find(viewWithAccessibilityIdentifier: "existing_count_label"))
    }

    func test_existingCountRow_visible_whenCountIsOne() throws {
        // coinInfo "10コイン" が "1" を含むため `contains("1")` だけだと
        // existingCountRow が無くても通る false positive になる。
        // coinInfo は常に "...コイン" suffix なので除外し、それ以外の Text に
        // count 数字が現れることで existingCountRow の描画を確認する。
        // 文言を exact match しないため locale / 文言変更には依存しない。
        let texts = try renderedTexts(existingCount: 1)
        XCTAssertTrue(
            texts.contains { !$0.hasSuffix("コイン") && $0.contains("1") },
            "existingCount(1) を表す Text が見つからない。描画された Text: \(texts)"
        )
    }

    func test_existingCountRow_visible_whenCountIsMany() throws {
        let texts = try renderedTexts(existingCount: 3)
        XCTAssertTrue(
            texts.contains { !$0.hasSuffix("コイン") && $0.contains("3") },
            "existingCount(3) を表す Text が見つからない。描画された Text: \(texts)"
        )
    }
}
