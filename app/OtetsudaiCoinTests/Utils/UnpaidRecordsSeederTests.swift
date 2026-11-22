#if DEBUG
import XCTest
@testable import OtetsudaiCoin

/// 検証撮影用の未払い記録の投入 (Issue #309)。
/// `--seed-unpaid-records 1|2` は `--in-memory-store` と一緒のときだけ効き、永続ストアを汚さない。
final class UnpaidRecordsSeederTests: XCTestCase {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return cal
    }()

    private let childA = UUID()
    private let childB = UUID()
    private let task = UUID()

    // MARK: - childCount

    func test_childCount_requiresInMemoryStore() {
        XCTAssertNil(UnpaidRecordsSeeder.childCount(arguments: ["app", "--seed-unpaid-records", "2"]))
    }

    func test_childCount_acceptsOneAndTwo() {
        XCTAssertEqual(
            UnpaidRecordsSeeder.childCount(arguments: ["app", "--in-memory-store", "--seed-unpaid-records", "1"]),
            1
        )
        XCTAssertEqual(
            UnpaidRecordsSeeder.childCount(arguments: ["app", "--seed-unpaid-records", "2", "--in-memory-store"]),
            2
        )
    }

    func test_childCount_rejectsOtherValues() {
        let tails: [[String]] = [["--seed-unpaid-records"], ["--seed-unpaid-records", "3"], ["--seed-unpaid-records", "x"], []]
        for tail in tails {
            XCTAssertNil(UnpaidRecordsSeeder.childCount(arguments: ["app", "--in-memory-store"] + tail), "\(tail)")
        }
    }

    // MARK: - records

    func test_records_twoPastMonthsThreeEach() {
        let now = date(2026, 11, 22, hour: 12)
        let records = UnpaidRecordsSeeder.records(childIds: [childA, childB], helpTaskId: task, now: now, calendar: calendar)

        XCTAssertEqual(records.count, 12)
        XCTAssertTrue(records.allSatisfy { $0.helpTaskId == task })
        for child in [childA, childB] {
            let mine = records.filter { $0.childId == child }
            XCTAssertEqual(count(mine, year: 2026, month: 10), 3, "child \(child)")
            XCTAssertEqual(count(mine, year: 2026, month: 9), 3, "child \(child)")
            XCTAssertEqual(count(mine, year: 2026, month: 11), 0, "child \(child)")
        }
        XCTAssertEqual(Set(records.map(\.id)).count, 12, "record ids must be unique")
    }

    func test_records_crossesYearBoundary() {
        let now = date(2026, 1, 15, hour: 12)
        let records = UnpaidRecordsSeeder.records(childIds: [childA], helpTaskId: task, now: now, calendar: calendar)

        XCTAssertEqual(records.count, 6)
        XCTAssertEqual(count(records, year: 2025, month: 12), 3)
        XCTAssertEqual(count(records, year: 2025, month: 11), 3)
        XCTAssertEqual(count(records, year: 2026, month: 1), 0)
    }

    // MARK: - Helpers

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func count(_ records: [HelpRecord], year: Int, month: Int) -> Int {
        records.filter {
            let c = calendar.dateComponents([.year, .month], from: $0.recordedAt)
            return c.year == year && c.month == month
        }.count
    }
}
#endif
