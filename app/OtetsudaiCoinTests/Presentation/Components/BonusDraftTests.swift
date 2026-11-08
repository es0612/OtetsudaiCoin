import XCTest
@testable import OtetsudaiCoin

/// おまけのシート (#279) の入力状態 `BonusDraft` のテスト。
final class BonusDraftTests: XCTestCase {

    func testSetAmountTextKeepsAsciiDigitsOnly() {
        var d = BonusDraft()
        d.setAmountText("5a0"); XCTAssertEqual(d.amountText, "50")
        d.setAmountText("５０"); XCTAssertEqual(d.amountText, "", "全角数字は落とす（numberPad は半角を出す。貼り付けだけの経路）")
        d.setAmountText("007"); XCTAssertEqual(d.amountText, "7")
    }

    func testSetAmountTextCapsAtSevenDigits() {
        var d = BonusDraft(); d.setAmountText("123456789"); XCTAssertEqual(d.amount, 1_234_567)
    }

    func testAddChipAccumulatesAndClampsAtMax() {
        var d = BonusDraft(); d.addChip(10); d.addChip(50); XCTAssertEqual(d.amount, 60)
        d.setAmountText("9999990"); d.addChip(100); XCTAssertEqual(d.amount, PaymentBonus.maxAmount)
    }

    func testBonusRequiresStampAndPositiveAmount() {
        var d = BonusDraft(); d.addChip(50); XCTAssertNil(d.bonus, "スタンプ未選択")
        d.stamp = .thanks; XCTAssertEqual(d.bonus, PaymentBonus(amount: 50, stamp: .thanks))
        d.setAmountText(""); XCTAssertNil(d.bonus, "額 0")
    }

    func testTotalAddsRemainderAndBonus() { var d = BonusDraft(); d.addChip(100); XCTAssertEqual(d.total(remainder: 230), 330) }

    func testStampColumnsDropToOneAtAccessibilitySizes() {
        XCTAssertEqual(BonusDraft.stampColumnCount(isAccessibilitySize: false), 2)
        XCTAssertEqual(BonusDraft.stampColumnCount(isAccessibilitySize: true), 1)
    }
}
