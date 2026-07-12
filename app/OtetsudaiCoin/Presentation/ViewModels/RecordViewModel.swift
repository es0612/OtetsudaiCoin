import Foundation

@MainActor
@Observable
class RecordViewModel: BaseViewModel {
    var availableChildren: [Child] = []
    var availableTasks: [HelpTask] = []
    var selectedChild: Child?
    var selectedTask: HelpTask?
    var lastRecordedCoinValue: Int = 10
    var recordedDate: Date = Date()
    var hasRecordedInSession: Bool = false
    var isBulkMode: Bool = false
    var selectedTaskIds: Set<UUID> = []
    var warningMessage: String? = nil
    var existingRecordCounts: [UUID: Int] = [:]
    var displayedMonth: Date = RecordViewModel.startOfMonth(Date())
    var recordedDays: Set<Int> = []

    func existingRecordCount(for taskId: UUID) -> Int {
        return existingRecordCounts[taskId] ?? 0
    }

    func resetSessionState() {
        hasRecordedInSession = false
        selectedTask = nil
        clearMessages()
    }

    func toggleBulkMode() {
        isBulkMode.toggle()
        selectedTask = nil
        selectedTaskIds = []
        clearErrorMessage()
    }
    
    private let childRepository: ChildRepository
    private let helpTaskRepository: HelpTaskRepository
    private let helpRecordRepository: HelpRecordRepository
    private let soundService: SoundServiceProtocol
    private var loadChildrenTask: Task<Void, Never>?
    private var loadCountsTask: Task<Void, Never>?
    private var loadRecordedDaysTask: Task<Void, Never>?

    init(
        childRepository: ChildRepository,
        helpTaskRepository: HelpTaskRepository,
        helpRecordRepository: HelpRecordRepository,
        soundService: SoundServiceProtocol? = nil
    ) {
        self.childRepository = childRepository
        self.helpTaskRepository = helpTaskRepository
        self.helpRecordRepository = helpRecordRepository
        self.soundService = soundService ?? SoundService()
        super.init()
    }
    
    override func setupNotificationListeners() {
        // NotificationManagerを使用して通知を監視
        NotificationManager.shared.observeChildrenUpdates(
            action: { [weak self] in
                Task { @MainActor in
                    self?.loadChildren()
                }
            },
            cancellables: &cancellables
        )
        
        NotificationManager.shared.observeHelpRecordUpdates(
            action: { [weak self] in 
                Task { @MainActor in
                    self?.loadData()
                }
            },
            cancellables: &cancellables
        )
    }
    
    @MainActor
    func loadData() {
        // 実行中のタスクをキャンセル
        cancelLoadDataTask()
        
        setLoading(true)
        
        loadDataTask = Task {
            do {
                let children = try await childRepository.findAll()
                let tasks = try await helpTaskRepository.findActive()
                
                // タスクがキャンセルされていないか確認
                guard !Task.isCancelled else { return }
                
                availableChildren = children
                availableTasks = tasks
                
                // 選択された子供が利用可能な子供リストに含まれているかチェック
                if let selectedChild = selectedChild {
                    if !children.contains(where: { $0.id == selectedChild.id }) {
                        // 選択された子供が削除されていた場合、選択をクリア
                        self.selectedChild = nil
                    }
                }
                
                // まだ子供が選択されていない場合、最初の子供を自動選択
                if selectedChild == nil && !children.isEmpty {
                    selectedChild = children.first
                }

                setLoading(false)
                loadExistingCountsForCurrentDateAndChild()
                loadRecordedDaysForDisplayedMonth()   // ← 追加
            } catch {
                guard !Task.isCancelled else { return }
                setUserFriendlyError(error)
                setLoading(false)
            }
        }
    }
    
    @MainActor
    func loadTasks() {
        loadData()
    }
    
