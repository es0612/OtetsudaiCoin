import Foundation
import Combine

extension Notification.Name {
    static let helpRecordUpdated = Notification.Name("helpRecordUpdated")
}

@MainActor
class RecordViewModel: BaseViewModel {
    @Published var availableChildren: [Child] = []
    @Published var availableTasks: [HelpTask] = []
    @Published var selectedChild: Child?
    @Published var selectedTask: HelpTask?
    
    private let childRepository: ChildRepository
    private let helpTaskRepository: HelpTaskRepository
    private let helpRecordRepository: HelpRecordRepository
    private let soundService: SoundServiceProtocol
    
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
        // SwiftUIの宣言的な仕組み：子供データ更新の自動監視
        NotificationCenter.default
            .publisher(for: .childrenUpdated)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.loadChildren()
                }
            }
            .store(in: &cancellables)
        
        // SwiftUIの宣言的な仕組み：お手伝い記録更新の自動監視
        NotificationCenter.default
            .publisher(for: .helpRecordUpdated)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.loadData()
                }
            }
            .store(in: &cancellables)
    }
    
    func loadData() {
        setLoading(true)
        
        Task {
            do {
                let children = try await childRepository.findAll()
                let tasks = try await helpTaskRepository.findActive()
                
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
                setError("データの読み込みに失敗しました: \(error.localizedDescription)")
            }
        }
    }
    
    func loadTasks() {
        loadData()
    }
    
    func loadChildren() {
        // 子供データのみ更新
        Task {
            do {
                let children = try await childRepository.findAll()
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
                setError("子供データの読み込みに失敗しました: \(error.localizedDescription)")
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
                
                // SwiftUIの宣言的な仕組み：データ更新の通知
                NotificationCenter.default.post(name: .helpRecordUpdated, object: nil)
                
                setSuccess("お手伝いを記録しました！")
                selectedTask = nil
            } catch {
                setError("記録の保存に失敗しました: \(error.localizedDescription)")
            }
        }
    }
}