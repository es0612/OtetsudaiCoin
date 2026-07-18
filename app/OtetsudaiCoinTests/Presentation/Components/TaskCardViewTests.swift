import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

@MainActor
final class TaskCardViewTests: XCTestCase {

    private func makeTask(name: String = "お風呂を入れる", coinRate: Int = 10, icon: String? = nil) -> HelpTask {
        HelpTask(id: UUID(), name: name, isActive: true, coinRate: coinRate, sortOrder: 0, icon: icon)
    }

    /// TaskCardView 内の全 Text を列挙して文字列で返す。
    ///
    /// `find(viewWithAccessibilityIdentifier:)` は ViewInspector 0.10.2 + iOS 26 SDK で
    /// systematic に効かない既知回帰があるため (CLAUDE.md「SwiftUI View テスト戦略」節)、
    /// `findAll(ViewType.Text.self)` で blocker を跨いで Text を収集する。
    private func renderedTexts(_ view: TaskCardView) throws -> [String] {
        try view.inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
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
        let view = TaskCardView(task: makeTask(), isSelected: false, existingCount: 1, onTap: {})
        let texts = try renderedTexts(view)
        XCTAssertTrue(
            texts.contains { !$0.hasSuffix("コイン") && $0.contains("1") },
            "existingCount(1) を表す Text が見つからない。描画された Text: \(texts)"
        )
    }

    func test_existingCountRow_visible_whenCountIsMany() throws {
        let view = TaskCardView(task: makeTask(), isSelected: false, existingCount: 3, onTap: {})
        let texts = try renderedTexts(view)
        XCTAssertTrue(
            texts.contains { !$0.hasSuffix("コイン") && $0.contains("3") },
            "existingCount(3) を表す Text が見つからない。描画された Text: \(texts)"
        )
    }

    // MARK: - #148 絵文字アイコン化 + 選択表現の簡素化

    func testRendersExplicitIconEmoji() throws {
        let view = TaskCardView(task: makeTask(icon: "🧹"), isSelected: false, onTap: {})
        let texts = try renderedTexts(view)
        XCTAssertTrue(texts.contains("🧹"), "rendered: \(texts)")
    }

    func testDefaultTaskRendersDictionaryEmoji() throws {
        let view = TaskCardView(task: makeTask(name: "お風呂を入れる"), isSelected: false, onTap: {})
        let texts = try renderedTexts(view)
        XCTAssertTrue(texts.contains("🛁"), "rendered: \(texts)")
    }

    // 「タップして選択」/「選択中」は xcstrings 経由でレンダリングされるキーであり、
    // `xcodebuild test` が生成する ephemeral clone simulator (例 "Clone 1 of iPhone 17 Pro Max")
    // はホスト (ja-JP) の locale を継承せず en_US 既定で起動することを実行時に観測した
    // (このブランチの RED/GREEN 実行で "タップして選択"→"Tap to select" / "選択中"→"Selected"
    // に翻訳された状態でレンダリングされた)。アプリがサポートするのは ja/en の2ロケールのみ
    // (Localizable.xcstrings) なので、両ロケールの訳文を許容して locale 非依存にする。
    private static let tapToSelectVariants = ["タップして選択", "Tap to select"]
    private static let selectedVariants = ["選択中", "Selected"]

    func testTapToSelectLabelIsRemoved() throws {
        let view = TaskCardView(task: makeTask(), isSelected: false, onTap: {})
        let texts = try renderedTexts(view)
        XCTAssertFalse(
            texts.contains { text in Self.tapToSelectVariants.contains { text.contains($0) } },
            "rendered: \(texts)"
        )
    }

    func testSingleModeSelectedShowsNoTextIndicator() throws {
        // 単独モードの選択表現は枠 + チェックマーク overlay のみ (「選択中」テキスト行は削除)
        let view = TaskCardView(task: makeTask(), isSelected: true, onTap: {})
        let texts = try renderedTexts(view)
        XCTAssertFalse(
            texts.contains { text in Self.selectedVariants.contains { text.contains($0) } },
            "rendered: \(texts)"
        )
    }

    func testBulkModeKeepsSelectionIndicator() throws {
        let view = TaskCardView(task: makeTask(), isSelected: true, isBulkMode: true, onTap: {})
        let texts = try renderedTexts(view)
        XCTAssertTrue(
            texts.contains { text in Self.selectedVariants.contains { text.contains($0) } },
            "rendered: \(texts)"
        )
    }

    func testSelectedCardUsesBrandPrimaryShapes() throws {
        let view = TaskCardView(task: makeTask(), isSelected: true, onTap: {})
        let shapes = try view.inspect().findAll(ViewType.Shape.self)
        let fills = shapes.compactMap { try? $0.fillShapeStyle(Color.self) }
        // アイコン円 (brandPrimary 0.15) かカード背景 (brandPrimary 0.1) のどちらかが取得できること
        let expected: [Color] = [
            AccessibilityColors.brandPrimary.opacity(0.15),
            AccessibilityColors.brandPrimary.opacity(0.1)
        ]
        XCTAssertTrue(fills.contains { expected.contains($0) }, "observed fills: \(fills)")
    }
}
