import Foundation

struct UnpaidPeriod: Equatable, Codable {
    let childId: UUID
    let month: Int
    let year: Int
    let expectedAmount: Int
    
    init(childId: UUID, month: Int, year: Int, expectedAmount: Int) {
        self.childId = childId
        self.month = month
        self.year = year
        self.expectedAmount = expectedAmount
    }
    
    static func == (lhs: UnpaidPeriod, rhs: UnpaidPeriod) -> Bool {
        return lhs.childId == rhs.childId && 
               lhs.month == rhs.month && 
               lhs.year == rhs.year
    }
    
    var monthYearString: String {
        return "\(year)年\(month)月"
    }
    
    var dateComponents: DateComponents {
        return DateComponents(year: year, month: month)
    }
    
    var date: Date? {
        return Calendar.current.date(from: dateComponents)
    }
}