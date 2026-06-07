import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

/// RecordCalendarView のコンポーネントテスト。
///
/// ## 設計上の注意 (findAll fallback)
/// ViewInspector 0.10.2 + iOS 26 SDK の組み合わせで
/// `accessibilityIdentifier()` が全ビュータイプで nil / throw を返す
/// (v3v4AccessibilityProperties が iOS 26 内部構造変化で取得不可)。
/// そのため `find(viewWithAccessibilityIdentifier:)` が全ケースで SearchFailure になる。
///
/// 代替戦略:
/// - ボタン系: `findAll(ViewType.Button.self)` + 内包 Text でフィルタ
/// - ドット系: `fillShapeStyle(Color.self)` で Circle の fill 色を直接確認
///   (button サブツリー内の Shape を `findAll(ViewType.Shape.self)` で列挙)
///
/// `tap()` / `isDisabled()` はボタンタイプ上で正常動作することをローカル実行で確認済み。
/// CLAUDE.md § SwiftUI View テスト戦略 "findAll fallback" に準拠。
@MainActor
final class RecordCalendarViewTests: XCTestCase {

    private let cal = Calendar.current

    /// 2026-06 を表示月、今日=2026-06-15 とした標準セットアップ。
    private func makeView(
        recordedDays: Set<Int> = [],
        selectedDay: Int? = nil,
        onSelectDay: @escaping (Int) -> Void = { _ in },
        onPrevMonth: @escaping () -> Void = {},
        onNextMonth: @escaping () -> Void = {},
        canGoNextMonth: Bool = false,
        showHeader: Bool = true
    ) -> RecordCalendarView {
        let displayedMonth = cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let today = cal.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        let selectedDate = selectedDay.flatMap {
            cal.date(from: DateComponents(year: 2026, month: 6, day: $0, hour: 12))
        } ?? cal.date(from: DateComponents(year: 2030, month: 1, day: 1))!  // 既定は表示月外
        return RecordCalendarView(
            displayedMonth: displayedMonth,
            selectedDate: selectedDate,
            recordedDays: recordedDays,
            today: today,
            canGoNextMonth: canGoNextMonth,
            showHeader: showHeader,
            onSelectDay: onSelectDay,
            onPrevMonth: onPrevMonth,
            onNextMonth: onNextMonth
        )
    }

    // MARK: - Helpers

    /// ボタンサブツリー内の Shape の fill 色リストを返す。
    /// 記録ありの日は successGreen (#00AA44FF) の Circle が含まれる。
    private func shapeFills(in button: InspectableView<ViewType.Button>) -> [Color] {
        return button.findAll(ViewType.Shape.self).compactMap { try? $0.fillShapeStyle(Color.self) }
    }

    // MARK: - Tests

    /// 記録がある日 (5, 20) には緑 fill の Circle が存在し、記録なし (3) には存在しない。
    func test_recordDot_shownForRecordedDay_hiddenForOthers() throws {
        let view = makeView(recordedDays: [5, 20])
        let allButtons = try view.inspect().findAll(ViewType.Button.self)
        let btn5 = allButtons.first(where: { (try? $0.find(text: "5")) != nil })
        let btn20 = allButtons.first(where: { (try? $0.find(text: "20")) != nil })
        let btn3 = allButtons.first(where: { (try? $0.find(text: "3")) != nil })
        let dotColor = AccessibilityColors.successGreen
        XCTAssertTrue(
            btn5.map { shapeFills(in: $0).contains(dotColor) } ?? false,
            "5日の Circle に successGreen fill がない。allButtons=\(allButtons.count), fills=\(btn5.map { shapeFills(in: $0) } ?? [])"
        )
        XCTAssertTrue(
            btn20.map { shapeFills(in: $0).contains(dotColor) } ?? false,
            "20日の Circle に successGreen fill がない。allButtons=\(allButtons.count), fills=\(btn20.map { shapeFills(in: $0) } ?? [])"
        )
        XCTAssertFalse(
            btn3.map { shapeFills(in: $0).contains(dotColor) } ?? false,
            "3日に余計な successGreen dot がある。fills=\(btn3.map { shapeFills(in: $0) } ?? [])"
        )
    }

