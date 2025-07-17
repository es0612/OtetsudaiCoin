import Foundation
import Combine

struct MonthlyRecord {
    let month: Int
    let year: Int
    let helpRecords: [HelpRecord]
    let allowanceAmount: Int
    let paymentRecord: AllowancePayment?
    let totalRecords: Int
    let isUnpaid: Bool
    let unpaidAmount: Int
    
    var monthYearString: String {
        return "\(year)年\(month)月"
    }
    
    var isPaid: Bool {
        return paymentRecord != nil
    }
    
    var isPartiallyPaid: Bool {
        return isPaid && unpaidAmount > 0
    }
    
    var paymentStatusText: String {
        if isUnpaid {
            return "未支払い"
        } else if isPartiallyPaid {
            return "一部支払い済み"
        } else {
            return "支払い済み"
        }
    }
    
    var highlightColor: String {
        if isPartiallyPaid {
            return "#FFB84D" // オレンジ系（一部支払い済み）
        } else if isUnpaid {
            return "#FF6B6B" // 赤系（未支払い）
        } else {
            return "#51CF66" // 緑系（全額支払い済み）
        }
    }
}

@MainActor
@Observable
class MonthlyHistoryViewModel {
    var monthlyRecords: [MonthlyRecord] = []
    var selectedChild: Child?
    var isLoading: Bool = false
    var errorMessage: String?
    var unpaidRecords: [MonthlyRecord] = []
    var totalUnpaidAmount: Int = 0
    
    private let helpRecordRepository: HelpRecordRepository
    private let allowancePaymentRepository: AllowancePaymentRepository
    private let helpTaskRepository: HelpTaskRepository
    private let allowanceCalculator: AllowanceCalculator
    private let unpaidDetector: UnpaidAllowanceDetectorService
    private var cancellables = Set<AnyCancellable>()
    private var loadHistoryTask: Task<Void, Never>?
    
    init(
        helpRecordRepository: HelpRecordRepository,
        allowancePaymentRepository: AllowancePaymentRepository,
        helpTaskRepository: HelpTaskRepository,
        allowanceCalculator: AllowanceCalculator,
        unpaidDetector: UnpaidAllowanceDetectorService = UnpaidAllowanceDetectorService()
    ) {
        self.helpRecordRepository = helpRecordRepository
        self.allowancePaymentRepository = allowancePaymentRepository
        self.helpTaskRepository = helpTaskRepository
        self.allowanceCalculator = allowanceCalculator
        self.unpaidDetector = unpaidDetector
    }
    
    deinit {
        // 循環参照を避けるため、deinit内では何もしない
        // タスクは自動的にキャンセルされ、cancellablesは自動的にクリーンアップされる
        print("MonthlyHistoryViewModel deinit called")
    }
    
    func selectChild(_ child: Child) {
        selectedChild = child
        // 即座にデータロードを実行
        Task {
            await MainActor.run {
                loadMonthlyHistory()
            }
        }
    }
    
