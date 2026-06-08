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
    // 画面表示直後の empty state（「データがありません」）gap を避けるため。
    // actual load の kick 責務は HomeView.monthlySummaryView(for:) の .onAppear に集中（二重起動回避）。
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

    @MainActor
    func testPayCurrentMonthSavesPaymentAndMarksPaid() async {
        let cal = Calendar.current
        let thisMonth = cal.dateComponents([.year, .month], from: Date())

        let dishesId = UUID()
        mockHelpTaskRepository.tasks = [HelpTask(id: dishesId, name: "皿洗い", isActive: true, coinRate: 100)]

        var c1 = thisMonth; c1.day = 3; c1.hour = 12
        var c2 = thisMonth; c2.day = 5; c2.hour = 12
        mockHelpRecordRepository.records = [
            HelpRecord(id: UUID(), childId: child.id, helpTaskId: dishesId, recordedAt: cal.date(from: c1)!),
            HelpRecord(id: UUID(), childId: child.id, helpTaskId: dishesId, recordedAt: cal.date(from: c2)!)
        ]
        mockAllowancePaymentRepository.payments = []

        await viewModel.loadMonth()
        XCTAssertEqual(viewModel.snapshot?.paymentStatus, .unpaid, "前提: 未払い")

        await viewModel.payCurrentMonth()

        XCTAssertEqual(mockAllowancePaymentRepository.payments.count, 1, "支払いが1件保存される")
        XCTAssertEqual(mockAllowancePaymentRepository.payments.first?.amount, 200, "金額は当月コイン合計")
        XCTAssertEqual(viewModel.snapshot?.paymentStatus, .paid, "再ロード後は支払い済み")
    }

    @MainActor
    func testPayCurrentMonthOnPartiallyPaidPaysOnlyRemainder() async {
        let cal = Calendar.current
        let thisMonth = cal.dateComponents([.year, .month], from: Date())

        let dishesId = UUID()
        mockHelpTaskRepository.tasks = [HelpTask(id: dishesId, name: "皿洗い", isActive: true, coinRate: 100)]
        var c1 = thisMonth; c1.day = 3; c1.hour = 12
        var c2 = thisMonth; c2.day = 5; c2.hour = 12
        mockHelpRecordRepository.records = [
            HelpRecord(id: UUID(), childId: child.id, helpTaskId: dishesId, recordedAt: cal.date(from: c1)!),
            HelpRecord(id: UUID(), childId: child.id, helpTaskId: dishesId, recordedAt: cal.date(from: c2)!)
        ]
        // 既に 100 だけ支払い済み（期待 200 → 残額 100）
        mockAllowancePaymentRepository.payments = [
            AllowancePayment(id: UUID(), childId: child.id, amount: 100, month: thisMonth.month!, year: thisMonth.year!, paidAt: Date())
        ]

        await viewModel.loadMonth()
        XCTAssertEqual(viewModel.snapshot?.paymentStatus, .partiallyPaid, "前提: 一部支払い済み")

        await viewModel.payCurrentMonth()

        let saved = mockAllowancePaymentRepository.payments
        XCTAssertEqual(saved.count, 2, "残額分の payment が1件だけ追加される（全額二重払いしない）")
        XCTAssertEqual(saved.last?.amount, 100, "追加額は残額(200-100)のみ")
        XCTAssertEqual(viewModel.snapshot?.paymentStatus, .paid, "完済後は支払い済み")
    }

    // CLAUDE.md: date-math 反復弱点(#112/#114/#115)への予防線。年境界(Dec→Jan)を必ず1件。
    // 「前年12月」を起点にすると次月=今年1月で必ず現在月以下 → future-guard を通過し実行日非依存。
    @MainActor
    func testGoToNextMonthCrossesYearBoundary() {
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        var decComps = DateComponents()
        decComps.year = currentYear - 1
        decComps.month = 12
        decComps.day = 1
        let december = cal.date(from: decComps)!

        let vm = MonthlySummaryViewModel(
            child: child,
            helpRecordRepository: mockHelpRecordRepository,
            helpTaskRepository: mockHelpTaskRepository,
            allowancePaymentRepository: mockAllowancePaymentRepository,
            initialMonth: december
        )

        vm.goToNextMonth()

        let comps = cal.dateComponents([.year, .month], from: vm.selectedMonth)
        XCTAssertEqual(comps.month, 1, "12月の次は1月")
        XCTAssertEqual(comps.year, currentYear, "前年12月 → 今年1月で年が繰り上がる (Dec→Jan)")
    }

    // MARK: - #125 M-1: 水平スワイプの方向（iOS 慣習に合わせる）

    // 起点を「前月」にし、左スワイプ→当月（== currentMonthStart で future-guard を通過）を期待。
    // 当月/前月の相対起点に限定することで実行日・年境界に依存しない（#112/#114/#115 の date-math 弱点予防）。
    @MainActor
    func testSwipeLeftAdvancesToNextMonth() {
        let cal = Calendar.current
        let currentStart = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
        let lastMonth = cal.date(byAdding: .month, value: -1, to: currentStart)!

        let vm = MonthlySummaryViewModel(
            child: child,
            helpRecordRepository: mockHelpRecordRepository,
            helpTaskRepository: mockHelpTaskRepository,
            allowancePaymentRepository: mockAllowancePaymentRepository,
            initialMonth: lastMonth
        )

        vm.handleHorizontalSwipe(translationWidth: -60)

        let comps = cal.dateComponents([.year, .month], from: vm.selectedMonth)
        let expected = cal.dateComponents([.year, .month], from: currentStart)
        XCTAssertEqual(comps.year, expected.year, "左スワイプ（width<0）は次の月（当月）へ進むべき")
        XCTAssertEqual(comps.month, expected.month, "左スワイプ（width<0）は次の月（当月）へ進むべき")
    }

    // 起点を「当月」にし、右スワイプ→前月を期待。buggy 方向だと goToNextMonth が future-guard で no-op になり当月のまま fail する。
    @MainActor
    func testSwipeRightGoesToPreviousMonth() {
        let cal = Calendar.current
        let currentStart = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!

        let vm = MonthlySummaryViewModel(
            child: child,
            helpRecordRepository: mockHelpRecordRepository,
            helpTaskRepository: mockHelpTaskRepository,
            allowancePaymentRepository: mockAllowancePaymentRepository,
            initialMonth: currentStart
        )

        vm.handleHorizontalSwipe(translationWidth: 60)

        let comps = cal.dateComponents([.year, .month], from: vm.selectedMonth)
        let expected = cal.dateComponents([.year, .month], from: cal.date(byAdding: .month, value: -1, to: currentStart)!)
        XCTAssertEqual(comps.year, expected.year, "右スワイプ（width>0）は前の月へ戻るべき")
        XCTAssertEqual(comps.month, expected.month, "右スワイプ（width>0）は前の月へ戻るべき")
    }

    // MARK: - #125 M-2: 記録ゼロの月は ¥0 支払い CTA を出さない

    @MainActor
    func testEmptyMonthIsPaidSoNoCTA() async {
        mockHelpTaskRepository.tasks = []
        mockHelpRecordRepository.records = []
        mockAllowancePaymentRepository.payments = []

        await viewModel.loadMonth()

        XCTAssertEqual(viewModel.snapshot?.totalCoins, 0, "前提: 記録ゼロで獲得コインは 0")
        XCTAssertEqual(
            viewModel.snapshot?.paymentStatus, .paid,
            "獲得 0 の月は支払い対象なし → .paid（CTA 非表示）。空月で ¥0 CTA が出る回帰を防ぐ"
        )
    }
}
