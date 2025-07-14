import Foundation
import Combine

@MainActor
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
        
        DebugLogger.logViewModelState(
            viewModel: "HelpRecordEditViewModel",
            state: "Initialized",
            details: "HelpRecord ID: \(helpRecord.id), Child: \(child.name)"
        )
    }
    
    deinit {
        DebugLogger.logViewModelState(
            viewModel: "HelpRecordEditViewModel",
            state: "Deinitializing",
            details: "Cancelling any running tasks"
        )
        cancelLoadDataTask()
    }
    
    func loadData() {
        DebugLogger.logViewModelState(
            viewModel: "HelpRecordEditViewModel",
            state: "loadData Started",
            details: "Setting loading to true"
        )
        setLoading(true)
        
        // 既存のタスクをキャンセル
        cancelLoadDataTask()
        
        loadDataTask = Task {
            let startTime = Date()
            DebugLogger.logTaskStart(taskName: "HelpRecordEditViewModel.loadData")
            
            do {
                DebugLogger.debug("Calling helpTaskRepository.findActive()")
                let tasks = try await helpTaskRepository.findActive()
                
                // Taskがキャンセルされているかチェック
                try Task.checkCancellation()
                
                await MainActor.run {
                    DebugLogger.logViewModelState(
                        viewModel: "HelpRecordEditViewModel",
                        state: "Tasks Loaded",
                        details: "Found \(tasks.count) active tasks"
                    )
                    
                    availableTasks = tasks
                    
                    // 現在のタスクを選択状態にする
                    selectedTask = tasks.first { $0.id == helpRecord.helpTaskId }
                    
                    // タスクが見つからない場合のログ出力
                    if selectedTask == nil && !tasks.isEmpty {
                        DebugLogger.warning("既存のタスクID \(helpRecord.helpTaskId) がアクティブなタスクリストに見つかりません")
                        // 最初のタスクをデフォルトで選択
                        selectedTask = tasks.first
                        DebugLogger.info("デフォルトタスクを選択: \(selectedTask?.name ?? "None")")
                    } else if selectedTask != nil {
                        DebugLogger.info("既存タスクを選択: \(selectedTask!.name)")
                    } else {
                        DebugLogger.warning("利用可能なタスクがありません")
                    }
                    
                    DebugLogger.logViewModelState(
                        viewModel: "HelpRecordEditViewModel",
                        state: "Loading Completed",
                        details: "Setting loading to false"
                    )
                    setLoading(false)
                    
                    DebugLogger.logTaskEnd(
                        taskName: "HelpRecordEditViewModel.loadData",
                        duration: Date().timeIntervalSince(startTime),
                        success: true
                    )
                }
            } catch {
                // Taskがキャンセルされた場合は処理しない
                if error is CancellationError {
                    DebugLogger.info("loadData task was cancelled")
                    return
                }
                
                await MainActor.run {
                    DebugLogger.logViewModelState(
                        viewModel: "HelpRecordEditViewModel",
                        state: "Loading Failed",
                        details: "Error: \(error.localizedDescription)"
                    )
                    setUserFriendlyError(error)
                    setLoading(false)
                    
                    DebugLogger.logTaskEnd(
                        taskName: "HelpRecordEditViewModel.loadData",
                        duration: Date().timeIntervalSince(startTime),
                        success: false,
                        error: error
                    )
                }
            }
        }
    }
    
    func saveChanges() {
        DebugLogger.logViewModelState(
            viewModel: "HelpRecordEditViewModel",
            state: "saveChanges Started"
        )
        
        guard let task = selectedTask else {
            DebugLogger.warning("saveChanges failed: No task selected")
            setError("お手伝いタスクを選択してください")
            return
        }
        
        DebugLogger.info("saveChanges: Selected task - \(task.name) (ID: \(task.id))")
        setLoading(true)
        
        Task {
            let startTime = Date()
            DebugLogger.logTaskStart(taskName: "HelpRecordEditViewModel.saveChanges")
            
            do {
                let updatedRecord = HelpRecord(
                    id: helpRecord.id,
                    childId: helpRecord.childId,
                    helpTaskId: task.id,
                    recordedAt: recordedDate
                )
                
                DebugLogger.debug("Updating record: \(updatedRecord.id)")
                try await helpRecordRepository.update(updatedRecord)
                
                await MainActor.run {
                    DebugLogger.info("Record updated successfully")
                    // データ更新の通知
                    NotificationManager.shared.notifyHelpRecordUpdated()
                    setSuccess("記録を更新しました")
                    
                    DebugLogger.logTaskEnd(
                        taskName: "HelpRecordEditViewModel.saveChanges",
                        duration: Date().timeIntervalSince(startTime),
                        success: true
                    )
                }
            } catch {
                await MainActor.run {
                    DebugLogger.error("saveChanges failed: \(error.localizedDescription)")
                    setUserFriendlyError(error)
                    
                    DebugLogger.logTaskEnd(
                        taskName: "HelpRecordEditViewModel.saveChanges",
                        duration: Date().timeIntervalSince(startTime),
                        success: false,
                        error: error
                    )
                }
            }
        }
    }
    
    func deleteRecord() {
        DebugLogger.logViewModelState(
            viewModel: "HelpRecordEditViewModel",
            state: "deleteRecord Started",
            details: "Record ID: \(helpRecord.id)"
        )
        setLoading(true)
        
        Task {
            let startTime = Date()
            DebugLogger.logTaskStart(taskName: "HelpRecordEditViewModel.deleteRecord")
            
            do {
                DebugLogger.debug("Deleting record: \(helpRecord.id)")
                try await helpRecordRepository.delete(helpRecord.id)
                
                await MainActor.run {
                    DebugLogger.info("Record deleted successfully")
                    // データ更新の通知
                    NotificationManager.shared.notifyHelpRecordUpdated()
                    setSuccess("記録を削除しました")
                    
                    DebugLogger.logTaskEnd(
                        taskName: "HelpRecordEditViewModel.deleteRecord",
                        duration: Date().timeIntervalSince(startTime),
                        success: true
                    )
                }
            } catch {
                await MainActor.run {
                    DebugLogger.error("deleteRecord failed: \(error.localizedDescription)")
                    setUserFriendlyError(error)
                    
                    DebugLogger.logTaskEnd(
                        taskName: "HelpRecordEditViewModel.deleteRecord",
                        duration: Date().timeIntervalSince(startTime),
                        success: false,
                        error: error
                    )
                }
            }
        }
    }
    
    var hasChanges: Bool {
        guard let task = selectedTask else { 
            DebugLogger.debug("hasChanges: false (no task selected)")
            return false 
        }
        
        let taskChanged = task.id != helpRecord.helpTaskId
        let timeInterval = abs(recordedDate.timeIntervalSince(helpRecord.recordedAt))
        let dateChanged = timeInterval > 60 // 1分以上の差があれば変更とみなす
        let result = taskChanged || dateChanged
        
        DebugLogger.debug("hasChanges: \(result) (task: \(taskChanged), date: \(dateChanged), interval: \(timeInterval)s)")
        return result
    }
}