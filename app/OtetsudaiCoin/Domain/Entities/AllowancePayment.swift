import Foundation

struct AllowancePayment: Equatable, Codable {
    let id: UUID
    let childId: UUID
    let amount: Int
    let month: Int
    let year: Int
    let paidAt: Date
    let note: String?
    
    init(id: UUID, childId: UUID, amount: Int, month: Int, year: Int, paidAt: Date, note: String? = nil) {
        self.id = id
        self.childId = childId
        self.amount = amount
        self.month = month
        self.year = year
        self.paidAt = paidAt
        self.note = note
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