import SwiftUI

struct RecordTutorialView: View {
    @ObservedObject var tutorialService: TutorialService
    @ObservedObject var recordViewModel: RecordViewModel
    @State private var currentStep = 0
    @State private var selectedTabForDemo = 1 // 記録タブ
    @State private var hasSelectedChild = false
    @State private var hasSelectedTask = false
    @State private var hasRecorded = false
    
    let totalSteps = 4
    
    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                colors: [Color.green.opacity(0.1), Color.blue.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // プログレスバー
                ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                    .padding()
                
                Spacer()
                
                // メインコンテンツ
                Group {
                    switch currentStep {
                    case 0:
                        introStep
                    case 1:
                        selectChildStep
                    case 2:
                        selectTaskStep
                    case 3:
                        completionStep
                    default:
                        introStep
                    }
                }
                .animation(.easeInOut(duration: 0.5), value: currentStep)
                
                Spacer()
                
                // ナビゲーションボタン
                navigationButtons
                    .padding()
            }
        }
        .onAppear {
            recordViewModel.loadData()
        }
    }
    
    private var introStep: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.green, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)
                    .shadow(radius: 10)
                
                Image(systemName: "list.clipboard.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            
            Text("お手伝いを記録しよう！")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("お子様ががんばったお手伝いを記録して、\nコインを獲得しましょう")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 12) {
                RecordFeatureRow(icon: "person.circle", title: "お子様を選択", description: "記録する子を選びます")
                RecordFeatureRow(icon: "checklist", title: "お手伝いを選択", description: "がんばったタスクを選択")
                RecordFeatureRow(icon: "plus.circle", title: "記録ボタンをタップ", description: "コインを獲得！")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
        .padding()
    }
    
    private var selectChildStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("お子様を選択")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("記録するお子様を選んでください")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // デモ用の子供選択
            VStack(spacing: 16) {
                Text("記録するお子様：")
                    .font(.headline)
                
                if !recordViewModel.availableChildren.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(recordViewModel.availableChildren, id: \.id) { child in
                                Button(action: {
                                    recordViewModel.selectChild(child)
                                    hasSelectedChild = true
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
                                                    .stroke(recordViewModel.selectedChild?.id == child.id ? Color.green : Color.clear, lineWidth: 3)
                                            )
                                        
                                        Text(child.name)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("お子様が登録されていません")
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            recordViewModel.loadData()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("データを更新")
                            }
                        }
                        .compactGradientButton()
                    }
                }
                
                if hasSelectedChild {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("お子様が選択されました！")
                            .foregroundColor(.green)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.1))
                    )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
        .padding()
    }
    
    private var selectTaskStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "checklist")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("お手伝いを選択")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("がんばったお手伝いを選んでください")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                Text("今日のお手伝い：")
                    .font(.headline)
                
                if !recordViewModel.availableTasks.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(recordViewModel.availableTasks.prefix(3), id: \.id) { task in
                            Button(action: {
                                recordViewModel.selectTask(task)
                                hasSelectedTask = true
                            }) {
                                HStack {
                                    Image(systemName: "hands.sparkles")
                                        .foregroundColor(.blue)
                                        .frame(width: 30)
                                    
                                    Text(task.name)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if recordViewModel.selectedTask?.id == task.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(recordViewModel.selectedTask?.id == task.id ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                if hasSelectedTask && hasSelectedChild {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("記録準備完了！")
                                .foregroundColor(.green)
                                .fontWeight(.semibold)
                        }
                        
                        Button(action: {
                            recordViewModel.recordHelp()
                            hasRecorded = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("記録する")
                            }
                        }
                        .successGradientButton(isDisabled: hasRecorded)
                        .disabled(hasRecorded)
                        
                        if hasRecorded {
                            Text("記録されました！🎉")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.1))
                    )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
        .padding()
    }
    
    private var completionStep: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)
                    .shadow(radius: 10)
                
                Image(systemName: "trophy.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            
            Text("おめでとうございます！")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("チュートリアル完了です\nこれでおてつだいコインを\n始められます！")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                CompletionFeature(icon: "house.fill", title: "ホーム画面", description: "お子様の成績を確認")
                CompletionFeature(icon: "plus.circle.fill", title: "記録画面", description: "お手伝いを記録してコイン獲得")
                CompletionFeature(icon: "gearshape.fill", title: "設定画面", description: "お子様の追加・編集")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
        .padding()
    }
    
    private var navigationButtons: some View {
        VStack(spacing: 12) {
            HStack {
                if currentStep > 0 {
                    Button("戻る") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                Button(currentStep == totalSteps - 1 ? "開始" : "次へ") {
                    if currentStep == totalSteps - 1 {
                        tutorialService.completeTutorial()
                    } else {
                        withAnimation {
                            currentStep += 1
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(currentStep == 1 && !hasSelectedChild)
                .disabled(currentStep == 2 && (!hasSelectedTask || !hasRecorded))
            }
            
            Button("チュートリアルをスキップ") {
                tutorialService.completeTutorial()
            }
            .foregroundColor(.secondary)
            .font(.caption)
        }
    }
}

struct RecordFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.green)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct CompletionFeature: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let childRepository = CoreDataChildRepository(context: context)
    let taskRepository = CoreDataHelpTaskRepository(context: context)
    let recordRepository = CoreDataHelpRecordRepository(context: context)
    
    let recordViewModel = RecordViewModel(
        childRepository: childRepository,
        helpTaskRepository: taskRepository,
        helpRecordRepository: recordRepository
    )
    
    RecordTutorialView(
        tutorialService: TutorialService(),
        recordViewModel: recordViewModel
    )
}