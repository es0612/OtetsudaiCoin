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
    
    func calculateConsecutiveDays(records: [HelpRecord]) -> Int {
        guard !records.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let today = Date()
        
        let uniqueDays = Set(records.compactMap { record in
            calendar.dateInterval(of: .day, for: record.recordedAt)?.start
        })
        
        let sortedDays = uniqueDays.sorted(by: >)
        
        guard let firstDay = sortedDays.first,
              calendar.isDate(firstDay, inSameDayAs: today) else {
            return 0
        }
        
        var consecutiveCount = 0
        var currentCheckDate = today
        
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