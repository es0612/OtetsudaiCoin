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
                                    .cornerRadius(AppRadius.small)
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
                                    .cornerRadius(AppRadius.small)
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

                    RecordButtonBar(viewModel: viewModel)
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
        RecordCalendarView(
            displayedMonth: viewModel.displayedMonth,
            selectedDate: viewModel.recordedDate,
            recordedDays: viewModel.recordedDays,
            today: Date(),
            canGoNextMonth: viewModel.canGoToNextMonth(),
            onSelectDay: { viewModel.selectDay($0) },
            onPrevMonth: { viewModel.goToPreviousMonth() },
            onNextMonth: { viewModel.goToNextMonth() }
        )
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
            .cornerRadius(AppRadius.medium)
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
                    .cornerRadius(AppRadius.medium)
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
                            existingCount: viewModel.existingRecordCount(for: task.id),
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

}

