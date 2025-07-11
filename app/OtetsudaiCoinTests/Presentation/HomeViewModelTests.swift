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
    
    func testSelectDifferentChildAfterSameChild() {
        let child1 = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let child2 = Child(id: UUID(), name: "花子", themeColor: "#33FF57")
        
        mockHelpRecordRepository.records = []
        mockAllowanceCalculator.monthlyAllowance = 300
        
        // 最初の子供を選択
        viewModel.selectChild(child1)
        XCTAssertEqual(viewModel.selectedChild?.id, child1.id)
        
        // 同じ子供を再選択（refreshDataは呼ばれない）
        mockHelpRecordRepository.resetCallCount()
        viewModel.selectChild(child1)
        XCTAssertEqual(mockHelpRecordRepository.findCallCount, 0)
        
        // 異なる子供を選択（refreshDataが呼ばれる）
        viewModel.selectChild(child2)
        XCTAssertEqual(viewModel.selectedChild?.id, child2.id)
        XCTAssertEqual(mockHelpRecordRepository.findCallCount, 1)
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