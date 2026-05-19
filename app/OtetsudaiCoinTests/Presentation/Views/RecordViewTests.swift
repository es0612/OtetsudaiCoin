import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin

@MainActor
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

    /// RecordView がクラッシュなく初期化できることを確認 (smoke test)
    /// ViewInspector は RecordView の NavigationStack + ScrollView + ZStack + BannerAdView + Material 構造を
    /// 深く traverse できない (既知制約) ため、UI 構造の存在は本テストで担保せず、Simulator 検証 (Task 13) に委ねる。
    /// ViewModel 側 (toggleBulkMode / recordBulkHelp) は RecordViewModelTests で網羅。
    func test_recordView_initializes_withoutCrash() {
        _ = RecordView(viewModel: viewModel)
    }

    /// 一括モード時に viewModel が toggleBulkMode を通じて状態を切替えられることを確認。
    /// View binding の wire-up が正しいことを ViewModel 経由で間接的に担保。
    func test_toggleBulkMode_setsStateForView() {
        XCTAssertFalse(viewModel.isBulkMode)
        viewModel.toggleBulkMode()
        XCTAssertTrue(viewModel.isBulkMode)
    }

    /// #74 refactor 完了後に PASS することを期待する structural test (red 段階).
    /// 現状の top-level ZStack + .ultraThinMaterial で record_button へ ViewInspector
    /// が到達できないことを Task 1 の段階で確認する.
    /// BannerAdView (ScrollView 内) は #49 仕様維持のため移動せず、その結果
    /// ScrollView 内の bulk_mode_toggle / record_date_picker には traversal せず
    /// ScrollView の sibling である record_button のみを対象にする.
    func test_recordView_canTraverseToRecordButton() throws {
        let view = RecordView(viewModel: viewModel)
        XCTAssertNoThrow(try view.inspect().find(viewWithAccessibilityIdentifier: "record_button"))
    }
}
