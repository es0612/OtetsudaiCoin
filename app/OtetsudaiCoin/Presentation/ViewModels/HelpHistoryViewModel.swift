import Foundation
import Combine

@MainActor
@Observable
class HelpHistoryViewModel {
    var helpRecords: [HelpRecordWithDetails] = []
    var selectedChild: Child?
    var selectedPeriod: HistoryPeriod = .thisMonth
    var isLoading: Bool = false
    var errorMessage: String?
    
    private let helpRecordRepository: HelpRecordRepository
    private let helpTaskRepository: HelpTaskRepository
    private let childRepository: ChildRepository
    private var cancellables: Set<AnyCancellable> = []
    private var loadHistoryTask: Task<Void, Never>?
    
    init(
        helpRecordRepository: HelpRecordRepository,
        helpTaskRepository: HelpTaskRepository,
        childRepository: ChildRepository
    ) {
        self.helpRecordRepository = helpRecordRepository
        self.helpTaskRepository = helpTaskRepository
        self.childRepository = childRepository
        
        // SwiftUIの宣言的な仕組み：データ更新の自動監視
        NotificationCenter.default
            .publisher(for: .helpRecordUpdated)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.loadHelpHistory()
                }
            }
            .store(in: &cancellables)
        
        // 初期データの読み込み
        Task {
            await loadInitialData()
        }
    }
    
    deinit {
        // 循環参照を避けるため、deinit内では何もしない
        // タスクは自動的にキャンセルされ、cancellablesは自動的にクリーンアップされる
        print("HelpHistoryViewModel deinit called")
    }
    
    func loadHelpHistory() {
        guard let child = selectedChild else { return }
        
        // 実行中のタスクをキャンセル
        loadHistoryTask?.cancel()
        
        isLoading = true
        errorMessage = nil
        
        loadHistoryTask = Task {
            do {
                let dateRange = selectedPeriod.dateRange
                let records = try await helpRecordRepository.findByChildId(child.id)
                    .filter { record in
                        record.recordedAt >= dateRange.start && record.recordedAt <= dateRange.end
                    }
                    .sorted { $0.recordedAt > $1.recordedAt }
                
                // タスクがキャンセルされていないか確認
                guard !Task.isCancelled else { return }
                
                // 詳細情報を取得（バッチ処理で最適化）
                let allTasks = try await helpTaskRepository.findAll()
                let taskMap = Dictionary(uniqueKeysWithValues: allTasks.map { ($0.id, $0) })
                
                let recordsWithDetails: [HelpRecordWithDetails] = records.compactMap { record in
                    guard let task = taskMap[record.helpTaskId] else { return nil }
                    return HelpRecordWithDetails(
                        helpRecord: record,
                        child: child,
                        task: task
                    )
                }
                
                // 最終的なキャンセル確認
                guard !Task.isCancelled else { return }
                
                helpRecords = recordsWithDetails
                isLoading = false
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = ErrorMessageConverter.convertToUserFriendlyMessage(error)
                isLoading = false
            }
        }
    }
    
    func selectChild(_ child: Child) {
        selectedChild = child
        loadHelpHistory()
    }
    
    func selectPeriod(_ period: HistoryPeriod) {
        selectedPeriod = period
        
        // 子供が未選択の場合は初期データを読み込み
        if selectedChild == nil {
            Task {
                await loadInitialData()
            }
        } else {
            loadHelpHistory()
        }
    }
    
    func deleteRecord(_ recordId: UUID) {
        Task {
            do {
                try await helpRecordRepository.delete(recordId)
                loadHelpHistory()
                // データ更新通知
                NotificationCenter.default.post(name: .helpRecordUpdated, object: nil)
            } catch {
                errorMessage = ErrorMessageConverter.convertToUserFriendlyMessage(error)
            }
        }
    }
    
    func clearErrorMessage() {
        errorMessage = nil
    }
    
    // MARK: - 初期データ読み込み
    
    /// 初期データの読み込み（最初の子供を自動選択）
    func loadInitialData() async {
        do {
            let children = try await childRepository.findAll()
            
            // 子供が未選択かつ利用可能な子供がいる場合、最初の子供を選択
            if selectedChild == nil, let firstChild = children.first {
                selectedChild = firstChild
                loadHelpHistory()
            } else if selectedChild != nil {
                // 既に子供が選択されている場合は履歴をロード
                loadHelpHistory()
            }
        } catch {
            errorMessage = ErrorMessageConverter.convertToUserFriendlyMessage(error)
        }
    }
}

// MARK: - サポートモデル

struct HelpRecordWithDetails: Identifiable {
    let helpRecord: HelpRecord
    let child: Child
    let task: HelpTask
    
    var id: UUID {
        return helpRecord.id
    }
    
    var earnedCoins: Int {
        return task.coinRate
    }
}

enum HistoryPeriod: String, CaseIterable {
    case thisWeek = "今週"
    case thisMonth = "今月"
    case last3Months = "過去3か月"
    case all = "全期間"
    
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return (start: startOfWeek, end: now)
            
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return (start: startOfMonth, end: now)
            
        case .last3Months:
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            let startOfThreeMonthsAgo = calendar.dateInterval(of: .month, for: threeMonthsAgo)?.start ?? threeMonthsAgo
            return (start: startOfThreeMonthsAgo, end: now)
            
        case .all:
            let distantPast = calendar.date(byAdding: .year, value: -10, to: now) ?? now
            return (start: distantPast, end: now)
        }
    }
}