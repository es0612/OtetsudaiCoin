import SwiftUI

struct RecordView: View {
    @Bindable var viewModel: RecordViewModel
    @State private var showCoinAnimation = false
    
    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    // メインコンテンツ
                    ScrollView {
                        VStack(spacing: 16) {
                            StateBasedContent(
                                viewState: viewModel.viewState,
                                onRetry: { viewModel.loadTasks() },
                            ) {
                                VStack(spacing: 16) {
                                    if let successMessage = viewModel.viewState.successMessage {
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
                                    
                                    childSelectionView
                                    
                                    taskListView
                                }
                                .padding()
                                .padding(.bottom, 80) // 固定ボタン分のスペース確保
                            }
                        }
                    }
                    
                    // 画面下部固定の記録ボタン
                    VStack(spacing: 0) {
                        Divider()
                        
                        recordButtonView
                            .padding()
                            .background(.ultraThinMaterial)
                    }
                }
                .navigationTitle("お手伝い記録")
                .onAppear {
                    // エラーメッセージのみクリアし、成功メッセージは保持
                    viewModel.clearErrorMessage()
                    viewModel.loadData()
                }
            }
            
            // コインアニメーションオーバーレイ
            if showCoinAnimation, let selectedChild = viewModel.selectedChild {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showCoinAnimation = false
                    }
                
                CoinAnimationView(
                    isVisible: $showCoinAnimation,
                    coinValue: viewModel.lastRecordedCoinValue,
                    themeColor: selectedChild.themeColor
                )
            }
        }
        .onChange(of: viewModel.viewState.successMessage) { _, successMessage in
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
    
    private var childSelectionView: some View {
        VStack(alignment: .leading) {
            childSelectionHeader
            childSelectionContent
        }
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
                            isSelected: viewModel.selectedTask?.id == task.id,
                            onTap: {
                                viewModel.selectTask(task)
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
            if let selectedChild = viewModel.selectedChild, let selectedTask = viewModel.selectedTask {
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
                viewModel.recordHelp()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("記録する")
                }
            }
            .successGradientButton(isDisabled: viewModel.selectedChild == nil || viewModel.selectedTask == nil)
            .disabled(viewModel.selectedChild == nil || viewModel.selectedTask == nil)
            .accessibilityIdentifier("record_button")
        }
    }
}

struct TaskCardView: View {
    let task: HelpTask
    let isSelected: Bool
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
            if isSelected {
                selectedIndicator
            } else {
                unselectedIndicator
            }
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

