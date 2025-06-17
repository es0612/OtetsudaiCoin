import Foundation
import Combine

extension Notification.Name {
    static let helpRecordUpdated = Notification.Name("helpRecordUpdated")
}

@MainActor
class RecordViewModel: ObservableObject {
    @Published var availableChildren: [Child] = []
    @Published var availableTasks: [HelpTask] = []
    @Published var selectedChild: Child?
    @Published var selectedTask: HelpTask?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
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
    }
    
    func loadData() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let children = try await childRepository.findAll()
                let tasks = try await helpTaskRepository.findActive()
                
                availableChildren = children
                availableTasks = tasks
                
                // 最初の子供を自動選択
                if selectedChild == nil && !children.isEmpty {
                    selectedChild = children.first
                }
                
                isLoading = false
            } catch {
                errorMessage = "データの読み込みに失敗しました: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func loadTasks() {
        loadData()
    }
    
    func selectChild(_ child: Child) {
        selectedChild = child
        clearMessages()
    }
    
    func selectTask(_ task: HelpTask) {
        selectedTask = task
        clearMessages()
    }
    
    func recordHelp() {
        clearMessages()
        
        guard let child = selectedChild else {
            errorMessage = "お子様を選択してください"
            return
        }
        
        guard let task = selectedTask else {
            errorMessage = "お手伝いタスクを選択してください"
            return
        }
        
        isLoading = true
        
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
                
                successMessage = "お手伝いを記録しました！"
                selectedTask = nil
                isLoading = false
            } catch {
                errorMessage = "記録の保存に失敗しました: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}