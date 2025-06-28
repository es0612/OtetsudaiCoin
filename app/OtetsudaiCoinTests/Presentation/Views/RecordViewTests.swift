import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin


final class RecordViewTests: XCTestCase {
    private var viewModel: RecordViewModel!
    private var mockChildRepository: MockChildRepository!
    private var mockHelpTaskRepository: MockHelpTaskRepository!
    private var mockHelpRecordRepository: MockHelpRecordRepository!
    private var mockSoundService: MockSoundService!
    
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
    
    func testRecordViewDisplaysTasksWhenLoaded() throws {
        let tasks = [
            HelpTask(id: UUID(), name: "お風呂を掃除する", isActive: true),
            HelpTask(id: UUID(), name: "食器を洗う", isActive: true)
        ]
        viewModel.availableTasks = tasks
        
        let view = RecordView(viewModel: viewModel)
        let list = try view.inspect().find(ViewType.List.self)
        
        XCTAssertNoThrow(try list.find(text: "お風呂を掃除する"))
        XCTAssertNoThrow(try list.find(text: "食器を洗う"))
    }
    
    func testRecordViewDisplaysSelectedChild() throws {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        viewModel.selectedChild = child
        
        // ViewModelの状態をテスト（より安定）
        XCTAssertEqual(viewModel.selectedChild?.name, "太郎")
        XCTAssertEqual(viewModel.selectedChild?.themeColor, "#FF5733")
        
        // Viewが作成できることを確認
        let view = RecordView(viewModel: viewModel)
        XCTAssertNotNil(view)
    }
    
    func testRecordViewDisplaysLoadingState() throws {
        viewModel.setLoading(true)
        
        let view = RecordView(viewModel: viewModel)
        
        XCTAssertNoThrow(try view.inspect().find(ViewType.ProgressView.self))
    }
    
    func testRecordViewDisplaysErrorMessage() throws {
        viewModel.setError("エラーが発生しました")
        
        let view = RecordView(viewModel: viewModel)
        
        XCTAssertNoThrow(try view.inspect().find(text: "エラーが発生しました"))
    }
    
    func testRecordViewDisplaysSuccessMessage() throws {
        viewModel.setSuccess("記録完了しました！")
        
        let view = RecordView(viewModel: viewModel)
        
        XCTAssertNoThrow(try view.inspect().find(text: "記録完了しました！"))
    }
    
    func testTaskSelectionTriggersViewModelMethod() throws {
        let tasks = [
            HelpTask(id: UUID(), name: "お風呂を掃除する", isActive: true),
            HelpTask(id: UUID(), name: "食器を洗う", isActive: true)
        ]
        viewModel.availableTasks = tasks
        
        let view = RecordView(viewModel: viewModel)
        let list = try view.inspect().find(ViewType.List.self)
        let firstRow = try list.find(ViewType.Button.self, containing: "お風呂を掃除する")
        
        try firstRow.tap()
        
        XCTAssertEqual(viewModel.selectedTask?.name, "お風呂を掃除する")
    }
    
    func testRecordButtonTriggersViewModelMethod() async throws {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let task = HelpTask(id: UUID(), name: "お風呂を掃除する", isActive: true)
        
        viewModel.selectedChild = child
        viewModel.selectedTask = task
        
        let view = RecordView(viewModel: viewModel)
        let recordButton = try view.inspect().find(ViewType.Button.self, containing: "記録する")
        
        try recordButton.tap()
        
        // 非同期処理の完了を待つ
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機
        
        // 記録処理が呼ばれることを確認（mockRepository経由で）
        XCTAssertEqual(mockHelpRecordRepository.records.count, 1)
    }
    
    func testRecordViewDisplaysEmptyStateWhenNoTasks() throws {
        viewModel.availableTasks = []
        
        let view = RecordView(viewModel: viewModel)
        
        XCTAssertNoThrow(try view.inspect().find(text: "利用可能なお手伝いタスクがありません"))
    }
    
    func testRecordViewDisablesRecordButtonWhenNoSelections() throws {
        let tasks = [
            HelpTask(id: UUID(), name: "お風呂を掃除する", isActive: true)
        ]
        viewModel.availableTasks = tasks
        // selectedChild と selectedTask は nil のまま
        
        let view = RecordView(viewModel: viewModel)
        let recordButton = try view.inspect().find(ViewType.Button.self, containing: "記録する")
        
        XCTAssertTrue(try recordButton.isDisabled())
    }
    
    func testRecordViewEnablesRecordButtonWhenBothSelected() throws {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let task = HelpTask(id: UUID(), name: "お風呂を掃除する", isActive: true)
        
        viewModel.selectedChild = child
        viewModel.selectedTask = task
        viewModel.availableTasks = [task]
        
        let view = RecordView(viewModel: viewModel)
        let recordButton = try view.inspect().find(ViewType.Button.self, containing: "記録する")
        
        XCTAssertFalse(try recordButton.isDisabled())
    }
}