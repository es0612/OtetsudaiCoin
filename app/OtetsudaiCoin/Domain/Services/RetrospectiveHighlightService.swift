import Foundation

struct Highlights: Equatable {
    let consecutiveDayStreak: Int
    let topDay: TopDay?
    let topTaskName: String?

    struct TopDay: Equatable {
        let date: Date
        let count: Int
    }
}

class RetrospectiveHighlightService {

    func compute(records: [HelpRecord], tasks: [HelpTask]) -> Highlights {
        guard !records.isEmpty else {
            return Highlights(consecutiveDayStreak: 0, topDay: nil, topTaskName: nil)
        }

        let cal = Calendar.current

        let recordsByDay: [Date: [HelpRecord]] = Dictionary(grouping: records) { record in
            cal.startOfDay(for: record.recordedAt)
        }

        let streak = computeMaxConsecutiveStreak(days: Array(recordsByDay.keys), calendar: cal)

        let topDay = recordsByDay
            .map { (date: $0.key, count: $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.date > rhs.date
            }
            .first
            .map { Highlights.TopDay(date: $0.date, count: $0.count) }

        let topTaskName = computeTopTaskName(records: records, tasks: tasks)

        return Highlights(
            consecutiveDayStreak: streak,
            topDay: topDay,
            topTaskName: topTaskName
        )
    }

    private func computeMaxConsecutiveStreak(days: [Date], calendar: Calendar) -> Int {
        guard !days.isEmpty else { return 0 }

        let daysByMonth: [DateComponents: [Date]] = Dictionary(grouping: days) { day in
            calendar.dateComponents([.year, .month], from: day)
        }

        var globalMax = 0
        for (_, monthDays) in daysByMonth {
            let sorted = monthDays.sorted()
            var current = 1
            var localMax = 1
            for i in 1..<sorted.count {
                let prev = sorted[i - 1]
                let next = sorted[i]
                if let nextDay = calendar.date(byAdding: .day, value: 1, to: prev),
                   calendar.isDate(nextDay, inSameDayAs: next) {
                    current += 1
                    localMax = max(localMax, current)
                } else {
                    current = 1
                }
            }
            globalMax = max(globalMax, localMax)
        }
        return globalMax
    }

    private func computeTopTaskName(records: [HelpRecord], tasks: [HelpTask]) -> String? {
        let taskMap = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })

        let recordsByTask: [UUID: [HelpRecord]] = Dictionary(grouping: records) { $0.helpTaskId }
        let sorted = recordsByTask
            .compactMap { (taskId, recs) -> (id: UUID, count: Int, latest: Date)? in
                guard let latest = recs.map({ $0.recordedAt }).max() else { return nil }
                return (taskId, recs.count, latest)
            }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs.latest > rhs.latest
            }

        guard let top = sorted.first else { return nil }
        return taskMap[top.id]?.name
    }
}
