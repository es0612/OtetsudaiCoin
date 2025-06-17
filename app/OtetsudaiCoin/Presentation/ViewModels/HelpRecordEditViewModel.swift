import Foundation
import Combine

@MainActor
class HelpRecordEditViewModel: ObservableObject {
    @Published var selectedTask: HelpTask?
    @Published var recordedDate: Date = Date()
    @Published var availableTasks: [HelpTask] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
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
    }
    
    func loadData() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let tasks = try await helpTaskRepository.findActive()
                availableTasks = tasks
                
                // 現在のタスクを選択状態にする
                selectedTask = tasks.first { $0.id == helpRecord.helpTaskId }
                
                isLoading = false
            } catch {
                errorMessage = "データの読み込みに失敗しました: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func saveChanges() {
        guard let task = selectedTask else {
            errorMessage = "お手伝いタスクを選択してください"
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
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
                
                successMessage = "記録を更新しました"
                isLoading = false
            } catch {
                errorMessage = "記録の更新に失敗しました: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func deleteRecord() {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                try await helpRecordRepository.delete(helpRecord.id)
                
                // SwiftUIの宣言的な仕組み：データ更新の通知
                NotificationCenter.default.post(name: .helpRecordUpdated, object: nil)
                
                successMessage = "記録を削除しました"
                isLoading = false
            } catch {
                errorMessage = "記録の削除に失敗しました: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    var hasChanges: Bool {
        guard let task = selectedTask else { return false }
        let calendar = Calendar.current
        let timeInterval = abs(recordedDate.timeIntervalSince(helpRecord.recordedAt))
        return task.id != helpRecord.helpTaskId || timeInterval > 60 // 1分以上の差があれば変更とみなす
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}