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

                // #154 (strict concurrency targeted): リポジトリは非 Sendable のため
                // `async let` の子タスク (非隔離) へ送れない。逐次 await へ変更する。
                // 各 fetch は Core Data の background context 上で走るのでメインスレッドは
                // ブロックせず、コストは「最大値」から「合計値」への増分のみ。
                // リポジトリの Sendable 化は complete 段階でまとめて扱う。
                let records = try await helpRecordRepository.findByChildIdInCurrentMonth(processChild.id)
                let tasks = try await helpTaskRepository.findAll()
                // 連続記録は月をまたいで数えるため、今月分ではなく全記録を渡す (#311)
                let allRecords = try await helpRecordRepository.findByChildId(processChild.id)

                // タスクがキャンセルされていないか、選択された子供が変更されていないか確認
                guard !Task.isCancelled, selectedChild?.id == processChild.id else {
                    setLoading(false)
                    return
                }

                // プロセスが正常に完了したことを確認
                guard !records.isEmpty || !tasks.isEmpty else {
                    // データが空の場合でも正常な状態として扱う
                    updateDisplayValues(records: [], tasks: [], allRecords: allRecords)
                    setLoading(false)
                    return
                }

                // 計算処理を分離
                updateDisplayValues(records: records, tasks: tasks, allRecords: allRecords)
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
    
    /// 表示用の値を更新
    private func updateDisplayValues(
        records: [HelpRecord], 
        tasks: [HelpTask], 
        allRecords: [HelpRecord]
    ) {
        // お小遣い計算
        let calculatedAllowance = allowanceCalculator.calculateMonthlyAllowance(records: records, tasks: tasks)
        currentMonthEarnings = calculatedAllowance
        
        // 「今月のコイン」は今月稼いだ額。支払いの額は表示に使わない (#311)
        monthlyAllowance = calculatedAllowance
        
        // その他の統計値
        consecutiveDays = allowanceCalculator.calculateConsecutiveDays(records: allRecords)
        totalRecordsThisMonth = records.count
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

    /// 未払いバナーに出す期間の一覧 (#301)。年月は locale に合わせる（ja「2026年10月」/ en「October 2026」）。
    /// unpaidPeriods は子どもごとの期間をつなげたものなので、年月の重複を除いて新しい順に並べる (#308)。
    func unpaidPeriodsText(locale: Locale = .current) -> String {
        var seen = Set<Int>()
        return unpaidPeriods
            .sorted { ($0.year, $0.month) > ($1.year, $1.month) }
            .filter { seen.insert($0.year * 100 + $0.month).inserted }
            .map { MonthlySummaryViewModel.monthLabel(year: $0.year, month: $0.month, locale: locale) }
            .joined(separator: ", ")
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
            let childName = children.first { $0.id == childId }?.name ?? String(localized: "不明")
            let childAmount = childGroups[childId]!.reduce(0) { $0 + $1.expectedAmount }
            
            unpaidWarningMessage = String(localized: "\(childName)の未支払いのお小遣いが\(childAmount)コインあります。月のまとめから支払えます。")
        } else {
            // 複数の子供の場合
            unpaidWarningMessage = String(localized: "\(affectedChildrenCount)人の子供に未支払いのお小遣いが合計\(totalUnpaidAmount)コインあります。月のまとめから支払えます。")
        }
    }
}