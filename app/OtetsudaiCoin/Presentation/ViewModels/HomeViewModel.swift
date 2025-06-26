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
        
        // SwiftUIの宣言的な仕組み：NotificationCenterでデータ更新を自動監視
        NotificationCenter.default
            .publisher(for: .helpRecordUpdated)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refreshData()
                }
            }
            .store(in: &cancellables)
        
        // 子供データ更新の監視
        NotificationCenter.default
            .publisher(for: .childrenUpdated)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.loadChildren()
                }
            }
            .store(in: &cancellables)
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
                errorMessage = "子供の情報を読み込めませんでした: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func selectChild(_ child: Child) {
        selectedChild = child
        refreshData()
    }
    
    func refreshData() {
        guard let child = selectedChild else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let records = try await helpRecordRepository.findByChildIdInCurrentMonth(child.id)
                let tasks = try await helpTaskRepository.findAll()
                
                monthlyAllowance = allowanceCalculator.calculateMonthlyAllowance(records: records, tasks: tasks)
                currentMonthEarnings = allowanceCalculator.calculateMonthlyAllowance(records: records, tasks: tasks)
                consecutiveDays = allowanceCalculator.calculateConsecutiveDays(records: records)
                totalRecordsThisMonth = records.count
                
                // 今月が支払い済みかチェック
                let calendar = Calendar.current
                let now = Date()
                let currentMonth = calendar.component(.month, from: now)
                let currentYear = calendar.component(.year, from: now)
                
                let payment = try await allowancePaymentRepository.findByChildIdAndMonth(child.id, month: currentMonth, year: currentYear)
                isCurrentMonthPaid = payment != nil
                
                // 支払い済みの場合は支払い済み金額を表示
                if let payment = payment {
                    monthlyAllowance = payment.amount
                }
                
                isLoading = false
            } catch {
                errorMessage = "データの読み込みに失敗しました: \(error.localizedDescription)"
                isLoading = false
            }
        }
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
                NotificationCenter.default.post(name: .helpRecordUpdated, object: nil)
                
            } catch {
                errorMessage = "支払い記録の保存に失敗しました: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}