    func loadChildren() {
        // 実行中のタスクをキャンセル
        loadChildrenTask?.cancel()
        
        // 子供データのみ更新
        loadChildrenTask = Task {
            do {
                let children = try await childRepository.findAll()
                
                // タスクがキャンセルされていないか確認
                guard !Task.isCancelled else { return }
                
                availableChildren = children
                
                // 選択された子供が削除されていた場合、選択をクリア
                if let selectedChild = selectedChild,
                   !children.contains(where: { $0.id == selectedChild.id }) {
                    self.selectedChild = nil
                }
                
                // まだ子供が選択されていない場合、最初の子供を自動選択
                if selectedChild == nil && !children.isEmpty {
                    selectedChild = children.first
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    setUserFriendlyError(error)
                }
            }
        }
    }
    
    func selectChild(_ child: Child) {
        let isChangingChild = selectedChild != nil && selectedChild?.id != child.id
        selectedChild = child
        if isChangingChild {
            selectedTaskIds = []
            selectedTask = nil
        }
        // 成功メッセージは保持し、エラーメッセージのみクリア
        clearErrorMessage()
        loadExistingCountsForCurrentDateAndChild()
        loadRecordedDaysForDisplayedMonth()   // ← 追加
    }

    func setPreselectedChild(_ child: Child) {
        selectedChild = child
    }
    
    func selectTask(_ task: HelpTask) {
        selectedTask = task
        // 成功メッセージは保持し、エラーメッセージのみクリア
        clearErrorMessage()
    }
    
    @MainActor
    func recordBulkHelp() {
        clearErrorMessage()
        warningMessage = nil

        guard let child = selectedChild else {
            setError(String(localized: "お子様を選択してください"))
            return
        }
        guard !selectedTaskIds.isEmpty else {
            return
        }

        let targetIds = selectedTaskIds
        let tasksById = Dictionary(uniqueKeysWithValues: availableTasks.map { ($0.id, $0) })

        setLoading(true)

        Task {
            var successIds: Set<UUID> = []
            var failureIds: Set<UUID> = []
            var totalCoins = 0
            let normalizedDate = Self.normalizeToNoon(recordedDate)

            for taskId in targetIds {
                guard let task = tasksById[taskId] else {
                    failureIds.insert(taskId)
                    continue
                }
                let helpRecord = HelpRecord(
                    id: UUID(),
                    childId: child.id,
                    helpTaskId: taskId,
                    recordedAt: normalizedDate
                )
                do {
                    try await helpRecordRepository.save(helpRecord)
                    successIds.insert(taskId)
                    totalCoins += task.coinRate
                } catch {
                    failureIds.insert(taskId)
                }
            }

            // 効果音 (成功 1 件以上で再生)
            if !successIds.isEmpty {
                do {
                    try soundService.playCoinEarnSound()
                    try soundService.playTaskCompleteSound()
                } catch {
                    try? soundService.playErrorSound()
                }
            }

            lastRecordedCoinValue = totalCoins
            selectedTaskIds = failureIds

            // 通知は実際に save できた件があるときだけ送る (全件失敗時に loadData → setLoading(true) で errorMessage が消えてしまうのを防ぐ)
            if !successIds.isEmpty {
                NotificationManager.shared.notifyHelpRecordUpdated()
            }

            if !successIds.isEmpty {
                hasRecordedInSession = true
                let successCount = successIds.count
                // 文字列補間で xcstrings の plural variations を利用 (String(format:) は variations を bypass)
                setSuccess(String(localized: "\(successCount) 件記録しました！"))
            }
            if !successIds.isEmpty && !failureIds.isEmpty {
                let failureCount = failureIds.count
                warningMessage = String(localized: "\(failureCount) 件失敗、もう一度タップしてください")
            }
            if successIds.isEmpty && !failureIds.isEmpty {
                setError(String(localized: "記録に失敗しました"))
            }
            setLoading(false)
        }
    }

