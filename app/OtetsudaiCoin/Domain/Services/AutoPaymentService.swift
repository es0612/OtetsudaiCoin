import Foundation

struct MonthlyResult {
    let child: Child
    let totalRecords: Int
    let monthlyAllowance: Int
    let consecutiveDays: Int
    let month: Int
    let year: Int
}

class AutoPaymentService: ObservableObject {
    @Published var pendingResults: [MonthlyResult] = []
    @Published var showingResultsPopup = false
    
    private let paymentSettingsManager: PaymentSettingsManager
    private let allowancePaymentRepository: AllowancePaymentRepository
    private let helpRecordRepository: HelpRecordRepository
    private let childRepository: ChildRepository
    private let allowanceCalculator: AllowanceCalculator
    
    init(
        paymentSettingsManager: PaymentSettingsManager,
        allowancePaymentRepository: AllowancePaymentRepository,
        helpRecordRepository: HelpRecordRepository,
        childRepository: ChildRepository,
        allowanceCalculator: AllowanceCalculator
    ) {
        self.paymentSettingsManager = paymentSettingsManager
        self.allowancePaymentRepository = allowancePaymentRepository
        self.helpRecordRepository = helpRecordRepository
        self.childRepository = childRepository
        self.allowanceCalculator = allowanceCalculator
    }
    
    func checkAndPerformAutoPayment() async {
        guard paymentSettingsManager.settings.isAutoPaymentEnabled else { return }
        
        let calendar = Calendar.current
        let now = Date()
        let currentDay = calendar.component(.day, from: now)
        let paymentDay = paymentSettingsManager.settings.paymentDay
        
        // 支払日でない場合は何もしない
        guard currentDay == paymentDay else { return }
        
        do {
            let children = try await childRepository.findAll()
            var results: [MonthlyResult] = []
            
            for child in children {
                // 今月既に支払い済みかチェック
                let currentMonth = calendar.component(.month, from: now)
                let currentYear = calendar.component(.year, from: now)
                
                let existingPayment = try await allowancePaymentRepository.findByChildIdAndMonth(
                    child.id, month: currentMonth, year: currentYear
                )
                
                if existingPayment != nil {
                    continue // 既に支払い済み
                }
                
                // 今月のお手伝い記録を取得
                let records = try await helpRecordRepository.findByChildIdInCurrentMonth(child.id)
                
                // 統計を計算
                let monthlyAllowance = allowanceCalculator.calculateMonthlyAllowance(records: records, child: child)
                let consecutiveDays = allowanceCalculator.calculateConsecutiveDays(records: records)
                
                // 記録がある場合のみ支払い
                if !records.isEmpty {
                    let payment = AllowancePayment(
                        id: UUID(),
                        childId: child.id,
                        amount: monthlyAllowance,
                        month: currentMonth,
                        year: currentYear,
                        paidAt: now,
                        note: "自動支払い"
                    )
                    
                    try await allowancePaymentRepository.save(payment)
                    
                    let result = MonthlyResult(
                        child: child,
                        totalRecords: records.count,
                        monthlyAllowance: monthlyAllowance,
                        consecutiveDays: consecutiveDays,
                        month: currentMonth,
                        year: currentYear
                    )
                    results.append(result)
                }
            }
            
            if !results.isEmpty {
                await MainActor.run {
                    self.pendingResults = results
                    self.showingResultsPopup = true
                }
            }
            
        } catch {
            print("自動支払い処理エラー: \(error)")
        }
    }
    
    func dismissResults() {
        pendingResults.removeAll()
        showingResultsPopup = false
        
        // データ更新の通知
        NotificationCenter.default.post(name: .helpRecordUpdated, object: nil)
    }
}