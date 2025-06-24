import Foundation
import Combine

@MainActor
class HelpRecordEditViewModel: BaseViewModel {
    @Published var selectedTask: HelpTask?
    @Published var recordedDate: Date = Date()
    @Published var availableTasks: [HelpTask] = []
    
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
    }
    
    func loadData() {
        setLoading(true)
        
        Task {
            do {
                let tasks = try await helpTaskRepository.findActive()
                availableTasks = tasks
                
                // 現在のタスクを選択状態にする
                selectedTask = tasks.first { $0.id == helpRecord.helpTaskId }
                
                setLoading(false)
            } catch {
                setError("データの読み込みに失敗しました: \(error.localizedDescription)")
            }
        }
    }
    
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
                
                // SwiftUIの宣言的な仕組み：データ更新の通知
                NotificationCenter.default.post(name: .helpRecordUpdated, object: nil)
                
                setSuccess("記録を更新しました")
            } catch {
                setError("記録の更新に失敗しました: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteRecord() {
        setLoading(true)
        
        Task {
            do {
                try await helpRecordRepository.delete(helpRecord.id)
                
                // SwiftUIの宣言的な仕組み：データ更新の通知
                NotificationCenter.default.post(name: .helpRecordUpdated, object: nil)
                
                setSuccess("記録を削除しました")
            } catch {
                setError("記録の削除に失敗しました: \(error.localizedDescription)")
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