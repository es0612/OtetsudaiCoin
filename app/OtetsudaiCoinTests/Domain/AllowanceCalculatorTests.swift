import XCTest
@testable import OtetsudaiCoin

final class AllowanceCalculatorTests: XCTestCase {

    func testCalculateMonthlyAllowanceWithNoRecords() {
        let calculator = AllowanceCalculator()
        let records: [HelpRecord] = []
        
        let allowance = calculator.calculateMonthlyAllowance(records: records)
        
        XCTAssertEqual(allowance, 0)
    }
    
    func testCalculateMonthlyAllowanceWithSingleRecord() {
        let calculator = AllowanceCalculator()
        let record = HelpRecord(
            id: UUID(),
            childId: UUID(),
            helpTaskId: UUID(),
            recordedAt: Date()
        )
        
        let allowance = calculator.calculateMonthlyAllowance(records: [record])
        
        XCTAssertEqual(allowance, 100)
    }
    
    func testCalculateMonthlyAllowanceWithMultipleRecords() {
        let calculator = AllowanceCalculator()
        let childId = UUID()
        let helpTaskId = UUID()
        
        let records = [
            HelpRecord(id: UUID(), childId: childId, helpTaskId: helpTaskId, recordedAt: Date()),
            HelpRecord(id: UUID(), childId: childId, helpTaskId: helpTaskId, recordedAt: Date()),
            HelpRecord(id: UUID(), childId: childId, helpTaskId: helpTaskId, recordedAt: Date())
        ]
        
        let allowance = calculator.calculateMonthlyAllowance(records: records)
        
        XCTAssertEqual(allowance, 300)
    }
    
    func testCalculateConsecutiveDaysWithNoRecords() {
        let calculator = AllowanceCalculator()
        let records: [HelpRecord] = []
        
        let consecutiveDays = calculator.calculateConsecutiveDays(records: records)
        
        XCTAssertEqual(consecutiveDays, 0)
    }
    
    func testCalculateConsecutiveDaysWithToday() {
        let calculator = AllowanceCalculator()
        let childId = UUID()
        let helpTaskId = UUID()
        let today = Date()
        
        let record = HelpRecord(id: UUID(), childId: childId, helpTaskId: helpTaskId, recordedAt: today)
        
        let consecutiveDays = calculator.calculateConsecutiveDays(records: [record])
        
        XCTAssertEqual(consecutiveDays, 1)
    }
    
    func testCalculateConsecutiveDaysWithMultipleDays() {
        let calculator = AllowanceCalculator()
        let childId = UUID()
        let helpTaskId = UUID()
        let calendar = Calendar.current
        let today = Date()
        
        let records = [
            HelpRecord(id: UUID(), childId: childId, helpTaskId: helpTaskId, recordedAt: today),
            HelpRecord(id: UUID(), childId: childId, helpTaskId: helpTaskId, recordedAt: calendar.date(byAdding: .day, value: -1, to: today)!),
            HelpRecord(id: UUID(), childId: childId, helpTaskId: helpTaskId, recordedAt: calendar.date(byAdding: .day, value: -2, to: today)!)
        ]
        
        let consecutiveDays = calculator.calculateConsecutiveDays(records: records)
        
        XCTAssertEqual(consecutiveDays, 3)
    }
    
    func testCalculateConsecutiveDaysWithGapInDays() {
        let calculator = AllowanceCalculator()
        let childId = UUID()
        let helpTaskId = UUID()
        let calendar = Calendar.current
        let today = Date()
        
        let records = [
            HelpRecord(id: UUID(), childId: childId, helpTaskId: helpTaskId, recordedAt: today),
            HelpRecord(id: UUID(), childId: childId, helpTaskId: helpTaskId, recordedAt: calendar.date(byAdding: .day, value: -1, to: today)!),
            HelpRecord(id: UUID(), childId: childId, helpTaskId: helpTaskId, recordedAt: calendar.date(byAdding: .day, value: -3, to: today)!)
        ]
        
        let consecutiveDays = calculator.calculateConsecutiveDays(records: records)
        
        XCTAssertEqual(consecutiveDays, 2)
    }
    
    func testCalculateConsecutiveDaysWithoutToday() {
        let calculator = AllowanceCalculator()
        let childId = UUID()
        let helpTaskId = UUID()
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        
        let record = HelpRecord(id: UUID(), childId: childId, helpTaskId: helpTaskId, recordedAt: yesterday)
        
        let consecutiveDays = calculator.calculateConsecutiveDays(records: [record])
        
        XCTAssertEqual(consecutiveDays, 0)
    }
}