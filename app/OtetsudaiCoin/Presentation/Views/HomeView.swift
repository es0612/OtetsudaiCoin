import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    @State private var showingMonthlyHistory = false
    @State private var showingPaymentConfirmation = false
    
    // ViewModelのキャッシュ化
    @State private var monthlyHistoryViewModel: MonthlyHistoryViewModel?
    
    var body: some View {
        NavigationView {
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
                        VStack(spacing: 20) {
                            // 未支払い警告バナー
                            if viewModel.showUnpaidWarning {
                                unpaidWarningBanner
                            }
                            
                            if let selectedChild = viewModel.selectedChild {
                                childStatsView(for: selectedChild)
                            }
                            
                            childrenListView
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("おてつだいコイン")
            .onAppear {
                viewModel.loadChildren()
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
        .sheet(isPresented: $showingMonthlyHistory) {
            if let monthlyViewModel = monthlyHistoryViewModel {
                MonthlyHistoryView(viewModel: monthlyViewModel)
            }
        }
        .alert("支払い確認", isPresented: $showingPaymentConfirmation) {
            Button("キャンセル", role: .cancel) { }
            Button("支払う") {
                viewModel.payMonthlyAllowance()
            }
        } message: {
            if viewModel.isCurrentMonthPaid {
                Text("追加分のお小遣いを支払いますか？\n金額: \(viewModel.currentMonthEarnings - viewModel.monthlyAllowance)コイン")
            } else {
                Text("今月のお小遣いを支払いますか？\n金額: \(viewModel.currentMonthEarnings)コイン")
            }
        }
    }
    
    private func childStatsView(for child: Child) -> some View {
        VStack(spacing: 20) {
            // 子供のアバター
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
                
                HStack(spacing: 8) {
                    Text("\(child.name)ちゃんの記録")
                        .appFont(.sectionHeader)
                        .foregroundColor(AccessibilityColors.textPrimary)
                    
                    NavigationLink(destination: getHelpHistoryView(for: child)) {
                        Image(systemName: "list.clipboard")
                            .font(.title3)
                            .foregroundColor(Color(hex: child.themeColor) ?? .blue)
                    }
                    
                    Button(action: {
                        // 非同期でViewModel準備を実行
                        DispatchQueue.main.async {
                            prepareMonthlyHistoryViewModel(for: child)
                            showingMonthlyHistory = true
                        }
                    }) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.title3)
                            .foregroundColor(Color(hex: child.themeColor) ?? .blue)
                    }
                }
            }
            
            // 統計カード
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                StatisticsCard(
                    icon: "star.fill",
                    title: "今月の実績",
                    value: "\(viewModel.totalRecordsThisMonth)",
                    subtitle: "回がんばった！",
                    color: Color(hex: child.themeColor) ?? .blue,
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
                
                StatisticsCard(
                    icon: "dollarsign.circle.fill",
                    title: "今月のコイン",
                    value: "\(viewModel.monthlyAllowance)",
                    subtitle: "コイン獲得！",
                    color: .green,
                    style: .large
                )
                
                StatisticsCard(
                    icon: "calendar",
                    title: "今月のお手伝い",
                    value: "\(viewModel.totalRecordsThisMonth)",
                    subtitle: "回",
                    color: .purple,
                    style: .large
                )
            }
            
            // お小遣い支払いセクション
            VStack(spacing: 16) {
                Divider()
                    .padding(.vertical, 8)
                
                if viewModel.isCurrentMonthPaid {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AccessibilityColors.successGreen)
                            Text("今月のお小遣いは支払い済みです")
                                .foregroundColor(AccessibilityColors.textSecondary)
                            Spacer()
                            Text("\(viewModel.monthlyAllowance)コイン")
                                .font(.caption)
                                .foregroundColor(AccessibilityColors.successGreen)
                                .fontWeight(.medium)
                        }
                        
                        if viewModel.monthlyAllowance < viewModel.currentMonthEarnings {
                            VStack(spacing: 4) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(AccessibilityColors.warningOrange)
                                        .font(.caption)
                                    Text("支払い後の追加獲得分")
                                        .font(.caption)
                                        .foregroundColor(AccessibilityColors.warningOrange)
                                    Spacer()
                                    Text("\(viewModel.currentMonthEarnings - viewModel.monthlyAllowance)コイン")
                                        .font(.caption)
                                        .foregroundColor(AccessibilityColors.warningOrange)
                                        .fontWeight(.medium)
                                }
                                
                                Button(action: {
                                    showingPaymentConfirmation = true
                                }) {
                                    Text("追加分を支払う")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.orange)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("今月のお小遣い")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Button(action: {
                            showingPaymentConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "creditcard.fill")
                                Text("今月のお小遣いを支払う")
                                Spacer()
                                Text("\(viewModel.monthlyAllowance)コイン")
                                    .fontWeight(.bold)
                            }
                        }
                        .primaryGradientButton()
                        .disabled(viewModel.monthlyAllowance == 0)
                        
                        if viewModel.monthlyAllowance == 0 {
                            Text("今月のお手伝い記録がありません")
                                .font(.caption)
                                .foregroundColor(AccessibilityColors.textSecondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal)
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
    
    private func prepareMonthlyHistoryViewModel(for child: Child) {
        let context = PersistenceController.shared.container.viewContext
        let repositoryFactory = RepositoryFactory(context: context)
        let viewModelFactory = ViewModelFactory(repositoryFactory: repositoryFactory)
        monthlyHistoryViewModel = viewModelFactory.createMonthlyHistoryViewModel()
        monthlyHistoryViewModel?.selectChild(child)
    }
    
    private var childrenListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("お子様を選択")
                .appFont(.sectionHeader)
                .padding(.horizontal)
            
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
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityIdentifier("child_button")
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var unpaidWarningBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.white)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("未支払いのお小遣いがあります")
                        .font(.headline)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                    
                    if let message = viewModel.unpaidWarningMessage {
                        Text(message)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                
                Spacer()
                
                Text("\(viewModel.totalUnpaidAmount)コイン")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            if !viewModel.unpaidPeriods.isEmpty {
                HStack {
                    Text("未支払い期間: ")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text(viewModel.unpaidPeriods.map { $0.monthYearString }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
            }
            
            HStack {
                Spacer()
                
                Button(action: {
                    if let selectedChild = viewModel.selectedChild {
                        prepareMonthlyHistoryViewModel(for: selectedChild)
                        showingMonthlyHistory = true
                    }
                }) {
                    HStack(spacing: 6) {
                        Text("支払い履歴を確認")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.2))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.red, Color.red.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .shadow(color: Color.red.opacity(0.3), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }
}


