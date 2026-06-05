import XCTest
@testable import OtetsudaiCoin

final class RecordViewModelTests: XCTestCase {
    private var viewModel: RecordViewModel!
    private var mockChildRepository: MockChildRepository!
    private var mockHelpTaskRepository: MockHelpTaskRepository!
    private var mockHelpRecordRepository: MockHelpRecordRepository!
    private var mockSoundService: MockSoundService!
    
    @MainActor
    override func setUp() {
        super.setUp()
        mockChildRepository = MockChildRepository()
        mockHelpTaskRepository = MockHelpTaskRepository()
        mockHelpRecordRepository = MockHelpRecordRepository()
        mockSoundService = MockSoundService()
        
        viewModel = RecordViewModel(
            childRepository: mockChildRepository,
            helpTaskRepository: mockHelpTaskRepository,
            helpRecordRepository: mockHelpRecordRepository,
            soundService: mockSoundService
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockSoundService = nil
        mockHelpRecordRepository = nil
        mockHelpTaskRepository = nil
        mockChildRepository = nil
        super.tearDown()
    }
    
    @MainActor
    func testInitialState() {
        XCTAssertTrue(viewModel.availableChildren.isEmpty)
        XCTAssertTrue(viewModel.availableTasks.isEmpty)
        XCTAssertNil(viewModel.selectedChild)
        XCTAssertNil(viewModel.selectedTask)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.successMessage)
    }
    
    @MainActor
    func testLoadDataSuccess() async {
        let expectedChildren = [
            Child(id: UUID(), name: "太郎", themeColor: "#FF5733"),
            Child(id: UUID(), name: "花子", themeColor: "#33FF57")
        ]
        let expectedTasks = [
            HelpTask(id: UUID(), name: "下の子の面倒を見る", isActive: true),
            HelpTask(id: UUID(), name: "お風呂を入れる", isActive: true),
            HelpTask(id: UUID(), name: "食器を片付ける", isActive: false)
        ]
        mockChildRepository.children = expectedChildren
        mockHelpTaskRepository.tasks = expectedTasks
        
        viewModel.loadData()
        
        // @Observableでの非同期処理完了を待機
        let expectation = XCTestExpectation(description: "Load data success")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
        
        XCTAssertEqual(viewModel.availableChildren.count, 2)
        XCTAssertEqual(viewModel.availableTasks.count, 2) // アクティブなタスクのみ
        XCTAssertTrue(viewModel.availableTasks.allSatisfy { $0.isActive })
        XCTAssertEqual(viewModel.selectedChild?.name, "太郎") // 最初の子供が自動選択される
    }
    
