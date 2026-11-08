import XCTest
@testable import OtetsudaiCoin

/// おまけ (#279) のスタンプと額の値オブジェクト、`AllowancePayment` への保存のテスト。
final class BonusStampTests: XCTestCase {

    func testStampKeysAreStable() {
        // 保存されるキー。出荷後に変えると過去のおまけが「未知のスタンプ」になる
        XCTAssertEqual(BonusStamp.allCases.map(\.rawValue), ["effort", "thanks", "steady", "challenge"])
    }

    func testUnknownKeyIsNotAStamp() {
        XCTAssertNil(BonusStamp(rawValue: "gold"))
    }

    func testPaymentBonusRejectsOutOfRangeAmount() {
        XCTAssertNil(PaymentBonus(amount: 0, stamp: .effort))
        XCTAssertNil(PaymentBonus(amount: -1, stamp: .effort))
        XCTAssertNil(PaymentBonus(amount: PaymentBonus.maxAmount + 1, stamp: .effort))
        XCTAssertEqual(PaymentBonus(amount: 1, stamp: .thanks)?.amount, 1)
        XCTAssertEqual(PaymentBonus(amount: PaymentBonus.maxAmount, stamp: .thanks)?.amount, 9_999_999)
    }

    func testBonusFieldsRoundTripThroughJSON() throws {
        let p = AllowancePayment(id: UUID(), childId: UUID(), amount: 200, month: 11, year: 2026,
                                 paidAt: Date(timeIntervalSinceReferenceDate: 0), bonusAmount: 50, bonusStampKey: "effort")
        let decoded = try JSONDecoder().decode(AllowancePayment.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(decoded.bonusAmount, 50)
        XCTAssertEqual(decoded.bonusStampKey, "effort")
    }
}
