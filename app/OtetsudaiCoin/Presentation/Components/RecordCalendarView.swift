import SwiftUI
import UIKit

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

    // #151: AX サイズの Dynamic Type でも日番号がクリップしないよう、セル geometry を
    // フォント (.subheadline) と同係数でスケールさせる。記録ドット (6pt) は装飾のため固定
    // (情報は accessibilityLabel が伝える)。
    @ScaledMetric(relativeTo: .subheadline) private var scaledDayCellSize: CGFloat = 30
    private var dayCellSize: CGFloat {
        Self.clampedDayCellSize(scaled: scaledDayCellSize, screenWidth: UIScreen.main.bounds.width)
    }
    /// filler は日セル 30 + spacing 2 + ドット 6 に相当。dayCellSize と連動させないと
    /// AX サイズで nil セルを含む週だけ行高が縮んで崩れる。
    private var fillerHeight: CGFloat { dayCellSize + 8 }

    /// セルサイズの clamp 判定 (テスト可能な pure helper)。
    /// @ScaledMetric は AX5 で 30 → 約63pt まで育ち、7 列 + 間隔が画面幅を超えて
    /// 水平 overflow するため、(a) 44pt (HIG 最小タップ領域) と (b) 画面幅から逆算した
    /// 1 列分 (横 padding 32 + セル間隔 4×6 を差し引いて 7 等分) の小さい方へ clamp する。
    /// (b) は Display Zoom 等の 320pt 論理幅でも 7 列が収まるための width-aware 上限。
    /// 既定値 30 を下回らない floor 付き (通常サイズでは常に 30)。
    ///
    /// なおフォントの上限は別機構 (body 側の .dynamicTypeSize(...accessibility2)) が与える。
    /// この clamp と cap は冗長ではなく両方必要: cap は子 View のフォントにしか効かず
    /// @ScaledMetric は cap 前の親 environment を読むので clamp が要り、逆に clamp を
    /// 残しても cap を外すと AX5 の日番号 (≈49pt、Text は非拘束) がセル幅を超えて
    /// overflow が再発する。
    static func clampedDayCellSize(scaled: CGFloat, screenWidth: CGFloat) -> CGFloat {
        let fitting = (screenWidth - 32 - 24) / 7
        return max(30, min(scaled, 44, fitting))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showHeader {
                header
            }
            // #151: 7 列グリッドは AX5 (subheadline ≈ 49pt) だと 2 桁日の週が画面幅を超えて
            // 水平 overflow する (AX 撮影で実測)。dense グリッドの定石として accessibility2
            // (≈ 27pt、既定比 1.8 倍) を上限にする。overflow 要因でない月タイトル・
            // 記録日 caption は cap の外に置き AX5 まで追従させる。
            Group {
                weekdayHeader
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: 4) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                            if let day {
                                dayCell(day)
                            } else {
                                // minWidth を day cell と揃え、幅が逼迫したとき filler だけ
                                // 潰れて週ごとに列位置がずれるのを防ぐ
                                Color.clear
                                    .frame(minWidth: dayCellSize, maxWidth: .infinity, minHeight: fillerHeight)
                            }
                        }
                    }
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            if showHeader {
                selectedCaption
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: onPrevMonth) {
                // #151: HIG の最小タップ領域 44×44pt を満たす (以前は高さ 32pt)。
                // min 指定なのは AX サイズで glyph が 44pt を超えても truncate させないため (#198)
                Text("‹").font(.title2).frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityIdentifier("calendar_prev_month")
            .accessibilityLabel(Text(String(localized: "前の月")))

            Spacer()
            Text(monthTitle).appFont(.sectionHeader)
            Spacer()

            Button(action: onNextMonth) {
                Text("›").font(.title2).frame(minWidth: 44, minHeight: 44)
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
                // #198 パターン: 可変サイズ Text を固定 frame + .background に入れると
                // AX サイズで 2 桁日番号が truncate する (実測で "…" になった)。
                // ZStack + 別 frame の Circle + 非拘束 Text で組み、frame は min 指定にする。
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(AccessibilityColors.brandPrimary)
                            .frame(width: dayCellSize, height: dayCellSize)
                    }
                    Text("\(day)")
                        // #151: Dynamic Type 追従。.secondaryInfo = .subheadline ≈ 15pt で既定サイズは同等
                        .appFont(.secondaryInfo)
                        .foregroundColor(dayForeground(isFuture: isFuture, isSelected: isSelected))
                }
                .frame(minWidth: dayCellSize, minHeight: dayCellSize)
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
