import XCTest
@testable import OtetsudaiCoin

@MainActor
final class TaskManagementViewModelTests: XCTestCase {
    private var viewModel: TaskManagementViewModel!
    private var mockTaskRepository: MockHelpTaskRepository!
    private var mockRecordRepository: MockHelpRecordRepository!

    // 固定日。相対日付 (Date() ± N日) は月初 flake を生むため使わない
    private let fixedNow = Date(timeIntervalSince1970: 1_781_316_000) // 2026-06-13T10:00:00Z

    private func makeTask(name: String, sortOrder: Int, id: UUID = UUID()) -> HelpTask {
        HelpTask(id: id, name: name, isActive: true, coinRate: 10, sortOrder: sortOrder)
    }

    private func makeRecord(taskId: UUID, daysAgo: Int) -> HelpRecord {
        HelpRecord(
            id: UUID(),
            childId: UUID(),
            helpTaskId: taskId,
            recordedAt: fixedNow.addingTimeInterval(TimeInterval(-daysAgo * 24 * 60 * 60))
        )
    }

    override func setUp() {
        super.setUp()
        mockTaskRepository = MockHelpTaskRepository()
        mockRecordRepository = MockHelpRecordRepository()
        viewModel = TaskManagementViewModel(
            helpTaskRepository: mockTaskRepository,
            helpRecordRepository: mockRecordRepository
        )
    }

    override func tearDown() {
        viewModel = nil
        mockTaskRepository = nil
        mockRecordRepository = nil
        super.tearDown()
    }

    // MARK: - loadTasks

    func testLoadTasksUsesRepositoryOrderWithoutReSorting() async {
        // repository は (sortOrder, name) ソート済みを返す契約。ViewModel が名前順に再ソートしないこと
        mockTaskRepository.tasks = [
            makeTask(name: "ん片付け", sortOrder: 0),
            makeTask(name: "あ食器", sortOrder: 1)
        ]

        await viewModel.loadTasks()

        XCTAssertEqual(viewModel.tasks.map(\.name), ["ん片付け", "あ食器"])
    }

    // MARK: - moveTasks (#122)

    func testMoveTasksReordersAndPersists() async {
        let taskA = makeTask(name: "A", sortOrder: 0)
        let taskB = makeTask(name: "B", sortOrder: 1)
        let taskC = makeTask(name: "C", sortOrder: 2)
        mockTaskRepository.tasks = [taskA, taskB, taskC]
        await viewModel.loadTasks()

        // C を先頭へ移動
        await viewModel.moveTasks(from: IndexSet(integer: 2), to: 0)

        XCTAssertEqual(viewModel.tasks.map(\.name), ["C", "A", "B"])
        XCTAssertEqual(mockTaskRepository.lastOrderedIds, [taskC.id, taskA.id, taskB.id])
    }

