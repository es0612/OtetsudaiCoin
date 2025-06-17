import XCTest
import Combine
@testable import OtetsudaiCoin

@MainActor
final class HelpHistoryViewModelTests: XCTestCase {
    
    private var mockHelpRecordRepository: MockHelpRecordRepository!
    private var mockHelpTaskRepository: MockHelpTaskRepository!
    private var mockChildRepository: MockChildRepository!
    private var viewModel: HelpHistoryViewModel!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockHelpRecordRepository = MockHelpRecordRepository()
        mockHelpTaskRepository = MockHelpTaskRepository()
        mockChildRepository = MockChildRepository()
        viewModel = HelpHistoryViewModel(
            helpRecordRepository: mockHelpRecordRepository,
            helpTaskRepository: mockHelpTaskRepository,
            childRepository: mockChildRepository
        )
        cancellables = []
    }
    
    override func tearDown() {
        cancellables.forEach { $0.cancel() }
        cancellables = nil
        viewModel = nil
        mockChildRepository = nil
        mockHelpTaskRepository = nil
        mockHelpRecordRepository = nil
        super.tearDown()
    }
    
    func testSelectChild() {
        // Given
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733", coinRate: 100)
        
        // When
        viewModel.selectChild(child)
        
        // Then
        XCTAssertEqual(viewModel.selectedChild?.id, child.id)
    }
    
    func testSelectPeriod() {
        // When
        viewModel.selectPeriod(.thisWeek)
        
        // Then
        XCTAssertEqual(viewModel.selectedPeriod, .thisWeek)
    }
    
    func testLoadHelpHistoryWithNoChild() {
        // Given: 子供が選択されていない状態
        
        // When
        viewModel.loadHelpHistory()
        
        // Then: ローディングが開始されない
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(viewModel.helpRecords.isEmpty)
    }
    
    func testLoadHelpHistorySuccess() async {
        // Given
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733", coinRate: 100)
        let task = HelpTask(id: UUID(), name: "食器洗い", isActive: true)
        let record = HelpRecord(id: UUID(), childId: child.id, helpTaskId: task.id, recordedAt: Date())
        
        mockChildRepository.children = [child]
        mockHelpTaskRepository.tasks = [task]
        mockHelpRecordRepository.records = [record]
        
        viewModel.selectChild(child)
        
        // When
        viewModel.loadHelpHistory()
        
        // 非同期処理の完了を待機
        let expectation = XCTestExpectation(description: "Load help history")
        viewModel.$isLoading
            .dropFirst()
            .sink { isLoading in
                if !isLoading {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.helpRecords.count, 1)
        XCTAssertEqual(viewModel.helpRecords.first?.helpRecord.id, record.id)
        XCTAssertEqual(viewModel.helpRecords.first?.child.id, child.id)
        XCTAssertEqual(viewModel.helpRecords.first?.task.id, task.id)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testLoadHelpHistoryError() async {
        // Given
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733", coinRate: 100)
        mockHelpRecordRepository.shouldThrowError = true
        
        viewModel.selectChild(child)
        
        // When
        viewModel.loadHelpHistory()
        
        // 非同期処理の完了を待機
        let expectation = XCTestExpectation(description: "Load help history error")
        viewModel.$errorMessage
            .dropFirst()
            .sink { errorMessage in
                if errorMessage != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(viewModel.helpRecords.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
    func testDeleteRecord() async {
        // Given
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733", coinRate: 100)
        let task = HelpTask(id: UUID(), name: "食器洗い", isActive: true)
        let record = HelpRecord(id: UUID(), childId: child.id, helpTaskId: task.id, recordedAt: Date())
        
        mockChildRepository.children = [child]
        mockHelpTaskRepository.tasks = [task]
        mockHelpRecordRepository.records = [record]
        
        viewModel.selectChild(child)
        viewModel.loadHelpHistory()
        
        // When
        viewModel.deleteRecord(record.id)
        
        // 非同期処理の完了を待機
        let expectation = XCTestExpectation(description: "Delete record")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 1.0)
        
        // Then
        XCTAssertTrue(mockHelpRecordRepository.records.isEmpty)
    }
    
    func testClearErrorMessage() {
        // Given
        viewModel.errorMessage = "テストエラー"
        
        // When
        viewModel.clearErrorMessage()
        
        // Then
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testHelpRecordWithDetailsEarnedCoins() {
        // Given
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733", coinRate: 150)
        let task = HelpTask(id: UUID(), name: "食器洗い", isActive: true)
        let record = HelpRecord(id: UUID(), childId: child.id, helpTaskId: task.id, recordedAt: Date())
        
        // When
        let recordWithDetails = HelpRecordWithDetails(helpRecord: record, child: child, task: task)
        
        // Then
        XCTAssertEqual(recordWithDetails.earnedCoins, 150)
    }
    
    func testHistoryPeriodDateRanges() {
        let calendar = Calendar.current
        let now = Date()
        
        // 今週のテスト
        let thisWeekRange = HistoryPeriod.thisWeek.dateRange
        XCTAssertTrue(thisWeekRange.start <= now)
        XCTAssertTrue(thisWeekRange.end >= now)
        
        // 今月のテスト
        let thisMonthRange = HistoryPeriod.thisMonth.dateRange
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        XCTAssertTrue(Calendar.current.isDate(thisMonthRange.start, inSameDayAs: startOfMonth))
        
        // 過去3か月のテスト
        let last3MonthsRange = HistoryPeriod.last3Months.dateRange
        XCTAssertTrue(last3MonthsRange.start < thisMonthRange.start)
        
        // 全期間のテスト
        let allRange = HistoryPeriod.all.dateRange
        XCTAssertTrue(allRange.start < last3MonthsRange.start)
    }
}