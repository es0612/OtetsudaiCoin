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

    // MARK: - AX サイズのレイアウト (#260)
    // dynamicTypeSize は ViewInspector から注入できないため、判定を static helper で検証する
    // (CLAUDE.md「@Environment(\.isEnabled) など環境値駆動の見た目分岐」)。環境値の配線は撮影で確認する。

    func test_taskGrid_usesTwoColumns_atDefaultSizes() {
        XCTAssertEqual(RecordView.taskGridColumns(isAccessibilitySize: false).count, 2)
    }

    func test_taskGrid_usesOneColumn_atAccessibilitySizes() {
        XCTAssertEqual(RecordView.taskGridColumns(isAccessibilitySize: true).count, 1)
    }

}
