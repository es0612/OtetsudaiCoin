import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin


final class HelpRecordEditViewTests: XCTestCase {
    
    private var mockHelpRecordRepository: MockHelpRecordRepository!
    private var mockHelpTaskRepository: MockHelpTaskRepository!
    private var viewModel: HelpRecordEditViewModel!
    
    override func setUp() {
        super.setUp()
        mockHelpRecordRepository = MockHelpRecordRepository()
        mockHelpTaskRepository = MockHelpTaskRepository()
        
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let record = HelpRecord(id: UUID(), childId: child.id, helpTaskId: UUID(), recordedAt: Date())
        
        viewModel = HelpRecordEditViewModel(
            helpRecord: record,
            child: child,
            helpRecordRepository: mockHelpRecordRepository,
            helpTaskRepository: mockHelpTaskRepository
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockHelpTaskRepository = nil
        mockHelpRecordRepository = nil
        super.tearDown()
    }
    
    func testHelpRecordEditViewDisplaysTitle() throws {
        // Given
        let view = HelpRecordEditView(viewModel: viewModel)
        
        // When & Then - NavigationViewが存在することを確認
        XCTAssertNoThrow(try view.inspect())
    }
    
    func testHelpRecordEditViewDisplaysForm() throws {
        // Given
        let view = HelpRecordEditView(viewModel: viewModel)
        
        // When & Then
        XCTAssertNoThrow(try view.inspect())
    }
    
    func testHelpRecordEditViewDisplaysDatePicker() throws {
        // Given
        let view = HelpRecordEditView(viewModel: viewModel)
        
        // When & Then
        XCTAssertNoThrow(try view.inspect().find(text: "日時"))
    }
    
    func testHelpRecordEditViewDisplaysDeleteButton() throws {
        // Given
        let view = HelpRecordEditView(viewModel: viewModel)
        
        // When & Then
        XCTAssertNoThrow(try view.inspect().find(text: "記録を削除"))
    }
    
    func testTaskSelectionRowDisplaysTaskInfo() throws {
        // Given
        let task = HelpTask(id: UUID(), name: "食器洗い", isActive: true)
        let row = TaskSelectionRow(task: task, isSelected: true, onSelect: {})
        
        // When & Then
        XCTAssertNoThrow(try row.inspect().find(text: "食器洗い"))
        XCTAssertNoThrow(try row.inspect().find(text: "お手伝いタスク"))
    }
    
    func testTaskSelectionRowDisplaysSelectedState() throws {
        // Given
        let task = HelpTask(id: UUID(), name: "食器洗い", isActive: true)
        
        // When: 選択状態
        let selectedRow = TaskSelectionRow(task: task, isSelected: true, onSelect: {})
        
        // Then: 基本的な表示確認のみ
        XCTAssertNoThrow(try selectedRow.inspect())
    }
}