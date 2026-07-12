import XCTest
@testable import OtetsudaiCoin

final class HomeViewModelTests: XCTestCase {
    private var viewModel: HomeViewModel!
    private var mockChildRepository: MockChildRepository!
    private var mockHelpRecordRepository: MockHelpRecordRepository!
    private var mockHelpTaskRepository: MockHelpTaskRepository!
    private var mockAllowanceCalculator: MockAllowanceCalculator!
    private var mockAllowancePaymentRepository: MockAllowancePaymentRepository!
    
    @MainActor
    override func setUp() {
        super.setUp()
        mockChildRepository = MockChildRepository()
        mockHelpRecordRepository = MockHelpRecordRepository()
        mockHelpTaskRepository = MockHelpTaskRepository()
        mockAllowanceCalculator = MockAllowanceCalculator()
        mockAllowancePaymentRepository = MockAllowancePaymentRepository()
        
        viewModel = HomeViewModel(
            childRepository: mockChildRepository,
            helpRecordRepository: mockHelpRecordRepository,
            helpTaskRepository: mockHelpTaskRepository,
            allowanceCalculator: mockAllowanceCalculator,
            allowancePaymentRepository: mockAllowancePaymentRepository
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockAllowancePaymentRepository = nil
        mockAllowanceCalculator = nil
        mockHelpTaskRepository = nil
        mockHelpRecordRepository = nil
        mockChildRepository = nil
        super.tearDown()
    }
    
    @MainActor
    func testInitialState() {
        XCTAssertNil(viewModel.selectedChild)
        XCTAssertEqual(viewModel.monthlyAllowance, 0)
        XCTAssertEqual(viewModel.consecutiveDays, 0)
        XCTAssertEqual(viewModel.totalRecordsThisMonth, 0)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    // #44: View 側の `.task` から呼ばれる loadChildrenAsync の挙動を確認
    @MainActor
    func testLoadChildrenAsyncPopulatesChildrenAndFinishesLoading() async {
        let child1 = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let child2 = Child(id: UUID(), name: "花子", themeColor: "#33FF57")
        mockChildRepository.children = [child1, child2]

        await viewModel.loadChildrenAsync()

        XCTAssertEqual(viewModel.children.count, 2)
        XCTAssertEqual(viewModel.children.map { $0.id }, [child1.id, child2.id])
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testLoadChildrenAsyncSurfacesErrorMessageOnFailure() async {
        mockChildRepository.shouldThrowError = true

        await viewModel.loadChildrenAsync()

        XCTAssertTrue(viewModel.children.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    @MainActor
    func testSelectChild() {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let records = [
            HelpRecord(id: UUID(), childId: child.id, helpTaskId: UUID(), recordedAt: Date())
        ]
        
        mockHelpRecordRepository.records = records
        mockAllowanceCalculator.monthlyAllowance = 500
        mockAllowanceCalculator.consecutiveDays = 3
        
        viewModel.selectChild(child)
        
        XCTAssertEqual(viewModel.selectedChild?.id, child.id)
        XCTAssertEqual(viewModel.selectedChild?.name, "太郎")
    }
    
    
    @MainActor
    func testSelectSameChildMultipleTimes() {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let records = [
            HelpRecord(id: UUID(), childId: child.id, helpTaskId: UUID(), recordedAt: Date())
        ]
        
        mockHelpRecordRepository.records = records
        mockAllowanceCalculator.monthlyAllowance = 500
        mockAllowanceCalculator.consecutiveDays = 3
        
        // 最初の選択
        viewModel.selectChild(child)
        XCTAssertEqual(viewModel.selectedChild?.id, child.id)
        
        // APIコール回数をリセット
        mockHelpRecordRepository.resetCallCount()
        mockHelpTaskRepository.resetCallCount()
        
        // 同じ子供を再選択
        viewModel.selectChild(child)
        
        // APIコールが実行されないことを確認
        XCTAssertEqual(mockHelpRecordRepository.findCallCount, 0)
        XCTAssertEqual(mockHelpTaskRepository.findCallCount, 0)
        
        // 選択された子供は変わらず
        XCTAssertEqual(viewModel.selectedChild?.id, child.id)
    }
    
    @MainActor
    func testSelectDifferentChildAfterSameChild() async {
        let child1 = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let child2 = Child(id: UUID(), name: "花子", themeColor: "#33FF57")
        
        mockHelpRecordRepository.records = []
        mockAllowanceCalculator.monthlyAllowance = 300
        
        // 最初の子供を選択
        viewModel.selectChild(child1)
        XCTAssertEqual(viewModel.selectedChild?.id, child1.id)
        
        // 非同期処理完了を待つ
        await viewModel.refreshDataTask?.value

        // 同じ子供を再選択（refreshDataは呼ばれない）
        mockHelpRecordRepository.resetCallCount()
        viewModel.selectChild(child1)
        XCTAssertEqual(mockHelpRecordRepository.findCallCount, 0)

        // 異なる子供を選択（refreshDataが呼ばれる）
        viewModel.selectChild(child2)
        XCTAssertEqual(viewModel.selectedChild?.id, child2.id)

        // 非同期処理完了を待つ
        await viewModel.refreshDataTask?.value

        XCTAssertEqual(mockHelpRecordRepository.findCallCount, 1)
    }

    @MainActor
    func testCheckUnpaidAllowancesWithNoUnpaid() async {
        let mockUnpaidDetector = MockUnpaidAllowanceDetectorService()
        mockUnpaidDetector.unpaidPeriods = []

        viewModel = createViewModelWithUnpaidDetector(unpaidDetector: mockUnpaidDetector)

        await viewModel.checkUnpaidAllowances()

        XCTAssertFalse(viewModel.hasUnpaidAllowances)
        XCTAssertTrue(viewModel.unpaidPeriods.isEmpty)
        XCTAssertNil(viewModel.unpaidWarningMessage)
    }
    
    @MainActor
    func testCheckUnpaidAllowancesWithUnpaidPeriods() async {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let unpaidPeriod = UnpaidPeriod(
            childId: child.id,
            month: 6,
            year: 2024,
            expectedAmount: 150
        )

        let mockUnpaidDetector = MockUnpaidAllowanceDetectorService()
        mockUnpaidDetector.unpaidPeriods = [unpaidPeriod]

        viewModel = createViewModelWithUnpaidDetector(unpaidDetector: mockUnpaidDetector)
        viewModel.children = [child]

        await viewModel.checkUnpaidAllowances()

        XCTAssertTrue(viewModel.hasUnpaidAllowances)
        XCTAssertEqual(viewModel.unpaidPeriods.count, 1)
        XCTAssertEqual(viewModel.unpaidPeriods.first?.childId, child.id)
        XCTAssertNotNil(viewModel.unpaidWarningMessage)
        XCTAssertTrue(viewModel.unpaidWarningMessage!.contains("太郎"))
        XCTAssertTrue(viewModel.unpaidWarningMessage!.contains("150"))
    }
    
    @MainActor
    func testCheckUnpaidAllowancesWithMultipleChildren() async {
        let child1 = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let child2 = Child(id: UUID(), name: "花子", themeColor: "#33FF57")

        let unpaidPeriods = [
            UnpaidPeriod(childId: child1.id, month: 6, year: 2024, expectedAmount: 150),
            UnpaidPeriod(childId: child2.id, month: 5, year: 2024, expectedAmount: 200)
        ]

        let mockUnpaidDetector = MockUnpaidAllowanceDetectorService()
        mockUnpaidDetector.unpaidPeriods = unpaidPeriods

        viewModel = createViewModelWithUnpaidDetector(unpaidDetector: mockUnpaidDetector)
        viewModel.children = [child1, child2]

        await viewModel.checkUnpaidAllowances()

        XCTAssertTrue(viewModel.hasUnpaidAllowances)
        XCTAssertEqual(viewModel.unpaidPeriods.count, 2)
        XCTAssertEqual(viewModel.totalUnpaidAmount, 350)
        XCTAssertNotNil(viewModel.unpaidWarningMessage)
        XCTAssertTrue(viewModel.unpaidWarningMessage!.contains("2人"))
        XCTAssertTrue(viewModel.unpaidWarningMessage!.contains("350"))
    }
    
    @MainActor
    func testDismissUnpaidWarning() async {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let unpaidPeriod = UnpaidPeriod(
            childId: child.id,
            month: 6,
            year: 2024,
            expectedAmount: 150
        )

        let mockUnpaidDetector = MockUnpaidAllowanceDetectorService()
        mockUnpaidDetector.unpaidPeriods = [unpaidPeriod]

        viewModel = createViewModelWithUnpaidDetector(unpaidDetector: mockUnpaidDetector)
        viewModel.children = [child]

        await viewModel.checkUnpaidAllowances()
        XCTAssertTrue(viewModel.hasUnpaidAllowances)

        viewModel.dismissUnpaidWarning()
        XCTAssertFalse(viewModel.showUnpaidWarning)
    }
    
    // MARK: - recordAllowancePayment（#145 移行に伴い最終状態を固定する characterization tests）

    @MainActor
    func testRecordAllowancePaymentWithoutChildSetsErrorMessage() {
        // Given: 子供未選択

        // When
        viewModel.recordAllowancePayment(amount: 100)

        // Then: 同期 guard で即エラー
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(mockAllowancePaymentRepository.payments.isEmpty)
    }

    @MainActor
    func testRecordAllowancePaymentNewPaymentSetsSuccessAndPaidFlag() async {
        // Given: 子供選択済み・当月支払いなし（新規支払い経路）
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        viewModel.selectedChild = child

        // When
        viewModel.recordAllowancePayment(amount: 150)

        // 非同期処理の完了を待機
        let expectation = XCTestExpectation(description: "Record allowance payment")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)

        // Then: 支払いが保存され、成功メッセージと支払い済みフラグが立つ
        XCTAssertEqual(mockAllowancePaymentRepository.payments.count, 1)
        XCTAssertEqual(mockAllowancePaymentRepository.payments.first?.amount, 150)
        XCTAssertTrue(viewModel.isCurrentMonthPaid)
        XCTAssertNotNil(viewModel.successMessage)
        XCTAssertTrue(viewModel.successMessage!.contains("太郎"))
        XCTAssertTrue(viewModel.successMessage!.contains("150"))
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testRecordAllowancePaymentFailureSetsErrorMessageAndStopsLoading() async {
        // Given: 保存が失敗する
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        viewModel.selectedChild = child
        mockAllowancePaymentRepository.shouldThrowError = true

        // When
        viewModel.recordAllowancePayment(amount: 150)

        // 非同期処理の完了を待機
        let expectation = XCTestExpectation(description: "Record allowance payment failure")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)

        // Then: エラーメッセージがセットされ、ローディングは終了する
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.isCurrentMonthPaid)
        XCTAssertNil(viewModel.successMessage)
    }

    @MainActor
    private func createViewModelWithUnpaidDetector(unpaidDetector: UnpaidAllowanceDetectorService) -> HomeViewModel {
        return HomeViewModel(
            childRepository: mockChildRepository,
            helpRecordRepository: mockHelpRecordRepository,
            helpTaskRepository: mockHelpTaskRepository,
            allowanceCalculator: mockAllowanceCalculator,
            allowancePaymentRepository: mockAllowancePaymentRepository,
            unpaidDetector: unpaidDetector
        )
    }
}

// MARK: - Mock Classes

class MockAllowanceCalculator: AllowanceCalculator {
    var monthlyAllowance: Int = 0
    var consecutiveDays: Int = 0
    
    override func calculateMonthlyAllowance(records: [HelpRecord], tasks: [HelpTask]) -> Int {
        return monthlyAllowance
    }
    
    override func calculateMonthlyAllowance(records: [HelpRecord]) -> Int {
        return monthlyAllowance
    }
    
    override func calculateConsecutiveDays(records: [HelpRecord]) -> Int {
        return consecutiveDays
    }
}

class MockUnpaidAllowanceDetectorService: UnpaidAllowanceDetectorService {
    var unpaidPeriods: [UnpaidPeriod] = []
    
    override func detectUnpaidPeriods(
        childId: UUID,
        helpRecords: [HelpRecord],
        payments: [AllowancePayment],
        tasks: [HelpTask]
    ) -> [UnpaidPeriod] {
        return unpaidPeriods.filter { $0.childId == childId }
    }
}