    @MainActor
    func testLoadDataFailure() async {
        mockHelpTaskRepository.shouldThrowError = true
        
        viewModel.loadData()
        
        // @Observableでの非同期処理完了を待機
        let expectation = XCTestExpectation(description: "Load data failure")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
        
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
    @MainActor
    func testSelectChild() {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        
        viewModel.selectChild(child)
        
        XCTAssertEqual(viewModel.selectedChild?.id, child.id)
        XCTAssertEqual(viewModel.selectedChild?.name, "太郎")
    }
    
    @MainActor
    func testSelectTask() {
        let task = HelpTask(id: UUID(), name: "お風呂を入れる", isActive: true)
        
        viewModel.selectTask(task)
        
        XCTAssertEqual(viewModel.selectedTask?.id, task.id)
        XCTAssertEqual(viewModel.selectedTask?.name, "お風呂を入れる")
    }
    
    @MainActor
    func testRecordHelpSuccess() async {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let task = HelpTask(id: UUID(), name: "お風呂を入れる", isActive: true)
        
        viewModel.selectChild(child)
        viewModel.selectTask(task)
        
        viewModel.recordHelp()
        
        // @Observableでの非同期処理完了を待機
        let expectation = XCTestExpectation(description: "Record help success")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
        
        // 記録後の状態確認
        XCTAssertEqual(viewModel.successMessage, String(localized: "お手伝いを記録しました！"))
        XCTAssertNil(viewModel.selectedTask)
        XCTAssertEqual(mockHelpRecordRepository.records.count, 1)
        XCTAssertEqual(mockHelpRecordRepository.records.first?.childId, child.id)
        XCTAssertEqual(mockHelpRecordRepository.records.first?.helpTaskId, task.id)
    }
    
    @MainActor
    func testRecordHelpWithoutChildSelection() {
        let task = HelpTask(id: UUID(), name: "お風呝を入れる", isActive: true)
        viewModel.selectTask(task)
        
        viewModel.recordHelp()
        
        XCTAssertEqual(viewModel.errorMessage, String(localized: "お子様を選択してください"))
    }

    @MainActor
    func testRecordHelpWithoutTaskSelection() {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        viewModel.selectChild(child)

        viewModel.recordHelp()

        XCTAssertEqual(viewModel.errorMessage, String(localized: "お手伝いタスクを選択してください"))
    }
    
    @MainActor
    func testRecordHelpFailure() async {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let task = HelpTask(id: UUID(), name: "お風呂を入れる", isActive: true)
        
        viewModel.selectChild(child)
        viewModel.selectTask(task)
        
        mockHelpRecordRepository.shouldThrowError = true
        
        viewModel.recordHelp()
        
        // @Observableでの非同期処理完了を待機
        let expectation = XCTestExpectation(description: "Record help failure")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
        
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
    @MainActor
    func testClearMessages() {
        viewModel.setError("テストエラー")
        viewModel.setSuccess("テスト成功")

        viewModel.clearMessages()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.successMessage)
    }

    // MARK: - 記録日（過去日付登録機能）

    @MainActor
    func testRecordedDateDefaultsToToday() {
        XCTAssertTrue(
            Calendar.current.isDateInToday(viewModel.recordedDate),
            "ViewModel 初期化時の recordedDate が今日でない: \(viewModel.recordedDate)"
        )
    }

    @MainActor
    func testRecordedDateResetsToTodayOnNewViewModelInstance() {
        let pastDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        viewModel.recordedDate = pastDate

        let newViewModel = RecordViewModel(
            childRepository: mockChildRepository,
            helpTaskRepository: mockHelpTaskRepository,
            helpRecordRepository: mockHelpRecordRepository,
            soundService: mockSoundService
        )

        XCTAssertTrue(
            Calendar.current.isDateInToday(newViewModel.recordedDate),
            "新 ViewModel の recordedDate が今日でない: \(newViewModel.recordedDate)"
        )
    }

    @MainActor
    func testRecordHelpUsesRecordedDateSnappedToNoon() async {
        let pastDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let task = HelpTask(id: UUID(), name: "皿洗い", isActive: true)

        viewModel.selectChild(child)
        viewModel.selectTask(task)
        viewModel.recordedDate = pastDate

        viewModel.recordHelp()

        let expectation = XCTestExpectation(description: "Record help with past date")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertEqual(mockHelpRecordRepository.records.count, 1)
        let saved = mockHelpRecordRepository.records.first!

        let cal = Calendar.current
        XCTAssertTrue(
            cal.isDate(saved.recordedAt, inSameDayAs: pastDate),
            "保存された日付が選択日と異なる: saved=\(saved.recordedAt), expected=\(pastDate)"
        )
        let comps = cal.dateComponents([.hour, .minute, .second], from: saved.recordedAt)
        XCTAssertEqual(comps.hour, 12, "時刻が 12:00 にスナップされていない")
        XCTAssertEqual(comps.minute, 0, "分が 0 にスナップされていない")
        XCTAssertEqual(comps.second, 0, "秒が 0 にスナップされていない")
    }

    @MainActor
    func testRecordedDatePersistsAcrossMultipleRecords() async {
        let pastDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let task1 = HelpTask(id: UUID(), name: "皿洗い", isActive: true)
        let task2 = HelpTask(id: UUID(), name: "洗濯", isActive: true)

        // 記録通知に伴って発火する loadData() で selectedChild が nil 化されないよう、
        // mock repositories に同じ child/task を seed しておく
        mockChildRepository.children = [child]
        mockHelpTaskRepository.tasks = [task1, task2]

        viewModel.selectChild(child)
        viewModel.recordedDate = pastDate
        viewModel.selectTask(task1)
        viewModel.recordHelp()

        // 1 件目の保存完了を records.count で堅牢に待機
        await waitUntil(timeout: 2.0) {
            self.mockHelpRecordRepository.records.count == 1
        }
        XCTAssertEqual(mockHelpRecordRepository.records.count, 1, "1 件目の保存が完了していない")

        // 2 回目の選択と記録
        viewModel.selectTask(task2)
        viewModel.recordHelp()

        await waitUntil(timeout: 2.0) {
            self.mockHelpRecordRepository.records.count == 2
        }

        XCTAssertEqual(mockHelpRecordRepository.records.count, 2)
        let cal = Calendar.current
        for (index, record) in mockHelpRecordRepository.records.enumerated() {
            XCTAssertTrue(
                cal.isDate(record.recordedAt, inSameDayAs: pastDate),
                "\(index + 1) 件目の日付が異なる: \(record.recordedAt)"
            )
        }
        XCTAssertTrue(
            cal.isDate(viewModel.recordedDate, inSameDayAs: pastDate),
            "recordedDate が記録後にリセットされている: \(viewModel.recordedDate)"
        )
    }

    /// 条件が満たされるまで polling する非同期ヘルパー
    @MainActor
    private func waitUntil(timeout: TimeInterval, condition: @escaping () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }
    
    // TODO: 効果音テストは後で修正する
    /*
    func testRecordHelpWithSoundEffect() async {
        // Given: MockSoundServiceの状態をリセット
        mockSoundService.playCoinEarnSoundCalled = false
        mockSoundService.playTaskCompleteSoundCalled = false
        mockSoundService.playErrorSoundCalled = false
        
        // 子供とタスクを設定
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let task = HelpTask(id: UUID(), name: "お風呂を掃除する", isActive: true)
        
        mockChildRepository.children = [child]
        mockHelpTaskRepository.tasks = [task]
        
        await viewModel.loadData()
        viewModel.selectChild(child)
        viewModel.selectTask(task)
        
        // When: お手伝いを記録
        await viewModel.recordHelp()
        
        // Then: 効果音が再生されることを確認
        XCTAssertTrue(mockSoundService.playCoinEarnSoundCalled, "コイン獲得音が再生されていません")
        XCTAssertTrue(mockSoundService.playTaskCompleteSoundCalled, "タスク完了音が再生されていません")
    }
    
    func testRecordHelpWithSoundError() async {
        // Given: 効果音エラーを設定
        mockSoundService.shouldThrowError = true
        
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let task = HelpTask(id: UUID(), name: "お風呂を掃除する", isActive: true)
        
        mockChildRepository.children = [child]
        mockHelpTaskRepository.tasks = [task]
        
        await viewModel.loadData()
        viewModel.selectChild(child)
        viewModel.selectTask(task)
        
        // When: お手伝いを記録（効果音エラー）
        await viewModel.recordHelp()
        
        // Then: 記録は成功し、エラー音が再生されることを確認
        XCTAssertEqual(mockHelpRecordRepository.records.count, 1)
        XCTAssertTrue(mockSoundService.playErrorSoundCalled)
    }
    */

    // MARK: - #69 Bulk Record Tests

    @MainActor
    func test_toggleBulkMode_resetsSelections() {
        // Given: 1 件モードで何かしら選択済み
        let task = HelpTask(id: UUID(), name: "ゴミ出し", isActive: true, coinRate: 10)
        viewModel.selectedTask = task
        XCTAssertFalse(viewModel.isBulkMode)

        // When: 一括モードに切替
        viewModel.toggleBulkMode()

        // Then: bulk mode on、selectedTask は nil、selectedTaskIds は empty
        XCTAssertTrue(viewModel.isBulkMode)
        XCTAssertNil(viewModel.selectedTask)
        XCTAssertTrue(viewModel.selectedTaskIds.isEmpty)

        // When: 一括モードで何か選択して 1 件モードに戻す
        viewModel.selectedTaskIds.insert(task.id)
        viewModel.toggleBulkMode()

        // Then: bulk mode off、両 selection 空に
        XCTAssertFalse(viewModel.isBulkMode)
        XCTAssertNil(viewModel.selectedTask)
        XCTAssertTrue(viewModel.selectedTaskIds.isEmpty)
    }

    @MainActor
    func test_selectChild_resetsBulkSelection() {
        // Given: 一括モードで複数選択済み
        let child1 = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let child2 = Child(id: UUID(), name: "花子", themeColor: "#33FF57")
        viewModel.isBulkMode = true
        viewModel.selectedTaskIds = [UUID(), UUID(), UUID()]
        viewModel.selectChild(child1)
        XCTAssertEqual(viewModel.selectedTaskIds.count, 3)

        // When: 別の child に切替
        viewModel.selectChild(child2)

        // Then: selectedTaskIds が空になる
        XCTAssertTrue(viewModel.selectedTaskIds.isEmpty)
        XCTAssertEqual(viewModel.selectedChild?.id, child2.id)
    }

    @MainActor
    func test_recordBulkHelp_partialFailure_failedRemain() async {
        // Given: 3 件選択、うち中央 1 件 (t2) のみ save 失敗
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let t1 = HelpTask(id: UUID(), name: "A", isActive: true, coinRate: 10)
        let t2 = HelpTask(id: UUID(), name: "B", isActive: true, coinRate: 20)
        let t3 = HelpTask(id: UUID(), name: "C", isActive: true, coinRate: 30)
        viewModel.availableChildren = [child]
        viewModel.selectedChild = child
        viewModel.availableTasks = [t1, t2, t3]
        viewModel.isBulkMode = true
        viewModel.selectedTaskIds = [t1.id, t2.id, t3.id]
        mockHelpRecordRepository.failingHelpTaskIds = [t2.id]

        // When
        viewModel.recordBulkHelp()
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Then: 2 件保存、失敗 1 件のみ selectedTaskIds に残る、合計コイン 40
        XCTAssertEqual(mockHelpRecordRepository.records.count, 2)
        XCTAssertEqual(viewModel.selectedTaskIds, [t2.id])
        XCTAssertEqual(viewModel.lastRecordedCoinValue, 40)
        XCTAssertNotNil(viewModel.successMessage)
    }

    @MainActor
    func test_recordBulkHelp_allFailed() async {
        // Given: 2 件選択、全件 save 失敗
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let t1 = HelpTask(id: UUID(), name: "A", isActive: true, coinRate: 10)
        let t2 = HelpTask(id: UUID(), name: "B", isActive: true, coinRate: 20)
        viewModel.availableChildren = [child]
        viewModel.selectedChild = child
        viewModel.availableTasks = [t1, t2]
        viewModel.isBulkMode = true
        viewModel.selectedTaskIds = [t1.id, t2.id]
        mockHelpRecordRepository.shouldThrowError = true

        // When
        viewModel.recordBulkHelp()
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Then: 0 件保存、選択は全て残る、error メッセージ
        XCTAssertEqual(mockHelpRecordRepository.records.count, 0)
        XCTAssertEqual(viewModel.selectedTaskIds, [t1.id, t2.id])
        XCTAssertEqual(viewModel.lastRecordedCoinValue, 0)
        XCTAssertNil(viewModel.successMessage)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    @MainActor
    func test_recordBulkHelp_singleSuccess_usesPluralOneVariation() async {
        // Given: 1 件のみ選択 → 成功
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let t1 = HelpTask(id: UUID(), name: "A", isActive: true, coinRate: 10)
        viewModel.availableChildren = [child]
        viewModel.selectedChild = child
        viewModel.availableTasks = [t1]
        viewModel.isBulkMode = true
        viewModel.selectedTaskIds = [t1.id]

        // When
        viewModel.recordBulkHelp()
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Then: success message に count=1 が反映され、ja sourceLanguage のため
        // "1 件記録しました！" (variations 未定義のため interpolation 経由でも他キーは使われる)
        // count=1 でも "1" の文字列が含まれることを担保 (plural 違反でない文言を確認)
        XCTAssertNotNil(viewModel.successMessage)
        XCTAssertTrue(viewModel.successMessage?.contains("1") ?? false)
    }

    @MainActor
    func test_recordBulkHelp_partialFailure_setsWarningMessage() async {
        // Given
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let t1 = HelpTask(id: UUID(), name: "A", isActive: true, coinRate: 10)
        let t2 = HelpTask(id: UUID(), name: "B", isActive: true, coinRate: 20)
        viewModel.availableChildren = [child]
        viewModel.selectedChild = child
        viewModel.availableTasks = [t1, t2]
        viewModel.isBulkMode = true
        viewModel.selectedTaskIds = [t1.id, t2.id]
        mockHelpRecordRepository.failingHelpTaskIds = [t1.id]

        // When
        viewModel.recordBulkHelp()
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Then
        XCTAssertNotNil(viewModel.warningMessage)
        XCTAssertTrue(viewModel.warningMessage?.contains("1") ?? false)
    }

    @MainActor
    func test_recordBulkHelp_allSuccess() async {
        // Given: child 選択済み、tasks 3 件選択 (coinRate 10/20/30)
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let t1 = HelpTask(id: UUID(), name: "A", isActive: true, coinRate: 10)
        let t2 = HelpTask(id: UUID(), name: "B", isActive: true, coinRate: 20)
        let t3 = HelpTask(id: UUID(), name: "C", isActive: true, coinRate: 30)
        viewModel.availableChildren = [child]
        viewModel.selectedChild = child
        viewModel.availableTasks = [t1, t2, t3]
        viewModel.isBulkMode = true
        viewModel.selectedTaskIds = [t1.id, t2.id, t3.id]

        // When
        viewModel.recordBulkHelp()
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Then: 3 件保存、selectedTaskIds 空、合計 60 コイン、success メッセージ
        XCTAssertEqual(mockHelpRecordRepository.records.count, 3)
        XCTAssertTrue(viewModel.selectedTaskIds.isEmpty)
        XCTAssertEqual(viewModel.lastRecordedCoinValue, 60)
        XCTAssertNotNil(viewModel.successMessage)
        XCTAssertNil(viewModel.errorMessage)
    }

    // MARK: - #73 existingRecordCounts

    @MainActor
    func test_existingRecordCounts_initiallyEmpty() {
        XCTAssertEqual(viewModel.existingRecordCounts, [:])
    }

    @MainActor
    func test_existingRecordCount_returnsZeroForUnknownTask() {
        let unknownId = UUID()
        XCTAssertEqual(viewModel.existingRecordCount(for: unknownId), 0)
    }

    @MainActor
    func test_loadExistingCounts_noSelectedChild_clearsMap() {
        // Given: 何らかの count が事前に残っている、selectedChild = nil
        viewModel.existingRecordCounts = [UUID(): 5]

        // When (selectedChild == nil の場合は同期的に [:] にする実装のため、await 不要)
        viewModel.loadExistingCountsForCurrentDateAndChild()

        // Then
        XCTAssertEqual(viewModel.existingRecordCounts, [:])
    }

    @MainActor
    func test_loadExistingCounts_filtersBySelectedChildAndDate() async {
        // Given: 2 子供 × 同日同タスク × 異日同タスク を含む record 群
        let childA = Child(id: UUID(), name: "A", themeColor: "#FF5733")
        let childB = Child(id: UUID(), name: "B", themeColor: "#33FF57")
        let task1 = HelpTask(id: UUID(), name: "皿洗い", isActive: true, coinRate: 10)
        let task2 = HelpTask(id: UUID(), name: "ゴミ出し", isActive: true, coinRate: 5)

        let today = Calendar.current.startOfDay(for: Date())
        let noon = Calendar.current.date(byAdding: .hour, value: 12, to: today)!
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: noon)!

        mockChildRepository.children = [childA, childB]
        mockHelpTaskRepository.tasks = [task1, task2]
        mockHelpRecordRepository.records = [
            HelpRecord(id: UUID(), childId: childA.id, helpTaskId: task1.id, recordedAt: noon),       // 対象
            HelpRecord(id: UUID(), childId: childA.id, helpTaskId: task1.id, recordedAt: noon),       // 対象
            HelpRecord(id: UUID(), childId: childA.id, helpTaskId: task2.id, recordedAt: noon),       // 対象 (別 task)
            HelpRecord(id: UUID(), childId: childB.id, helpTaskId: task1.id, recordedAt: noon),       // 除外 (別 child)
            HelpRecord(id: UUID(), childId: childA.id, helpTaskId: task1.id, recordedAt: yesterday),  // 除外 (別日)
        ]

        viewModel.selectedChild = childA
        viewModel.recordedDate = noon

        // When
        viewModel.loadExistingCountsForCurrentDateAndChild()
        // Task が cancel 制御込みで async に走るので、結果反映を条件待ち
        await waitUntil(timeout: 2.0) { self.viewModel.existingRecordCount(for: task1.id) == 2 }

        // Then
        XCTAssertEqual(viewModel.existingRecordCount(for: task1.id), 2)
        XCTAssertEqual(viewModel.existingRecordCount(for: task2.id), 1)
    }

    @MainActor
    func test_selectChild_triggersCountReload() async {
        // Given: child A と child B、それぞれ別の record
        let childA = Child(id: UUID(), name: "A", themeColor: "#FF5733")
        let childB = Child(id: UUID(), name: "B", themeColor: "#33FF57")
        let task = HelpTask(id: UUID(), name: "皿洗い", isActive: true, coinRate: 10)

        let noon = Calendar.current.date(byAdding: .hour, value: 12, to: Calendar.current.startOfDay(for: Date()))!
        mockChildRepository.children = [childA, childB]
        mockHelpTaskRepository.tasks = [task]
        mockHelpRecordRepository.records = [
            HelpRecord(id: UUID(), childId: childA.id, helpTaskId: task.id, recordedAt: noon),
            HelpRecord(id: UUID(), childId: childB.id, helpTaskId: task.id, recordedAt: noon),
            HelpRecord(id: UUID(), childId: childB.id, helpTaskId: task.id, recordedAt: noon),
        ]

        viewModel.selectedChild = childA
        viewModel.recordedDate = noon
        viewModel.loadExistingCountsForCurrentDateAndChild()
        await waitUntil(timeout: 2.0) { self.viewModel.existingRecordCount(for: task.id) == 1 }

        // When: child B に切り替え
        viewModel.selectChild(childB)

        // Then: count map が child B のものに更新
        await waitUntil(timeout: 2.0) { self.viewModel.existingRecordCount(for: task.id) == 2 }
        XCTAssertEqual(viewModel.existingRecordCount(for: task.id), 2)
    }

    @MainActor
    func test_recordHelpSuccess_updatesCountViaObserver() async {
        // Given: 初期 record なし、child と task を選択済み
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let task = HelpTask(id: UUID(), name: "皿洗い", isActive: true, coinRate: 10)
        mockChildRepository.children = [child]
        mockHelpTaskRepository.tasks = [task]

        viewModel.loadData()
        await waitUntil(timeout: 2.0) { !self.viewModel.isLoading }
        viewModel.selectTask(task)
        XCTAssertEqual(viewModel.existingRecordCount(for: task.id), 0)

        // When: 1 件 recordHelp
        viewModel.recordHelp()

        // observer chain (recordHelp → notify → loadData → loadCounts) は
        // 多段の Task switch を経由するため、固定 sleep ではなく条件待ち
        await waitUntil(timeout: 3.0) { self.viewModel.existingRecordCount(for: task.id) == 1 }

        // Then: count map が +1 されている
        XCTAssertEqual(viewModel.existingRecordCount(for: task.id), 1)
    }

    // MARK: - #84 recordedDays (記録がある日の集合)

    @MainActor
    func test_recordedDays_initiallyEmpty() {
        XCTAssertEqual(viewModel.recordedDays, [])
    }

    @MainActor
    func test_loadRecordedDays_noSelectedChild_clearsSet() {
        // Given: 何か入っている / selectedChild = nil
        viewModel.recordedDays = [1, 2, 3]
        viewModel.selectedChild = nil

        // When (selectedChild == nil は同期的に空集合化)
        viewModel.loadRecordedDaysForDisplayedMonth()

        // Then
        XCTAssertEqual(viewModel.recordedDays, [])
    }

    @MainActor
    func test_loadRecordedDays_filtersBySelectedChildAndMonth() async {
        // Given: childA の 3/5, 3/20 が対象。childB の 3/5・2月・4月 は除外。
        let childA = Child(id: UUID(), name: "A", themeColor: "#FF5733")
        let childB = Child(id: UUID(), name: "B", themeColor: "#33FF57")
        let task = HelpTask(id: UUID(), name: "皿洗い", isActive: true, coinRate: 10)
        let cal = Calendar.current
        func noon(_ y: Int, _ m: Int, _ d: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
        }
        mockHelpTaskRepository.tasks = [task]
        mockHelpRecordRepository.records = [
            HelpRecord(id: UUID(), childId: childA.id, helpTaskId: task.id, recordedAt: noon(2026, 3, 5)),   // 対象
            HelpRecord(id: UUID(), childId: childA.id, helpTaskId: task.id, recordedAt: noon(2026, 3, 20)),  // 対象
            HelpRecord(id: UUID(), childId: childB.id, helpTaskId: task.id, recordedAt: noon(2026, 3, 5)),   // 除外(別child)
            HelpRecord(id: UUID(), childId: childA.id, helpTaskId: task.id, recordedAt: noon(2026, 2, 28)),  // 除外(前月)
            HelpRecord(id: UUID(), childId: childA.id, helpTaskId: task.id, recordedAt: noon(2026, 4, 1)),   // 除外(翌月)
        ]
        viewModel.selectedChild = childA
        viewModel.displayedMonth = RecordViewModel.startOfMonth(noon(2026, 3, 15))

        // When
        viewModel.loadRecordedDaysForDisplayedMonth()
        await waitUntil(timeout: 2.0) { self.viewModel.recordedDays == [5, 20] }

        // Then
        XCTAssertEqual(viewModel.recordedDays, [5, 20])
    }

    // MARK: - #84 月移動と日選択

    @MainActor
    func test_canGoToNextMonth_falseForCurrentMonth_trueForPast() {
        let cal = Calendar.current
        let today = cal.date(from: DateComponents(year: 2026, month: 6, day: 15))!

        viewModel.displayedMonth = RecordViewModel.startOfMonth(today)
        XCTAssertFalse(viewModel.canGoToNextMonth(today: today))

        viewModel.displayedMonth = cal.date(from: DateComponents(year: 2026, month: 4, day: 1))!
        XCTAssertTrue(viewModel.canGoToNextMonth(today: today))
    }

    @MainActor
    func test_goToPreviousMonth_movesDisplayedMonthBack() {
        let cal = Calendar.current
        viewModel.displayedMonth = cal.date(from: DateComponents(year: 2026, month: 3, day: 1))!

        viewModel.goToPreviousMonth()

        XCTAssertEqual(
            viewModel.displayedMonth,
            cal.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        )
    }

    @MainActor
    func test_goToNextMonth_cappedAtCurrentMonth() {
        let cal = Calendar.current
        let today = cal.date(from: DateComponents(year: 2026, month: 6, day: 15))!

        // 過去月からは進める
        viewModel.displayedMonth = cal.date(from: DateComponents(year: 2026, month: 4, day: 1))!
        viewModel.goToNextMonth(today: today)
        XCTAssertEqual(viewModel.displayedMonth, cal.date(from: DateComponents(year: 2026, month: 5, day: 1))!)

        // 今日の月で頭打ち (no-op)
        viewModel.displayedMonth = RecordViewModel.startOfMonth(today)
        viewModel.goToNextMonth(today: today)
        XCTAssertEqual(viewModel.displayedMonth, RecordViewModel.startOfMonth(today))
    }

    @MainActor
    func test_monthNavigation_handlesYearBoundary() {
        let cal = Calendar.current
        // goToPreviousMonth: 2026年1月 → 2025年12月 (年跨ぎ)
        viewModel.displayedMonth = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        viewModel.goToPreviousMonth()
        XCTAssertEqual(viewModel.displayedMonth,
                       cal.date(from: DateComponents(year: 2025, month: 12, day: 1))!)

        // canGoToNextMonth: 2025年12月表示・今日=2026年1月 → 進める (年跨ぎ比較)
        let todayJan = cal.date(from: DateComponents(year: 2026, month: 1, day: 10))!
        XCTAssertTrue(viewModel.canGoToNextMonth(today: todayJan))

        // goToNextMonth: 2025年12月 → 2026年1月 (年跨ぎ)
        viewModel.goToNextMonth(today: todayJan)
        XCTAssertEqual(viewModel.displayedMonth,
                       cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!)

        // 今日の月 (2026年1月) で頭打ち
        XCTAssertFalse(viewModel.canGoToNextMonth(today: todayJan))
    }

    @MainActor
    func test_selectDay_setsRecordedDateNoon_ignoresFuture() {
        let cal = Calendar.current
        let today = cal.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        viewModel.displayedMonth = RecordViewModel.startOfMonth(today)

        // 過去日は選択され noon 正規化される
        viewModel.selectDay(10, today: today)
        let comps = cal.dateComponents([.year, .month, .day, .hour], from: viewModel.recordedDate)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 6)
        XCTAssertEqual(comps.day, 10)
        XCTAssertEqual(comps.hour, 12)

        // 今日 (15) は選択可能 (guard は strict `>` なので今日は通る)
        viewModel.selectDay(15, today: today)
        XCTAssertEqual(cal.component(.day, from: viewModel.recordedDate), 15)

        // 未来日 (16) は無視され recordedDate は 15 のまま
        viewModel.selectDay(16, today: today)
        XCTAssertEqual(cal.component(.day, from: viewModel.recordedDate), 15)
    }

