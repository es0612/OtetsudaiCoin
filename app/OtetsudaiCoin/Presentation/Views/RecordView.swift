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
                        .buttonStyle(.borderedProminent)
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
        VStack(alignment: .leading) {
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
            } else {
                List(viewModel.availableTasks, id: \.id) { task in
                    Button(action: {
                        viewModel.selectTask(task)
                    }) {
                        HStack {
                            Image(systemName: "hands.sparkles")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            Text(task.name)
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if viewModel.selectedTask?.id == task.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityIdentifier("task_button")
                }
                .listStyle(PlainListStyle())
                .frame(maxHeight: 200)
            }
        }
    }
    
    private var recordButtonView: some View {
        Button(action: {
            viewModel.recordHelp()
        }) {
            Text("記録する")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    (viewModel.selectedChild != nil && viewModel.selectedTask != nil) ? 
                    Color.blue : Color.gray
                )
                .cornerRadius(12)
        }
        .disabled(viewModel.selectedChild == nil || viewModel.selectedTask == nil)
        .accessibilityIdentifier("record_button")
    }
}

