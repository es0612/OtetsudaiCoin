import XCTest
@testable import OtetsudaiCoin

final class UnpaidAllowanceDetectorServiceTests: XCTestCase {
    
    var detector: UnpaidAllowanceDetectorService!
    var calendar: Calendar!
    
    override func setUp() {
        super.setUp()
        detector = UnpaidAllowanceDetectorService()
        calendar = Calendar.current
    }
    
    override func tearDown() {
        detector = nil
        calendar = nil
        super.tearDown()
    }
    
    func testDetectUnpaidPeriodsWithNoData() {
        let childId = UUID()
        let records: [HelpRecord] = []
        let payments: [AllowancePayment] = []
        let tasks: [HelpTask] = []
        
        let unpaidPeriods = detector.detectUnpaidPeriods(
            childId: childId,
            helpRecords: records,
            payments: payments,
            tasks: tasks
        )
        
        XCTAssertEqual(unpaidPeriods.count, 0)
    }
    
    func testDetectUnpaidPeriodsWithCurrentMonthOnly() {
        let childId = UUID()
        let helpTaskId = UUID()
        let now = Date()
        
        let record = HelpRecord(
            id: UUID(),
            childId: childId,
            helpTaskId: helpTaskId,
            recordedAt: now
        )
        let task = HelpTask(id: helpTaskId, name: "テストタスク", isActive: true, coinRate: 10)
        
        let unpaidPeriods = detector.detectUnpaidPeriods(
            childId: childId,
            helpRecords: [record],
            payments: [],
            tasks: [task]
        )
        
        XCTAssertEqual(unpaidPeriods.count, 0)
    }
    
    func testDetectUnpaidPeriodsWithLastMonth() {
        let childId = UUID()
        let helpTaskId = UUID()
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date())!
        
        let record = HelpRecord(
            id: UUID(),
            childId: childId,
            helpTaskId: helpTaskId,
            recordedAt: lastMonth
        )
        let task = HelpTask(id: helpTaskId, name: "テストタスク", isActive: true, coinRate: 10)
        
        let unpaidPeriods = detector.detectUnpaidPeriods(
            childId: childId,
            helpRecords: [record],
            payments: [],
            tasks: [task]
        )
        
        XCTAssertEqual(unpaidPeriods.count, 1)
        let unpaidPeriod = unpaidPeriods.first!
        XCTAssertEqual(unpaidPeriod.childId, childId)
        XCTAssertEqual(unpaidPeriod.expectedAmount, 10)
        
