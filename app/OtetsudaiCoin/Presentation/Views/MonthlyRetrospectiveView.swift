import SwiftUI

struct MonthlyRetrospectiveView: View {
    @Bindable var viewModel: MonthlyRetrospectiveViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    monthHeader
                    if let snap = viewModel.snapshot {
                        heroSection(snap: snap)
                        highlightBadges(snap: snap)
                        taskBreakdownChart(snap: snap)
                        monthCalendarHeatmap(snap: snap)
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
            .navigationTitle(viewModel.snapshot?.monthLabel ?? "振り返り")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { dismiss() }
                }
            }
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
        .task {
            await viewModel.loadMonth()
        }
    }

    // MARK: - Sections

    private var monthHeader: some View {
        HStack {
            Button {
                viewModel.goToPreviousMonth()
                Task { await viewModel.loadMonth() }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(AccessibilityColors.primaryBlue)
            }
            .accessibilityIdentifier("retrospective_prev_month")

            Spacer()

            Text("\(viewModel.child.name)ちゃんの記録")
                .appFont(.sectionHeader)
                .foregroundColor(AccessibilityColors.textPrimary)

            Spacer()

            Button {
                viewModel.goToNextMonth()
                Task { await viewModel.loadMonth() }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(AccessibilityColors.primaryBlue)
            }
            .accessibilityIdentifier("retrospective_next_month")
        }
    }

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

    private func monthCalendarHeatmap(snap: MonthSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(snap.monthLabel)のカレンダー")
                .appFont(.sectionHeader)
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(snap.calendar, id: \.day) { day in
                    let intensity = min(Double(day.count) / 5.0, 1.0)
                    Rectangle()
                        .fill(
                            day.count == 0
                                ? AccessibilityColors.textSecondary.opacity(0.1)
                                : AccessibilityColors.primaryBlue.opacity(0.3 + 0.7 * intensity)
                        )
                        .frame(height: 24)
                        .cornerRadius(4)
                        .overlay(
                            Text("\(day.day)")
                                .font(.system(size: 9))
                                .foregroundColor(day.count == 0 ? AccessibilityColors.textSecondary : .white)
                        )
                }
            }
        }
    }

    private func paymentCTA(snap: MonthSnapshot) -> some View {
        // 実際の支払い実行は HomeView 側に集約。本イシューのスコープでは表示のみ。
        Button {
            // 将来 HomeView との統合で対応（YAGNI）
        } label: {
            HStack {
                Image(systemName: "yensign.circle.fill")
                Text("お小遣いを渡す")
            }
        }
        .primaryGradientButton()
        .accessibilityIdentifier("retrospective_payment_cta")
    }
}