    func loadMonthlyHistory() {
        guard let child = selectedChild else { 
            DebugLogger.warning("loadMonthlyHistory called but selectedChild is nil")
            return 
        }
        
        // 実行中のタスクをキャンセル
        loadHistoryTask?.cancel()
        
        isLoading = true
        errorMessage = nil
        
        DebugLogger.info("Loading monthly history for child: \(child.name)")
        
        loadHistoryTask = Task {
            do {
                // 過去12ヶ月のデータを取得
                let calendar = Calendar.current
                let now = Date()
                var monthlyData: [MonthlyRecord] = []
                
                // 全ての記録と支払いデータを取得（未支払い検出のため）
                let allRecords = try await helpRecordRepository.findByChildId(child.id)
                let allPayments = try await allowancePaymentRepository.findByChildId(child.id)
                let allTasks = try await helpTaskRepository.findAll()
                
                // 未支払い期間を検出
                let unpaidPeriods = unpaidDetector.detectUnpaidPeriods(
                    childId: child.id,
                    helpRecords: allRecords,
                    payments: allPayments,
                    tasks: allTasks
                )
                
                for monthOffset in 0..<12 {
                    guard let targetDate = calendar.date(byAdding: .month, value: -monthOffset, to: now),
                          let monthInterval = calendar.dateInterval(of: .month, for: targetDate) else {
                        continue
                    }
                    
                    // タスクがキャンセルされていないか確認
                    guard !Task.isCancelled else { 
                        isLoading = false
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
                    let allowanceAmount = allowanceCalculator.calculateMonthlyAllowance(records: records, tasks: allTasks)
                    
                    // 未支払い状況を判定
                    let unpaidPeriod = unpaidPeriods.first { $0.month == month && $0.year == year }
                    let isUnpaid = unpaidPeriod != nil
                    let unpaidAmount = unpaidPeriod?.expectedAmount ?? 0
                    
                    let monthlyRecord = MonthlyRecord(
                        month: month,
                        year: year,
                        helpRecords: records,
                        allowanceAmount: allowanceAmount,
                        paymentRecord: payment,
                        totalRecords: records.count,
                        isUnpaid: isUnpaid,
                        unpaidAmount: unpaidAmount
                    )
                    
                    // 記録がある月のみ追加
                    if !records.isEmpty || payment != nil {
                        monthlyData.append(monthlyRecord)
                    }
                }
                
                // 最終的なキャンセル確認とUI更新
                guard !Task.isCancelled else { 
                    isLoading = false
                    return 
                }
                
                monthlyRecords = monthlyData
                unpaidRecords = monthlyData.filter { $0.isUnpaid }
                totalUnpaidAmount = unpaidRecords.reduce(0) { $0 + $1.unpaidAmount }
                isLoading = false
                
            } catch {
                guard !Task.isCancelled else { 
                    isLoading = false
                    return 
                }
                errorMessage = ErrorMessageConverter.convertToUserFriendlyMessage(error)
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
            errorMessage = ErrorMessageConverter.convertToUserFriendlyMessage(error)
            isLoading = false
        }
    }
    
    func payUnpaidAmount(for monthlyRecord: MonthlyRecord) async {
        guard let child = selectedChild else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            if let existingPayment = monthlyRecord.paymentRecord {
                // 既存の支払いに追加
                let updatedPayment = AllowancePayment(
                    id: existingPayment.id,
                    childId: child.id,
                    amount: existingPayment.amount + monthlyRecord.unpaidAmount,
                    month: monthlyRecord.month,
                    year: monthlyRecord.year,
                    paidAt: existingPayment.paidAt,
                    note: (existingPayment.note ?? "") + "（未支払い分追加）"
                )
                try await allowancePaymentRepository.save(updatedPayment)
            } else {
                // 新規支払い
                let payment = AllowancePayment(
                    id: UUID(),
                    childId: child.id,
                    amount: monthlyRecord.unpaidAmount,
                    month: monthlyRecord.month,
                    year: monthlyRecord.year,
                    paidAt: Date(),
                    note: "\(monthlyRecord.year)年\(monthlyRecord.month)月の未支払い分お小遣い支払い"
                )
                try await allowancePaymentRepository.save(payment)
            }
            
            // データを再読み込み
            loadMonthlyHistory()
            
        } catch {
            errorMessage = ErrorMessageConverter.convertToUserFriendlyMessage(error)
            isLoading = false
        }
    }
    
    func payAllUnpaidAllowances() async {
        guard let child = selectedChild else { return }
        guard !unpaidRecords.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            for unpaidRecord in unpaidRecords {
                if let existingPayment = unpaidRecord.paymentRecord {
                    // 既存の支払いに追加
                    let updatedPayment = AllowancePayment(
                        id: existingPayment.id,
                        childId: child.id,
                        amount: existingPayment.amount + unpaidRecord.unpaidAmount,
                        month: unpaidRecord.month,
                        year: unpaidRecord.year,
                        paidAt: existingPayment.paidAt,
                        note: (existingPayment.note ?? "") + "（一括支払い）"
                    )
                    try await allowancePaymentRepository.save(updatedPayment)
                } else {
                    // 新規支払い
                    let payment = AllowancePayment(
                        id: UUID(),
                        childId: child.id,
                        amount: unpaidRecord.unpaidAmount,
                        month: unpaidRecord.month,
                        year: unpaidRecord.year,
                        paidAt: Date(),
                        note: "\(unpaidRecord.year)年\(unpaidRecord.month)月の一括お小遣い支払い"
                    )
                    try await allowancePaymentRepository.save(payment)
                }
            }
            
            // データを再読み込み
            loadMonthlyHistory()
            
        } catch {
            errorMessage = ErrorMessageConverter.convertToUserFriendlyMessage(error)
            isLoading = false
        }
    }
}