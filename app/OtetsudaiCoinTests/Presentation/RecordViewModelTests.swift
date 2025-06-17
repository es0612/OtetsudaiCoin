import XCTest
import Combine
@testable import OtetsudaiCoin

@MainActor
final class RecordViewModelTests: XCTestCase {
    private var viewModel: RecordViewModel!
    private var mockChildRepository: MockChildRepository!
    private var mockHelpTaskRepository: MockHelpTaskRepository!
    private var mockHelpRecordRepository: MockHelpRecordRepository!
    private var mockSoundService: MockSoundService!
    private var cancellables: Set<AnyCancellable>!
    
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
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        viewModel = nil
        mockSoundService = nil
        mockHelpRecordRepository = nil
        mockHelpTaskRepository = nil
        mockChildRepository = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertTrue(viewModel.availableChildren.isEmpty)
        XCTAssertTrue(viewModel.availableTasks.isEmpty)
        XCTAssertNil(viewModel.selectedChild)
        XCTAssertNil(viewModel.selectedTask)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.successMessage)
    }
    
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
        
        let expectation = XCTestExpectation(description: "Data loaded")
        
        viewModel.$availableTasks
            .dropFirst()
            .sink { tasks in
                XCTAssertEqual(tasks.count, 2) // アクティブなタスクのみ
                XCTAssertTrue(tasks.allSatisfy { $0.isActive })
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.loadData()
        
        await fulfillment(of: [expectation], timeout: 1.0)
        
        XCTAssertEqual(viewModel.availableChildren.count, 2)
        XCTAssertEqual(viewModel.selectedChild?.name, "太郎") // 最初の子供が自動選択される
    }
    
    func testLoadDataFailure() async {
        mockHelpTaskRepository.shouldThrowError = true
        
        let expectation = XCTestExpectation(description: "Error occurred")
        
        viewModel.$errorMessage
            .compactMap { $0 }
            .sink { errorMessage in
                XCTAssertNotNil(errorMessage)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.loadData()
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testSelectChild() {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        
        viewModel.selectChild(child)
        
        XCTAssertEqual(viewModel.selectedChild?.id, child.id)
        XCTAssertEqual(viewModel.selectedChild?.name, "太郎")
    }
    
    func testSelectTask() {
        let task = HelpTask(id: UUID(), name: "お風呂を入れる", isActive: true)
        
        viewModel.selectTask(task)
        
        XCTAssertEqual(viewModel.selectedTask?.id, task.id)
        XCTAssertEqual(viewModel.selectedTask?.name, "お風呂を入れる")
    }
    
    func testRecordHelpSuccess() async {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let task = HelpTask(id: UUID(), name: "お風呂を入れる", isActive: true)
        
        viewModel.selectChild(child)
        viewModel.selectTask(task)
        
        let expectation = XCTestExpectation(description: "Help recorded successfully")
        
        viewModel.$successMessage
            .compactMap { $0 }
            .sink { successMessage in
                XCTAssertEqual(successMessage, "お手伝いを記録しました！")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.recordHelp()
        
        await fulfillment(of: [expectation], timeout: 1.0)
        
        // 記録後の状態確認
        XCTAssertNil(viewModel.selectedTask)
        XCTAssertEqual(mockHelpRecordRepository.records.count, 1)
        XCTAssertEqual(mockHelpRecordRepository.records.first?.childId, child.id)
        XCTAssertEqual(mockHelpRecordRepository.records.first?.helpTaskId, task.id)
    }
    
    func testRecordHelpWithoutChildSelection() {
        let task = HelpTask(id: UUID(), name: "お風呝を入れる", isActive: true)
        viewModel.selectTask(task)
        
        viewModel.recordHelp()
        
        XCTAssertEqual(viewModel.errorMessage, "お子様を選択してください")
    }
    
    func testRecordHelpWithoutTaskSelection() {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        viewModel.selectChild(child)
        
        viewModel.recordHelp()
        
        XCTAssertEqual(viewModel.errorMessage, "お手伝いタスクを選択してください")
    }
    
    func testRecordHelpFailure() async {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let task = HelpTask(id: UUID(), name: "お風呂を入れる", isActive: true)
        
        viewModel.selectChild(child)
        viewModel.selectTask(task)
        
        mockHelpRecordRepository.shouldThrowError = true
        
        let expectation = XCTestExpectation(description: "Error occurred")
        
        viewModel.$errorMessage
            .compactMap { $0 }
            .sink { errorMessage in
                XCTAssertNotNil(errorMessage)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.recordHelp()
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testClearMessages() {
        viewModel.errorMessage = "テストエラー"
        viewModel.successMessage = "テスト成功"
        
        viewModel.clearMessages()
        
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.successMessage)
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
}