    @MainActor
    func test_selectChild_triggersRecordedDaysReload() async {
        let cal = Calendar.current
        let base = RecordViewModel.startOfMonth(Date())
        func noon(_ d: Int) -> Date {
            cal.date(byAdding: DateComponents(day: d - 1, hour: 12), to: base)!
        }
        let childA = Child(id: UUID(), name: "A", themeColor: "#FF5733")
        let childB = Child(id: UUID(), name: "B", themeColor: "#33FF57")
        let task = HelpTask(id: UUID(), name: "皿洗い", isActive: true, coinRate: 10)
        mockHelpTaskRepository.tasks = [task]
        mockHelpRecordRepository.records = [
            HelpRecord(id: UUID(), childId: childA.id, helpTaskId: task.id, recordedAt: noon(3)),
            HelpRecord(id: UUID(), childId: childB.id, helpTaskId: task.id, recordedAt: noon(7)),
            HelpRecord(id: UUID(), childId: childB.id, helpTaskId: task.id, recordedAt: noon(9)),
        ]
        // displayedMonth を records と同じ月アンカーに固定し、月境界 race を排除
        viewModel.displayedMonth = base
        viewModel.selectChild(childA)
        await waitUntil(timeout: 2.0) { self.viewModel.recordedDays == [3] }

        // When: childB に切替 → {7, 9}
        viewModel.selectChild(childB)

        // Then
        await waitUntil(timeout: 2.0) { self.viewModel.recordedDays == [7, 9] }
        XCTAssertEqual(viewModel.recordedDays, [7, 9])
    }
}
