import XCTest
@testable import OtetsudaiCoin

/// HelpHistoryView の日付フォーマット helper (#155 コメント報告の i18n 漏れ) と
/// 日付 grouping helper (#205) のテスト。記録時刻系は TimeStringFormatterTests へ移設 (#206)。
///
/// - 日付 fixture は固定絶対日付 (2026-07-15 = 月中日) を使い、実行日非依存にする (#112/#114/#115 の flake 対策)。
/// - locale は明示的に ja_JP / en_US を渡し、実行環境 locale に依存しない。
/// - View 本体の traverse は ViewInspector の既知制約があるため行わず、static helper を直接検証する。
@MainActor
final class HelpHistoryViewTests: XCTestCase {

    /// 2026-07-15 (水) 09:05 を gregorian で固定生成する。
    private func fixedDate(hour: Int = 9, minute: Int = 5) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 15
        components.hour = hour
        components.minute = minute
        let calendar = Calendar(identifier: .gregorian)
        return calendar.date(from: components)!
    }

    // MARK: - dayGroupLabel (履歴の日付グループ見出し)

    /// ja では現行の「7月15日 (水)」とほぼ同等 (テンプレート化で括弧前スペースのみ消える) であること (非退行)。
    func testDayGroupLabelJapaneseLocaleKeepsCurrentStyle() {
        let label = HelpHistoryView.dayGroupLabel(
            from: fixedDate(), locale: Locale(identifier: "ja_JP")
        )
        XCTAssertEqual(label, "7月15日(水)", "rendered: \(label)")
    }

    /// en では「Wed, Jul 15」相当のローカライズ表記になること (旧実装は ja_JP 固定で「7月15日 (水)」が出る実バグ)。
    func testDayGroupLabelEnglishLocaleUsesLocalizedTemplate() {
        let label = HelpHistoryView.dayGroupLabel(
            from: fixedDate(), locale: Locale(identifier: "en_US")
        )
        XCTAssertEqual(label, "Wed, Jul 15", "rendered: \(label)")
        XCTAssertFalse(label.contains("月"), "en locale に日本語表記が混入: \(label)")
    }

    // MARK: - groupRecordsByDay (#205)

    /// 2026-07-{day} {hour}:00 の HelpRecordWithDetails を固定生成する
    /// (HelpRecordRowTests.makeView の factory パターンを流用)。
    private func makeRecord(day: Int, hour: Int) -> HelpRecordWithDetails {
        let date = Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 7, day: day, hour: hour)
        )!
        let child = Child(id: UUID(), name: "さくら", themeColor: "#FF6B6B")
        let task = HelpTask(id: UUID(), name: "皿洗い", isActive: true, coinRate: 100, sortOrder: 0, icon: nil)
        let record = HelpRecord(id: UUID(), childId: child.id, helpTaskId: task.id, recordedAt: date)
        return HelpRecordWithDetails(helpRecord: record, child: child, task: task)
    }

    /// グループは日付降順、グループ内は入力配列順を維持すること (characterization)。
    func testGroupRecordsByDaySortsGroupsDescendingAndKeepsWithinGroupOrder() {
        // day15 の 2 件は「遅い時刻が先」の unsorted 配列順にして、
        // グループ代表値の取り方 (first vs min) の差が結果へ出ないことも lock する
        let records = [
            makeRecord(day: 15, hour: 18),
            makeRecord(day: 14, hour: 9),
            makeRecord(day: 15, hour: 8),
            makeRecord(day: 16, hour: 12),
        ]
        let groups = HelpHistoryView.groupRecordsByDay(records) { date in
            "day-\(Calendar(identifier: .gregorian).component(.day, from: date))"
        }
        XCTAssertEqual(groups.map(\.key), ["day-16", "day-15", "day-14"],
                       "rendered: \(groups.map(\.key))")
        XCTAssertEqual(groups[1].value.map(\.helpRecord.recordedAt),
                       [records[0], records[2]].map(\.helpRecord.recordedAt),
                       "グループ内の入力配列順が保たれていない")
    }

    /// dayKey (formatter.string 相当) は各レコード 1 回 = 計 n 回しか呼ばれないこと (#205 perf)。
    /// 旧実装は sort 比較内の線形探索で O(n·k·log k) 回呼んでいた。
    func testGroupRecordsByDayCallsDayKeyOncePerRecord() {
        let records = [
            makeRecord(day: 15, hour: 18),
            makeRecord(day: 14, hour: 9),
            makeRecord(day: 15, hour: 8),
            makeRecord(day: 16, hour: 12),
            makeRecord(day: 13, hour: 7),
        ]
        var callCount = 0
        _ = HelpHistoryView.groupRecordsByDay(records) { date in
            callCount += 1
            return "day-\(Calendar(identifier: .gregorian).component(.day, from: date))"
        }
        XCTAssertEqual(callCount, records.count,
                       "dayKey が \(callCount) 回呼ばれた (期待: \(records.count) 回 = レコードあたり 1 回)")
    }

    /// 空配列で空結果 (crash しない) こと。
    func testGroupRecordsByDayEmptyInputReturnsEmpty() {
        let groups = HelpHistoryView.groupRecordsByDay([]) { _ in "x" }
        XCTAssertTrue(groups.isEmpty)
    }

}