    /// 表示月内の選択日 (12) には primaryBlue の選択リングがあり、非選択日 (10) には無い。
    /// dot テストと同じ findAll(ViewType.Shape.self) + fillShapeStyle 方式で
    /// Circle の fill 色 (#0066CCFF) を直接確認する。
    func test_selectionCircle_shownForSelectedDayInMonth() throws {
        let view = makeView(selectedDay: 12)
        let allButtons = try view.inspect().findAll(ViewType.Button.self)
        let btn12 = allButtons.first(where: { (try? $0.find(text: "12")) != nil })
        let btn10 = allButtons.first(where: { (try? $0.find(text: "10")) != nil })
        let selectionColor = AccessibilityColors.primaryBlue
        XCTAssertTrue(
            btn12.map { shapeFills(in: $0).contains(selectionColor) } ?? false,
            "選択日(12)の Circle に primaryBlue fill がない。allButtons=\(allButtons.count), fills=\(btn12.map { shapeFills(in: $0) } ?? [])"
        )
        XCTAssertFalse(
            btn10.map { shapeFills(in: $0).contains(selectionColor) } ?? false,
            "非選択日(10)に余計な primaryBlue 選択リングがある。fills=\(btn10.map { shapeFills(in: $0) } ?? [])"
        )
    }

    /// 日セルをタップすると onSelectDay にその日が渡る。
    func test_tapDay_callsOnSelectDayWithDay() throws {
        var tapped: Int?
        let view = makeView(onSelectDay: { tapped = $0 })
        let allButtons = try view.inspect().findAll(ViewType.Button.self)
        guard let btn10 = allButtons.first(where: { (try? $0.find(text: "10")) != nil }) else {
            XCTFail("calendar_day_10 が見つからない (allButtons=\(allButtons.count))")
            return
        }
        try btn10.tap()
        XCTAssertEqual(tapped, 10, "タップした 10日 が onSelectDay に渡らなかった (allButtons=\(allButtons.count))")
    }

    /// 未来日 (今日 2026-06-15 より後) は disabled、過去日・今日は enabled。
    func test_futureDay_buttonDisabled() throws {
        let view = makeView()
        let allButtons = try view.inspect().findAll(ViewType.Button.self)
        guard let futureBtn = allButtons.first(where: { (try? $0.find(text: "16")) != nil }),
              let pastBtn = allButtons.first(where: { (try? $0.find(text: "10")) != nil }),
              let todayBtn = allButtons.first(where: { (try? $0.find(text: "15")) != nil }) else {
            XCTFail("16日 / 10日 / 15日 ボタンが見つからない (allButtons=\(allButtons.count))")
            return
        }
        XCTAssertTrue(
            futureBtn.isDisabled(),
            "未来日(16)が disabled になっていない (allButtons=\(allButtons.count))"
        )
        XCTAssertFalse(
            pastBtn.isDisabled(),
            "過去日(10)が誤って disabled (allButtons=\(allButtons.count))"
        )
        // 今日 (15) は選択可能 (境界は strict `>` なので今日は disabled でない)
        XCTAssertFalse(
            todayBtn.isDisabled(),
            "今日(15)が誤って disabled (allButtons=\(allButtons.count))"
        )
    }

    /// canGoNextMonth=false のとき次月ボタンが disabled になる。
    func test_nextMonthButton_disabledWhenCannotGoNext() throws {
        let view = makeView(canGoNextMonth: false)
        let allButtons = try view.inspect().findAll(ViewType.Button.self)
        guard let next = allButtons.first(where: { (try? $0.find(text: "›")) != nil }) else {
            XCTFail("次月ボタン(›)が見つからない (allButtons=\(allButtons.count))")
            return
        }
        XCTAssertTrue(
            next.isDisabled(),
            "canGoNextMonth=false で次月ボタンが disabled でない (allButtons=\(allButtons.count))"
        )
    }

    /// 前月ボタンをタップすると onPrevMonth が呼ばれる。
    func test_tapPrevMonth_callsOnPrevMonth() throws {
        var called = false
        let view = makeView(onPrevMonth: { called = true })
        let allButtons = try view.inspect().findAll(ViewType.Button.self)
        guard let prev = allButtons.first(where: { (try? $0.find(text: "‹")) != nil }) else {
            XCTFail("前月ボタン(‹)が見つからない (allButtons=\(allButtons.count))")
            return
        }
        try prev.tap()
        XCTAssertTrue(called, "前月ボタンのタップで onPrevMonth が呼ばれない (allButtons=\(allButtons.count))")
    }

    /// showHeader:false で月ナビ chevron (‹/›) と selectedCaption (記録日 + 日付) を描画しない。
    /// サマリ埋め込み用途で chrome を隠す経路を担保する。
    func testShowHeaderFalseHidesMonthNavChevrons() throws {
        let view = makeView(showHeader: false)
        let texts = try view.inspect().findAll(ViewType.Text.self).map { try $0.string() }
        XCTAssertFalse(texts.contains("‹"), "showHeader:false ではヘッダーの ‹ を描画しない / rendered: \(texts)")
        XCTAssertFalse(texts.contains("›"), "showHeader:false ではヘッダーの › を描画しない / rendered: \(texts)")
        XCTAssertFalse(texts.contains("記録日"), "showHeader:false では selectedCaption(記録日 + 日付) を描画しない / rendered: \(texts)")
    }
}
