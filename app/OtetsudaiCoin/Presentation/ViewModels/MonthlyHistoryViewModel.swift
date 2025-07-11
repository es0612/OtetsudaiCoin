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

@Observable
class MonthlyHistoryViewModel {
    var monthlyRecords: [MonthlyRecord] = []
    var selectedChild: Child?
    var isLoading: Bool = false
    var errorMessage: String?
    
    private let helpRecordRepository: HelpRecordRepository
    private let allowancePaymentRepository: AllowancePaymentRepository
    private let helpTaskRepository: HelpTaskRepository
    private let allowanceCalculator: AllowanceCalculator
    private var cancellables = Set<AnyCancellable>()
    private var loadHistoryTask: Task<Void, Never>?
    
    init(
        helpRecordRepository: HelpRecordRepository,
        allowancePaymentRepository: AllowancePaymentRepository,
        helpTaskRepository: HelpTaskRepository,
        allowanceCalculator: AllowanceCalculator
    ) {
        self.helpRecordRepository = helpRecordRepository
        self.allowancePaymentRepository = allowancePaymentRepository
        self.helpTaskRepository = helpTaskRepository
        self.allowanceCalculator = allowanceCalculator
    }
    
    deinit {
        // メモリリーク防止のためタスクをキャンセル
        loadHistoryTask?.cancel()
        cancellables.removeAll()
    }
    
    func selectChild(_ child: Child) {
        selectedChild = child
        loadMonthlyHistory()
    }
    
    func loadMonthlyHistory() {
        guard let child = selectedChild else { return }
        
        // 実行中のタスクをキャンセル
        loadHistoryTask?.cancel()
        
        isLoading = true
        errorMessage = nil
        
        loadHistoryTask = Task { @MainActor in
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
                    
                    // タスクがキャンセルされていないか確認
                    guard !Task.isCancelled else { 
                        await MainActor.run {
                            isLoading = false
                        }
                        return 
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
                    let tasks = try await helpTaskRepository.findAll()
                    let allowanceAmount = allowanceCalculator.calculateMonthlyAllowance(records: records, tasks: tasks)
                    
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
                
                // 最終的なキャンセル確認とUI更新
                await MainActor.run {
                    guard !Task.isCancelled else { 
                        isLoading = false
                        return 
                    }
                    
                    monthlyRecords = monthlyData
                    isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    guard !Task.isCancelled else { 
                        isLoading = false
                        return 
                    }
                    errorMessage = "履歴の読み込みに失敗しました: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    func refreshData() {
        loadMonthlyHistory()
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    func payAllowance(for monthlyRecord: MonthlyRecord) async {
        guard let child = selectedChild else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let payment = AllowancePayment(
                id: UUID(),
                childId: child.id,
                amount: monthlyRecord.allowanceAmount,
                month: monthlyRecord.month,
                year: monthlyRecord.year,
                paidAt: Date(),
                note: "\(monthlyRecord.year)年\(monthlyRecord.month)月のお小遣い支払い"
            )
            
            try await allowancePaymentRepository.save(payment)
            
            // データを再読み込み
            loadMonthlyHistory()
            
        } catch {
            errorMessage = "支払いの記録に失敗しました: \(error.localizedDescription)"
            isLoading = false
        }
    }
}