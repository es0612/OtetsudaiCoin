import XCTest
import Combine
@testable import OtetsudaiCoin

@MainActor
final class HomeViewModelTests: XCTestCase {
    private var viewModel: HomeViewModel!
    private var mockChildRepository: MockChildRepository!
    private var mockHelpRecordRepository: MockHelpRecordRepository!
    private var mockAllowanceCalculator: MockAllowanceCalculator!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockChildRepository = MockChildRepository()
        mockHelpRecordRepository = MockHelpRecordRepository()
        mockAllowanceCalculator = MockAllowanceCalculator()
        
        viewModel = HomeViewModel(
            childRepository: mockChildRepository,
            helpRecordRepository: mockHelpRecordRepository,
            allowanceCalculator: mockAllowanceCalculator
        )
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        viewModel = nil
        mockAllowanceCalculator = nil
        mockHelpRecordRepository = nil
        mockChildRepository = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertNil(viewModel.selectedChild)
        XCTAssertEqual(viewModel.monthlyAllowance, 0)
        XCTAssertEqual(viewModel.consecutiveDays, 0)
        XCTAssertEqual(viewModel.totalRecordsThisMonth, 0)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testLoadChildrenSuccess() {
        let expectedChildren = [
            Child(id: UUID(), name: "太郎", themeColor: "#FF5733"),
            Child(id: UUID(), name: "花子", themeColor: "#33FF57")
        ]
        mockChildRepository.children = expectedChildren
        
        let expectation = XCTestExpectation(description: "Children loaded")
        
        viewModel.$children
            .dropFirst()
            .sink { children in
                XCTAssertEqual(children.count, 2)
                XCTAssertEqual(children[0].name, "太郎")
                XCTAssertEqual(children[1].name, "花子")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.loadChildren()
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testLoadChildrenFailure() {
        mockChildRepository.shouldThrowError = true
        
        let expectation = XCTestExpectation(description: "Error occurred")
        
        viewModel.$errorMessage
            .compactMap { $0 }
            .sink { errorMessage in
                XCTAssertNotNil(errorMessage)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        viewModel.loadChildren()
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSelectChild() async {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let records = [
            HelpRecord(id: UUID(), childId: child.id, helpTaskId: UUID(), recordedAt: Date())
        ]
        
        mockHelpRecordRepository.records = records
        mockAllowanceCalculator.monthlyAllowance = 500
        mockAllowanceCalculator.consecutiveDays = 3
        
        viewModel.selectChild(child)
        
        // 非同期処理の完了を待つ
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機
        
        XCTAssertEqual(viewModel.selectedChild?.id, child.id)
        XCTAssertEqual(viewModel.selectedChild?.name, "太郎")
        XCTAssertEqual(viewModel.monthlyAllowance, 500)
        XCTAssertEqual(viewModel.consecutiveDays, 3)
        XCTAssertEqual(viewModel.totalRecordsThisMonth, 1)
    }
    
    func testRefreshData() async {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        viewModel.selectedChild = child
        
        let records = [
            HelpRecord(id: UUID(), childId: child.id, helpTaskId: UUID(), recordedAt: Date()),
            HelpRecord(id: UUID(), childId: child.id, helpTaskId: UUID(), recordedAt: Date())
        ]
        
        mockHelpRecordRepository.records = records
        mockAllowanceCalculator.monthlyAllowance = 800
        mockAllowanceCalculator.consecutiveDays = 5
        
        viewModel.refreshData()
        
        // 非同期処理の完了を待つ
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒待機
        
        XCTAssertEqual(viewModel.monthlyAllowance, 800)
        XCTAssertEqual(viewModel.consecutiveDays, 5)
        XCTAssertEqual(viewModel.totalRecordsThisMonth, 2)
    }
}

// MARK: - Mock Classes

class MockAllowanceCalculator: AllowanceCalculator {
    var monthlyAllowance: Int = 0
    var consecutiveDays: Int = 0
    
    override func calculateMonthlyAllowance(records: [HelpRecord]) -> Int {
        return monthlyAllowance
    }
    
    override func calculateConsecutiveDays(records: [HelpRecord]) -> Int {
        return consecutiveDays
    }
}