import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    @State private var showingMonthlyHistory = false
    @State private var showingPaymentConfirmation = false
    
    // ViewModelのキャッシュ化
    @State private var helpHistoryViewModel: HelpHistoryViewModel?
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
                        prepareMonthlyHistoryViewModel(for: child)
                        showingMonthlyHistory = true
                    }) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.title3)
                            .foregroundColor(Color(hex: child.themeColor) ?? .blue)
                    }
                }
            }
            
            // 統計カード
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                StatsCard(
                    icon: "star.fill",
                    title: "今月の実績",
                    value: "\(viewModel.totalRecordsThisMonth)",
                    subtitle: "回がんばった！",
                    color: Color(hex: child.themeColor) ?? .blue
                )
                
                StatsCard(
                    icon: "flame.fill",
                    title: "連続記録",
                    value: "\(viewModel.consecutiveDays)",
                    subtitle: "日連続！",
                    color: .orange
                )
                
                StatsCard(
                    icon: "dollarsign.circle.fill",
                    title: "今月のコイン",
                    value: "\(viewModel.monthlyAllowance)",
                    subtitle: "コイン獲得！",
                    color: .green
                )
                
                StatsCard(
                    icon: "calendar",
                    title: "今月のお手伝い",
                    value: "\(viewModel.totalRecordsThisMonth)",
                    subtitle: "回",
                    color: .purple
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
        // ViewModelをキャッシュして再利用
        if helpHistoryViewModel == nil {
            let context = PersistenceController.shared.container.viewContext
            let helpRecordRepository = CoreDataHelpRecordRepository(context: context)
            let helpTaskRepository = CoreDataHelpTaskRepository(context: context)
            let childRepository = CoreDataChildRepository(context: context)
            
            helpHistoryViewModel = HelpHistoryViewModel(
                helpRecordRepository: helpRecordRepository,
                helpTaskRepository: helpTaskRepository,
                childRepository: childRepository
            )
        }
        
        helpHistoryViewModel?.selectChild(child)
        
        return Group {
            if let historyViewModel = helpHistoryViewModel {
                HelpHistoryView(viewModel: historyViewModel)
            } else {
                VStack {
                    ProgressView()
                    Text("読み込み中...")
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
            }
        }
    }
    
    private func prepareMonthlyHistoryViewModel(for child: Child) {
        // ViewModelをキャッシュして再利用
        if monthlyHistoryViewModel == nil {
            let context = PersistenceController.shared.container.viewContext
            let helpRecordRepository = CoreDataHelpRecordRepository(context: context)
            let allowancePaymentRepository = InMemoryAllowancePaymentRepository.shared
            
            monthlyHistoryViewModel = MonthlyHistoryViewModel(
                helpRecordRepository: helpRecordRepository,
                allowancePaymentRepository: allowancePaymentRepository,
                helpTaskRepository: CoreDataHelpTaskRepository(context: context),
                allowanceCalculator: AllowanceCalculator()
            )
            
            monthlyHistoryViewModel?.selectChild(child)
        } else {
            monthlyHistoryViewModel?.selectChild(child)
        }
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
}

struct StatsCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .appFont(.captionText)
                .foregroundColor(.secondary)
            
            Text(value)
                .appFont(.primaryInfo)
                .foregroundColor(color)
            
            Text(subtitle)
                .appFont(.captionText)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

