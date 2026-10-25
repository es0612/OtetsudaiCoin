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

    // MARK: - #151 Dynamic Type

    /// #151: AX サイズで内容がクリップしないよう、カードは固定 height ではなく
    /// minHeight で下方向に伸びられること。
    /// flexFrame() traversal は本リポ初出のため観測値を message に dump する (#106 ルール)。
    func test_cardFrame_usesMinHeightNotFixedHeight() throws {
        let view = TaskCardView(task: makeTask(), isSelected: false, onTap: {})
        let vstacks = try view.inspect().findAll(ViewType.VStack.self)
        let flexFrames = vstacks.compactMap { try? $0.flexFrame() }
        let fixedFrames = vstacks.compactMap { try? $0.fixedFrame() }
        XCTAssertTrue(
            flexFrames.contains(where: { $0.minHeight == 150 }),
            "minHeight=150 の flexFrame が見つからない。vstacks=\(vstacks.count), flex=\(flexFrames), fixed=\(fixedFrames)"
        )
        XCTAssertFalse(
            fixedFrames.contains(where: { $0.height == 150 }),
            "固定 height=150 が残っている。fixed=\(fixedFrames)"
        )
    }

    // MARK: - #277 カードの幅と高さ

    /// 既定サイズの 2 列でも、カードは列の幅と行の高さいっぱいに広がる (#277)。
    /// #265 では AX サイズだけ幅をそろえていた (既定サイズは中身の幅で、横に並ぶ 2 枚の幅も高さも不ぞろい)。
    func test_cardFrame_fillsTheGridCell() throws {
        let view = TaskCardView(task: makeTask(), isSelected: false, onTap: {})
        let flexFrames = try view.inspect().findAll(ViewType.VStack.self).compactMap { try? $0.flexFrame() }
        XCTAssertTrue(
            flexFrames.contains(where: { $0.maxWidth == .infinity && $0.maxHeight == .infinity }),
            "maxWidth / maxHeight が .infinity の flexFrame が見つからない。flex=\(flexFrames)"
        )
    }

    /// 高さをそろえた行で、余った高さはタスク名の枠が受け取る (#277)。
    /// 名前が 1 行のカードでも「10 コイン」と「選択」が下端へ寄り、2 行の隣のカードと横一列にそろう。
    func test_taskTitle_absorbsExtraHeight() throws {
        // 既定タスク名は displayName で翻訳される (clone simulator の en_US では "Run the bath") ため、
        // 辞書に無い名前で verbatim 表示させて locale に依存せず掴む。
        let view = TaskCardView(task: makeTask(name: "辞書に無い独自タスク"), isSelected: false, onTap: {})
        let texts = try view.inspect().findAll(ViewType.Text.self)
        let titleFrames = texts
            .filter { (try? $0.string()) == "辞書に無い独自タスク" }
            .compactMap { try? $0.flexFrame() }
        XCTAssertTrue(
            titleFrames.contains(where: { $0.maxHeight == .infinity }),
            "タスク名の Text に maxHeight=.infinity の flexFrame が無い。texts=\(texts.compactMap { try? $0.string() }), titleFrames=\(titleFrames)"
        )
    }
}
