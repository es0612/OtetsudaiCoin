import Foundation

/// 支払いに付けるおまけ (#279)。額とスタンプの組。
///
/// おまけはお小遣いの `amount` に混ぜず、`AllowancePayment.bonusAmount` / `bonusStampKey` に別で持つ。
/// 額が 1〜`maxAmount` の外なら作れない（nil）。
struct PaymentBonus: Equatable {
    static let maxAmount = 9_999_999

    let amount: Int
    let stamp: BonusStamp

    init?(amount: Int, stamp: BonusStamp) {
        guard (1...Self.maxAmount).contains(amount) else { return nil }
        self.amount = amount
        self.stamp = stamp
    }
}