        let lastMonthComponents = calendar.dateComponents([.year, .month], from: lastMonth)
        XCTAssertEqual(unpaidPeriod.year, lastMonthComponents.year!)
        XCTAssertEqual(unpaidPeriod.month, lastMonthComponents.month!)
    }
    
    func testDetectUnpaidPeriodsWithMultipleUnpaidMonths() {
        let childId = UUID()
        let helpTaskId = UUID()
        let twoMonthsAgo = calendar.date(byAdding: .month, value: -2, to: Date())!
        let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: Date())!
        
        let records = [
            HelpRecord(id: UUID(), childId: childId, helpTaskId: helpTaskId, recordedAt: twoMonthsAgo),
            HelpRecord(id: UUID(), childId: childId, helpTaskId: helpTaskId, recordedAt: threeMonthsAgo)
        ]
        let task = HelpTask(id: helpTaskId, name: "テストタスク", isActive: true, coinRate: 10)
        
        let unpaidPeriods = detector.detectUnpaidPeriods(
            childId: childId,
            helpRecords: records,
            payments: [],
            tasks: [task]
        )
        
        XCTAssertEqual(unpaidPeriods.count, 2)
        
        let sortedPeriods = unpaidPeriods.sorted { period1, period2 in
            if period1.year != period2.year {
                return period1.year > period2.year
            }
            return period1.month > period2.month
        }
        
        let twoMonthsAgoComponents = calendar.dateComponents([.year, .month], from: twoMonthsAgo)
        let threeMonthsAgoComponents = calendar.dateComponents([.year, .month], from: threeMonthsAgo)
        
        XCTAssertEqual(sortedPeriods[0].year, twoMonthsAgoComponents.year!)
        XCTAssertEqual(sortedPeriods[0].month, twoMonthsAgoComponents.month!)
        XCTAssertEqual(sortedPeriods[1].year, threeMonthsAgoComponents.year!)
        XCTAssertEqual(sortedPeriods[1].month, threeMonthsAgoComponents.month!)
    }
    
    func testDetectUnpaidPeriodsWithPartialPayment() {
        let childId = UUID()
        let helpTaskId = UUID()
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date())!
        let lastMonthComponents = calendar.dateComponents([.year, .month], from: lastMonth)
        
        let records = [
            HelpRecord(id: UUID(), childId: childId, helpTaskId: helpTaskId, recordedAt: lastMonth),
            HelpRecord(id: UUID(), childId: childId, helpTaskId: helpTaskId, recordedAt: lastMonth)
        ]
        let task = HelpTask(id: helpTaskId, name: "テストタスク", isActive: true, coinRate: 10)
        
        let partialPayment = AllowancePayment(
            id: UUID(),
            childId: childId,
            amount: 10,
            month: lastMonthComponents.month!,
            year: lastMonthComponents.year!,
            paidAt: Date()
        )
        
        let unpaidPeriods = detector.detectUnpaidPeriods(
            childId: childId,
            helpRecords: records,
            payments: [partialPayment],
            tasks: [task]
        )
        
        XCTAssertEqual(unpaidPeriods.count, 1)
        let unpaidPeriod = unpaidPeriods.first!
        XCTAssertEqual(unpaidPeriod.expectedAmount, 10)
    }
    
    func testDetectUnpaidPeriodsWithFullPayment() {
        let childId = UUID()
        let helpTaskId = UUID()
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date())!
        let lastMonthComponents = calendar.dateComponents([.year, .month], from: lastMonth)
        
        let record = HelpRecord(
            id: UUID(),
            childId: childId,
            helpTaskId: helpTaskId,
            recordedAt: lastMonth
        )
        let task = HelpTask(id: helpTaskId, name: "テストタスク", isActive: true, coinRate: 10)
        
        let fullPayment = AllowancePayment(
            id: UUID(),
            childId: childId,
            amount: 10,
            month: lastMonthComponents.month!,
            year: lastMonthComponents.year!,
            paidAt: Date()
        )
        
        let unpaidPeriods = detector.detectUnpaidPeriods(
            childId: childId,
            helpRecords: [record],
            payments: [fullPayment],
            tasks: [task]
        )
        
        XCTAssertEqual(unpaidPeriods.count, 0)
    }
    
    func testDetectUnpaidPeriodsExcludesCurrentMonth() {
        let childId = UUID()
        let helpTaskId = UUID()
        let now = Date()
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date())!
        
        let records = [
            HelpRecord(id: UUID(), childId: childId, helpTaskId: helpTaskId, recordedAt: now),
            HelpRecord(id: UUID(), childId: childId, helpTaskId: helpTaskId, recordedAt: lastMonth)
        ]
        let task = HelpTask(id: helpTaskId, name: "テストタスク", isActive: true, coinRate: 10)
        
        let unpaidPeriods = detector.detectUnpaidPeriods(
            childId: childId,
            helpRecords: records,
            payments: [],
            tasks: [task]
        )
        
        XCTAssertEqual(unpaidPeriods.count, 1)
        
        let lastMonthComponents = calendar.dateComponents([.year, .month], from: lastMonth)
        let unpaidPeriod = unpaidPeriods.first!
        XCTAssertEqual(unpaidPeriod.year, lastMonthComponents.year!)
        XCTAssertEqual(unpaidPeriod.month, lastMonthComponents.month!)
    }
}