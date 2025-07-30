import SwiftUI

struct RecordTutorialView: View {
    @Bindable var tutorialService: TutorialService
    @Bindable var recordViewModel: RecordViewModel
    @State private var currentStep = 0
    @State private var selectedTabForDemo = 1 // 記録タブ
    @State private var showCoinAnimation = false
    
    let totalSteps = 4
    
    // @Observableによる状態管理で計算されるプロパティ
    private var hasSelectedChild: Bool {
        recordViewModel.selectedChild != nil
    }
    
    private var hasSelectedTask: Bool {
        recordViewModel.selectedTask != nil
    }
    
    private var hasRecorded: Bool {
        recordViewModel.hasRecordedInSession
    }
    
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
            
            // コインアニメーションオーバーレイ
            if showCoinAnimation, let selectedChild = recordViewModel.selectedChild {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showCoinAnimation = false
                    }
                
                CoinAnimationView(
                    isVisible: $showCoinAnimation,
                    coinValue: recordViewModel.lastRecordedCoinValue,
                    themeColor: selectedChild.themeColor
                )
            }
        }
        .onChange(of: recordViewModel.isLoading) { oldValue, newValue in
            // データロード完了時に自動的に子供を選択（onChange重複実行を防ぐため条件を厳密化）
            if oldValue == true && newValue == false && !recordViewModel.availableChildren.isEmpty && recordViewModel.selectedChild == nil {
                DispatchQueue.main.async {
                    recordViewModel.selectedChild = recordViewModel.availableChildren.first
                }
            }
        }
        .onChange(of: recordViewModel.successMessage) { oldValue, newValue in
            // 記録成功時にhasRecordedInSessionを確実に更新
            if oldValue == nil && newValue != nil {
                DispatchQueue.main.async {
                    recordViewModel.hasRecordedInSession = true
                    // コインアニメーションを表示
                    showCoinAnimation = true
                }
            }
        }
        .onChange(of: showCoinAnimation) { _, isShowing in
            if !isShowing {
                // アニメーション終了時に成功メッセージをクリア
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    recordViewModel.clearMessages()
                }
            }
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
                                }) {
                                    VStack(spacing: 4) {
                                        ZStack {
                                            Circle()
                                                .fill(Color(hex: child.themeColor) ?? .blue)
                                                .frame(width: 50, height: 50)
                                                .overlay(
                                                    Text(String(child.name.prefix(1)))
                                                        .font(.title3)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(.white)
                                                )
                                                .overlay(
                                                    // 選択時の白い太い境界線（視認性向上）
                                                    Circle()
                                                        .stroke(Color.white, lineWidth: recordViewModel.selectedChild?.id == child.id ? 3 : 0)
                                                )
                                                .overlay(
                                                    // 外側の濃い境界線（コントラスト向上）
                                                    Circle()
                                                        .stroke(Color.black.opacity(0.3), lineWidth: recordViewModel.selectedChild?.id == child.id ? 4 : 0)
                                                )
                                                .shadow(
                                                    color: recordViewModel.selectedChild?.id == child.id ? Color.black.opacity(0.3) : Color.clear,
                                                    radius: recordViewModel.selectedChild?.id == child.id ? 6 : 0,
                                                    x: 0, y: 2
                                                )
                                            
                                            // 選択時のチェックマークアイコン
                                            if recordViewModel.selectedChild?.id == child.id {
                                                VStack {
                                                    HStack {
                                                        Spacer()
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .font(.system(size: 14))
                                                            .foregroundColor(.white)
                                                            .background(
                                                                Circle()
                                                                    .fill(Color.green)
                                                                    .frame(width: 14, height: 14)
                                                            )
                                                            .offset(x: 0, y: -1)
                                                    }
                                                    Spacer()
                                                }
                                            }
                                        }
                                        .frame(width: 60, height: 60)
                                        
                                        Text(child.name)
                                            .font(.caption2)
                                            .foregroundColor(.primary)
                                            .fontWeight(recordViewModel.selectedChild?.id == child.id ? .bold : .regular)
                                            .lineLimit(1)
                                            .frame(width: 60)
                                    }
                                    .frame(width: 70, height: 90)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .scaleEffect(recordViewModel.selectedChild?.id == child.id ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: recordViewModel.selectedChild?.id == child.id)
                            }
                        }
                        .padding(.horizontal)
                    }
                } else {
                    Text("お子様が登録されていません")
                        .foregroundColor(.secondary)
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
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(recordViewModel.availableTasks, id: \.id) { task in
                                TutorialTaskCardView(
                                    task: task,
                                    isSelected: recordViewModel.selectedTask?.id == task.id,
                                    onTap: {
                                        recordViewModel.selectTask(task)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxHeight: 300)
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
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("記録する")
                            }
                        }
                        .successGradientButton(isDisabled: hasRecorded)
                        .disabled(hasRecorded)
                        
                        if hasRecorded {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("記録完了！アニメーションを確認してください")
                                    .foregroundColor(.green)
                                    .fontWeight(.semibold)
                            }
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
                .disabled(
                    (currentStep == 1 && !hasSelectedChild) ||
                    (currentStep == 2 && !hasRecorded)
                )
            }
            
            Button("チュートリアルをスキップ") {
                tutorialService.completeTutorial()
            }
            .foregroundColor(.secondary)
            .font(.caption)
        }
    }
}

struct TutorialTaskCardView: View {
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
    @Previewable @State var previewRecordViewModel: RecordViewModel?
    
    Group {
        if let recordViewModel = previewRecordViewModel {
            RecordTutorialView(
                tutorialService: TutorialService(),
                recordViewModel: recordViewModel
            )
        } else {
            Text("Loading...")
        }
    }
    .task {
        await MainActor.run {
            let context = PersistenceController.preview.container.viewContext
            let childRepository = CoreDataChildRepository(context: context)
            let taskRepository = CoreDataHelpTaskRepository(context: context)
            let recordRepository = CoreDataHelpRecordRepository(context: context)
            
            previewRecordViewModel = RecordViewModel(
                childRepository: childRepository,
                helpTaskRepository: taskRepository,
                helpRecordRepository: recordRepository
            )
        }
    }
}