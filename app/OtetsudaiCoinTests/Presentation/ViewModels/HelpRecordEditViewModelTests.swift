import XCTest
@testable import OtetsudaiCoin

final class HelpRecordEditViewModelTests: XCTestCase {
    
    private var mockHelpRecordRepository: MockHelpRecordRepository!
    private var mockHelpTaskRepository: MockHelpTaskRepository!
    private var viewModel: HelpRecordEditViewModel!
    private var helpRecord: HelpRecord!
    private var child: Child!
    
    override func setUp() {
        super.setUp()
        mockHelpRecordRepository = MockHelpRecordRepository()
        mockHelpTaskRepository = MockHelpTaskRepository()
        child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        helpRecord = HelpRecord(id: UUID(), childId: child.id, helpTaskId: UUID(), recordedAt: Date())
        viewModel = HelpRecordEditViewModel(
            helpRecord: helpRecord,
            child: child,
            helpRecordRepository: mockHelpRecordRepository,
            helpTaskRepository: mockHelpTaskRepository
        )
    }
    
    override func tearDown() {
        viewModel = nil
        helpRecord = nil
        child = nil
        mockHelpTaskRepository = nil
        mockHelpRecordRepository = nil
        super.tearDown()
    }
    
    func testInitialization() {
        // Then
        XCTAssertEqual(viewModel.recordedDate, helpRecord.recordedAt)
        XCTAssertTrue(viewModel.availableTasks.isEmpty)
        XCTAssertNil(viewModel.selectedTask)
    }
    
    @MainActor
    func testLoadDataSuccess() async {
        // Given
        let task1 = HelpTask(id: helpRecord.helpTaskId, name: "食器洗い", isActive: true)
        let task2 = HelpTask(id: UUID(), name: "掃除", isActive: true)
        mockHelpTaskRepository.tasks = [task1, task2]
        
        // When
        viewModel.loadData()
        
        // 非同期処理の完了を待機
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機
        
        // Then
        XCTAssertFalse(viewModel.viewState.isLoading)
        XCTAssertEqual(viewModel.availableTasks.count, 2)
        XCTAssertEqual(viewModel.selectedTask?.id, task1.id)
        XCTAssertNil(viewModel.viewState.errorMessage)
    }
    
    @MainActor
    func testLoadDataError() async {
        // Given
        mockHelpTaskRepository.shouldThrowError = true
        
        // When
        viewModel.loadData()
        
        // 非同期処理の完了を待機
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機
        
        // Then
        XCTAssertFalse(viewModel.viewState.isLoading)
        XCTAssertTrue(viewModel.availableTasks.isEmpty)
        XCTAssertNotNil(viewModel.viewState.errorMessage)
    }
    
    @MainActor
    func testSaveChangesSuccess() async {
        // Given
        let newTask = HelpTask(id: UUID(), name: "掃除", isActive: true)
        viewModel.selectedTask = newTask
        let newDate = Date().addingTimeInterval(3600)
        viewModel.recordedDate = newDate
        
        // MockHelpRecordRepositoryに元のレコードを追加
        mockHelpRecordRepository.records.append(helpRecord)
        
        // When
        viewModel.saveChanges()
        
        // 非同期処理の完了を待機（長めに設定）
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3秒待機
        
        // Then
        XCTAssertFalse(viewModel.viewState.isLoading)
        XCTAssertNotNil(viewModel.viewState.successMessage)
        XCTAssertNil(viewModel.viewState.errorMessage)
    }
    
    @MainActor
    func testSaveChangesWithoutTask() {
        // Given: タスクが選択されていない状態
        
        // When
        viewModel.saveChanges()
        
        // Then
        XCTAssertNotNil(viewModel.viewState.errorMessage)
        XCTAssertEqual(viewModel.viewState.errorMessage, "お手伝いタスクを選択してください")
    }
    
    @MainActor
    func testDeleteRecordSuccess() async {
        // When
        viewModel.deleteRecord()
        
        // 非同期処理の完了を待機
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機
        
        // Then
        XCTAssertFalse(viewModel.viewState.isLoading)
        XCTAssertNotNil(viewModel.viewState.successMessage)
        XCTAssertNil(viewModel.viewState.errorMessage)
    }
    
    func testHasChanges() {
        // Given
        let originalTask = HelpTask(id: helpRecord.helpTaskId, name: "食器洗い", isActive: true)
        let newTask = HelpTask(id: UUID(), name: "掃除", isActive: true)
        
        // When: 元のタスクを選択
        viewModel.selectedTask = originalTask
        
        // Then: 変更なし
        XCTAssertFalse(viewModel.hasChanges)
        
        // When: 新しいタスクを選択
        viewModel.selectedTask = newTask
        
        // Then: 変更あり
        XCTAssertTrue(viewModel.hasChanges)
        
        // When: 日時を変更
        viewModel.selectedTask = originalTask
        viewModel.recordedDate = Date().addingTimeInterval(3600)
        
        // Then: 変更あり
        XCTAssertTrue(viewModel.hasChanges)
    }
    
    func testClearMessages() {
        // Given
        viewModel.setError("テストエラー")
        viewModel.setSuccess("テスト成功")
        
        // When
        viewModel.clearMessages()
        
        // Then
        XCTAssertNil(viewModel.viewState.errorMessage)
        XCTAssertNil(viewModel.viewState.successMessage)
    }
}