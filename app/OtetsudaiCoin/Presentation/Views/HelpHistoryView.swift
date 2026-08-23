import SwiftUI

struct HelpHistoryView: View {
    @Bindable var viewModel: HelpHistoryViewModel
    @State private var showingDeleteAlert = false
    @State private var recordToDelete: HelpRecordWithDetails?
    @State private var recordToEdit: HelpRecordWithDetails?
    @State private var availableChildren: [Child] = []
    
    // 共有ファクトリー（Repository重複作成を防ぐ）
    private let sharedRepositoryFactory: RepositoryFactory
    private let sharedViewModelFactory: ViewModelFactory
    
    init(viewModel: HelpHistoryViewModel) {
        self.viewModel = viewModel
        let context = PersistenceController.shared.container.viewContext
        self.sharedRepositoryFactory = RepositoryFactory(context: context)
        self.sharedViewModelFactory = ViewModelFactory(repositoryFactory: sharedRepositoryFactory)
    }
    
    var body: some View {
        NavigationStack {
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
                Text("「\(record.task.displayName)」の記録を削除しますか？この操作は取り消せません。")
            }
        }
        .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearErrorMessage()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(item: $recordToEdit) { record in
            createEditView(for: record)
        }
        .onChange(of: viewModel.helpRecords.count) { oldCount, newCount in
            // 削除により件数が減った場合、編集シートを閉じる
            if newCount < oldCount && recordToEdit != nil {
                recordToEdit = nil
            }
        }
        .task {
            // #32: 初期ロードを View 側の `.task` に統一（ViewModel init からの auto-Task を廃止）
            loadAvailableChildren()
            await viewModel.loadInitialData()
        }
    }
    
    private var filterSection: some View {
        VStack(spacing: 16) {
            // 子供選択
            if availableChildren.count > 1 {
                childSelectionView
            }
            
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
            StatisticsCard(
                icon: "checkmark.circle.fill",
                title: "実績",
                value: "\(viewModel.helpRecords.count)",
                subtitle: "回",
                color: .blue,
                style: .compact
            )
            
            StatisticsCard(
                icon: "star.fill",
                title: "獲得コイン",
                value: "\(totalEarnedCoins)",
                subtitle: "コイン",
                color: .orange,
                style: .compact
            )
            
            StatisticsCard(
                icon: "trophy.fill",
                title: "平均コイン",
                value: "\(averageCoinsPerRecord)",
                subtitle: "コイン/回",
                color: .purple,
                style: .compact
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

            // #32: 「全データが無い」ではなく「今のフィルタには無い」ことを明示
            Text("「\(viewModel.selectedPeriod.rawValue)」の記録はありません")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text("期間を変えて過去の記録を探すか、記録タブから新しいお手伝いを記録してみましょう！")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if viewModel.selectedPeriod != .all {
                Button {
                    viewModel.selectedPeriod = .all
                    viewModel.selectPeriod(.all)
                } label: {
                    Text("全期間で表示する")
                        .font(.body)
                        .fontWeight(.semibold)
                }
                .primaryButton()
                .padding(.top, 8)
            }
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
        // formatter 生成 (ICU 初期化) は安くないため、旧実装同様に 1 インスタンスを
        // grouping / sort lookup で使い回す (sort lookup は O(n²) 回呼ばれる)。
        let formatter = Self.makeDayGroupFormatter(locale: Locale.current)

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

    /// 履歴の日付グループ見出し用の locale 対応 formatter を生成する (#155 コメント報告の i18n 漏れ対応)。
    ///
    /// 旧実装は `dateFormat = "M月d日 (E)"` + ja_JP 固定で、en ロケールでも日本語表記が出ていた。
    /// `MMMEd` テンプレートは ja で「7月15日(水)」(現行「7月15日 (水)」とほぼ同一、括弧前スペースのみ差)、
    /// en で「Wed, Jul 15」になる。
    static func makeDayGroupFormatter(locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMMEd")
        return formatter
    }

    /// `makeDayGroupFormatter` の薄い wrapper。単発フォーマット / テスト用。
    /// `groupedRecords` のようなループ内では formatter を 1 度だけ作って使い回すこと。
    static func dayGroupLabel(from date: Date, locale: Locale) -> String {
        makeDayGroupFormatter(locale: locale).string(from: date)
    }

    /// 記録時刻 formatter の locale 別 cache (#201)。
    /// 旧実装は呼び出し (= HelpRecordRow の行 render) ごとに DateFormatter を生成しており、
    /// 長い履歴リストのスクロールで全可視行分の生成+設定コストが発生していた。
    /// View body (= MainActor) からしか呼ばれないため @MainActor で隔離し、
    /// 素の static var の data race を避ける。
    @MainActor
    private static var timeFormatterCache: [String: DateFormatter] = [:]

    /// locale に対応する時刻 formatter を返す (cache 済みなら再利用)。
    @MainActor
    static func timeFormatter(locale: Locale) -> DateFormatter {
        if let cached = timeFormatterCache[locale.identifier] {
            return cached
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.locale = locale
        timeFormatterCache[locale.identifier] = formatter
        return formatter
    }

    /// 記録時刻を locale に応じて生成する (#155 コメント報告の i18n 漏れ対応)。
    ///
    /// 旧実装は `HelpRecordRow` 内の private func で ja_JP 固定になっており、
    /// en ロケールでも 24 時間表記が強制されていた。`.short` スタイルは
    /// ja で「9:05」(現行と同一)、en で「9:05 AM」になる。
    @MainActor
    static func timeString(from date: Date, locale: Locale) -> String {
        timeFormatter(locale: locale).string(from: date)
    }
    
    private func createEditView(for record: HelpRecordWithDetails) -> some View {
        let editViewModel = sharedViewModelFactory.createHelpRecordEditViewModel(
            helpRecord: record.helpRecord,
            child: record.child
        )
        
        return HelpRecordEditView(viewModel: editViewModel)
    }
    
    private var childSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("お手伝いした人")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Picker("子供選択", selection: Binding<UUID?>(
                get: { viewModel.selectedChild?.id },
                set: { selectedId in
                    if let id = selectedId,
                       let child = availableChildren.first(where: { $0.id == id }) {
                        viewModel.selectChild(child)
                    }
                }
            )) {
                ForEach(availableChildren, id: \.id) { child in
                    Text(child.name).tag(child.id as UUID?)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    private func loadAvailableChildren() {
        Task {
            do {
                let childRepository = sharedRepositoryFactory.createChildRepository()
                let children = try await childRepository.findAll()
                
                await MainActor.run {
                    self.availableChildren = children
                }
            } catch {
                DebugLogger.error("Failed to load children: \(error.localizedDescription)")
            }
        }
    }
}

struct HelpRecordRow: View {
    let record: HelpRecordWithDetails
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // タスクアイコン
            // #177 項目5: displayIcon 絵文字 (#148 のカードデザイン展開)。
            // テーマカラーグラデはリング状に残して子ども識別を保ちつつ、内側に適応色
            // ディスクを敷いて絵文字のコントラストを担保する (テーマ色 x 絵文字色の
            // 組み合わせ次第で視認性が無制限に落ちるのを防ぐ)。
            // ZStack + 非拘束 Text は TaskCardView と同じパターンで、AX サイズの
            // Dynamic Type でも絵文字が truncate せず overflow に留まる。
            // 絵文字は装飾。行の意味は displayName の Text が担うため VoiceOver から隠す (#84 パターン)
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: record.child.themeColor) ?? .blue,
                                (Color(hex: record.child.themeColor) ?? .blue).opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 44)
                Circle()
                    .fill(AccessibilityColors.systemBackgroundSecondary)
                    .frame(width: 34, height: 34)
                Text(record.task.displayIcon)
                    .font(.title3)
                    .accessibilityHidden(true)
            }
            
            // タスク情報
            VStack(alignment: .leading, spacing: 4) {
                Text(record.task.displayName)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(HelpHistoryView.timeString(from: record.helpRecord.recordedAt, locale: Locale.current))
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
            // #151: 各ボタンが 44pt 幅 (アイコン 16pt + 左右 14pt ずつの余白) を
            // 持つようになったため、ボタン間の 12pt は視覚的に不要。4pt へ詰めて
            // タスク名側の横幅を戻す (アイコン間の実距離は 32pt 確保される)。
            HStack(spacing: 4) {
                // 編集ボタン
                // #151: アイコン実寸 (約 16pt) がそのままタップ領域だったため、
                // HIG の最小 44×44pt まで広げる。contentShape で frame 全体を
                // 当たり判定にする (frame だけではアイコンの形のまま)。
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                        .foregroundColor(AccessibilityColors.brandPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())

                // 削除ボタン
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
    }
    
}


#Preview {
    @Previewable @State var previewViewModel: HelpHistoryViewModel?
    
    Group {
        if let viewModel = previewViewModel {
            HelpHistoryView(viewModel: viewModel)
        } else {
            Text("Loading...")
        }
    }
    .task {
        await MainActor.run {
            let context = PersistenceController.preview.container.viewContext
            let helpRecordRepository = CoreDataHelpRecordRepository(context: context)
            let helpTaskRepository = CoreDataHelpTaskRepository(context: context)
            let childRepository = CoreDataChildRepository(context: context)
            
            previewViewModel = HelpHistoryViewModel(
                helpRecordRepository: helpRecordRepository,
                helpTaskRepository: helpTaskRepository,
                childRepository: childRepository
            )
        }
    }
}