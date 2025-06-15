import XCTest
@testable import OtetsudaiCoin

final class HelpRecordTests: XCTestCase {

    func testHelpRecordInitialization() {
        let id = UUID()
        let childId = UUID()
        let helpTaskId = UUID()
        let recordedAt = Date()
        
        let record = HelpRecord(id: id, childId: childId, helpTaskId: helpTaskId, recordedAt: recordedAt)
        
        XCTAssertEqual(record.id, id)
        XCTAssertEqual(record.childId, childId)
        XCTAssertEqual(record.helpTaskId, helpTaskId)
        XCTAssertEqual(record.recordedAt, recordedAt)
    }
    
    func testHelpRecordEqualityById() {
        let id = UUID()
        let record1 = HelpRecord(id: id, childId: UUID(), helpTaskId: UUID(), recordedAt: Date())
        let record2 = HelpRecord(id: id, childId: UUID(), helpTaskId: UUID(), recordedAt: Date())
        
        XCTAssertEqual(record1, record2)
    }
    
    func testHelpRecordInequality() {
        let record1 = HelpRecord(id: UUID(), childId: UUID(), helpTaskId: UUID(), recordedAt: Date())
        let record2 = HelpRecord(id: UUID(), childId: UUID(), helpTaskId: UUID(), recordedAt: Date())
        
        XCTAssertNotEqual(record1, record2)
    }
    
    func testHelpRecordIsInCurrentMonth() {
        let calendar = Calendar.current
        let now = Date()
        
        let currentMonthRecord = HelpRecord(id: UUID(), childId: UUID(), helpTaskId: UUID(), recordedAt: now)
        XCTAssertTrue(currentMonthRecord.isInCurrentMonth())
        
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: now)!
        let previousMonthRecord = HelpRecord(id: UUID(), childId: UUID(), helpTaskId: UUID(), recordedAt: previousMonth)
        XCTAssertFalse(previousMonthRecord.isInCurrentMonth())
        
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: now)!
        let nextMonthRecord = HelpRecord(id: UUID(), childId: UUID(), helpTaskId: UUID(), recordedAt: nextMonth)
        XCTAssertFalse(nextMonthRecord.isInCurrentMonth())
    }
    
    func testHelpRecordIsToday() {
        let calendar = Calendar.current
        let now = Date()
        
        let todayRecord = HelpRecord(id: UUID(), childId: UUID(), helpTaskId: UUID(), recordedAt: now)
        XCTAssertTrue(todayRecord.isToday())
        
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let yesterdayRecord = HelpRecord(id: UUID(), childId: UUID(), helpTaskId: UUID(), recordedAt: yesterday)
        XCTAssertFalse(yesterdayRecord.isToday())
        
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let tomorrowRecord = HelpRecord(id: UUID(), childId: UUID(), helpTaskId: UUID(), recordedAt: tomorrow)
        XCTAssertFalse(tomorrowRecord.isToday())
    }
    
    func testFilterRecordsForChildInCurrentMonth() {
        let childId = UUID()
        let otherChildId = UUID()
        let helpTaskId = UUID()
        let calendar = Calendar.current
        let now = Date()
        
        let currentMonthRecord1 = HelpRecord(id: UUID(), childId: childId, helpTaskId: helpTaskId, recordedAt: now)
        let currentMonthRecord2 = HelpRecord(id: UUID(), childId: childId, helpTaskId: helpTaskId, recordedAt: calendar.date(byAdding: .day, value: -5, to: now)!)
        let otherChildRecord = HelpRecord(id: UUID(), childId: otherChildId, helpTaskId: helpTaskId, recordedAt: now)
        let previousMonthRecord = HelpRecord(id: UUID(), childId: childId, helpTaskId: helpTaskId, recordedAt: calendar.date(byAdding: .month, value: -1, to: now)!)
        
        let allRecords = [currentMonthRecord1, currentMonthRecord2, otherChildRecord, previousMonthRecord]
        let filteredRecords = HelpRecord.filterForChildInCurrentMonth(records: allRecords, childId: childId)
        
        XCTAssertEqual(filteredRecords.count, 2)
        XCTAssertTrue(filteredRecords.contains(currentMonthRecord1))
        XCTAssertTrue(filteredRecords.contains(currentMonthRecord2))
        XCTAssertFalse(filteredRecords.contains(otherChildRecord))
        XCTAssertFalse(filteredRecords.contains(previousMonthRecord))
    }
}