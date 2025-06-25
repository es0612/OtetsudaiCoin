import SwiftUI

struct HelpHistoryView: View {
    @ObservedObject var viewModel: HelpHistoryViewModel
    @State private var showingDeleteAlert = false
    @State private var recordToDelete: HelpRecordWithDetails?
    @State private var showingEditView = false
    @State private var recordToEdit: HelpRecordWithDetails?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // フィルタセクション
                filterSection
                
                // メインコンテンツ
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.helpRecords.isEmpty {
                    emptyStateView
                } else {
                    historyListView
                }
            }
            .navigationTitle("お手伝い履歴")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("削除確認", isPresented: $showingDeleteAlert) {
            Button("削除", role: .destructive) {
                if let record = recordToDelete {
                    viewModel.deleteRecord(record.helpRecord.id)
                }
                recordToDelete = nil
            }
            Button("キャンセル", role: .cancel) {
                recordToDelete = nil
            }
        } message: {
            if let record = recordToDelete {
                Text("「\(record.task.name)」の記録を削除しますか？この操作は取り消せません。")
            }
        }
        .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearErrorMessage()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showingEditView) {
            if let record = recordToEdit {
                createEditView(for: record)
            }
        }
    }
    
    private var filterSection: some View {
        VStack(spacing: 16) {
            // 期間選択
            Picker("期間", selection: $viewModel.selectedPeriod) {
                ForEach(HistoryPeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: viewModel.selectedPeriod) { _, newPeriod in
                viewModel.selectPeriod(newPeriod)
            }
            
            // 統計サマリー
            if !viewModel.helpRecords.isEmpty {
                statisticsSummary
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var statisticsSummary: some View {
        HStack(spacing: 20) {
            StatisticCard(
                icon: "checkmark.circle.fill",
                title: "実績",
                value: "\(viewModel.helpRecords.count)",
                subtitle: "回",
                color: .blue
            )
            
            StatisticCard(
                icon: "star.fill",
                title: "獲得コイン",
                value: "\(totalEarnedCoins)",
                subtitle: "コイン",
                color: .orange
            )
            
            StatisticCard(
                icon: "trophy.fill",
                title: "平均コイン",
                value: "\(averageCoinsPerRecord)",
                subtitle: "コイン/回",
                color: .purple
            )
        }
    }
    
    private var totalEarnedCoins: Int {
        viewModel.helpRecords.reduce(0) { $0 + $1.earnedCoins }
    }
    
    private var averageCoinsPerRecord: Int {
        guard !viewModel.helpRecords.isEmpty else { return 0 }
        return totalEarnedCoins / viewModel.helpRecords.count
    }
    
    private var averageCoinsPerDay: Int {
        guard !viewModel.helpRecords.isEmpty else { return 0 }
        
        // 記録のある日数を計算
        let calendar = Calendar.current
        let uniqueDays = Set(viewModel.helpRecords.map { record in
            calendar.startOfDay(for: record.helpRecord.recordedAt)
        })
        
        guard !uniqueDays.isEmpty else { return 0 }
        return totalEarnedCoins / uniqueDays.count
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("履歴を読み込み中...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("お手伝い記録がありません")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("選択した期間にお手伝いの記録がありません。\n記録タブから新しいお手伝いを記録してみましょう！")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var historyListView: some View {
        List {
            ForEach(groupedRecords, id: \.key) { group in
                Section(header: Text(group.key).font(.headline)) {
                    ForEach(group.value, id: \.helpRecord.id) { record in
                        HelpRecordRow(
                            record: record,
                            onEdit: {
                                recordToEdit = record
                                showingEditView = true
                            },
                            onDelete: {
                                recordToDelete = record
                                showingDeleteAlert = true
                            }
                        )
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private var groupedRecords: [(key: String, value: [HelpRecordWithDetails])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 (E)"
        formatter.locale = Locale(identifier: "ja_JP")
        
        let grouped = Dictionary(grouping: viewModel.helpRecords) { record in
            formatter.string(from: record.helpRecord.recordedAt)
        }
        
        return grouped.sorted { lhs, rhs in
            let lhsDate = viewModel.helpRecords.first { record in
                formatter.string(from: record.helpRecord.recordedAt) == lhs.key
            }?.helpRecord.recordedAt ?? Date.distantPast
            
            let rhsDate = viewModel.helpRecords.first { record in
                formatter.string(from: record.helpRecord.recordedAt) == rhs.key
            }?.helpRecord.recordedAt ?? Date.distantPast
            
            return lhsDate > rhsDate
        }
    }
    
    private func createEditView(for record: HelpRecordWithDetails) -> some View {
        let context = PersistenceController.shared.container.viewContext
        let helpRecordRepository = CoreDataHelpRecordRepository(context: context)
        let helpTaskRepository = CoreDataHelpTaskRepository(context: context)
        
        let editViewModel = HelpRecordEditViewModel(
            helpRecord: record.helpRecord,
            child: record.child,
            helpRecordRepository: helpRecordRepository,
            helpTaskRepository: helpTaskRepository
        )
        
        return HelpRecordEditView(viewModel: editViewModel)
    }
}

struct HelpRecordRow: View {
    let record: HelpRecordWithDetails
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // タスクアイコン
            Circle()
                .fill(LinearGradient(
                    colors: [Color(hex: record.child.themeColor) ?? .blue, 
                            (Color(hex: record.child.themeColor) ?? .blue).opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "hands.sparkles")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                )
            
            // タスク情報
            VStack(alignment: .leading, spacing: 4) {
                Text(record.task.name)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(timeString(from: record.helpRecord.recordedAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("+\(record.earnedCoins)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            // アクションボタン
            HStack(spacing: 12) {
                // 編集ボタン
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                
                // 削除ボタン
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }
}

struct StatisticCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let helpRecordRepository = CoreDataHelpRecordRepository(context: context)
    let helpTaskRepository = CoreDataHelpTaskRepository(context: context)
    let childRepository = CoreDataChildRepository(context: context)
    
    let viewModel = HelpHistoryViewModel(
        helpRecordRepository: helpRecordRepository,
        helpTaskRepository: helpTaskRepository,
        childRepository: childRepository
    )
    
    HelpHistoryView(viewModel: viewModel)
}