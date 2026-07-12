import SwiftUI
import UIKit

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel

    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.isLoading {
                    SkeletonViews.HomeViewSkeleton()
                } else if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(AccessibilityColors.errorRed)
                        Text(errorMessage)
                            .appFont(.errorMessage)
                            .foregroundColor(AccessibilityColors.errorRed)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("再試行") {
                            viewModel.loadChildren()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.children.isEmpty {
                    VStack {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.largeTitle)
                            .foregroundColor(AccessibilityColors.textSecondary)
                        Text("お子様を登録してください")
                            .appFont(.sectionHeader)
                            .foregroundColor(AccessibilityColors.textSecondary)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: DeviceInfo.contentPadding) {
                            // 未支払い警告バナー
                            if viewModel.showUnpaidWarning {
                                unpaidWarningBanner
                            }
                            
                            if let selectedChild = viewModel.selectedChild {
                                childStatsView(for: selectedChild)
                            }
                            
                            childrenListView
                        }
                        .adaptivePadding()
                    }
                    .adaptiveContentWidth()
                }
            }
            .navigationTitle("おてつだいコイン")
            .task {
                // #44: 初期ロードを View 側の `.task` に統一（履歴系画面と同じパターン）。
                // `.onAppear` から fire-and-forget の Task 起動だと、NotificationManager 経由の
                // 自動再ロードと競合してメイン画面が空表示のまま固定されるケースが残っていた。
                await viewModel.loadChildrenAsync()
            }
        }
        .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearMessages()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("完了", isPresented: .constant(viewModel.successMessage != nil)) {
            Button("OK") {
                viewModel.clearMessages()
            }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
    }

    private func childStatsView(for child: Child) -> some View {
        VStack(spacing: 20) {
            // 子供のアバター + 名前
            VStack(spacing: 12) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: child.themeColor) ?? .blue, (Color(hex: child.themeColor) ?? .blue).opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(String(child.name.prefix(1)))
                            .appFont(.appTitle)
                            .foregroundColor(.white)
                    )
                    .shadow(color: (Color(hex: child.themeColor) ?? .blue).opacity(0.3), radius: 8, x: 0, y: 4)

                Text("\(child.name)ちゃんの記録")
                    .appFont(.sectionHeader)
                    .foregroundColor(AccessibilityColors.textPrimary)
            }

            // 入口2つ（旧: 無地アイコン3つ）
            VStack(spacing: 8) {
                NavigationLink(destination: monthlySummaryView(for: child)) {
                    entryRow(icon: "chart.bar.doc.horizontal", title: "月のまとめ", color: Color(hex: child.themeColor) ?? .blue)
                }
                .accessibilityIdentifier("home_monthly_summary_entry")

                NavigationLink(destination: getHelpHistoryView(for: child)) {
                    entryRow(icon: "list.clipboard", title: "お手伝い履歴", color: Color(hex: child.themeColor) ?? .blue)
                }
                .accessibilityIdentifier("home_help_history_entry")
            }

            // 統計（今月のコイン + 連続記録）
            HStack(spacing: DeviceInfo.statisticsCardSpacing) {
                StatisticsCard(
                    icon: "dollarsign.circle.fill",
                    title: "今月のコイン",
                    value: "\(viewModel.monthlyAllowance)",
                    subtitle: "コイン獲得！",
                    color: .green,
                    style: .large
                )
                StatisticsCard(
                    icon: "flame.fill",
                    title: "連続記録",
                    value: "\(viewModel.consecutiveDays)",
                    subtitle: "日連続！",
                    color: .orange,
                    style: .large
                )
            }
        }
        .adaptivePadding()
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xLarge)
                .fill(Color(.systemBackground))
                .appShadow(AppShadow.floating)
        )
        .padding(.horizontal, DeviceInfo.contentPadding)
    }
    
    private func getHelpHistoryView(for child: Child) -> some View {
        let context = PersistenceController.shared.container.viewContext
        let repositoryFactory = RepositoryFactory(context: context)
        let viewModelFactory = ViewModelFactory(repositoryFactory: repositoryFactory)
        let historyViewModel = viewModelFactory.createHelpHistoryViewModel()
        
        return HelpHistoryView(viewModel: historyViewModel)
            .onAppear {
                historyViewModel.selectChild(child)
            }
    }
    
    private func monthlySummaryView(for child: Child, initialMonth: Date? = nil) -> some View {
        let context = PersistenceController.shared.container.viewContext
        let repositoryFactory = RepositoryFactory(context: context)
        let vm = MonthlySummaryViewModel(
            child: child,
            helpRecordRepository: repositoryFactory.createHelpRecordRepository(),
            helpTaskRepository: repositoryFactory.createHelpTaskRepository(),
            allowancePaymentRepository: repositoryFactory.createAllowancePaymentRepository(),
            initialMonth: initialMonth
        )
        return MonthlySummaryView(viewModel: vm)
            .onAppear { Task { await vm.loadMonth() } }
    }

    @ViewBuilder
    private func entryRow(icon: String, title: LocalizedStringKey, color: Color) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(color)
            Text(title).appFont(.sectionHeader).foregroundColor(AccessibilityColors.textPrimary)
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundColor(AccessibilityColors.textSecondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(Color(.systemBackground))
                .appShadow(AppShadow.card)
        )
    }

    private var childrenListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("お子様を選択")
                .appFont(.sectionHeader)
                .padding(.horizontal, DeviceInfo.contentPadding)
            
            LazyVStack(spacing: 8) {
                ForEach(viewModel.children, id: \.id) { child in
                    Button(action: {
                        viewModel.selectChild(child)
                    }) {
                        HStack {
                            Circle()
                                .fill(Color(hex: child.themeColor) ?? .blue)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(String(child.name.prefix(1)))
                                        .font(.headline)
                                        .foregroundColor(.white)
                                )
                            
                            Text(child.name)
                                .font(.title3)
                                .foregroundColor(AccessibilityColors.textPrimary)
                            
                            Spacer()
                            
                            if viewModel.selectedChild?.id == child.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(hex: child.themeColor) ?? .blue)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.medium)
                                .fill(Color(.systemBackground))
                                .appShadow(AppShadow.card)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityIdentifier("child_button")
                }
            }
            .padding(.horizontal, DeviceInfo.contentPadding)
        }
    }
    
    private var unpaidWarningBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .foregroundColor(AccessibilityColors.warningOrange)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("未支払いのお小遣いがあります")
                        .font(.subheadline)
                        .foregroundColor(AccessibilityColors.textPrimary)
                        .fontWeight(.semibold)

                    if let message = viewModel.unpaidWarningMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(AccessibilityColors.textSecondary)
                    }
                }

                Spacer()

                Text("\(viewModel.totalUnpaidAmount)コイン")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AccessibilityColors.warningOrange)
            }

            if !viewModel.unpaidPeriods.isEmpty {
                HStack {
                    Text("未支払い期間: ")
                        .font(.caption)
                        .foregroundColor(AccessibilityColors.textSecondary)

                    Text(viewModel.unpaidPeriods.map { $0.monthYearString }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(AccessibilityColors.textPrimary)
                        .fontWeight(.medium)

                    Spacer()
                }
            }
            
            HStack {
                Spacer()

                if let targetChild = viewModel.selectedChild
                    ?? viewModel.unpaidPeriods.first.flatMap({ period in
                        viewModel.children.first { $0.id == period.childId }
                    }) {
                    let initialMonth = (viewModel.unpaidPeriods.first { $0.childId == targetChild.id }?.date) ?? Date()
                    NavigationLink(destination: monthlySummaryView(for: targetChild, initialMonth: initialMonth)) {
                        HStack(spacing: 6) {
                            Text("お小遣いを確認")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Image(systemName: "arrow.right").font(.caption)
                        }
                        .foregroundColor(AccessibilityColors.warningOrange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: AppRadius.small)
                                .fill(AccessibilityColors.warningOrange.opacity(0.15))
                        )
                    }
                    .accessibilityIdentifier("home_unpaid_summary_link")
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(Color(.systemBackground))
                .appShadow(AppShadow.cardElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(AccessibilityColors.warningOrange.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, DeviceInfo.contentPadding)
    }
}


