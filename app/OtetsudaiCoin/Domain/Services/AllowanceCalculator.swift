import Foundation

class AllowanceCalculator {
    func calculateMonthlyAllowance(records: [HelpRecord], tasks: [HelpTask]) -> Int {
        let taskMap = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.coinRate) })
        return records.reduce(0) { total, record in
            total + (taskMap[record.helpTaskId] ?? 10)
        }
    }
    
    func calculateMonthlyAllowance(records: [HelpRecord]) -> Int {
        // 下位互換性のため、デフォルト値10を使用
        return records.count * 10
    }
    
    func calculateConsecutiveDays(records: [HelpRecord], today: Date = Date()) -> Int {
        guard !records.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        
        // #311: 今日より後の日付の記録は数えない（未来の記録が最新日になって 0 に倒れるのを防ぐ）
        let todayStart = calendar.startOfDay(for: today)
        let uniqueDays = Set(records.compactMap { record in
            calendar.dateInterval(of: .day, for: record.recordedAt)?.start
        }.filter { $0 <= todayStart })
        
        let sortedDays = uniqueDays.sorted(by: >)
        
        // #311: 最新の記録日が今日なら今日から、昨日なら昨日からさかのぼる。それ以外は 0
        guard let firstDay = sortedDays.first,
              let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              calendar.isDate(firstDay, inSameDayAs: today) || calendar.isDate(firstDay, inSameDayAs: yesterday) else {
            return 0
        }
        
        var consecutiveCount = 0
        var currentCheckDate = firstDay
        
        for day in sortedDays {
            if calendar.isDate(day, inSameDayAs: currentCheckDate) {
                consecutiveCount += 1
                currentCheckDate = calendar.date(byAdding: .day, value: -1, to: currentCheckDate) ?? currentCheckDate
            } else {
                break
            }
        }
        
        return consecutiveCount
    }
}