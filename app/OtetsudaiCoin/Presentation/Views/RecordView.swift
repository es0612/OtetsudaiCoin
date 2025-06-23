import SwiftUI

struct RecordView: View {
    @ObservedObject var viewModel: RecordViewModel
    @State private var showCoinAnimation = false
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack(spacing: 20) {
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
                            viewModel.loadTasks()
                        }
                        .primaryGradientButton()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 20) {
                        if let successMessage = viewModel.successMessage {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(successMessage)
                                    .foregroundColor(.green)
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        childSelectionView
                        
                        taskListView
                        
                        recordButtonView
                        
                        Spacer()
                    }
                    .padding()
                    }
                }
                .navigationTitle("お手伝い記録")
                .onAppear {
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
                    coinValue: 100, // デフォルトのコイン価値
                    themeColor: selectedChild.themeColor
                )
            }
        }
        .onReceive(viewModel.$successMessage) { successMessage in
            if successMessage != nil && !showCoinAnimation {
                showCoinAnimation = true
            }
        }
    }
    
    private var childSelectionView: some View {
        VStack(alignment: .leading) {
            Text("お手伝いする人を選んでください")
                .font(.headline)
                .padding(.horizontal)
            
            if viewModel.availableChildren.isEmpty {
                Text("お子様が登録されていません")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.availableChildren, id: \.id) { child in
                            Button(action: {
                                viewModel.selectChild(child)
                            }) {
                                VStack {
                                    Circle()
                                        .fill(Color(hex: child.themeColor) ?? .blue)
                                        .frame(width: 60, height: 60)
                                        .overlay(
                                            Text(String(child.name.prefix(1)))
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(viewModel.selectedChild?.id == child.id ? Color.blue : Color.clear, lineWidth: 3)
                                        )
                                    
                                    Text(child.name)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                            }
                            .accessibilityIdentifier("child_button")
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 100)
            }
        }
    }
    
    private var taskListView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("今日のお手伝い")
                .font(.headline)
                .padding(.horizontal)
            
            if viewModel.availableTasks.isEmpty {
                Text("利用可能なお手伝いタスクがありません")
                    .foregroundColor(.secondary)
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

struct TaskCardView: View {
    let task: HelpTask
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? .blue : .gray.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "hands.sparkles")
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : .blue)
                }
                
                Text(task.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                } else {
                    Spacer()
                        .frame(height: 20)
                }
            }
            .padding()
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

