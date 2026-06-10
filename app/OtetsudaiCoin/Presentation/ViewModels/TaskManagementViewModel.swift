import Foundation

@MainActor
@Observable
class TaskManagementViewModel {
    var tasks: [HelpTask] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var successMessage: String?

    private let helpTaskRepository: HelpTaskRepository
    private let helpRecordRepository: HelpRecordRepository
    private var loadTasksTask: Task<Void, Never>?

    init(helpTaskRepository: HelpTaskRepository, helpRecordRepository: HelpRecordRepository) {
        self.helpTaskRepository = helpTaskRepository
        self.helpRecordRepository = helpRecordRepository
    }

    func loadTasks() async {
        // 実行中のタスクをキャンセル
        loadTasksTask?.cancel()

        isLoading = true
        errorMessage = nil

        loadTasksTask = Task {
            do {
                let allTasks = try await helpTaskRepository.findAll()

                // タスクがキャンセルされていないか確認
                guard !Task.isCancelled else { return }

                // repository が (sortOrder, name) ソート済みを返す契約のため再ソート不要
                tasks = allTasks
                isLoading = false
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = ErrorMessageConverter.convertToUserFriendlyMessage(error)
                isLoading = false
            }
        }

        // タスクの完了を待つ
        await loadTasksTask?.value
    }

    func addTask(name: String, coinRate: Int = 10) async {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = String(localized: "タスク名を入力してください")
            return
        }

        guard coinRate > 0 else {
            errorMessage = String(localized: "コイン単価は1以上で入力してください")
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // 重複チェック
        if tasks.contains(where: { $0.name == trimmedName }) {
            errorMessage = String(localized: "同じ名前のタスクが既に存在します")
            return
        }

        // 末尾追加: 現在の最大 sortOrder + 1
        let nextSortOrder = (tasks.map(\.sortOrder).max() ?? -1) + 1
        let newTask = HelpTask(
            id: UUID(),
            name: trimmedName,
            isActive: true,
            coinRate: coinRate,
            sortOrder: nextSortOrder
        )

        do {
            try await helpTaskRepository.save(newTask)
            successMessage = String(localized: "タスクを追加しました")
            await loadTasks()
        } catch {
            errorMessage = ErrorMessageConverter.convertToUserFriendlyMessage(error)
        }
    }

    func updateTask(_ task: HelpTask) async {
        do {
            try await helpTaskRepository.update(task)
            successMessage = String(localized: "タスクを更新しました")
            await loadTasks()
        } catch {
            errorMessage = ErrorMessageConverter.convertToUserFriendlyMessage(error)
        }
    }

    func deleteTask(id: UUID) async {
        do {
            try await helpTaskRepository.delete(id)
            successMessage = String(localized: "タスクを削除しました")
            await loadTasks()
        } catch {
            errorMessage = ErrorMessageConverter.convertToUserFriendlyMessage(error)
        }
    }

    func toggleTaskStatus(_ task: HelpTask) async {
        // activate()/deactivate() は sortOrder を保持するため、手動再構築より安全
        let updatedTask = task.isActive ? task.deactivate() : task.activate()
        await updateTask(updatedTask)
    }

    func moveTasks(from source: IndexSet, to destination: Int) async {
        var reordered = tasks
        reordered.move(fromOffsets: source, toOffset: destination)
        tasks = reordered

        do {
            try await helpTaskRepository.updateSortOrders(reordered.map(\.id))
        } catch {
            errorMessage = ErrorMessageConverter.convertToUserFriendlyMessage(error)
            await loadTasks() // DB の状態に巻き戻す
        }
    }

    func sortByFrequency(now: Date = Date()) async {
        guard let windowStart = Calendar.current.date(byAdding: .day, value: -90, to: now) else {
            return
        }

        do {
            let records = try await helpRecordRepository.findByDateRange(from: windowStart, to: now)
            // 全子ども合算で件数集計
            let counts = Dictionary(grouping: records, by: { $0.helpTaskId }).mapValues { $0.count }

            let sorted = tasks.sorted { lhs, rhs in
                let lhsCount = counts[lhs.id] ?? 0
                let rhsCount = counts[rhs.id] ?? 0
                if lhsCount != rhsCount {
                    return lhsCount > rhsCount
                }
                return lhs.name < rhs.name
            }

            tasks = sorted
            try await helpTaskRepository.updateSortOrders(sorted.map(\.id))
            successMessage = String(localized: "よく使う順に並べ替えました")
        } catch {
            errorMessage = ErrorMessageConverter.convertToUserFriendlyMessage(error)
        }
    }

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}
