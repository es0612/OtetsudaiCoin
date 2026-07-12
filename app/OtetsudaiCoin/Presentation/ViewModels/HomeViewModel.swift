import Foundation

@MainActor
@Observable
class HomeViewModel: BaseViewModel {
    var children: [Child] = []
    var selectedChild: Child?
    var monthlyAllowance: Int = 0
    var currentMonthEarnings: Int = 0
    var consecutiveDays: Int = 0
    var totalRecordsThisMonth: Int = 0
    var isCurrentMonthPaid: Bool = false
    // isLoading / errorMessage / successMessage は BaseViewModel から継承

    // 未支払い警告機能
    var unpaidPeriods: [UnpaidPeriod] = []
    var hasUnpaidAllowances: Bool = false
    var showUnpaidWarning: Bool = false
    var unpaidWarningMessage: String?
    var totalUnpaidAmount: Int = 0

    private let childRepository: ChildRepository
    private let helpRecordRepository: HelpRecordRepository
    private let helpTaskRepository: HelpTaskRepository
    private let allowanceCalculator: AllowanceCalculator
    private let allowancePaymentRepository: AllowancePaymentRepository
    private let unpaidDetector: UnpaidAllowanceDetectorService
    private(set) var refreshDataTask: Task<Void, Never>?

    init(
        childRepository: ChildRepository,
        helpRecordRepository: HelpRecordRepository,
        helpTaskRepository: HelpTaskRepository,
        allowanceCalculator: AllowanceCalculator,
        allowancePaymentRepository: AllowancePaymentRepository,
        unpaidDetector: UnpaidAllowanceDetectorService = UnpaidAllowanceDetectorService()
    ) {
        self.childRepository = childRepository
        self.helpRecordRepository = helpRecordRepository
        self.helpTaskRepository = helpTaskRepository
        self.allowanceCalculator = allowanceCalculator
        self.allowancePaymentRepository = allowancePaymentRepository
        self.unpaidDetector = unpaidDetector
        super.init()
    }

    // NotificationManagerを使用してデータ更新を自動監視（BaseViewModel.init から呼ばれる）
    override func setupNotificationListeners() {
        NotificationManager.shared.observeHelpRecordUpdates(
            action: { [weak self] in
                Task { @MainActor in
                    self?.refreshData()
                }
            },
            cancellables: &cancellables
        )

        NotificationManager.shared.observeChildrenUpdates(
            action: { [weak self] in
                Task { @MainActor in
                    self?.loadChildren()
                }
            },
            cancellables: &cancellables
        )
    }

    // deinitでは@MainActorプロパティにアクセスできないため削除
    // タスクはViewModelのライフサイクルとともに自動的にキャンセルされる
    
    func loadChildren() {
        Task {
            await loadChildrenAsync()
        }
    }

    // #44: View 側の `.task` から明示的に await できる async 版。
    // 内部の `Task { }` を経由しないため、SwiftUI の `.task` ライフサイクルでキャンセル制御できる。
    func loadChildrenAsync() async {
        setLoading(true)

        do {
            let loadedChildren = try await childRepository.findAll()
            children = loadedChildren

            // 未支払いのお小遣いがあるかチェック
            if !children.isEmpty {
                await checkUnpaidAllowances()
            }

            setLoading(false)
        } catch {
            setUserFriendlyError(error)
        }
    }
    
    func selectChild(_ child: Child) {
        // 既に同じ子供が選択されている場合は何もしない
        if selectedChild?.id == child.id {
            return
        }
        
        // 実行中のタスクをキャンセル
        refreshDataTask?.cancel()
        
        selectedChild = child
        refreshData()
    }
    
