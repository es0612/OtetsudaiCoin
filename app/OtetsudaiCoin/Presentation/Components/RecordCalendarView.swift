import SwiftUI

/// 記録画面の「記録日」用インライン月カレンダー。
/// 選択中の子どもの記録がある日に緑ドットを表示し、記録漏れ・二重登録に事前に気づけるようにする (#84)。
/// 純プレゼンテーショナル: 状態は引数、操作はクロージャで親 (RecordView/RecordViewModel) に委譲。
/// `Image(systemName:)` を使わず AccessibilityImageLabel blocker を避ける設計。
struct RecordCalendarView: View {
    let displayedMonth: Date      // 表示中の月 (月初アンカー)
    let selectedDate: Date        // 選択中の記録日
    let recordedDays: Set<Int>    // displayedMonth 内で記録がある日
    let today: Date               // 未来日判定の基準
    let canGoNextMonth: Bool
    var showHeader: Bool = true
    let onSelectDay: (Int) -> Void
    let onPrevMonth: () -> Void
    let onNextMonth: () -> Void

    private let cal = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showHeader {
                header
            }
            weekdayHeader
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 4) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                        if let day {
                            dayCell(day)
                        } else {
                            Color.clear.frame(maxWidth: .infinity).frame(height: 38)
                        }
                    }
                }
            }
            if showHeader {
                selectedCaption
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: onPrevMonth) {
                Text("‹").font(.title2).frame(width: 44, height: 32)
            }
            .accessibilityIdentifier("calendar_prev_month")
            .accessibilityLabel(Text(String(localized: "前の月")))

            Spacer()
            Text(monthTitle).appFont(.sectionHeader)
            Spacer()

            Button(action: onNextMonth) {
                Text("›").font(.title2).frame(width: 44, height: 32)
                    .opacity(canGoNextMonth ? 1 : 0.3)
            }
            .disabled(!canGoNextMonth)
            .accessibilityIdentifier("calendar_next_month")
            .accessibilityLabel(Text(String(localized: "次の月")))
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(orderedWeekdaySymbols, id: \.self) { sym in
                Text(sym)
                    .font(.caption2)
                    .foregroundColor(AccessibilityColors.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Day cell

    private func dayCell(_ day: Int) -> some View {
        let isRecorded = recordedDays.contains(day)
        let isSelected = selectedDayInDisplayedMonth == day
        let isFuture = isFutureDay(day)
        return Button {
            onSelectDay(day)
        } label: {
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.system(size: 15))
                    .foregroundColor(dayForeground(isFuture: isFuture, isSelected: isSelected))
                    .frame(width: 30, height: 30)
                    .background {
                        if isSelected {
                            Circle().fill(AccessibilityColors.brandPrimary)
                        }
                    }
                Circle()
                    .fill(isRecorded ? AccessibilityColors.successGreen : Color.clear)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)  // 記録有無は cell の accessibilityLabel ("記録あり"/"記録なし") が伝える
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(isFuture)
        .accessibilityIdentifier("calendar_day_\(day)")
        .accessibilityLabel(Text(dayAccessibilityLabel(day, isRecorded: isRecorded, isSelected: isSelected, isFuture: isFuture)))
    }

    private func dayForeground(isFuture: Bool, isSelected: Bool) -> Color {
        if isFuture { return AccessibilityColors.textDisabled }
        if isSelected { return .white }
        return AccessibilityColors.textPrimary
    }

    private var selectedCaption: some View {
        HStack(spacing: 6) {
            Text(String(localized: "記録日")).appFont(.secondaryInfo)
                .foregroundColor(AccessibilityColors.textSecondary)
            Text(selectedDate, format: .dateTime.year().month().day())
                .appFont(.secondaryInfo)
        }
        .padding(.top, 2)
    }

    // MARK: - Derived data

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("yMMMM")
        return f.string(from: displayedMonth)
    }

    private var orderedWeekdaySymbols: [String] {
        let symbols = cal.shortWeekdaySymbols          // index 0 = Sunday
        let first = cal.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// 週ごとに分割した日番号 (前方の空白は nil)。
    private var weeks: [[Int?]] {
        guard let range = cal.range(of: .day, in: .month, for: displayedMonth) else { return [] }
        let firstWeekday = cal.component(.weekday, from: displayedMonth) // 1=Sun..7=Sat
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        var cells: [Int?] = Array(repeating: nil, count: leading)
        cells.append(contentsOf: range.map { Optional($0) })
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0 ..< $0 + 7]) }
    }

    /// selectedDate が displayedMonth と同じ年月なら、その日。違えば nil (ハイライトしない)。
    private var selectedDayInDisplayedMonth: Int? {
        let d = cal.dateComponents([.year, .month, .day], from: selectedDate)
        let m = cal.dateComponents([.year, .month], from: displayedMonth)
        return (d.year == m.year && d.month == m.month) ? d.day : nil
    }

    private func isFutureDay(_ day: Int) -> Bool {
        var comps = cal.dateComponents([.year, .month], from: displayedMonth)
        comps.day = day
        guard let date = cal.date(from: comps) else { return false }
        return cal.startOfDay(for: date) > cal.startOfDay(for: today)
    }

    private func dayAccessibilityLabel(_ day: Int, isRecorded: Bool, isSelected: Bool, isFuture: Bool) -> String {
        var comps = cal.dateComponents([.year, .month], from: displayedMonth)
        comps.day = day
        let date = cal.date(from: comps) ?? displayedMonth
        var parts = [date.formatted(.dateTime.year().month().day())]
        parts.append(isRecorded ? String(localized: "記録あり") : String(localized: "記録なし"))
        if isSelected { parts.append(String(localized: "選択中")) }
        if isFuture { parts.append(String(localized: "選択できません")) }
        return parts.joined(separator: "、")
    }
}
