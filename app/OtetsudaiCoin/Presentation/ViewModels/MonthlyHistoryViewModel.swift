import Foundation
import Combine

struct MonthlyRecord {
    let month: Int
    let year: Int
    let helpRecords: [HelpRecord]
    let allowanceAmount: Int
    let paymentRecord: AllowancePayment?
    let totalRecords: Int
    
    var monthYearString: String {
        return "\(year)年\(month)月"
    }
    
    var isPaid: Bool {
        return paymentRecord != nil
    }
}

@MainActor
class MonthlyHistoryViewModel: ObservableObject {
    @Published var monthlyRecords: [MonthlyRecord] = []
    @Published var selectedChild: Child?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let helpRecordRepository: HelpRecordRepository
    private let allowancePaymentRepository: AllowancePaymentRepository
    private let allowanceCalculator: AllowanceCalculator
    private var cancellables = Set<AnyCancellable>()
    
    init(
        helpRecordRepository: HelpRecordRepository,
        allowancePaymentRepository: AllowancePaymentRepository,
        allowanceCalculator: AllowanceCalculator
    ) {
        self.helpRecordRepository = helpRecordRepository
        self.allowancePaymentRepository = allowancePaymentRepository
        self.allowanceCalculator = allowanceCalculator
    }
    
    func selectChild(_ child: Child) {
        selectedChild = child
        loadMonthlyHistory()
    }
    
    func loadMonthlyHistory() {
        guard let child = selectedChild else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // 過去12ヶ月のデータを取得
                let calendar = Calendar.current
                let now = Date()
                var monthlyData: [MonthlyRecord] = []
                
                for monthOffset in 0..<12 {
                    guard let targetDate = calendar.date(byAdding: .month, value: -monthOffset, to: now),
                          let monthInterval = calendar.dateInterval(of: .month, for: targetDate) else {
                        continue
                    }
                    
                    let month = calendar.component(.month, from: targetDate)
                    let year = calendar.component(.year, from: targetDate)
                    
                    // その月のお手伝い記録を取得
                    let records = try await helpRecordRepository.findByDateRange(
                        from: monthInterval.start,
                        to: monthInterval.end
                    ).filter { $0.childId == child.id }
                    
                    // その月の支払い記録を取得
                    let payment = try await allowancePaymentRepository.findByChildIdAndMonth(
                        child.id,
                        month: month,
                        year: year
                    )
                    
                    // お小遣い金額を計算
                    let allowanceAmount = allowanceCalculator.calculateMonthlyAllowance(records: records, child: child)
                    
                    let monthlyRecord = MonthlyRecord(
                        month: month,
                        year: year,
                        helpRecords: records,
                        allowanceAmount: allowanceAmount,
                        paymentRecord: payment,
                        totalRecords: records.count
                    )
                    
                    // 記録がある月のみ追加
                    if !records.isEmpty || payment != nil {
                        monthlyData.append(monthlyRecord)
                    }
                }
                
                monthlyRecords = monthlyData
                isLoading = false
                
            } catch {
                errorMessage = "履歴の読み込みに失敗しました: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func refreshData() {
        loadMonthlyHistory()
    }
    
    func clearError() {
        errorMessage = nil
    }
}