    func refreshData() {
        guard let child = selectedChild else { return }
        
        // 実行中のタスクをキャンセル
        refreshDataTask?.cancel()
        
        setLoading(true)

        refreshDataTask = Task {
            do {
                // 処理開始時の選択された子供を保持
                let processChild = child

                // データ取得を並行処理で高速化
                async let recordsTask = helpRecordRepository.findByChildIdInCurrentMonth(processChild.id)
                async let tasksTask = helpTaskRepository.findAll()
                async let paymentTask = getCurrentMonthPayment(for: processChild.id)

                let records = try await recordsTask
                let tasks = try await tasksTask
                let payment = try await paymentTask

                // タスクがキャンセルされていないか、選択された子供が変更されていないか確認
                guard !Task.isCancelled, selectedChild?.id == processChild.id else {
                    setLoading(false)
                    return
                }

                // プロセスが正常に完了したことを確認
                guard !records.isEmpty || !tasks.isEmpty else {
                    // データが空の場合でも正常な状態として扱う
                    updateDisplayValues(records: [], tasks: [], payment: payment)
                    setLoading(false)
                    return
                }

                // 計算処理を分離
                updateDisplayValues(records: records, tasks: tasks, payment: payment)
                setLoading(false)

            } catch {
                guard !Task.isCancelled else {
                    setLoading(false)
                    return
                }
                setUserFriendlyError(error)
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
            setError(String(localized: "子供が選択されていません"))
            return
        }

        let amountToPay = isCurrentMonthPaid ?
            (currentMonthEarnings - monthlyAllowance) : currentMonthEarnings
        
        recordAllowancePayment(amount: amountToPay)
    }
    
    func recordAllowancePayment(amount: Int) {
        guard let child = selectedChild else {
            setError(String(localized: "子供が選択されていません"))
            return
        }

        // BaseViewModel の setLoading(true) は errorMessage をクリアする（successMessage は保持）。
        // 移行前は successMessage も明示クリアしていたが、統一のため基底セマンティクスを採用する。
        setLoading(true)

        Task {
            do {
                // 処理開始時の選択された子供を保持
                let processChild = child
                
                if isCurrentMonthPaid {
                    // 追加支払いの場合は既存の支払い記録を更新
                    let calendar = Calendar.current
                    let now = Date()
                    let currentMonth = calendar.component(.month, from: now)
                    let currentYear = calendar.component(.year, from: now)
                    
                    if let existingPayment = try await allowancePaymentRepository.findByChildIdAndMonth(processChild.id, month: currentMonth, year: currentYear) {
                        let updatedPayment = AllowancePayment(
                            id: existingPayment.id,
                            childId: processChild.id,
                            amount: existingPayment.amount + amount,
                            month: existingPayment.month,
                            year: existingPayment.year,
                            paidAt: existingPayment.paidAt,
                            note: (existingPayment.note ?? "今月のお小遣い支払い") + "（追加支払い）"
                        )
                        try await allowancePaymentRepository.save(updatedPayment)
                        
                        // UI更新前に選択された子供が変更されていないか確認
                        guard selectedChild?.id == processChild.id else {
                            setLoading(false)
                            return
                        }

                        setSuccess("\(processChild.name)に追加で\(amount)コインのお小遣いを渡しました")
                    }
                } else {
                    // 新規支払いの場合
                    let payment = AllowancePayment.fromCurrentMonth(
                        childId: processChild.id,
                        amount: amount,
                        note: "今月のお小遣い支払い"
                    )
                    
                    try await allowancePaymentRepository.save(payment)
                    
                    // UI更新前に選択された子供が変更されていないか確認
                    guard selectedChild?.id == processChild.id else {
                        setLoading(false)
                        return
                    }

                    isCurrentMonthPaid = true
                    setSuccess("\(processChild.name)に\(amount)コインのお小遣いを渡しました")
                }
                setLoading(false)

                // データを再読み込み
                refreshData()
                
                // 他の画面にも通知
                NotificationManager.shared.notifyHelpRecordUpdated()

            } catch {
                guard !Task.isCancelled else {
                    setLoading(false)
                    return
                }
                setUserFriendlyError(error)
            }
        }
    }

    // MARK: - 未支払い警告機能
    
    func checkUnpaidAllowances() async {
        do {
            var allUnpaidPeriods: [UnpaidPeriod] = []

            for child in children {
                // 子供別のお手伝い記録とタスクを取得
                let helpRecords = try await helpRecordRepository.findByChildId(child.id)
                let tasks = try await helpTaskRepository.findAll()
                let payments = try await allowancePaymentRepository.findByChildId(child.id)

                // 未支払い期間を検出
                let childUnpaidPeriods = unpaidDetector.detectUnpaidPeriods(
                    childId: child.id,
                    helpRecords: helpRecords,
                    payments: payments,
                    tasks: tasks
                )

                allUnpaidPeriods.append(contentsOf: childUnpaidPeriods)
            }

            // UI更新
            unpaidPeriods = allUnpaidPeriods
            hasUnpaidAllowances = !allUnpaidPeriods.isEmpty
            showUnpaidWarning = hasUnpaidAllowances
            totalUnpaidAmount = allUnpaidPeriods.reduce(0) { $0 + $1.expectedAmount }

            if hasUnpaidAllowances {
                generateUnpaidWarningMessage()
            } else {
                unpaidWarningMessage = nil
            }

        } catch {
            setUserFriendlyError(error)
        }
    }

    func dismissUnpaidWarning() {
        showUnpaidWarning = false
    }
    
    private func generateUnpaidWarningMessage() {
        guard !unpaidPeriods.isEmpty else {
            unpaidWarningMessage = nil
            return
        }
        
        // 子供別にグループ化
        let childGroups = Dictionary(grouping: unpaidPeriods) { $0.childId }
        let affectedChildrenCount = childGroups.count
        
        if affectedChildrenCount == 1 {
            // 1人の子供の場合
            let childId = childGroups.keys.first!
            let childName = children.first { $0.id == childId }?.name ?? "不明"
            let childAmount = childGroups[childId]!.reduce(0) { $0 + $1.expectedAmount }
            
            unpaidWarningMessage = "\(childName)の未支払いのお小遣いが\(childAmount)コインあります。履歴画面から支払いを行ってください。"
        } else {
            // 複数の子供の場合
            unpaidWarningMessage = "\(affectedChildrenCount)人の子供に未支払いのお小遣いが合計\(totalUnpaidAmount)コインあります。履歴画面から支払いを行ってください。"
        }
    }
}