import XCTest
import Combine
@testable import OtetsudaiCoin

@MainActor
final class HelpRecordEditViewModelTests: XCTestCase {
    
    private var mockHelpRecordRepository: MockHelpRecordRepository!
    private var mockHelpTaskRepository: MockHelpTaskRepository!
    private var viewModel: HelpRecordEditViewModel!
    private var helpRecord: HelpRecord!
    private var child: Child!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockHelpRecordRepository = MockHelpRecordRepository()
        mockHelpTaskRepository = MockHelpTaskRepository()
        child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733", coinRate: 100)
        helpRecord = HelpRecord(id: UUID(), childId: child.id, helpTaskId: UUID(), recordedAt: Date())
        viewModel = HelpRecordEditViewModel(
            helpRecord: helpRecord,
            child: child,
            helpRecordRepository: mockHelpRecordRepository,
            helpTaskRepository: mockHelpTaskRepository
        )
        cancellables = []
    }
    
    override func tearDown() {
        cancellables.forEach { $0.cancel() }
        cancellables = nil
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
    
    func testLoadDataSuccess() async {
        // Given
        let task1 = HelpTask(id: helpRecord.helpTaskId, name: "食器洗い", isActive: true)
        let task2 = HelpTask(id: UUID(), name: "掃除", isActive: true)
        mockHelpTaskRepository.tasks = [task1, task2]
        
        // When
        viewModel.loadData()
        
        // 非同期処理の完了を待機
        let expectation = XCTestExpectation(description: "Load data")
        viewModel.$isLoading
            .dropFirst()
            .sink { isLoading in
                if !isLoading {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.availableTasks.count, 2)
        XCTAssertEqual(viewModel.selectedTask?.id, task1.id)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testLoadDataError() async {
        // Given
        mockHelpTaskRepository.shouldThrowError = true
        
        // When
        viewModel.loadData()
        
        // 非同期処理の完了を待機
        let expectation = XCTestExpectation(description: "Load data error")
        viewModel.$errorMessage
            .dropFirst()
            .sink { errorMessage in
                if errorMessage != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(viewModel.availableTasks.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
    func testSaveChangesSuccess() async {
        // Given
        let newTask = HelpTask(id: UUID(), name: "掃除", isActive: true)
        viewModel.selectedTask = newTask
        let newDate = Date().addingTimeInterval(3600)
        viewModel.recordedDate = newDate
        
        // When
        viewModel.saveChanges()
        
        // 非同期処理の完了を待機
        let expectation = XCTestExpectation(description: "Save changes")
        viewModel.$successMessage
            .dropFirst()
            .sink { successMessage in
                if successMessage != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.successMessage)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testSaveChangesWithoutTask() {
        // Given: タスクが選択されていない状態
        
        // When
        viewModel.saveChanges()
        
        // Then
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, "お手伝いタスクを選択してください")
    }
    
    func testDeleteRecordSuccess() async {
        // When
        viewModel.deleteRecord()
        
        // 非同期処理の完了を待機
        let expectation = XCTestExpectation(description: "Delete record")
        viewModel.$successMessage
            .dropFirst()
            .sink { successMessage in
                if successMessage != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.successMessage)
        XCTAssertNil(viewModel.errorMessage)
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
        viewModel.errorMessage = "テストエラー"
        viewModel.successMessage = "テスト成功"
        
        // When
        viewModel.clearMessages()
        
        // Then
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.successMessage)
    }
}