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
    
    // #311: 今日未記録でも昨日までの連続を出す
    func testCalculateConsecutiveDaysYesterdayOnly() {
        let calculator = AllowanceCalculator()
        let childId = UUID()
        let helpTaskId = UUID()
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        
        let record = HelpRecord(id: UUID(), childId: childId, helpTaskId: helpTaskId, recordedAt: yesterday)
        
        let consecutiveDays = calculator.calculateConsecutiveDays(records: [record])
        
        XCTAssertEqual(consecutiveDays, 1)
    }
    
    // MARK: - #311 固定日付（正午）
    
    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }
    
    private func records(_ dates: [Date]) -> [HelpRecord] {
        let childId = UUID()
        let taskId = UUID()
        return dates.map { HelpRecord(id: UUID(), childId: childId, helpTaskId: taskId, recordedAt: $0) }
    }
    
    func testConsecutiveDays_crossesMonth_countsFromToday() {
        let rs = records([day(2026, 10, 30), day(2026, 10, 31), day(2026, 11, 1), day(2026, 11, 2)])
        XCTAssertEqual(AllowanceCalculator().calculateConsecutiveDays(records: rs, today: day(2026, 11, 2)), 4)
    }
    
    func testConsecutiveDays_todayNotRecorded_countsFromYesterday() {
        let rs = records([day(2026, 10, 30), day(2026, 10, 31), day(2026, 11, 1), day(2026, 11, 2)])
        XCTAssertEqual(AllowanceCalculator().calculateConsecutiveDays(records: rs, today: day(2026, 11, 3)), 4)
    }
    
    func testConsecutiveDays_lastRecordTwoDaysAgo_isZero() {
        let rs = records([day(2026, 10, 30), day(2026, 10, 31), day(2026, 11, 1), day(2026, 11, 2)])
        XCTAssertEqual(AllowanceCalculator().calculateConsecutiveDays(records: rs, today: day(2026, 11, 4)), 0)
    }
    
    func testConsecutiveDays_crossesYear() {
        let rs = records([day(2026, 12, 30), day(2026, 12, 31), day(2027, 1, 1)])
        XCTAssertEqual(AllowanceCalculator().calculateConsecutiveDays(records: rs, today: day(2027, 1, 1)), 3)
    }
    
    func testConsecutiveDays_sameDayTwice_countsOnce() {
        let rs = records([day(2026, 11, 1), day(2026, 11, 1), day(2026, 11, 2)])
        XCTAssertEqual(AllowanceCalculator().calculateConsecutiveDays(records: rs, today: day(2026, 11, 2)), 2)
    }
    
    func testConsecutiveDays_unsortedRecords() {
        let rs = records([day(2026, 11, 2), day(2026, 10, 31), day(2026, 11, 1)])
        XCTAssertEqual(AllowanceCalculator().calculateConsecutiveDays(records: rs, today: day(2026, 11, 2)), 3)
    }
}
