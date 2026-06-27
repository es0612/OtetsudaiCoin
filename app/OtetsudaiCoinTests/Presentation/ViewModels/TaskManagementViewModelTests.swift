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

    func testToggleAfterMoveDoesNotResurrectStaleSortOrder() async {
        let taskA = makeTask(name: "A", sortOrder: 0)
        let taskB = makeTask(name: "B", sortOrder: 1)
        let taskC = makeTask(name: "C", sortOrder: 2)
        mockTaskRepository.tasks = [taskA, taskB, taskC]
        await viewModel.loadTasks()

        await viewModel.moveTasks(from: IndexSet(integer: 2), to: 0) // C を先頭へ
        guard let movedC = viewModel.tasks.first else { return XCTFail("tasks empty") }
        await viewModel.toggleTaskStatus(movedC) // 直後のトグルが stale sortOrder を書き戻さないこと

        await viewModel.loadTasks()
        XCTAssertEqual(viewModel.tasks.map(\.name), ["C", "A", "B"],
                       "rendered: \(viewModel.tasks.map { ($0.name, $0.sortOrder) })")
    }

    func testReorderTasksUpdatesInMemoryOrderSynchronouslyWithoutPersisting() async {
        // onMove 経路: 同期 reorder のみ呼ぶと、永続化前に即座に tasks が並べ替わる (#130-②)
        let taskA = makeTask(name: "A", sortOrder: 0)
        let taskB = makeTask(name: "B", sortOrder: 1)
        let taskC = makeTask(name: "C", sortOrder: 2)
        mockTaskRepository.tasks = [taskA, taskB, taskC]
        await viewModel.loadTasks()

        let reordered = viewModel.reorderTasks(from: IndexSet(integer: 2), to: 0)

        XCTAssertEqual(viewModel.tasks.map(\.name), ["C", "A", "B"], "reorderTasks は同期で in-memory 順序を更新すべき")
        XCTAssertEqual(reordered.map(\.name), ["C", "A", "B"])
        XCTAssertEqual(mockTaskRepository.updateSortOrdersCallCount, 0, "reorderTasks 単独では永続化しない")
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

    func testCanSortByFrequencyReflectsTaskCount() async {
        XCTAssertFalse(viewModel.canSortByFrequency, "0 件では並べ替え不可")

        mockTaskRepository.tasks = [makeTask(name: "A", sortOrder: 0)]
        await viewModel.loadTasks()
        XCTAssertFalse(viewModel.canSortByFrequency, "1 件では並べ替え不可")

        mockTaskRepository.tasks = [
            makeTask(name: "A", sortOrder: 0),
            makeTask(name: "B", sortOrder: 1)
        ]
        await viewModel.loadTasks()
        XCTAssertTrue(viewModel.canSortByFrequency, "2 件以上で並べ替え可")
    }

    func testSortByFrequencyIsNoOpWhenSingleTask() async {
        mockTaskRepository.tasks = [makeTask(name: "A", sortOrder: 0)]
        await viewModel.loadTasks()

        await viewModel.sortByFrequency(now: fixedNow)

        XCTAssertEqual(mockTaskRepository.updateSortOrdersCallCount, 0, "1 件では永続化しない")
        XCTAssertNil(viewModel.successMessage, "1 件では成功メッセージを出さない")
    }

    func testSortByFrequencyIsNoOpWhenNoTasks() async {
        // 0 件 (loadTasks せず空のまま) でも guard で短絡し副作用なし
        await viewModel.sortByFrequency(now: fixedNow)

        XCTAssertEqual(mockTaskRepository.updateSortOrdersCallCount, 0, "0 件では永続化しない")
        XCTAssertNil(viewModel.successMessage, "0 件では成功メッセージを出さない")
    }

    func testSortByFrequencyOnFetchErrorSetsErrorAndDoesNotPersist() async {
        // 2 件以上で canSortByFrequency=true にしてからフェッチエラーを注入する
        mockTaskRepository.tasks = [makeTask(name: "A", sortOrder: 0), makeTask(name: "B", sortOrder: 1)]
        await viewModel.loadTasks()
        mockRecordRepository.shouldThrowError = true

        await viewModel.sortByFrequency(now: fixedNow)

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(mockTaskRepository.updateSortOrdersCallCount, 0)
    }

    func testSortByFrequencyOnPersistErrorRollsBackAndSetsError() async {
        let nameB = makeTask(name: "B", sortOrder: 0)
        let nameA = makeTask(name: "A", sortOrder: 1)
        mockTaskRepository.tasks = [nameB, nameA]
        await viewModel.loadTasks()
        mockTaskRepository.shouldThrowErrorOnUpdateSortOrders = true

        await viewModel.sortByFrequency(now: fixedNow)

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.tasks.map(\.name), ["B", "A"]) // DB 状態へ巻き戻し
    }

    // MARK: - 直列化 (#130-①)

    func testConcurrentReordersAreSerialized() async {
        let taskA = makeTask(name: "A", sortOrder: 0)
        let taskB = makeTask(name: "B", sortOrder: 1)
        let taskC = makeTask(name: "C", sortOrder: 2)
        mockTaskRepository.tasks = [taskA, taskB, taskC]
        await viewModel.loadTasks()

        // 2 つの並べ替えをほぼ同時に発火。直列化されていれば updateSortOrders は
        // 同時に 1 つしか走らない (#130-①)。
        async let first: Void = viewModel.moveTasks(from: IndexSet(integer: 2), to: 0)
        async let second: Void = viewModel.moveTasks(from: IndexSet(integer: 0), to: 2)
        _ = await (first, second)

        XCTAssertLessThanOrEqual(
            mockTaskRepository.maxConcurrentUpdateSortOrders, 1,
            "並べ替え永続化は直列化されるべき（observed max concurrent: \(mockTaskRepository.maxConcurrentUpdateSortOrders), calls: \(mockTaskRepository.updateSortOrdersCallCount)）"
        )
        XCTAssertEqual(mockTaskRepository.updateSortOrdersCallCount, 2, "両方の永続化が実行されるべき")
    }

    // MARK: - errorMessage 残留の解消 (#136)

    func testSuccessfulSortClearsStaleErrorFromPriorFailedPersist() async {
        // 失敗した永続化が errorMessage をセットしたまま、後続の成功永続化が走っても
        // errorMessage が残るケースを潰す (#136 副次所見)。永続化は直列化されるため、
        // 「敗北した失敗 persist の後に成功 persist が走る」並行ケースは、enqueue 順に並べた
        // この逐次ケースに帰着する。最後に成功した永続化の結末が最終状態であるべき。
        let taskA = makeTask(name: "A", sortOrder: 0)
        let taskB = makeTask(name: "B", sortOrder: 1)
        mockTaskRepository.tasks = [taskA, taskB]
        await viewModel.loadTasks()

        // 1) まず永続化を失敗させて errorMessage をセット
        mockTaskRepository.shouldThrowErrorOnUpdateSortOrders = true
        await viewModel.sortByFrequency(now: fixedNow)
        XCTAssertNotNil(viewModel.errorMessage, "失敗永続化で errorMessage がセットされるべき")

        // 2) 次の永続化を成功させると、前回の errorMessage はクリアされるべき
        mockTaskRepository.shouldThrowErrorOnUpdateSortOrders = false
        await viewModel.sortByFrequency(now: fixedNow)

        XCTAssertNil(viewModel.errorMessage,
                     "後続の成功永続化は古い errorMessage をクリアすべき（残: \(String(describing: viewModel.errorMessage))）")
        XCTAssertNotNil(viewModel.successMessage, "成功永続化では successMessage がセットされるべき")
    }

    func testSuccessfulReorderClearsStaleErrorFromPriorFailedPersist() async {
        // 上と同じ不変条件を reorder 経路 (persistReorder) でも担保する。
        let taskA = makeTask(name: "A", sortOrder: 0)
        let taskB = makeTask(name: "B", sortOrder: 1)
        let taskC = makeTask(name: "C", sortOrder: 2)
        mockTaskRepository.tasks = [taskA, taskB, taskC]
        await viewModel.loadTasks()

        mockTaskRepository.shouldThrowErrorOnUpdateSortOrders = true
        await viewModel.moveTasks(from: IndexSet(integer: 2), to: 0)
        XCTAssertNotNil(viewModel.errorMessage, "失敗した並べ替え永続化で errorMessage がセットされるべき")

        mockTaskRepository.shouldThrowErrorOnUpdateSortOrders = false
        await viewModel.moveTasks(from: IndexSet(integer: 2), to: 0)

        XCTAssertNil(viewModel.errorMessage,
                     "後続の成功した並べ替え永続化は古い errorMessage をクリアすべき（残: \(String(describing: viewModel.errorMessage))）")
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
