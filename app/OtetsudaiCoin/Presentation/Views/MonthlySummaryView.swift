import SwiftUI

struct MonthlySummaryView: View {
    @Bindable var viewModel: MonthlySummaryViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let snap = viewModel.snapshot {
                    heroSection(snap: snap)
                    highlightBadges(snap: snap)
                    taskBreakdownChart(snap: snap)
                    recordCalendarSection(snap: snap)
                    if snap.paymentStatus != .paid {
                        paymentCTA(snap: snap)
                    }
                } else if viewModel.isLoading {
                    ProgressView("読み込み中...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    Text("データがありません")
                        .appFont(.secondaryInfo)
                        .foregroundColor(AccessibilityColors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .padding()
        }
        .navigationTitle("月のまとめ")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) { monthNavBar }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -50 {
                        viewModel.goToPreviousMonth()
                        Task { await viewModel.loadMonth() }
                    } else if value.translation.width > 50 {
                        viewModel.goToNextMonth()
                        Task { await viewModel.loadMonth() }
                    }
                }
        )
        .animation(.easeInOut, value: viewModel.selectedMonth)
    }

    // MARK: - Navigation Bar

    private var monthNavBar: some View {
        HStack {
            Button {
                viewModel.goToPreviousMonth()
                Task { await viewModel.loadMonth() }
            } label: {
                Text("‹").font(.title2).frame(width: 44, height: 32)
            }
            .accessibilityIdentifier("summary_prev_month")
            .accessibilityLabel(Text(String(localized: "前の月")))

            Spacer()
            Text(viewModel.snapshot?.monthLabel ?? "").appFont(.sectionHeader)
            Spacer()

            Button {
                viewModel.goToNextMonth()
                Task { await viewModel.loadMonth() }
            } label: {
                Text("›").font(.title2).frame(width: 44, height: 32)
            }
            .accessibilityIdentifier("summary_next_month")
            .accessibilityLabel(Text(String(localized: "次の月")))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Sections

    private func heroSection(snap: MonthSnapshot) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                VStack {
                    Text("\(snap.totalCount)")
                        .appFont(.appTitle)
                        .foregroundColor(AccessibilityColors.primaryBlue)
                    Text("回")
                        .appFont(.captionText)
                        .foregroundColor(AccessibilityColors.textSecondary)
                }
                VStack {
                    Text("¥\(snap.totalCoins)")
                        .appFont(.appTitle)
                        .foregroundColor(AccessibilityColors.successGreen)
                    Text("獲得")
                        .appFont(.captionText)
                        .foregroundColor(AccessibilityColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                LinearGradient(
                    colors: [
                        (Color(hex: viewModel.child.themeColor) ?? .blue).opacity(0.15),
                        (Color(hex: viewModel.child.themeColor) ?? .blue).opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
        }
    }

    private func highlightBadges(snap: MonthSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ハイライト")
                .appFont(.sectionHeader)
            HStack(spacing: 12) {
                badge(icon: "flame.fill", label: "連続", value: "\(snap.highlights.consecutiveDayStreak)日", color: .orange)
                if let topDay = snap.highlights.topDay {
                    let day = Calendar.current.component(.day, from: topDay.date)
                    badge(icon: "star.fill", label: "頑張った日", value: "\(day)日 (\(topDay.count)回)", color: .yellow)
                } else {
                    badge(icon: "star.fill", label: "頑張った日", value: "—", color: .yellow)
                }
                badge(icon: "trophy.fill", label: "ベスト", value: snap.highlights.topTaskName ?? "—", color: .pink)
            }
        }
    }

    private func badge(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(label)
                .appFont(.captionText)
                .foregroundColor(AccessibilityColors.textSecondary)
            Text(value)
                .appFont(.captionText)
                .fontWeight(.semibold)
                .foregroundColor(AccessibilityColors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }

    private func taskBreakdownChart(snap: MonthSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("お手伝い内訳")
                .appFont(.sectionHeader)
            if snap.taskBreakdown.isEmpty {
                Text("まだ記録がありません")
                    .appFont(.captionText)
                    .foregroundColor(AccessibilityColors.textSecondary)
            } else {
                ForEach(snap.taskBreakdown.indices, id: \.self) { idx in
                    let item = snap.taskBreakdown[idx]
                    let maxCount = max(snap.taskBreakdown.first?.count ?? 1, 1)
                    HStack {
                        Text(item.name)
                            .appFont(.captionText)
                            .frame(width: 90, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(AccessibilityColors.primaryBlue.opacity(0.15))
                                Rectangle()
                                    .fill(AccessibilityColors.primaryBlue)
                                    .frame(width: geo.size.width * CGFloat(item.count) / CGFloat(maxCount))
                            }
                            .cornerRadius(4)
                        }
                        .frame(height: 16)
                        Text("\(item.count)回")
                            .appFont(.captionText)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func recordCalendarSection(snap: MonthSnapshot) -> some View {
        let recordedDays = Set(snap.calendar.filter { $0.count > 0 }.map { $0.day })
        return VStack(alignment: .leading, spacing: 8) {
            Text("\(snap.monthLabel)のカレンダー")
                .appFont(.sectionHeader)
            RecordCalendarView(
                displayedMonth: viewModel.selectedMonth,
                selectedDate: Date.distantPast,
                recordedDays: recordedDays,
                today: Date(),
                canGoNextMonth: false,
                showHeader: false,
                onSelectDay: { _ in },
                onPrevMonth: {},
                onNextMonth: {}
            )
        }
    }

    private func paymentCTA(snap: MonthSnapshot) -> some View {
        let remainder = snap.totalCoins - snap.paidAmount
        return Button {
            Task { await viewModel.payCurrentMonth() }
        } label: {
            HStack {
                Image(systemName: "yensign.circle.fill")
                Text(snap.paidAmount > 0 ? "追加分のお小遣いを支払う" : "この月のお小遣いを支払う")
                Spacer()
                Text("¥\(remainder)").fontWeight(.bold)
            }
        }
        .primaryGradientButton()
        .accessibilityIdentifier("summary_payment_cta")
    }
}
