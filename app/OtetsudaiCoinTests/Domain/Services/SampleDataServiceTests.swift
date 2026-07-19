#if DEBUG
import XCTest
@testable import OtetsudaiCoin

@MainActor
final class SampleDataServiceTests: XCTestCase {
    func testSampleHelpTasksHaveSequentialSortOrders() {
        let tasks = SampleDataService.sampleHelpTasks()
        XCTAssertEqual(
            tasks.map(\.sortOrder),
            Array(0..<tasks.count),
            "sortOrder は挿入順の 0 始まり連番であるべき: \(tasks.map { ($0.name, $0.sortOrder) })"
        )
    }

    func testSampleHelpTasksHaveDistinctSortOrders() {
        let tasks = SampleDataService.sampleHelpTasks()
        XCTAssertFalse(tasks.isEmpty, "サンプルタスクが空")
        XCTAssertEqual(
            Set(tasks.map(\.sortOrder)).count,
            tasks.count,
            "sortOrder が重複している: \(tasks.map { ($0.name, $0.sortOrder) })"
        )
    }

    /// サンプルタスク名は defaultIconsByName に無いため、明示 icon が無いと
    /// demo で全カードが ✨ フォールバックになる (#177 項目2)。
    func testSampleHelpTasksHaveExplicitIcons() {
        let tasks = SampleDataService.sampleHelpTasks()
        XCTAssertFalse(tasks.isEmpty, "サンプルタスクが空")
        for task in tasks {
            XCTAssertNotNil(task.icon, "\(task.name) に明示 icon が無い")
            XCTAssertNotEqual(task.displayIcon, "✨", "\(task.name) が汎用 ✨ にフォールバックしている")
        }
    }
}
#endif
