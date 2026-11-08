import Foundation

struct AllowancePayment: Equatable, Codable {
    let id: UUID
    let childId: UUID
    let amount: Int
    let month: Int
    let year: Int
    let paidAt: Date
    let note: String?
    /// おまけの額 (#279)。お小遣いの `amount` には混ぜない。おまけ無しは 0
    let bonusAmount: Int
    /// おまけのスタンプのキー (`BonusStamp.rawValue`)。おまけ無しは nil。表示文言ではなくキーを保存する
    let bonusStampKey: String?
    
    init(
        id: UUID,
        childId: UUID,
        amount: Int,
        month: Int,
        year: Int,
        paidAt: Date,
        note: String? = nil,
        bonusAmount: Int = 0,
        bonusStampKey: String? = nil
    ) {
        self.id = id
        self.childId = childId
        self.amount = amount
        self.month = month
        self.year = year
        self.paidAt = paidAt
        self.note = note
        self.bonusAmount = bonusAmount
        self.bonusStampKey = bonusStampKey
    }
    
    /// #279 より前に保存された JSON（UserDefaults の旧データ）にはおまけの欄が無いので、
    /// 欄が無ければ「おまけ無し」として読む。他の欄は今までどおり必須。
    /// `encode(to:)` と `CodingKeys` は合成のまま。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        childId = try container.decode(UUID.self, forKey: .childId)
        amount = try container.decode(Int.self, forKey: .amount)
        month = try container.decode(Int.self, forKey: .month)
        year = try container.decode(Int.self, forKey: .year)
        paidAt = try container.decode(Date.self, forKey: .paidAt)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        bonusAmount = try container.decodeIfPresent(Int.self, forKey: .bonusAmount) ?? 0
        bonusStampKey = try container.decodeIfPresent(String.self, forKey: .bonusStampKey)
    }
    
    static func == (lhs: AllowancePayment, rhs: AllowancePayment) -> Bool {
        return lhs.id == rhs.id
    }
    
    var monthYearString: String {
        return "\(year)年\(month)月"
    }
    
    static func fromCurrentMonth(childId: UUID, amount: Int, note: String? = nil) -> AllowancePayment {
        let now = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)
        
        return AllowancePayment(
            id: UUID(),
            childId: childId,
            amount: amount,
            month: month,
            year: year,
            paidAt: now,
            note: note
        )
    }
}