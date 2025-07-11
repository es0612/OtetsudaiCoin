import Foundation
import Combine

@Observable
class HomeViewModel {
    var children: [Child] = []
    var selectedChild: Child?
    var monthlyAllowance: Int = 0
    var currentMonthEarnings: Int = 0
    var consecutiveDays: Int = 0
    var totalRecordsThisMonth: Int = 0
    var isCurrentMonthPaid: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?
    var successMessage: String?
    
    private let childRepository: ChildRepository
    private let helpRecordRepository: HelpRecordRepository
    private let helpTaskRepository: HelpTaskRepository
    private let allowanceCalculator: AllowanceCalculator
    private let allowancePaymentRepository: AllowancePaymentRepository
    private var cancellables: Set<AnyCancellable> = []
    private var refreshDataTask: Task<Void, Never>?
    
    init(
        childRepository: ChildRepository,
        helpRecordRepository: HelpRecordRepository,
        helpTaskRepository: HelpTaskRepository,
        allowanceCalculator: AllowanceCalculator,
        allowancePaymentRepository: AllowancePaymentRepository
    ) {
        self.childRepository = childRepository
        self.helpRecordRepository = helpRecordRepository
        self.helpTaskRepository = helpTaskRepository
        self.allowanceCalculator = allowanceCalculator
        self.allowancePaymentRepository = allowancePaymentRepository
        
        // NotificationManagerを使用してデータ更新を自動監視
        NotificationManager.shared.observeHelpRecordUpdates(
            action: { [weak self] in self?.refreshData() },
            cancellables: &cancellables
        )
        
        NotificationManager.shared.observeChildrenUpdates(
            action: { [weak self] in self?.loadChildren() },
            cancellables: &cancellables
        )
    }
    
    deinit {
        // メモリリーク防止のためタスクをキャンセル
        refreshDataTask?.cancel()
        cancellables.removeAll()
    }
    
    func loadChildren() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let loadedChildren = try await childRepository.findAll()
                children = loadedChildren
                isLoading = false
            } catch {
                errorMessage = ErrorMessageConverter.convertToUserFriendlyMessage(error)
                isLoading = false
            }
        }
    }
    
    func selectChild(_ child: Child) {
        // 既に同じ子供が選択されている場合は何もしない
        if selectedChild?.id == child.id {
            return
        }
        
        selectedChild = child
        refreshData()
    }
    
    func refreshData() {
        guard let child = selectedChild else { return }
        
        // 実行中のタスクをキャンセル
        refreshDataTask?.cancel()
        
        isLoading = true
        errorMessage = nil
        
        refreshDataTask = Task { @MainActor in
            do {
                // データ取得を並行処理で高速化
                async let recordsTask = helpRecordRepository.findByChildIdInCurrentMonth(child.id)
                async let tasksTask = helpTaskRepository.findAll()
                async let paymentTask = getCurrentMonthPayment(for: child.id)
                
                let records = try await recordsTask
                let tasks = try await tasksTask
                let payment = try await paymentTask
                
                // タスクがキャンセルされていないか確認
                guard !Task.isCancelled else { 
                    await MainActor.run {
                        isLoading = false
                    }
                    return 
                }
                
                // 計算処理を分離
                await MainActor.run {
                    updateDisplayValues(records: records, tasks: tasks, payment: payment)
                    isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    guard !Task.isCancelled else { 
                        isLoading = false
                        return 
                    }
                    errorMessage = ErrorMessageConverter.convertToUserFriendlyMessage(error)
                    isLoading = false
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// 現在月の支払い記録を取得
    private func getCurrentMonthPayment(for childId: UUID) async throws -> AllowancePayment? {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        return try await allowancePaymentRepository.findByChildIdAndMonth(
            childId, 
            month: currentMonth, 
            year: currentYear
        )
    }
    
    /// 表示用の値を更新
    private func updateDisplayValues(
        records: [HelpRecord], 
        tasks: [HelpTask], 
        payment: AllowancePayment?
    ) {
        // お小遣い計算
        let calculatedAllowance = allowanceCalculator.calculateMonthlyAllowance(records: records, tasks: tasks)
        currentMonthEarnings = calculatedAllowance
        
        // 支払い状況による表示切り替え
        isCurrentMonthPaid = payment != nil
        monthlyAllowance = payment?.amount ?? calculatedAllowance
        
        // その他の統計値
        consecutiveDays = allowanceCalculator.calculateConsecutiveDays(records: records)
        totalRecordsThisMonth = records.count
    }
    
    func payMonthlyAllowance() {
        guard selectedChild != nil else {
            errorMessage = "子供が選択されていません"
            return
        }
        
        let amountToPay = isCurrentMonthPaid ? 
            (currentMonthEarnings - monthlyAllowance) : currentMonthEarnings
        
        recordAllowancePayment(amount: amountToPay)
    }
    
    func recordAllowancePayment(amount: Int) {
        guard selectedChild != nil else {
            errorMessage = "子供が選択されていません"
            return
        }
        
        let child = selectedChild!
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                if isCurrentMonthPaid {
                    // 追加支払いの場合は既存の支払い記録を更新
                    let calendar = Calendar.current
                    let now = Date()
                    let currentMonth = calendar.component(.month, from: now)
                    let currentYear = calendar.component(.year, from: now)
                    
                    if let existingPayment = try await allowancePaymentRepository.findByChildIdAndMonth(child.id, month: currentMonth, year: currentYear) {
                        let updatedPayment = AllowancePayment(
                            id: existingPayment.id,
                            childId: child.id,
                            amount: existingPayment.amount + amount,
                            month: existingPayment.month,
                            year: existingPayment.year,
                            paidAt: existingPayment.paidAt,
                            note: (existingPayment.note ?? "今月のお小遣い支払い") + "（追加支払い）"
                        )
                        try await allowancePaymentRepository.save(updatedPayment)
                        successMessage = "\(child.name)に追加で\(amount)コインのお小遣いを渡しました"
                    }
                } else {
                    // 新規支払いの場合
                    let payment = AllowancePayment.fromCurrentMonth(
                        childId: child.id,
                        amount: amount,
                        note: "今月のお小遣い支払い"
                    )
                    
                    try await allowancePaymentRepository.save(payment)
                    isCurrentMonthPaid = true
                    successMessage = "\(child.name)に\(amount)コインのお小遣いを渡しました"
                }
                isLoading = false
                
                // データを再読み込み
                refreshData()
                
                // 他の画面にも通知
                NotificationManager.shared.notifyHelpRecordUpdated()
                
            } catch {
                errorMessage = ErrorMessageConverter.convertToUserFriendlyMessage(error)
                isLoading = false
            }
        }
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}