import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

@MainActor
final class BonusCelebrationViewTests: XCTestCase {
    private func makeView(onClose: @escaping () -> Void = {}) throws -> BonusCelebrationView {
        BonusCelebrationView(bonus: try XCTUnwrap(PaymentBonus(amount: 50, stamp: .effort)), onClose: onClose)
    }

    func testReduceMotionPlanFadesWithoutScaling() {
        XCTAssertEqual(BonusCelebrationView.MotionPlan.make(reduceMotion: true).initialScale, 1.0, "動かさない")
    }

    func testDefaultPlanScalesIn() {
        XCTAssertLessThan(BonusCelebrationView.MotionPlan.make(reduceMotion: false).initialScale, 1.0)
    }

    /// スタンプ名は locale 依存の文字列なので、絵文字と金額だけを確かめる
    func testShowsStampAndAmount() throws {
        let texts = try makeView().inspect().findAll(ViewType.Text.self).compactMap { try? $0.string() }
        XCTAssertTrue(texts.contains("🏅"), "texts: \(texts)")
        XCTAssertTrue(texts.contains("+¥50"), "texts: \(texts)")
    }

    func testCloseButtonCallsOnClose() throws {
        var closed = false
        let view = try makeView { closed = true }
        try view.inspect().find(ViewType.Button.self).tap()
        XCTAssertTrue(closed)
    }
}
