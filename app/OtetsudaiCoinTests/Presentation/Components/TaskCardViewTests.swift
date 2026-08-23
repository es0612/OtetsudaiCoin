import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

@MainActor
final class TaskCardViewTests: XCTestCase {

    private func makeTask(name: String = "お風呂を入れる", coinRate: Int = 10, icon: String? = nil) -> HelpTask {
        HelpTask(id: UUID(), name: name, isActive: true, coinRate: coinRate, sortOrder: 0, icon: icon)
    }

    // MARK: - #73 existingCountRow

    /// coinInfo (ja "10コイン" / en "10 Coins") を除外した Text に判定文字列が現れるか。
    /// clone simulator は en_US 既定で起動する (下記 tapToSelectVariants のコメント参照) ため、
    /// ja suffix だけの除外だと "10 Coins" が数字を含んで false positive になる (#177 項目3)。
    private func nonCoinTexts(_ texts: [String]) -> [String] {
        texts.filter { !$0.hasSuffix("コイン") && !$0.hasSuffix("Coins") }
    }

    func test_existingCountRow_hidden_whenCountIsZero() throws {
        // 旧実装の XCTAssertThrowsError(find(viewWithAccessibilityIdentifier:)) は
        // iOS 26 + ViewInspector 0.10.2 で当該 API が常に throw するため無条件 pass だった (#177 項目3)。
        // findAll ベースで「coinInfo 以外に数字を含む Text が無い」ことを直接 assert する。
        let view = TaskCardView(task: makeTask(), isSelected: false, existingCount: 0, onTap: {})
        let texts = try view.renderedTexts()
        XCTAssertFalse(
            nonCoinTexts(texts).contains { $0.contains(where: \.isNumber) },
            "existingCount(0) なのに件数表示の Text が描画されている。rendered: \(texts)"
        )
    }

    func test_existingCountRow_visible_whenCountIsOne() throws {
        // 文言を exact match しないため locale / 文言変更には依存しない
        // (ja "すでに 1 件記録済み" / en "Already recorded 1 time" のどちらでも "1" を含む)。
        let view = TaskCardView(task: makeTask(), isSelected: false, existingCount: 1, onTap: {})
        let texts = try view.renderedTexts()
        XCTAssertTrue(
            nonCoinTexts(texts).contains { $0.contains("1") },
            "existingCount(1) を表す Text が見つからない。描画された Text: \(texts)"
        )
    }

    func test_existingCountRow_visible_whenCountIsMany() throws {
        let view = TaskCardView(task: makeTask(), isSelected: false, existingCount: 3, onTap: {})
        let texts = try view.renderedTexts()
        XCTAssertTrue(
            nonCoinTexts(texts).contains { $0.contains("3") },
            "existingCount(3) を表す Text が見つからない。描画された Text: \(texts)"
        )
    }

    // MARK: - #148 絵文字アイコン化 + 選択表現の簡素化

    func testRendersExplicitIconEmoji() throws {
        let view = TaskCardView(task: makeTask(icon: "🧹"), isSelected: false, onTap: {})
        let texts = try view.renderedTexts()
        XCTAssertTrue(texts.contains("🧹"), "rendered: \(texts)")
    }

    func testDefaultTaskRendersDictionaryEmoji() throws {
        let view = TaskCardView(task: makeTask(name: "お風呂を入れる"), isSelected: false, onTap: {})
        let texts = try view.renderedTexts()
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
        let texts = try view.renderedTexts()
        XCTAssertFalse(
            texts.contains { text in Self.tapToSelectVariants.contains { text.contains($0) } },
            "rendered: \(texts)"
        )
    }

    func testSingleModeSelectedShowsNoTextIndicator() throws {
        // 単独モードの選択表現は枠 + チェックマーク overlay のみ (「選択中」テキスト行は削除)
        let view = TaskCardView(task: makeTask(), isSelected: true, onTap: {})
        let texts = try view.renderedTexts()
        XCTAssertFalse(
            texts.contains { text in Self.selectedVariants.contains { text.contains($0) } },
            "rendered: \(texts)"
        )
    }

    func testBulkModeKeepsSelectionIndicator() throws {
        let view = TaskCardView(task: makeTask(), isSelected: true, isBulkMode: true, onTap: {})
        let texts = try view.renderedTexts()
        XCTAssertTrue(
            texts.contains { text in Self.selectedVariants.contains { text.contains($0) } },
            "rendered: \(texts)"
        )
    }

    func testSelectedCardUsesBrandPrimaryShapes() throws {
        let view = TaskCardView(task: makeTask(), isSelected: true, onTap: {})
        // #177 項目7: アイコン円 (0.15) とカード背景 (0.1) の両方を個別に assert する (AND)。
        // OR だと片方だけの色 regression を検出できない。findAll(Shape) が
        // .background 内 RoundedRectangle にも到達できることは本テストの GREEN + mutation 検証で実証済み。
        try assertBrandPrimaryIconAndCardFills(view)
    }

    /// #151: 未選択カードの背景はダークモードで消えない適応色を使う。
    ///
    /// 修正前は `Color.gray.opacity(0.05)` の極薄塗りで、黒地ではほぼ見えず
    /// カードの境界が失われていた。`systemBackgroundSecondary`
    /// (`Color(.secondarySystemBackground)`) はライト/ダークで明度が反転するため
    /// どちらでも地との差が残る。
    ///
    /// hex リテラル直書きではなくトークン定数と比較することで、
    /// トークン側の値を変えたときにテストが追随する。
    func testUnselectedCardBackgroundUsesAdaptiveColor() throws {
        let view = TaskCardView(task: makeTask(), isSelected: false, onTap: {})
        let fills = try view.renderedFills()

        XCTAssertTrue(
            fills.contains(AccessibilityColors.systemBackgroundSecondary),
            "未選択カードの背景が適応色でない / observed fills: \(fills)"
        )
        XCTAssertFalse(
            fills.contains(Color.gray.opacity(0.05)),
            "ダークモードで消える gray.opacity(0.05) が残っている / observed fills: \(fills)"
        )
    }
}
