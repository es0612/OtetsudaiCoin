import Foundation
import Combine

@Observable
class TaskManagementViewModel {
    var tasks: [HelpTask] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var successMessage: String?
    
    private let helpTaskRepository: HelpTaskRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(helpTaskRepository: HelpTaskRepository) {
        self.helpTaskRepository = helpTaskRepository
    }
    
    func loadTasks() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let allTasks = try await helpTaskRepository.findAll()
            tasks = allTasks.sorted { $0.name < $1.name }
            isLoading = false
        } catch {
            errorMessage = "タスクの読み込みに失敗しました: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func addTask(name: String, coinRate: Int = 10) async {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "タスク名を入力してください"
            return
        }
        
        guard coinRate > 0 else {
            errorMessage = "コイン単価は1以上で入力してください"
            return
        }
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 重複チェック
        if tasks.contains(where: { $0.name == trimmedName }) {
            errorMessage = "同じ名前のタスクが既に存在します"
            return
        }
        
        let newTask = HelpTask(
            id: UUID(),
            name: trimmedName,
            isActive: true,
            coinRate: coinRate
        )
        
        do {
            try await helpTaskRepository.save(newTask)
            successMessage = "タスクを追加しました"
            await loadTasks()
        } catch {
            errorMessage = "タスクの追加に失敗しました: \(error.localizedDescription)"
        }
    }
    
    func updateTask(_ task: HelpTask) async {
        do {
            try await helpTaskRepository.update(task)
            successMessage = "タスクを更新しました"
            await loadTasks()
        } catch {
            errorMessage = "タスクの更新に失敗しました: \(error.localizedDescription)"
        }
    }
    
    func deleteTask(id: UUID) async {
        do {
            try await helpTaskRepository.delete(id)
            successMessage = "タスクを削除しました"
            await loadTasks()
        } catch {
            errorMessage = "タスクの削除に失敗しました: \(error.localizedDescription)"
        }
    }
    
    func toggleTaskStatus(_ task: HelpTask) async {
        let updatedTask = HelpTask(
            id: task.id,
            name: task.name,
            isActive: !task.isActive,
            coinRate: task.coinRate
        )
        await updateTask(updatedTask)
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}