#if DEBUG
import Foundation

/// 検証撮影用に、未払いのお小遣いがある状態を作る (Issue #309)。
///
/// `--seed-unpaid-records 1|2` を `--in-memory-store` と一緒に渡したときだけ、
/// `ContentView.setupInitialData()` が先頭 1 人 (または 2 人) の子どもに
/// 先月と 2 か月前の記録を入れる。未払いの検出は今月を飛ばすため、記録は先月以前に置く。
/// `--in-memory-store` が無いときは何もしない (永続ストアを汚さない)。
enum UnpaidRecordsSeeder {

    static let argument = "--seed-unpaid-records"

    /// 記録を入れる子どもの数。条件を満たさないときは `nil`。
    static func childCount(arguments: [String] = ProcessInfo.processInfo.arguments) -> Int? {
        guard arguments.contains("--in-memory-store"),
              let index = arguments.firstIndex(of: argument),
              arguments.indices.contains(index + 1),
              let count = Int(arguments[index + 1]),
              (1...2).contains(count) else {
            return nil
        }
        return count
    }

    /// 子どもごとに、`now` の 1 か月前と 2 か月前の月の 10 日 (9 時・12 時・15 時) に 1 件ずつ。
    static func records(childIds: [UUID], helpTaskId: UUID, now: Date, calendar: Calendar) -> [HelpRecord] {
        var records: [HelpRecord] = []
        for childId in childIds {
            for monthsAgo in 1...2 {
                guard let shifted = calendar.date(byAdding: .month, value: -monthsAgo, to: now) else { continue }
                let month = calendar.dateComponents([.year, .month], from: shifted)
                for hour in [9, 12, 15] {
                    let components = DateComponents(year: month.year, month: month.month, day: 10, hour: hour)
                    guard let recordedAt = calendar.date(from: components) else { continue }
                    records.append(HelpRecord(id: UUID(), childId: childId, helpTaskId: helpTaskId, recordedAt: recordedAt))
                }
            }
        }
        return records
    }
}
#endif
