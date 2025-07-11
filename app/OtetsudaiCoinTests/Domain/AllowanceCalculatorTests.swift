import XCTest
@testable import OtetsudaiCoin

final class AllowanceCalculatorTests: XCTestCase {

    func testCalculateMonthlyAllowanceWithNoRecords() {
        let calculator = AllowanceCalculator()
        let records: [HelpRecord] = []
        let tasks: [HelpTask] = []
        
        let allowance = calculator.calculateMonthlyAllowance(records: records, tasks: tasks)
        
        XCTAssertEqual(allowance, 0)
    }
    
    func testCalculateMonthlyAllowanceWithSingleRecord() {
        let calculator = AllowanceCalculator()
        let helpTaskId = UUID()
        let record = HelpRecord(
            id: UUID(),
            childId: UUID(),
            helpTaskId: helpTaskId,
            recordedAt: Date()
        )
        let task = HelpTask(id: helpTaskId, name: "テストタスク", isActive: true, coinRate: 10)
        
        let allowance = calculator.calculateMonthlyAllowance(records: [record], tasks: [task])
        
        XCTAssertEqual(allowance, 10)
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
        let task = HelpTask(id: helpTaskId, name: "テストタスク", isActive: true, coinRate: 10)
        
        let allowance = calculator.calculateMonthlyAllowance(records: records, tasks: [task])
        
        XCTAssertEqual(allowance, 30)
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