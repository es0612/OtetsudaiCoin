import Foundation
import Combine


class RecordViewModel: BaseViewModel {
    var availableChildren: [Child] = []
    var availableTasks: [HelpTask] = []
    var selectedChild: Child?
    var selectedTask: HelpTask?
    var lastRecordedCoinValue: Int = 10
    var hasRecordedInSession: Bool = false
    
    func resetSessionState() {
        hasRecordedInSession = false
        selectedTask = nil
        clearMessages()
    }
    
    private let childRepository: ChildRepository
    private let helpTaskRepository: HelpTaskRepository
    private let helpRecordRepository: HelpRecordRepository
    private let soundService: SoundServiceProtocol
    private var loadChildrenTask: Task<Void, Never>?
    
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
            action: { [weak self] in self?.loadChildren() },
            cancellables: &cancellables
        )
        
        NotificationManager.shared.observeHelpRecordUpdates(
            action: { [weak self] in self?.loadData() },
            cancellables: &cancellables
        )
    }
    
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
            } catch {
                guard !Task.isCancelled else { return }
                setUserFriendlyError(error)
                setLoading(false)
            }
        }
    }
    
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
                setUserFriendlyError(error)
            }
        }
    }
    
    func selectChild(_ child: Child) {
        selectedChild = child
        // 成功メッセージは保持し、エラーメッセージのみクリア
        clearErrorMessage()
    }
    
    func setPreselectedChild(_ child: Child) {
        selectedChild = child
    }
    
    func selectTask(_ task: HelpTask) {
        selectedTask = task
        // 成功メッセージは保持し、エラーメッセージのみクリア
        clearErrorMessage()
    }
    
    func recordHelp() {
        clearErrorMessage()
        
        guard let child = selectedChild else {
            setError("お子様を選択してください")
            return
        }
        
        guard let task = selectedTask else {
            setError("お手伝いタスクを選択してください")
            return
        }
        
        setLoading(true)
        
        Task {
            do {
                let helpRecord = HelpRecord(
                    id: UUID(),
                    childId: child.id,
                    helpTaskId: task.id,
                    recordedAt: Date()
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
                setSuccess("お手伝いを記録しました！")
                selectedTask = nil
            } catch {
                setUserFriendlyError(error)
            }
        }
    }
}