    func testMoveTasksOnErrorSetsErrorMessageAndReloads() async {
        let taskA = makeTask(name: "A", sortOrder: 0)
        let taskB = makeTask(name: "B", sortOrder: 1)
        mockTaskRepository.tasks = [taskA, taskB]
        await viewModel.loadTasks()
        // write (updateSortOrders) だけ失敗し read (findAll) は成功する現実的ケース
        mockTaskRepository.shouldThrowErrorOnUpdateSortOrders = true

        await viewModel.moveTasks(from: IndexSet(integer: 1), to: 0)

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.tasks.map(\.name), ["A", "B"]) // DB 状態へ巻き戻し
    }

    // MARK: - sortByFrequency (#123)

    func testSortByFrequencyOrdersByRecentRecordCountDescending() async {
        let rare = makeTask(name: "あレア", sortOrder: 0)
        let popular = makeTask(name: "ん人気", sortOrder: 1)
        mockTaskRepository.tasks = [rare, popular]
        mockRecordRepository.records = [
            makeRecord(taskId: popular.id, daysAgo: 1),
            makeRecord(taskId: popular.id, daysAgo: 2),
            makeRecord(taskId: rare.id, daysAgo: 3)
        ]
        await viewModel.loadTasks()

        await viewModel.sortByFrequency(now: fixedNow)

        XCTAssertEqual(viewModel.tasks.map(\.name), ["ん人気", "あレア"],
                       "rendered: \(viewModel.tasks.map { ($0.name, $0.sortOrder) })")
        XCTAssertEqual(mockTaskRepository.lastOrderedIds, [popular.id, rare.id])
        XCTAssertNotNil(viewModel.successMessage)
    }

    func testSortByFrequencyExcludesRecordsOlderThan90Days() async {
        let old = makeTask(name: "あ昔人気", sortOrder: 0)
        let recent = makeTask(name: "ん最近", sortOrder: 1)
        mockTaskRepository.tasks = [old, recent]
        mockRecordRepository.records = [
            // 91日以上前 × 3件 → 窓外で 0 件扱い
            makeRecord(taskId: old.id, daysAgo: 91),
            makeRecord(taskId: old.id, daysAgo: 92),
            makeRecord(taskId: old.id, daysAgo: 93),
            // 89日前 × 1件 → 窓内
            makeRecord(taskId: recent.id, daysAgo: 89)
        ]
        await viewModel.loadTasks()

        await viewModel.sortByFrequency(now: fixedNow)

        XCTAssertEqual(viewModel.tasks.map(\.name), ["ん最近", "あ昔人気"])
    }

    func testSortByFrequencyBreaksTiesByName() async {
        let nameB = makeTask(name: "B", sortOrder: 0)
        let nameA = makeTask(name: "A", sortOrder: 1)
        mockTaskRepository.tasks = [nameB, nameA]
        // 両方 0 件 → 名前順
        await viewModel.loadTasks()

        await viewModel.sortByFrequency(now: fixedNow)

        XCTAssertEqual(viewModel.tasks.map(\.name), ["A", "B"])
    }

    func testSortByFrequencyOnFetchErrorSetsErrorAndDoesNotPersist() async {
        mockTaskRepository.tasks = [makeTask(name: "A", sortOrder: 0)]
        await viewModel.loadTasks()
        mockRecordRepository.shouldThrowError = true

        await viewModel.sortByFrequency(now: fixedNow)

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(mockTaskRepository.updateSortOrdersCallCount, 0)
    }

    // MARK: - sortOrder 保持/採番

    func testAddTaskAppendsToEndWithMaxSortOrderPlusOne() async {
        mockTaskRepository.tasks = [
            makeTask(name: "既存1", sortOrder: 0),
            makeTask(name: "既存2", sortOrder: 5)
        ]
        await viewModel.loadTasks()

        await viewModel.addTask(name: "新規", coinRate: 10)

        let saved = mockTaskRepository.tasks.first { $0.name == "新規" }
        XCTAssertEqual(saved?.sortOrder, 6)
    }

    func testToggleTaskStatusPreservesSortOrder() async {
        let task = makeTask(name: "対象", sortOrder: 3)
        mockTaskRepository.tasks = [task]
        await viewModel.loadTasks()

        await viewModel.toggleTaskStatus(task)

        let updated = mockTaskRepository.tasks.first { $0.id == task.id }
        XCTAssertEqual(updated?.isActive, false)
        XCTAssertEqual(updated?.sortOrder, 3)
    }

    func testUpdateTaskPreservesSortOrderWhenCallerPassesIt() async {
        // 編集フォーム経路 (TaskFormView.updateTask 相当) の sortOrder 保持を gate する
        let task = makeTask(name: "編集前", sortOrder: 4)
        mockTaskRepository.tasks = [task]
        await viewModel.loadTasks()

        let edited = HelpTask(id: task.id, name: "編集後", isActive: true, coinRate: 15, sortOrder: task.sortOrder)
        await viewModel.updateTask(edited)

        let updated = mockTaskRepository.tasks.first { $0.id == task.id }
        XCTAssertEqual(updated?.sortOrder, 4)
        XCTAssertEqual(updated?.name, "編集後")
    }
}
