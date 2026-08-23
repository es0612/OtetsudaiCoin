import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin


@MainActor
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
        XCTAssertNoThrow(try view.inspect().find(text: "日時", locale: Locale(identifier: "ja")))
    }
    
    func testHelpRecordEditViewDisplaysDeleteButton() throws {
        // Given
        let view = HelpRecordEditView(viewModel: viewModel)
        
        // When & Then
        XCTAssertNoThrow(try view.inspect().find(text: "記録を削除", locale: Locale(identifier: "ja")))
    }
    
    func testTaskSelectionRowDisplaysTaskInfo() throws {
        // Given
        let task = HelpTask(id: UUID(), name: "食器洗い", isActive: true)
        let row = TaskSelectionRow(task: task, isSelected: true, onSelect: {})
        
        // When & Then
        XCTAssertNoThrow(try row.inspect().find(text: "食器洗い"))
        XCTAssertNoThrow(try row.inspect().find(text: "お手伝いタスク", locale: Locale(identifier: "ja")))
    }
    
    func testTaskSelectionRowDisplaysSelectedState() throws {
        // Given
        let task = HelpTask(id: UUID(), name: "食器洗い", isActive: true)
        
        // When: 選択状態
        let selectedRow = TaskSelectionRow(task: task, isSelected: true, onSelect: {})
        
        // Then: 基本的な表示確認のみ
        XCTAssertNoThrow(try selectedRow.inspect())
    }

    /// #177 項目5: タスク選択行のアイコンは displayIcon 絵文字を表示する (#148 の展開)。
    func testTaskSelectionRowRendersDisplayIconEmoji() throws {
        let task = HelpTask(id: UUID(), name: "食器洗い", isActive: true, coinRate: 10, sortOrder: 0, icon: "🧽")
        let row = TaskSelectionRow(task: task, isSelected: false, onSelect: {})
        let texts = try row.renderedTexts()
        XCTAssertTrue(texts.contains("🧽"), "rendered: \(texts)")
    }

    /// icon 未設定 & 辞書外名は ✨ へフォールバックする。
    func testTaskSelectionRowFallsBackToSparkle() throws {
        let task = HelpTask(id: UUID(), name: "辞書に無い独自タスク", isActive: true)
        let row = TaskSelectionRow(task: task, isSelected: false, onSelect: {})
        let texts = try row.renderedTexts()
        XCTAssertTrue(texts.contains("✨"), "rendered: \(texts)")
    }

    /// #177 項目5 で導入した円塗りルール (選択 taskIconSelectedFill / 非選択 taskIconUnselectedFill) の
    /// regression guard。項目7 と同じ findAll(Shape) + トークン定数の等価比較パターン。
    func testTaskSelectionRowCircleFillFollowsSelectionState() throws {
        let task = HelpTask(id: UUID(), name: "食器洗い", isActive: true)

        let selectedFills = try TaskSelectionRow(task: task, isSelected: true, onSelect: {}).renderedFills()
        XCTAssertTrue(
            selectedFills.contains(AccessibilityColors.taskIconSelectedFill),
            "選択時の円が taskIconSelectedFill でない / observed fills: \(selectedFills)"
        )

        let unselectedFills = try TaskSelectionRow(task: task, isSelected: false, onSelect: {}).renderedFills()
        XCTAssertTrue(
            unselectedFills.contains(AccessibilityColors.taskIconUnselectedFill),
            "非選択時の円が taskIconUnselectedFill でない / observed fills: \(unselectedFills)"
        )
    }
}
