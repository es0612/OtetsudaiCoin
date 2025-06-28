import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

final class HelpHistoryViewTests: XCTestCase {
    
    private var mockHelpRecordRepository: MockHelpRecordRepository!
    private var mockHelpTaskRepository: MockHelpTaskRepository!
    private var mockChildRepository: MockChildRepository!
    private var viewModel: HelpHistoryViewModel!
    
    override func setUp() {
        super.setUp()
        mockHelpRecordRepository = MockHelpRecordRepository()
        mockHelpTaskRepository = MockHelpTaskRepository()
        mockChildRepository = MockChildRepository()
        viewModel = HelpHistoryViewModel(
            helpRecordRepository: mockHelpRecordRepository,
            helpTaskRepository: mockHelpTaskRepository,
            childRepository: mockChildRepository
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockChildRepository = nil
        mockHelpTaskRepository = nil
        mockHelpRecordRepository = nil
        super.tearDown()
    }
    
    func testHelpHistoryViewDisplaysTitle() throws {
        // Given
        let view = HelpHistoryView(viewModel: viewModel)
        
        // When & Then - NavigationViewが存在することを確認
        XCTAssertNoThrow(try view.inspect())
    }
    
    func testHelpHistoryViewDisplaysPeriodFilter() throws {
        // Given
        let view = HelpHistoryView(viewModel: viewModel)
        
        // When & Then
        XCTAssertNoThrow(try view.inspect().find(ViewType.Picker.self))
    }
    
    func testHelpHistoryViewDisplaysEmptyState() throws {
        // Given: 空のデータでViewModel
        let view = HelpHistoryView(viewModel: viewModel)
        
        // When & Then
        XCTAssertNoThrow(try view.inspect().find(text: "お手伝い記録がありません"))
    }
    
    func testHelpHistoryViewDisplaysLoadingState() throws {
        // Given
        // @Observableでは内部状態は直接変更できません
        let view = HelpHistoryView(viewModel: viewModel)
        
        // When & Then
        XCTAssertNoThrow(try view.inspect().find(text: "履歴を読み込み中..."))
    }
    
    func testStatisticCardDisplaysCorrectInfo() throws {
        // Given
        let card = StatisticCard(
            icon: "star.fill",
            title: "テスト",
            value: "10",
            subtitle: "回",
            color: .blue
        )
        
        // When & Then
        XCTAssertNoThrow(try card.inspect().find(text: "テスト"))
        XCTAssertNoThrow(try card.inspect().find(text: "10"))
        XCTAssertNoThrow(try card.inspect().find(text: "回"))
    }
    
    func testHelpRecordRowDisplaysTaskInfo() throws {
        // Given
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let task = HelpTask(id: UUID(), name: "食器洗い", isActive: true)
        let record = HelpRecord(id: UUID(), childId: child.id, helpTaskId: task.id, recordedAt: Date())
        let recordWithDetails = HelpRecordWithDetails(helpRecord: record, child: child, task: task)
        
        let row = HelpRecordRow(record: recordWithDetails, onEdit: {}, onDelete: {})
        
        // When & Then
        XCTAssertNoThrow(try row.inspect().find(text: "食器洗い"))
        XCTAssertNoThrow(try row.inspect().find(text: "+100"))
    }
}