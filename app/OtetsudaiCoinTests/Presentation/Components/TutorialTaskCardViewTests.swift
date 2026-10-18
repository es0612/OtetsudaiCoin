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

    func testRendersExplicitIconEmoji() throws {
        let view = TutorialTaskCardView(task: makeTask(icon: "🧹"), isSelected: false, onTap: {})
        let texts = try view.renderedTexts()
        XCTAssertTrue(texts.contains("🧹"), "rendered: \(texts)")
    }

    func testDefaultTaskRendersDictionaryEmoji() throws {
        let view = TutorialTaskCardView(task: makeTask(name: "お風呂を入れる"), isSelected: false, onTap: {})
        let texts = try view.renderedTexts()
        XCTAssertTrue(texts.contains("🛁"), "rendered: \(texts)")
    }

    func testUnknownNameFallsBackToSparkle() throws {
        let view = TutorialTaskCardView(task: makeTask(name: "辞書に無い独自タスク"), isSelected: false, onTap: {})
        let texts = try view.renderedTexts()
        XCTAssertTrue(texts.contains("✨"), "rendered: \(texts)")
    }

    func testSelectedCardUsesBrandPrimaryShapes() throws {
        let view = TutorialTaskCardView(task: makeTask(), isSelected: true, onTap: {})
        // #177 項目7: アイコン円 (0.15) とカード背景 (0.1) の両方を個別に assert する (AND)。
        // OR だと片方だけの色 regression を検出できない。findAll(Shape) が
        // .background 内 RoundedRectangle にも到達できることは本テストの GREEN + mutation 検証で実証済み。
        try assertBrandPrimaryIconAndCardFills(view)
    }

    // MARK: - AX サイズのレイアウト (#253)
    // dynamicTypeSize は ViewInspector から注入できないため、判定を static helper で検証する
    // (CLAUDE.md「@Environment(\.isEnabled) など環境値駆動の見た目分岐」)。環境値の配線は撮影で確認する。

    func testGridUsesTwoColumnsAtDefaultSizes() {
        XCTAssertEqual(TutorialTaskCardView.gridColumns(isAccessibilitySize: false).count, 2)
    }

    func testGridUsesOneColumnAtAccessibilitySizes() {
        XCTAssertEqual(TutorialTaskCardView.gridColumns(isAccessibilitySize: true).count, 1)
    }

    func testCardKeepsFixedHeightAtDefaultSizes() {
        XCTAssertEqual(TutorialTaskCardView.cardHeight(isAccessibilitySize: false), 120)
    }

    func testCardSizesToContentAtAccessibilitySizes() {
        XCTAssertNil(TutorialTaskCardView.cardHeight(isAccessibilitySize: true))
    }

    func testNameLimitedToTwoLinesAtDefaultSizes() {
        XCTAssertEqual(TutorialTaskCardView.nameLineLimit(isAccessibilitySize: false), 2)
    }

    func testNameHasNoLineLimitAtAccessibilitySizes() {
        XCTAssertNil(TutorialTaskCardView.nameLineLimit(isAccessibilitySize: true))
    }

    func testCardWidthFollowsContentAtDefaultSizes() {
        XCTAssertNil(TutorialTaskCardView.cardMaxWidth(isAccessibilitySize: false))
    }

    func testCardFillsTheColumnAtAccessibilitySizes() {
        XCTAssertEqual(TutorialTaskCardView.cardMaxWidth(isAccessibilitySize: true), .infinity)
    }

    func testRecordActionStaysAfterTheListAtDefaultSizes() {
        XCTAssertFalse(TutorialTaskCardView.placesRecordActionBelowSelectedCard(isAccessibilitySize: false))
    }

    func testRecordActionFollowsTheSelectedCardAtAccessibilitySizes() {
        XCTAssertTrue(TutorialTaskCardView.placesRecordActionBelowSelectedCard(isAccessibilitySize: true))
    }

    func testUnselectedCardUsesFixedSpacerAtDefaultSizes() {
        XCTAssertFalse(TutorialTaskCardView.reservesCheckmarkSpace(isAccessibilitySize: false))
    }

    func testUnselectedCardReservesCheckmarkSpaceAtAccessibilitySizes() {
        XCTAssertTrue(TutorialTaskCardView.reservesCheckmarkSpace(isAccessibilitySize: true))
    }

    func testListScrollsInsideItsOwnWindowAtDefaultSizes() {
        XCTAssertTrue(TutorialTaskCardView.usesNestedScroll(isAccessibilitySize: false))
    }

    func testListLeavesScrollingToTheStepAtAccessibilitySizes() {
        XCTAssertFalse(TutorialTaskCardView.usesNestedScroll(isAccessibilitySize: true))
    }

    // MARK: - 記録する帯 (#262)

    func testRecordActionPlacementTable() {
        typealias P = TutorialTaskCardView.RecordActionPlacement
        func f(_ ax: Bool, _ child: Bool, _ task: Bool) -> P {
            TutorialTaskCardView.recordActionPlacement(isAccessibilitySize: ax, hasSelectedChild: child, hasSelectedTask: task)
        }
        XCTAssertEqual(f(false, true, true), P.belowList)
        XCTAssertEqual(f(true, true, true), P.belowSelectedCard)
        XCTAssertEqual(f(false, false, true), P.hidden)
        XCTAssertEqual(f(true, false, true), P.hidden)
        XCTAssertEqual(f(false, true, false), P.hidden)
        XCTAssertEqual(f(true, true, false), P.hidden)
    }

    func testRecordActionKeepsContentWidthAtDefaultSizes() {
        XCTAssertNil(TutorialTaskCardView.recordActionMaxWidth(isAccessibilitySize: false))
    }

    func testRecordActionFillsTheColumnAtAccessibilitySizes() {
        XCTAssertEqual(TutorialTaskCardView.recordActionMaxWidth(isAccessibilitySize: true), .infinity)
    }

    func testScrollTargetOnlyWhenBelowSelectedCard() {
        let id = UUID()
        XCTAssertEqual(
            TutorialTaskCardView.recordActionScrollTarget(placement: .belowSelectedCard, selectedTaskID: id),
            "recordAction-\(id.uuidString)"
        )
        XCTAssertNil(TutorialTaskCardView.recordActionScrollTarget(placement: .belowList, selectedTaskID: id))
        XCTAssertNil(TutorialTaskCardView.recordActionScrollTarget(placement: .hidden, selectedTaskID: id))
        XCTAssertNil(TutorialTaskCardView.recordActionScrollTarget(placement: .belowSelectedCard, selectedTaskID: nil))
    }

    func testScrollTargetChangesWithTheSelectedTask() {
        XCTAssertNotEqual(
            TutorialTaskCardView.recordActionScrollTarget(placement: .belowSelectedCard, selectedTaskID: UUID()),
            TutorialTaskCardView.recordActionScrollTarget(placement: .belowSelectedCard, selectedTaskID: UUID())
        )
    }

    // TutorialStepContainer は TutorialScrollRequest の変化でスクロールする。スクロール先が同じでも
    // serial が進めば別の値になり、選択済みカードの再タップやステップの往復でもスクロールし直す (#265)
    func testScrollRequestChangesWhenOnlySerialAdvances() {
        XCTAssertNotEqual(
            TutorialScrollRequest(target: "recordAction-a", serial: 0),
            TutorialScrollRequest(target: "recordAction-a", serial: 1)
        )
    }

}
