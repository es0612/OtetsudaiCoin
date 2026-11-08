import Foundation

/// おまけのシート (#279) の入力状態。View から切り離して unit test する。
///
/// 額の入力は半角数字だけ・7 桁まで。7 桁は Core Data の `Integer 32` があふれないための技術上の上限で、
/// おまけの方針としての上限ではない（上限値は `PaymentBonus.maxAmount`）。
struct BonusDraft: Equatable {
    static let chipAmounts = [10, 50, 100]
    static let maxDigits = 7

    var stamp: BonusStamp?
    private(set) var amountText: String = ""

    /// 入力中の額。空なら 0。
    var amount: Int {
        Int(amountText) ?? 0
    }

    /// 入力を半角数字だけにし、先頭の 0 を落とし、`maxDigits` 桁で切る。
    /// 全角数字は落とす（numberPad は半角を出す。全角が入るのは貼り付けのときだけ）。
    mutating func setAmountText(_ raw: String) {
        let digits = raw.filter { $0.isASCII && $0.isNumber }
        let trimmed = digits.drop { $0 == "0" }
        amountText = String(trimmed.prefix(Self.maxDigits))
    }

    /// チップの額を今の額に足す。`PaymentBonus.maxAmount` で止める。
    mutating func addChip(_ value: Int) {
        let next = min(amount + value, PaymentBonus.maxAmount)
        setAmountText(String(next))
    }

    /// 渡す額（お小遣いの残り + おまけ）。
    func total(remainder: Int) -> Int {
        remainder + amount
    }

    /// 確定できるおまけ。スタンプが未選択か、額が 1〜`PaymentBonus.maxAmount` の外なら nil。
    var bonus: PaymentBonus? {
        stamp.flatMap { PaymentBonus(amount: amount, stamp: $0) }
    }

    /// スタンプのグリッドの列数。アクセシビリティサイズの文字では 1 列にして、スタンプ名を切らない。
    static func stampColumnCount(isAccessibilitySize: Bool) -> Int {
        isAccessibilitySize ? 1 : 2
    }

    /// 額のチップの列数。アクセシビリティサイズの文字では 1 列にして、「+¥100」を 1 行のままカプセルに収める。
    static func chipColumnCount(isAccessibilitySize: Bool) -> Int {
        isAccessibilitySize ? 1 : chipAmounts.count
    }
}
