import XCTest
@testable import OtetsudaiCoin

final class MonthlySummaryViewModelTests: XCTestCase {

    private var viewModel: MonthlySummaryViewModel!
    private var mockChildRepository: MockChildRepository!
    private var mockHelpRecordRepository: MockHelpRecordRepository!
    private var mockHelpTaskRepository: MockHelpTaskRepository!
    private var mockAllowancePaymentRepository: MockAllowancePaymentRepository!
    private var child: Child!

    @MainActor
    override func setUp() {
        super.setUp()
        mockChildRepository = MockChildRepository()
        mockHelpRecordRepository = MockHelpRecordRepository()
        mockHelpTaskRepository = MockHelpTaskRepository()
        mockAllowancePaymentRepository = MockAllowancePaymentRepository()

        child = Child(id: UUID(), name: "さくら", themeColor: "#FF6B6B")

        viewModel = MonthlySummaryViewModel(
            child: child,
            helpRecordRepository: mockHelpRecordRepository,
            helpTaskRepository: mockHelpTaskRepository,
            allowancePaymentRepository: mockAllowancePaymentRepository
        )
    }

    override func tearDown() {
        viewModel = nil
        mockAllowancePaymentRepository = nil
        mockHelpTaskRepository = nil
        mockHelpRecordRepository = nil
        mockChildRepository = nil
        child = nil
        super.tearDown()
    }

    // #54: init 終端で isLoading=true を defensive に立てる。
    // sheet 表示直後の empty state（「データがありません」）gap を避けるため。
    // actual load の kick 責務は HomeView.prepareRetrospectiveViewModel 側に集中（二重起動回避）。
    @MainActor
    func testInitSetsIsLoadingDefensively() {
        let freshViewModel = MonthlySummaryViewModel(
            child: child,
            helpRecordRepository: mockHelpRecordRepository,
            helpTaskRepository: mockHelpTaskRepository,
            allowancePaymentRepository: mockAllowancePaymentRepository
        )

        // 旧設計は init 直後 isLoading=false（empty state が見える）
        // 新設計: init 直後から isLoading=true（ProgressView が見える）
        XCTAssertTrue(freshViewModel.isLoading, "init 直後は defensive に isLoading=true でなければならない")
        XCTAssertNil(freshViewModel.snapshot, "snapshot は init 直後は nil")
    }

    @MainActor
    func testInitialMonthIsCurrentMonth() {
        let cal = Calendar.current
        let nowComps = cal.dateComponents([.year, .month], from: Date())
        let modelComps = cal.dateComponents([.year, .month], from: viewModel.selectedMonth)

        XCTAssertEqual(modelComps.year, nowComps.year)
        XCTAssertEqual(modelComps.month, nowComps.month)
    }

    @MainActor
    func testGoToPreviousMonthDecrements() {
        let initial = viewModel.selectedMonth

        viewModel.goToPreviousMonth()

        let cal = Calendar.current
        let expected = cal.date(byAdding: .month, value: -1, to: initial)!
        let actualComps = cal.dateComponents([.year, .month], from: viewModel.selectedMonth)
        let expectedComps = cal.dateComponents([.year, .month], from: expected)

        XCTAssertEqual(actualComps.year, expectedComps.year)
        XCTAssertEqual(actualComps.month, expectedComps.month)
    }

    @MainActor
    func testCannotGoBeyondTwelveMonthsAgo() {
        for _ in 0..<12 {
            viewModel.goToPreviousMonth()
        }
        let twelveMonthsAgo = viewModel.selectedMonth

        viewModel.goToPreviousMonth()

        XCTAssertEqual(
            Calendar.current.dateComponents([.year, .month], from: viewModel.selectedMonth),
            Calendar.current.dateComponents([.year, .month], from: twelveMonthsAgo),
            "12 ヶ月前を超えて遷移してはいけない"
        )
    }

    @MainActor
    func testCannotGoToFutureMonth() {
        let initial = viewModel.selectedMonth

        viewModel.goToNextMonth()

        XCTAssertEqual(
            Calendar.current.dateComponents([.year, .month], from: viewModel.selectedMonth),
            Calendar.current.dateComponents([.year, .month], from: initial)
        )
    }

    @MainActor
    func testLoadMonthPopulatesSnapshot() async {
        let cal = Calendar.current
        let now = Date()
        let thisMonth = cal.dateComponents([.year, .month], from: now)

        let dishesId = UUID()
        let dishes = HelpTask(id: dishesId, name: "皿洗い", isActive: true, coinRate: 100)
        mockHelpTaskRepository.tasks = [dishes]

        var c1 = thisMonth
        c1.day = 3
        c1.hour = 12
        var c2 = thisMonth
        c2.day = 5
        c2.hour = 12

        let r1 = HelpRecord(id: UUID(), childId: child.id, helpTaskId: dishesId, recordedAt: cal.date(from: c1)!)
        let r2 = HelpRecord(id: UUID(), childId: child.id, helpTaskId: dishesId, recordedAt: cal.date(from: c2)!)
        mockHelpRecordRepository.records = [r1, r2]

        mockAllowancePaymentRepository.payments = []

        await viewModel.loadMonth()

        XCTAssertNotNil(viewModel.snapshot)
        let snap = viewModel.snapshot!
        XCTAssertEqual(snap.totalCount, 2)
        XCTAssertEqual(snap.totalCoins, 200)
        XCTAssertEqual(snap.taskBreakdown.count, 1)
        XCTAssertEqual(snap.taskBreakdown.first?.name, "皿洗い")
        XCTAssertEqual(snap.taskBreakdown.first?.count, 2)
        XCTAssertEqual(snap.highlights.consecutiveDayStreak, 1)
        XCTAssertEqual(snap.paymentStatus, .unpaid)
        XCTAssertTrue(snap.monthLabel.contains("\(thisMonth.year!)"))
        XCTAssertTrue(snap.monthLabel.contains("\(thisMonth.month!)"))
    }

    @MainActor
    func testPaymentStatusReflectsAllowancePayment() async {
        let cal = Calendar.current
        let now = Date()
        let thisMonth = cal.dateComponents([.year, .month], from: now)

        let dishesId = UUID()
        let dishes = HelpTask(id: dishesId, name: "皿洗い", isActive: true, coinRate: 100)
        mockHelpTaskRepository.tasks = [dishes]

        var c1 = thisMonth
        c1.day = 3
        c1.hour = 12
        let r1 = HelpRecord(id: UUID(), childId: child.id, helpTaskId: dishesId, recordedAt: cal.date(from: c1)!)
        mockHelpRecordRepository.records = [r1]

        let payment = AllowancePayment(
            id: UUID(),
            childId: child.id,
            amount: 100,
            month: thisMonth.month!,
            year: thisMonth.year!,
            paidAt: Date()
        )
        mockAllowancePaymentRepository.payments = [payment]

        await viewModel.loadMonth()

        XCTAssertEqual(viewModel.snapshot?.paymentStatus, .paid)
    }
}
