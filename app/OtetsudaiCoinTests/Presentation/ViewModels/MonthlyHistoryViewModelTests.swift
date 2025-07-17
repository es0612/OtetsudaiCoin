import XCTest
@testable import OtetsudaiCoin

final class MonthlyHistoryViewModelTests: XCTestCase {
    private var viewModel: MonthlyHistoryViewModel!
    private var mockHelpRecordRepository: MockHelpRecordRepository!
    private var mockAllowancePaymentRepository: MockAllowancePaymentRepository!
    private var mockHelpTaskRepository: MockHelpTaskRepository!
    private var mockAllowanceCalculator: MockAllowanceCalculator!
    private var mockUnpaidDetector: MockUnpaidAllowanceDetectorService!
    
    @MainActor
    override func setUp() {
        super.setUp()
        mockHelpRecordRepository = MockHelpRecordRepository()
        mockAllowancePaymentRepository = MockAllowancePaymentRepository()
        mockHelpTaskRepository = MockHelpTaskRepository()
        mockAllowanceCalculator = MockAllowanceCalculator()
        mockUnpaidDetector = MockUnpaidAllowanceDetectorService()
        
        viewModel = MonthlyHistoryViewModel(
            helpRecordRepository: mockHelpRecordRepository,
            allowancePaymentRepository: mockAllowancePaymentRepository,
            helpTaskRepository: mockHelpTaskRepository,
            allowanceCalculator: mockAllowanceCalculator,
            unpaidDetector: mockUnpaidDetector
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockUnpaidDetector = nil
        mockAllowanceCalculator = nil
        mockHelpTaskRepository = nil
        mockAllowancePaymentRepository = nil
        mockHelpRecordRepository = nil
        super.tearDown()
    }
    
    @MainActor
    func testInitialState() {
        XCTAssertNil(viewModel.selectedChild)
        XCTAssertTrue(viewModel.monthlyRecords.isEmpty)
        XCTAssertTrue(viewModel.unpaidRecords.isEmpty)
        XCTAssertEqual(viewModel.totalUnpaidAmount, 0)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    @MainActor
    func testSelectChild() {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        
        viewModel.selectChild(child)
        
        XCTAssertEqual(viewModel.selectedChild?.id, child.id)
        XCTAssertEqual(viewModel.selectedChild?.name, "太郎")
    }
    
    @MainActor
    func testLoadMonthlyHistoryWithUnpaidRecords() async {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let calendar = Calendar.current
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date())!
        let lastMonthComponents = calendar.dateComponents([.year, .month], from: lastMonth)
        
        // モックデータ設定
        let helpRecord = HelpRecord(
            id: UUID(),
            childId: child.id,
            helpTaskId: UUID(),
            recordedAt: lastMonth
        )
        mockHelpRecordRepository.records = [helpRecord]
        mockAllowanceCalculator.monthlyAllowance = 100
        
        let unpaidPeriod = UnpaidPeriod(
            childId: child.id,
            month: lastMonthComponents.month!,
            year: lastMonthComponents.year!,
            expectedAmount: 100
        )
        mockUnpaidDetector.unpaidPeriods = [unpaidPeriod]
        
        viewModel.selectChild(child)
        
        // 非同期処理完了を待つ
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機
        
        // 検証
        XCTAssertFalse(viewModel.monthlyRecords.isEmpty)
        XCTAssertEqual(viewModel.unpaidRecords.count, 1)
        XCTAssertEqual(viewModel.totalUnpaidAmount, 100)
        
        let unpaidRecord = viewModel.unpaidRecords.first!
        XCTAssertTrue(unpaidRecord.isUnpaid)
        XCTAssertEqual(unpaidRecord.unpaidAmount, 100)
        XCTAssertEqual(unpaidRecord.paymentStatusText, "未支払い")
        XCTAssertEqual(unpaidRecord.highlightColor, "#FF6B6B")
    }
    
    @MainActor
    func _testLoadMonthlyHistoryWithPartiallyPaidRecords() async {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let calendar = Calendar.current
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date())!
        let lastMonthComponents = calendar.dateComponents([.year, .month], from: lastMonth)
        
        // モックデータ設定
        let helpRecord = HelpRecord(
            id: UUID(),
            childId: child.id,
            helpTaskId: UUID(),
            recordedAt: lastMonth
        )
        mockHelpRecordRepository.records = [helpRecord]
        mockAllowanceCalculator.monthlyAllowance = 100
        
        let partialPayment = AllowancePayment(
            id: UUID(),
            childId: child.id,
            amount: 50, // 半分だけ支払い済み
            month: lastMonthComponents.month!,
            year: lastMonthComponents.year!,
            paidAt: Date()
        )
        mockAllowancePaymentRepository.payments = [partialPayment]
        
        let unpaidPeriod = UnpaidPeriod(
            childId: child.id,
            month: lastMonthComponents.month!,
            year: lastMonthComponents.year!,
            expectedAmount: 50 // 残り50コイン未支払い
        )
        mockUnpaidDetector.unpaidPeriods = [unpaidPeriod]
        
        viewModel.selectChild(child)
        
        // 非同期処理完了を待つ
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機
        
        // 検証
        XCTAssertFalse(viewModel.monthlyRecords.isEmpty)
        XCTAssertEqual(viewModel.unpaidRecords.count, 1)
        XCTAssertEqual(viewModel.totalUnpaidAmount, 50)
        
        // 月別記録から最初のものを取得して確認
        let monthlyRecord = viewModel.monthlyRecords.first!
        XCTAssertTrue(monthlyRecord.isUnpaid)
        XCTAssertTrue(monthlyRecord.isPartiallyPaid)
        XCTAssertEqual(monthlyRecord.unpaidAmount, 50)
        XCTAssertEqual(monthlyRecord.paymentStatusText, "一部支払い済み")
        XCTAssertEqual(monthlyRecord.highlightColor, "#FFB84D") // 一部支払い済みなので橙
    }
    
