import SwiftUI

struct HomeView: View {
    @Bindable var viewModel: HomeViewModel
    @State private var showingMonthlyHistory = false
    @State private var showingPaymentConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text(errorMessage)
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
                            .foregroundColor(.gray)
                        Text("お子様を登録してください")
                            .font(.title2)
                            .foregroundColor(.gray)
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
            if let selectedChild = viewModel.selectedChild {
                createMonthlyHistoryView(for: selectedChild)
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
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                    .shadow(color: (Color(hex: child.themeColor) ?? .blue).opacity(0.3), radius: 8, x: 0, y: 4)
                
                HStack(spacing: 8) {
                    Text("\(child.name)ちゃんの記録")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    NavigationLink(destination: createHelpHistoryView(for: child)) {
                        Image(systemName: "list.clipboard")
                            .font(.title3)
                            .foregroundColor(Color(hex: child.themeColor) ?? .blue)
                    }
                    
                    Button(action: {
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
                                .foregroundColor(.green)
                            Text("今月のお小遣いは支払い済みです")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(viewModel.monthlyAllowance)コイン")
                                .font(.caption)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }
                        
                        if viewModel.monthlyAllowance < viewModel.currentMonthEarnings {
                            VStack(spacing: 4) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text("支払い後の追加獲得分")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Spacer()
                                    Text("\(viewModel.currentMonthEarnings - viewModel.monthlyAllowance)コイン")
                                        .font(.caption)
                                        .foregroundColor(.orange)
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
                                .foregroundColor(.secondary)
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
    
    private func createHelpHistoryView(for child: Child) -> some View {
        let context = PersistenceController.shared.container.viewContext
        let helpRecordRepository = CoreDataHelpRecordRepository(context: context)
        let helpTaskRepository = CoreDataHelpTaskRepository(context: context)
        let childRepository = CoreDataChildRepository(context: context)
        
        let historyViewModel = HelpHistoryViewModel(
            helpRecordRepository: helpRecordRepository,
            helpTaskRepository: helpTaskRepository,
            childRepository: childRepository
        )
        
        historyViewModel.selectChild(child)
        
        return HelpHistoryView(viewModel: historyViewModel)
    }
    
    private func createMonthlyHistoryView(for child: Child) -> some View {
        let context = PersistenceController.shared.container.viewContext
        let helpRecordRepository = CoreDataHelpRecordRepository(context: context)
        let allowancePaymentRepository = InMemoryAllowancePaymentRepository.shared
        
        let monthlyHistoryViewModel = MonthlyHistoryViewModel(
            helpRecordRepository: helpRecordRepository,
            allowancePaymentRepository: allowancePaymentRepository,
            helpTaskRepository: CoreDataHelpTaskRepository(context: context),
            allowanceCalculator: AllowanceCalculator()
        )
        
        monthlyHistoryViewModel.selectChild(child)
        
        return MonthlyHistoryView(viewModel: monthlyHistoryViewModel)
    }
    
    private var childrenListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("お子様を選択")
                .font(.headline)
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
                                .foregroundColor(.primary)
                            
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
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
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

extension Color {
    init?(hex: String) {
        guard hex.hasPrefix("#"), hex.count == 7 else { return nil }
        
        let hexColor = String(hex.dropFirst())
        guard let value = UInt64(hexColor, radix: 16) else { return nil }
        
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        
        self.init(red: red, green: green, blue: blue)
    }
}