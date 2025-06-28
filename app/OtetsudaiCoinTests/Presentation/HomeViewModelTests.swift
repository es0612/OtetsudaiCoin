import XCTest
@testable import OtetsudaiCoin

final class HomeViewModelTests: XCTestCase {
    private var viewModel: HomeViewModel!
    private var mockChildRepository: MockChildRepository!
    private var mockHelpRecordRepository: MockHelpRecordRepository!
    private var mockHelpTaskRepository: MockHelpTaskRepository!
    private var mockAllowanceCalculator: MockAllowanceCalculator!
    private var mockAllowancePaymentRepository: MockAllowancePaymentRepository!
    
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
        
        viewModel.loadChildren()
        
        XCTAssertEqual(viewModel.children.count, 2)
        XCTAssertEqual(viewModel.children[0].name, "太郎")
        XCTAssertEqual(viewModel.children[1].name, "花子")
    }
    
    func testLoadChildrenFailure() {
        mockChildRepository.shouldThrowError = true
        
        viewModel.loadChildren()
        
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
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
    
    func testRefreshData() {
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
        
        XCTAssertEqual(viewModel.monthlyAllowance, 800)
        XCTAssertEqual(viewModel.consecutiveDays, 5)
        XCTAssertEqual(viewModel.totalRecordsThisMonth, 2)
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