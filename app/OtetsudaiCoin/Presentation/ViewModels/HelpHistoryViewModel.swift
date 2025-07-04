import Foundation
import Combine

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
    }
    
    func loadHelpHistory() {
        guard let child = selectedChild else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let dateRange = selectedPeriod.dateRange
                let records = try await helpRecordRepository.findByChildId(child.id)
                    .filter { record in
                        record.recordedAt >= dateRange.start && record.recordedAt <= dateRange.end
                    }
                    .sorted { $0.recordedAt > $1.recordedAt }
                
                // 詳細情報を取得
                var recordsWithDetails: [HelpRecordWithDetails] = []
                for record in records {
                    if let task = try await helpTaskRepository.findById(record.helpTaskId) {
                        let recordWithDetails = HelpRecordWithDetails(
                            helpRecord: record,
                            child: child,
                            task: task
                        )
                        recordsWithDetails.append(recordWithDetails)
                    }
                }
                
                helpRecords = recordsWithDetails
                isLoading = false
            } catch {
                errorMessage = "履歴の読み込みに失敗しました: \(error.localizedDescription)"
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
        loadHelpHistory()
    }
    
    func deleteRecord(_ recordId: UUID) {
        Task {
            do {
                try await helpRecordRepository.delete(recordId)
                loadHelpHistory()
                // データ更新通知
                NotificationCenter.default.post(name: .helpRecordUpdated, object: nil)
            } catch {
                errorMessage = "記録の削除に失敗しました: \(error.localizedDescription)"
            }
        }
    }
    
    func clearErrorMessage() {
        errorMessage = nil
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