    @MainActor
    func recordHelp() {
        clearErrorMessage()
        
        guard let child = selectedChild else {
            setError(String(localized: "お子様を選択してください"))
            return
        }

        guard let task = selectedTask else {
            setError(String(localized: "お手伝いタスクを選択してください"))
            return
        }
        
        setLoading(true)
        
        Task {
            do {
                let normalizedDate = Self.normalizeToNoon(recordedDate)
                let helpRecord = HelpRecord(
                    id: UUID(),
                    childId: child.id,
                    helpTaskId: task.id,
                    recordedAt: normalizedDate
                )
                
                try await helpRecordRepository.save(helpRecord)
                
                // 効果音を再生
                do {
                    try soundService.playCoinEarnSound()
                    try soundService.playTaskCompleteSound()
                } catch {
                    // 効果音エラーの場合はエラー音を再生
                    try? soundService.playErrorSound()
                }
                
                // アニメーション用にコイン値を保存
                lastRecordedCoinValue = task.coinRate
                
                // データ更新の通知
                NotificationManager.shared.notifyHelpRecordUpdated()
                
                hasRecordedInSession = true
                setSuccess(String(localized: "お手伝いを記録しました！"))
                selectedTask = nil
            } catch {
                setUserFriendlyError(error)
            }
        }
    }

    @MainActor
    func loadExistingCountsForCurrentDateAndChild() {
        loadCountsTask?.cancel()

        guard let child = selectedChild else {
            existingRecordCounts = [:]
            return
        }

        let targetDate = recordedDate
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: targetDate)
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)?.addingTimeInterval(-1) else {
            return
        }

        loadCountsTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let records = try await self.helpRecordRepository.findByDateRange(from: startOfDay, to: endOfDay)
                guard !Task.isCancelled else { return }
                let filtered = records.filter { $0.childId == child.id }
                let map = Dictionary(grouping: filtered, by: { $0.helpTaskId }).mapValues { $0.count }
                await MainActor.run {
                    self.existingRecordCounts = map
                }
            } catch {
                // count 取得失敗時は無視 (UX 影響低、既存 errorMessage を上書きしない)
            }
        }
    }

    @MainActor
    func loadRecordedDaysForDisplayedMonth() {
        loadRecordedDaysTask?.cancel()

        guard let child = selectedChild else {
            recordedDays = []
            return
        }

        let cal = Calendar.current
        let monthStart = RecordViewModel.startOfMonth(displayedMonth)
        guard let monthEnd = cal.date(byAdding: DateComponents(month: 1, second: -1), to: monthStart) else {
            return
        }

        loadRecordedDaysTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let records = try await self.helpRecordRepository.findByDateRange(from: monthStart, to: monthEnd)
                guard !Task.isCancelled else { return }
                let days = Set(
                    records
                        .filter { $0.childId == child.id }
                        .map { cal.component(.day, from: $0.recordedAt) }
                )
                await MainActor.run {
                    self.recordedDays = days
                }
            } catch {
                // 取得失敗は無視 (UX 影響低・既存 errorMessage を上書きしない)
            }
        }
    }

    func canGoToNextMonth(today: Date = Date()) -> Bool {
        displayedMonth < RecordViewModel.startOfMonth(today)
    }

    @MainActor
    func goToPreviousMonth() {
        let cal = Calendar.current
        guard let prev = cal.date(byAdding: .month, value: -1, to: displayedMonth) else { return }
        displayedMonth = RecordViewModel.startOfMonth(prev)
        loadRecordedDaysForDisplayedMonth()
    }

    @MainActor
    func goToNextMonth(today: Date = Date()) {
        guard canGoToNextMonth(today: today) else { return }
        let cal = Calendar.current
        guard let next = cal.date(byAdding: .month, value: 1, to: displayedMonth) else { return }
        displayedMonth = RecordViewModel.startOfMonth(next)
        loadRecordedDaysForDisplayedMonth()
    }

    @MainActor
    func selectDay(_ day: Int, today: Date = Date()) {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: displayedMonth)
        comps.day = day
        guard let date = cal.date(from: comps) else { return }
        // 未来日は無視 (View 側でも disabled だが二重防御)
        if cal.startOfDay(for: date) > cal.startOfDay(for: today) { return }
        recordedDate = RecordViewModel.normalizeToNoon(date)
        // 旧 DatePicker .onChange 相当: 選択日の per-task 件数 (#73) を更新
        loadExistingCountsForCurrentDateAndChild()
    }

    private static func normalizeToNoon(_ date: Date) -> Date {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        return cal.date(byAdding: .hour, value: 12, to: startOfDay) ?? startOfDay
    }

    static func startOfMonth(_ date: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: date)
        return cal.date(from: comps) ?? cal.startOfDay(for: date)
    }
}