    @MainActor
    func testLoadMonthlyHistoryWithFullyPaidRecords() async {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let calendar = Calendar.current
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date())!
        let lastMonthComponents = calendar.dateComponents([.year, .month], from: lastMonth)
        
        // モックデータ設定
        let helpRecord = HelpRecord(
            id: UUID(),
            childId: child.id,
            helpTaskId: UUID(),
            recordedAt: lastMonth
        )
        mockHelpRecordRepository.records = [helpRecord]
        mockAllowanceCalculator.monthlyAllowance = 100
        
        let fullPayment = AllowancePayment(
            id: UUID(),
            childId: child.id,
            amount: 100, // 全額支払い済み
            month: lastMonthComponents.month!,
            year: lastMonthComponents.year!,
            paidAt: Date()
        )
        mockAllowancePaymentRepository.payments = [fullPayment]
        
        // 未支払い期間なし
        mockUnpaidDetector.unpaidPeriods = []
        
        viewModel.selectChild(child)
        
        // 非同期処理完了を待つ
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機
        
        // 検証
        XCTAssertFalse(viewModel.monthlyRecords.isEmpty)
        XCTAssertTrue(viewModel.unpaidRecords.isEmpty) // 未支払い記録なし
        XCTAssertEqual(viewModel.totalUnpaidAmount, 0)
        
        let paidRecord = viewModel.monthlyRecords.first!
        XCTAssertFalse(paidRecord.isUnpaid)
        XCTAssertFalse(paidRecord.isPartiallyPaid)
        XCTAssertEqual(paidRecord.unpaidAmount, 0)
        XCTAssertEqual(paidRecord.paymentStatusText, "支払い済み")
        XCTAssertEqual(paidRecord.highlightColor, "#51CF66") // 緑色
    }
}