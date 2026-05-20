import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

@MainActor
final class RecordButtonBarTests: XCTestCase {
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

    // MARK: - Structural test

    /// #74: RecordView 本体は NavigationStack + ScrollView + BannerAdView の組み合わせで
    /// ViewInspector が深く traverse できないが、独立 component に切り出した
    /// RecordButtonBar 単体なら Button へ到達できる.
    /// `find(viewWithAccessibilityIdentifier:)` は Image + .foregroundColor の
    /// AccessibilityImageLabel が blocker になるため避け、`find(ViewType.Button.self)` を使う.
    func test_recordButtonBar_containsRecordButton() throws {
        let view = RecordButtonBar(viewModel: viewModel)
        XCTAssertNoThrow(try view.inspect().find(ViewType.Button.self))
    }

    /// 初期状態 (child/task 未選択) で button が disabled であることを ViewInspector 経由で確認.
    func test_recordButtonBar_buttonIsDisabled_whenNoSelection() throws {
        let view = RecordButtonBar(viewModel: viewModel)
        let button = try view.inspect().find(ViewType.Button.self)
        XCTAssertTrue(try button.isDisabled())
    }

    /// 単発モードで child + task が両方選ばれていれば button が enabled になることを確認.
    func test_recordButtonBar_buttonIsEnabled_whenSingleSelectionComplete() throws {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let task = HelpTask(id: UUID(), name: "お皿洗い", isActive: true, coinRate: 10)
        viewModel.selectedChild = child
        viewModel.selectedTask = task

        let view = RecordButtonBar(viewModel: viewModel)
        let button = try view.inspect().find(ViewType.Button.self)
        XCTAssertFalse(try button.isDisabled())
    }

    // MARK: - Behavior (一括モード label の plural variations)

    /// 一括モード時に recordButtonLabel が "{n} 件をまとめて記録する" を返し、
    /// xcstrings の plural variations が文字列補間経由で正しく解決されることを担保.
    /// 詳細は CLAUDE.md の「i18n: xcstrings plural variations」節を参照.
    func test_recordButtonLabel_inBulkMode_reflectsSelectedTaskCount() {
        let task = HelpTask(id: UUID(), name: "Test", isActive: true, coinRate: 10)
        viewModel.availableTasks = [task]
        viewModel.toggleBulkMode()
        viewModel.selectedTaskIds = [task.id]

        let bar = RecordButtonBar(viewModel: viewModel)
        XCTAssertTrue(bar.recordButtonLabel.contains("1"),
                      "Expected button label to contain '1', got: \(bar.recordButtonLabel)")
    }

    /// 単発モード時の label は "記録する" 固定であることを担保.
    func test_recordButtonLabel_inSingleMode_isStaticString() {
        let bar = RecordButtonBar(viewModel: viewModel)
        XCTAssertEqual(bar.recordButtonLabel, String(localized: "記録する"))
    }

    /// 一括モード時に「選択されていない / お子様未選択」だと button が disabled になることを担保.
    func test_recordButtonDisabled_inBulkMode_whenNoTaskSelected() {
        viewModel.toggleBulkMode()
        XCTAssertTrue(viewModel.isBulkMode)

        let bar = RecordButtonBar(viewModel: viewModel)
        XCTAssertTrue(bar.recordButtonDisabled, "selectedTaskIds が空なら disabled")
    }
}
