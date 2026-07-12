import Foundation

@MainActor
@Observable
class TaskManagementViewModel: BaseViewModel {
    var tasks: [HelpTask] = []
    // isLoading / errorMessage / successMessage は BaseViewModel から継承

    /// 「よく使う順に並べ替え」が意味を持つか。0/1 件では並べ替え不要 (#130-③)。
    var canSortByFrequency: Bool {
        tasks.count > 1
    }

    private let helpTaskRepository: HelpTaskRepository
    private let helpRecordRepository: HelpRecordRepository
    private var loadTasksTask: Task<Void, Never>?
    private var sortPersistChain: Task<Void, Never>?

    init(helpTaskRepository: HelpTaskRepository, helpRecordRepository: HelpRecordRepository) {
        self.helpTaskRepository = helpTaskRepository
        self.helpRecordRepository = helpRecordRepository
        super.init()
    }

    func loadTasks() async {
        // 実行中のタスクをキャンセル
        loadTasksTask?.cancel()

        setLoading(true)

        loadTasksTask = Task {
            do {
                let allTasks = try await helpTaskRepository.findAll()

                // タスクがキャンセルされていないか確認
                guard !Task.isCancelled else { return }

                // repository が (sortOrder, name) ソート済みを返す契約のため再ソート不要
                tasks = allTasks
                setLoading(false)
            } catch {
                guard !Task.isCancelled else { return }
                setUserFriendlyError(error)
            }
        }

        // タスクの完了を待つ
        await loadTasksTask?.value
    }

    func addTask(name: String, coinRate: Int = 10) async {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setError(String(localized: "タスク名を入力してください"))
            return
        }

        guard coinRate > 0 else {
            setError(String(localized: "コイン単価は1以上で入力してください"))
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // 重複チェック
        if tasks.contains(where: { $0.name == trimmedName }) {
            setError(String(localized: "同じ名前のタスクが既に存在します"))
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
            setSuccess(String(localized: "タスクを追加しました"))
            await loadTasks()
        } catch {
            setUserFriendlyError(error)
        }
    }

    func updateTask(_ task: HelpTask) async {
        do {
            try await helpTaskRepository.update(task)
            setSuccess(String(localized: "タスクを更新しました"))
            await loadTasks()
        } catch {
            setUserFriendlyError(error)
        }
    }

    func deleteTask(id: UUID) async {
        do {
            try await helpTaskRepository.delete(id)
            setSuccess(String(localized: "タスクを削除しました"))
            await loadTasks()
        } catch {
            setUserFriendlyError(error)
        }
    }

    func toggleTaskStatus(_ task: HelpTask) async {
        // activate()/deactivate() は sortOrder を保持するため、手動再構築より安全
        let updatedTask = task.isActive ? task.deactivate() : task.activate()
        await updateTask(updatedTask)
    }

    /// in-memory の並べ替えを同期適用し、並べ替え後配列を返す。
    /// onMove から同期呼び出しすることで、SwiftUI List が同一 runloop で並べ替え後配列を
    /// 反映し、行が一瞬元位置へ戻る snap-back glitch を防ぐ (#130-②)。
    @discardableResult
    func reorderTasks(from source: IndexSet, to destination: Int) -> [HelpTask] {
        // in-flight な loadTasks の stale 結果が楽観的更新を上書きしないようキャンセル
        loadTasksTask?.cancel()
        var reordered = tasks
        reordered.move(fromOffsets: source, toOffset: destination)
        tasks = reordered
        return reordered
    }

    /// 並べ替え永続化を直列化する。前の永続化が完了してから次を開始することで、
    /// moveTasks 同士 / moveTasks vs sortByFrequency が別 background context で走った際の
    /// 完了順逆転による DB/in-memory 不整合を防ぐ (#130-①)。
    private func enqueueSortPersist(_ body: @escaping () async -> Void) async {
        // 注: body 内から persistReorder/sortByFrequency を呼ばないこと（chain 自己待ちで deadlock）
        let previous = sortPersistChain
        let task = Task { @MainActor in
            await previous?.value
            await body()
        }
        sortPersistChain = task
        await task.value
    }

    /// 並べ替え結果を永続化する。失敗時は DB 状態へ巻き戻す。
    func persistReorder(_ reordered: [HelpTask]) async {
        await enqueueSortPersist { [self] in
            do {
                try await helpTaskRepository.updateSortOrders(reordered.map(\.id))
                // DB の再採番 (0..n-1) を in-memory にもミラーし、後続の toggle/編集が
                // stale な sortOrder を書き戻すのを防ぐ
                tasks = reordered.enumerated().map { $1.updatingSortOrder($0) }
                clearErrorMessage() // 先行する失敗永続化が残した errorMessage をクリア (#136)
            } catch {
                let message = ErrorMessageConverter.convertToUserFriendlyMessage(error)
                await loadTasks() // DB の状態に巻き戻す
                setError(message) // loadTasks 冒頭の setLoading(true) による errorMessage クリアに消されないよう reload 後にセット
            }
        }
    }

    /// 同期 reorder + 永続化をまとめた従来 API（テスト/プログラム経路用）。
    func moveTasks(from source: IndexSet, to destination: Int) async {
        let reordered = reorderTasks(from: source, to: destination)
        await persistReorder(reordered)
    }

    func sortByFrequency(now: Date = Date()) async {
        guard canSortByFrequency else { return }
        guard let windowStart = Calendar.current.date(byAdding: .day, value: -90, to: now) else {
            return
        }

        // in-flight な loadTasks の stale 結果が並べ替え結果を上書きしないようキャンセル
        loadTasksTask?.cancel()

        let records: [HelpRecord]
        do {
            records = try await helpRecordRepository.findByDateRange(from: windowStart, to: now)
        } catch {
            setUserFriendlyError(error)
            return
        }

        // 全子ども合算で件数集計（records 由来で reorder 非依存なので body 外で確定してよい）
        let counts = Dictionary(grouping: records, by: { $0.helpTaskId }).mapValues { $0.count }

        await enqueueSortPersist { [self] in
            // 並べ替え結果は永続化 body の実行時点の tasks から計算する。呼び出し時に capture すると、
            // 先行する永続化の完了待ち中に tasks の集合が変わった場合に stale な並びを書きうる (#136)。
            let sorted = tasks.sorted { lhs, rhs in
                let lhsCount = counts[lhs.id] ?? 0
                let rhsCount = counts[rhs.id] ?? 0
                if lhsCount != rhsCount {
                    return lhsCount > rhsCount
                }
                return lhs.name < rhs.name
            }
            do {
                try await helpTaskRepository.updateSortOrders(sorted.map(\.id))
                // DB の再採番 (0..n-1) を in-memory にもミラー（moveTasks と同様）
                tasks = sorted.enumerated().map { $1.updatingSortOrder($0) }
                // setSuccess は errorMessage もクリアするため、先行する失敗永続化が残した
                // errorMessage の掃除も兼ねる (#136)
                setSuccess(String(localized: "よく使う順に並べ替えました"))
            } catch {
                let message = ErrorMessageConverter.convertToUserFriendlyMessage(error)
                await loadTasks() // DB の状態に巻き戻す
                setError(message) // loadTasks 冒頭の setLoading(true) による errorMessage クリアに消されないよう reload 後にセット
            }
        }
    }
}
