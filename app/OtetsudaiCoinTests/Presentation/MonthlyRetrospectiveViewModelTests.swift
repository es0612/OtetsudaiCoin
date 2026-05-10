import XCTest
@testable import OtetsudaiCoin

final class MonthlyRetrospectiveViewModelTests: XCTestCase {

    private var viewModel: MonthlyRetrospectiveViewModel!
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

        viewModel = MonthlyRetrospectiveViewModel(
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
}
