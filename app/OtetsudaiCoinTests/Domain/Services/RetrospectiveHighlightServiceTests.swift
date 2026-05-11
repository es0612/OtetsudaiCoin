import XCTest
@testable import OtetsudaiCoin

final class RetrospectiveHighlightServiceTests: XCTestCase {

    private var service: RetrospectiveHighlightService!

    override func setUp() {
        super.setUp()
        service = RetrospectiveHighlightService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // 共通ヘルパー: 指定の年月日の HelpRecord を作る
    private func record(year: Int, month: Int, day: Int, taskId: UUID) -> HelpRecord {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 12
        let date = Calendar.current.date(from: comps)!
        return HelpRecord(id: UUID(), childId: UUID(), helpTaskId: taskId, recordedAt: date)
    }

    func testEmptyRecordsReturnsAllZero() {
        let result = service.compute(records: [], tasks: [])
        XCTAssertEqual(result.consecutiveDayStreak, 0)
        XCTAssertNil(result.topDay)
        XCTAssertNil(result.topTaskName)
    }

    func testSingleRecord() {
        let taskId = UUID()
        let task = HelpTask(id: taskId, name: "皿洗い", isActive: true)
        let r = record(year: 2026, month: 5, day: 15, taskId: taskId)

        let result = service.compute(records: [r], tasks: [task])

        XCTAssertEqual(result.consecutiveDayStreak, 1)
        XCTAssertNotNil(result.topDay)
        XCTAssertEqual(result.topDay?.count, 1)
        XCTAssertEqual(result.topTaskName, "皿洗い")
    }

    func testConsecutiveStreak() {
        let taskId = UUID()
        let task = HelpTask(id: taskId, name: "皿洗い", isActive: true)
        let days = [1, 2, 3, 5, 6, 7, 8]
        let records = days.map { record(year: 2026, month: 5, day: $0, taskId: taskId) }

        let result = service.compute(records: records, tasks: [task])

        XCTAssertEqual(result.consecutiveDayStreak, 4, "最大連続が 4 日でない")
    }

    func testTopDayWithTie() {
        let taskId = UUID()
        let task = HelpTask(id: taskId, name: "皿洗い", isActive: true)
        let records = [
            record(year: 2026, month: 5, day: 10, taskId: taskId),
            record(year: 2026, month: 5, day: 10, taskId: taskId),
            record(year: 2026, month: 5, day: 20, taskId: taskId),
            record(year: 2026, month: 5, day: 20, taskId: taskId)
        ]

        let result = service.compute(records: records, tasks: [task])

        let day = Calendar.current.component(.day, from: result.topDay!.date)
        XCTAssertEqual(day, 20, "同件数なら最新の日を返すべき")
        XCTAssertEqual(result.topDay?.count, 2)
    }

    func testTopTaskName() {
        let dishesId = UUID()
        let laundryId = UUID()
        let dishes = HelpTask(id: dishesId, name: "皿洗い", isActive: true)
        let laundry = HelpTask(id: laundryId, name: "洗濯", isActive: true)
        let records = [
            record(year: 2026, month: 5, day: 1, taskId: dishesId),
            record(year: 2026, month: 5, day: 2, taskId: dishesId),
            record(year: 2026, month: 5, day: 3, taskId: dishesId),
            record(year: 2026, month: 5, day: 4, taskId: laundryId)
        ]

        let result = service.compute(records: records, tasks: [dishes, laundry])

        XCTAssertEqual(result.topTaskName, "皿洗い")
    }

    func testTopTaskNameWithTie() {
        let dishesId = UUID()
        let laundryId = UUID()
        let dishes = HelpTask(id: dishesId, name: "皿洗い", isActive: true)
        let laundry = HelpTask(id: laundryId, name: "洗濯", isActive: true)
        let records = [
            record(year: 2026, month: 5, day: 1, taskId: dishesId),
            record(year: 2026, month: 5, day: 2, taskId: dishesId),
            record(year: 2026, month: 5, day: 10, taskId: laundryId),
            record(year: 2026, month: 5, day: 20, taskId: laundryId)
        ]

        let result = service.compute(records: records, tasks: [dishes, laundry])

        XCTAssertEqual(result.topTaskName, "洗濯", "同件数なら最新の記録のタスクを返す")
    }

    func testIgnoresAcrossMonthBoundary() {
        let taskId = UUID()
        let task = HelpTask(id: taskId, name: "皿洗い", isActive: true)
        let records = [
            record(year: 2026, month: 4, day: 30, taskId: taskId),
            record(year: 2026, month: 5, day: 1, taskId: taskId)
        ]

        let result = service.compute(records: records, tasks: [task])

        XCTAssertEqual(result.consecutiveDayStreak, 1, "月またぎは連続にカウントしない")
    }
}
