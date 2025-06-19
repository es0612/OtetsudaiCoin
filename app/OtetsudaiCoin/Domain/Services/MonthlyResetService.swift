import Foundation

protocol MonthlyResetServiceProtocol {
    func checkAndPerformMonthlyReset() async throws
    func getLastResetDate() -> Date?
    func setLastResetDate(_ date: Date)
}

class MonthlyResetService: MonthlyResetServiceProtocol {
    private let helpRecordRepository: HelpRecordRepository
    private let userDefaults: UserDefaults
    
    private let lastResetDateKey = "lastMonthlyResetDate"
    
    init(helpRecordRepository: HelpRecordRepository, userDefaults: UserDefaults = .standard) {
        self.helpRecordRepository = helpRecordRepository
        self.userDefaults = userDefaults
    }
    
    func checkAndPerformMonthlyReset() async throws {
        let calendar = Calendar.current
        let now = Date()
        
        // 今月の1日を取得
        let currentMonthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        
        // 最後のリセット日を取得
        let lastResetDate = getLastResetDate()
        
        // 最後のリセットが今月以前の場合、日付を更新（削除は行わない）
        if let lastReset = lastResetDate {
            let lastResetMonthStart = calendar.dateInterval(of: .month, for: lastReset)?.start ?? lastReset
            
            // 前月以前にリセットされている場合、新しい月なので日付を更新
            if lastResetMonthStart < currentMonthStart {
                setLastResetDate(now)
                // 注意: データ削除は行わず、履歴として保持
            }
        } else {
            // 初回起動の場合、リセット日のみ記録
            setLastResetDate(now)
        }
    }
    
    func getLastResetDate() -> Date? {
        let timestamp = userDefaults.double(forKey: lastResetDateKey)
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }
    
    func setLastResetDate(_ date: Date) {
        userDefaults.set(date.timeIntervalSince1970, forKey: lastResetDateKey)
    }
    
}

enum MonthlyResetError: Error, LocalizedError {
    case dateCalculationFailed
    
    var errorDescription: String? {
        switch self {
        case .dateCalculationFailed:
            return "日付の計算に失敗しました"
        }
    }
}