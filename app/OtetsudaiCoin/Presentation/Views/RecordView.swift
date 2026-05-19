import SwiftUI

struct RecordView: View {
    @Bindable var viewModel: RecordViewModel
    @State private var showCoinAnimation = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // メインコンテンツ
                ScrollView {
                    VStack(spacing: 16) {
                        bulkModeToggleRow
                        StateBasedContent(
                            isLoading: viewModel.isLoading,
                            errorMessage: viewModel.errorMessage,
                            onRetry: { viewModel.loadTasks() }
                        ) {
                            VStack(spacing: 16) {
                                if let successMessage = viewModel.successMessage {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AccessibilityColors.successGreen)
                                        Text(successMessage)
                                            .appFont(.buttonText)
                                            .foregroundColor(AccessibilityColors.successGreen)
                                    }
                                    .padding()
                                    .background(AccessibilityColors.successGreenLight)
                                    .cornerRadius(8)
                                }

                                if let warningMessage = viewModel.warningMessage {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text(warningMessage)
                                            .appFont(.buttonText)
                                            .foregroundColor(.orange)
                                    }
                                    .padding()
                                    .background(Color.orange.opacity(0.15))
                                    .cornerRadius(8)
                                }

                                childSelectionView

                                dateSection

                                taskListView
                            }
                            .padding()
                            .padding(.bottom, 80) // 固定ボタン分のスペース確保
                        }

                        // Issue #49: スクロール末端に AdMob バナーを配置。
                        // StateBasedContent の外側に置くことで loading/error 中も表示。
                        BannerAdView()
                            .frame(height: 50)
                            .padding(.bottom, 8)
                    }
                }

                // 画面下部固定の記録ボタン
                VStack(spacing: 0) {
                    Divider()

                    recordButtonView
                        .padding()
                        .background(Color(.systemBackground).opacity(0.95))
                }
            }
            .navigationTitle("お手伝い記録")
            .onAppear {
                // エラーメッセージのみクリアし、成功メッセージは保持
                viewModel.clearErrorMessage()
                viewModel.loadData()
            }
        }
        .overlay {
            if showCoinAnimation {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showCoinAnimation = false
                    }
            }
        }
        .overlay {
            if showCoinAnimation, let selectedChild = viewModel.selectedChild {
                CoinAnimationView(
                    isVisible: $showCoinAnimation,
                    coinValue: viewModel.lastRecordedCoinValue,
                    themeColor: selectedChild.themeColor
                )
            }
        }
        .onChange(of: viewModel.successMessage) { _, successMessage in
            if successMessage != nil && !showCoinAnimation {
                showCoinAnimation = true
            }
        }
        .onChange(of: showCoinAnimation) { _, isShowing in
            if !isShowing {
                // アニメーション終了時に成功メッセージをクリア
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    viewModel.clearMessages()
                }
            }
        }
    }
    
    private var bulkModeToggleRow: some View {
        Toggle(isOn: Binding(
            get: { viewModel.isBulkMode },
            set: { _ in viewModel.toggleBulkMode() }
        )) {
            Text("一括モード")
                .appFont(.sectionHeader)
        }
        .padding(.horizontal)
        .accessibilityIdentifier("bulk_mode_toggle")
    }

    private var childSelectionView: some View {
        VStack(alignment: .leading) {
            childSelectionHeader
            childSelectionContent
        }
    }

    private var dateSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .foregroundColor(.blue)
                .font(.title3)
            Text(String(localized: "記録日"))
                .appFont(.sectionHeader)
            Spacer()
            DatePicker(
                "",
                selection: $viewModel.recordedDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .accessibilityIdentifier("record_date_picker")
        }
        .padding(.horizontal)
    }
    
    private var childSelectionHeader: some View {
        Text("お手伝いする人を選んでください")
            .appFont(.sectionHeader)
            .padding(.horizontal)
    }
    
    private var childSelectionContent: some View {
        Group {
            if viewModel.availableChildren.isEmpty {
                emptyChildrenView
            } else {
                childrenScrollView
            }
        }
    }
    
    private var emptyChildrenView: some View {
        Text("お子様が登録されていません")
            .appFont(.secondaryInfo)
            .foregroundColor(AccessibilityColors.textSecondary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .center)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
    }
    
    private var childrenScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.availableChildren, id: \.id) { child in
                    ChildCardView(
                        child: child,
                        isSelected: viewModel.selectedChild?.id == child.id,
                        onTap: { viewModel.selectChild(child) }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var taskListView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("今日のお手伝い")
                .appFont(.sectionHeader)
                .padding(.horizontal)
            
            if viewModel.availableTasks.isEmpty {
                Text("利用可能なお手伝いタスクがありません")
                    .appFont(.secondaryInfo)
                    .foregroundColor(AccessibilityColors.textSecondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(viewModel.availableTasks, id: \.id) { task in
                        TaskCardView(
                            task: task,
                            isSelected: viewModel.isBulkMode
                                ? viewModel.selectedTaskIds.contains(task.id)
                                : viewModel.selectedTask?.id == task.id,
                            isBulkMode: viewModel.isBulkMode,
                            onTap: {
                                if viewModel.isBulkMode {
                                    if viewModel.selectedTaskIds.contains(task.id) {
                                        viewModel.selectedTaskIds.remove(task.id)
                                    } else {
                                        viewModel.selectedTaskIds.insert(task.id)
                                    }
                                } else {
                                    viewModel.selectTask(task)
                                }
                            }
                        )
                        .accessibilityIdentifier("task_button")
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var recordButtonView: some View {
        VStack(spacing: 8) {
            // 選択状態の表示
            if viewModel.isBulkMode {
                bulkSummaryView
            } else if let selectedChild = viewModel.selectedChild, let selectedTask = viewModel.selectedTask {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(selectedChild.name)さんの「\(selectedTask.name)」")
                        .appFont(.captionText)
                        .foregroundColor(.secondary)
                    Text("\(selectedTask.coinRate)コイン")
                        .appFont(.captionText)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
                .padding(.horizontal)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.orange)
                    Text("お手伝いする人とタスクを選んでください")
                        .appFont(.captionText)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }

            // 記録ボタン
            Button(action: {
                if viewModel.isBulkMode {
                    viewModel.recordBulkHelp()
                } else {
                    viewModel.recordHelp()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text(recordButtonLabel)
                }
            }
            .successGradientButton(isDisabled: recordButtonDisabled)
            .disabled(recordButtonDisabled)
            .accessibilityIdentifier("record_button")
        }
    }

    private var recordButtonLabel: String {
        if viewModel.isBulkMode {
            // 文字列補間で `String.LocalizationValue` を生成すると、xcstrings の plural variations が
            // count 値に応じて one / other 自動選択される。String(format:) は variations を bypass するため使わない。
            let count = viewModel.selectedTaskIds.count
            return String(localized: "\(count) 件をまとめて記録する")
        } else {
            return String(localized: "記録する")
        }
    }

    private var recordButtonDisabled: Bool {
        if viewModel.isBulkMode {
            return viewModel.selectedChild == nil || viewModel.selectedTaskIds.isEmpty
        } else {
            return viewModel.selectedChild == nil || viewModel.selectedTask == nil
        }
    }

    private var bulkSummaryView: some View {
        let count = viewModel.selectedTaskIds.count
        let tasksById = Dictionary(uniqueKeysWithValues: viewModel.availableTasks.map { ($0.id, $0) })
        let totalCoins = viewModel.selectedTaskIds.reduce(0) { acc, id in
            acc + (tasksById[id]?.coinRate ?? 0)
        }
        let format = String(localized: "選択中 %lld 件 / 計 %lld コイン")
        return HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(String(format: format, count, totalCoins))
                .appFont(.captionText)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}

struct TaskCardView: View {
    let task: HelpTask
    let isSelected: Bool
    var isBulkMode: Bool = false
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                taskIcon
                taskTitle
                coinInfo
                selectionIndicator
            }
            .padding()
            .frame(height: 140)
            .background(cardBackground)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private var taskIcon: some View {
        ZStack {
            Circle()
                .fill(isSelected ? .blue : .gray.opacity(0.2))
                .frame(width: 50, height: 50)
            
            Image(systemName: "hands.sparkles")
                .font(.title2)
                .foregroundColor(isSelected ? .white : .blue)
        }
    }
    
    private var taskTitle: some View {
        Text(task.name)
            .appFont(.cardTitle)
            .fontWeight(.medium)
            .multilineTextAlignment(.center)
            .foregroundColor(AccessibilityColors.textPrimary)
            .lineLimit(2)
    }
    
    private var coinInfo: some View {
        Text("\(task.coinRate)コイン")
            .appFont(.captionText)
            .fontWeight(.semibold)
            .foregroundColor(isSelected ? .blue : .secondary)
    }
    
    private var selectionIndicator: some View {
        Group {
            if isBulkMode {
                bulkSelectionIndicator
            } else if isSelected {
                selectedIndicator
            } else {
                unselectedIndicator
            }
        }
    }

    private var bulkSelectionIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .font(.title3)
                .foregroundColor(isSelected ? .blue : .gray.opacity(0.5))
            Text(isSelected ? "選択中" : "選択")
                .appFont(.captionText)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .blue : .gray.opacity(0.7))
        }
    }
    
    private var selectedIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(.blue)
            Text("選択中")
                .appFont(.captionText)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
        }
    }
    
    private var unselectedIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "circle")
                .font(.title3)
                .foregroundColor(.gray.opacity(0.5))
            Text("タップして選択")
                .appFont(.captionText)
                .foregroundColor(.gray.opacity(0.7))
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
    }
}

