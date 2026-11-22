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

    // MARK: - targetChildIds

    /// `findAll()` は並び順を決めないので、名前順で選ぶ。実行ごとに違う子に入ると、
    /// before/after の比較で verify-31 が「太郎 / 花子」と入れ替わって偽の差分になる (#309 review)。
    func test_targetChildIds_picksByNameRegardlessOfFetchOrder() {
        let taro = Child(id: childA, name: "太郎", themeColor: "#E8590C")
        let hanako = Child(id: childB, name: "花子", themeColor: "#099268")

        XCTAssertEqual(UnpaidRecordsSeeder.targetChildIds([hanako, taro], count: 1), [childA])
        XCTAssertEqual(UnpaidRecordsSeeder.targetChildIds([taro, hanako], count: 1), [childA])
        XCTAssertEqual(UnpaidRecordsSeeder.targetChildIds([hanako, taro], count: 2), [childA, childB])
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
