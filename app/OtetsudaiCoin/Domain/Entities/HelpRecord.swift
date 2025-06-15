import Foundation

struct HelpRecord: Equatable {
    let id: UUID
    let childId: UUID
    let helpTaskId: UUID
    let recordedAt: Date
    
    init(id: UUID, childId: UUID, helpTaskId: UUID, recordedAt: Date) {
        self.id = id
        self.childId = childId
        self.helpTaskId = helpTaskId
        self.recordedAt = recordedAt
    }
    
    static func == (lhs: HelpRecord, rhs: HelpRecord) -> Bool {
        return lhs.id == rhs.id
    }
    
    func isInCurrentMonth() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        return calendar.isDate(recordedAt, equalTo: now, toGranularity: .month)
    }
    
    func isToday() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        return calendar.isDate(recordedAt, inSameDayAs: now)
    }
    
    static func filterForChildInCurrentMonth(records: [HelpRecord], childId: UUID) -> [HelpRecord] {
        return records.filter { record in
            record.childId == childId && record.isInCurrentMonth()
        }
    }
}