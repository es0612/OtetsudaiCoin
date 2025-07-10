import Foundation
import Combine

@Observable
class HelpRecordEditViewModel: BaseViewModel {
    var selectedTask: HelpTask?
    var recordedDate: Date = Date()
    var availableTasks: [HelpTask] = []
    
    private let helpRecord: HelpRecord
    private let child: Child
    private let helpRecordRepository: HelpRecordRepository
    private let helpTaskRepository: HelpTaskRepository
    
    init(
        helpRecord: HelpRecord,
        child: Child,
        helpRecordRepository: HelpRecordRepository,
        helpTaskRepository: HelpTaskRepository
    ) {
        self.helpRecord = helpRecord
        self.child = child
        self.helpRecordRepository = helpRecordRepository
        self.helpTaskRepository = helpTaskRepository
        self.recordedDate = helpRecord.recordedAt
        super.init()
        
        // 初期化時にデータを読み込む
        Task { @MainActor in
            loadData()
        }
    }
    
    @MainActor
    func loadData() {
        setLoading(true)
        
        Task {
            do {
                let tasks = try await helpTaskRepository.findActive()
                
                await MainActor.run {
                    availableTasks = tasks
                    // 現在のタスクを選択状態にする
                    selectedTask = tasks.first { $0.id == helpRecord.helpTaskId }
                    setLoading(false)
                }
            } catch {
                await MainActor.run {
                    setUserFriendlyError(error)
                }
            }
        }
    }
    
    @MainActor
    func saveChanges() {
        guard let task = selectedTask else {
            setError("お手伝いタスクを選択してください")
            return
        }
        
        setLoading(true)
        
        Task {
            do {
                let updatedRecord = HelpRecord(
                    id: helpRecord.id,
                    childId: helpRecord.childId,
                    helpTaskId: task.id,
                    recordedAt: recordedDate
                )
                
                try await helpRecordRepository.update(updatedRecord)
                
                await MainActor.run {
                    // データ更新の通知
                    NotificationManager.shared.notifyHelpRecordUpdated()
                    setSuccess("記録を更新しました")
                }
            } catch {
                await MainActor.run {
                    setUserFriendlyError(error)
                }
            }
        }
    }
    
    @MainActor
    func deleteRecord() {
        setLoading(true)
        
        Task {
            do {
                try await helpRecordRepository.delete(helpRecord.id)
                
                await MainActor.run {
                    // データ更新の通知
                    NotificationManager.shared.notifyHelpRecordUpdated()
                    setSuccess("記録を削除しました")
                }
            } catch {
                await MainActor.run {
                    setUserFriendlyError(error)
                }
            }
        }
    }
    
    var hasChanges: Bool {
        guard let task = selectedTask else { return false }
        _ = Calendar.current
        let timeInterval = abs(recordedDate.timeIntervalSince(helpRecord.recordedAt))
        return task.id != helpRecord.helpTaskId || timeInterval > 60 // 1分以上の差があれば変更とみなす
    }
}