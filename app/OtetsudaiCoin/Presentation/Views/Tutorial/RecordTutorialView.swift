import SwiftUI

struct RecordTutorialView: View {
    @Bindable var tutorialService: TutorialService
    @Bindable var recordViewModel: RecordViewModel
    @State private var currentStep = 0
    @State private var selectedTabForDemo = 1 // 記録タブ
    @State private var showCoinAnimation = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
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
                colors: [AccessibilityColors.brandPrimary.opacity(0.10), AccessibilityColors.brandAccent.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // プログレスバー
                ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                    .progressViewStyle(LinearProgressViewStyle(tint: AccessibilityColors.brandPrimary))
                    .padding()
                
                // メインコンテンツ (縦に収まらないときだけスクロール、#246)
                TutorialStepContainer(step: currentStep, scrollTarget: recordActionScrollTarget) {
                    stepContent
                }
                
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
            // #151 提案3: 円とアイコンを同じ倍率 (最大 1.3 倍) で育て、アイコンが円からはみ出さないようにする
            ZStack {
                Circle()
                    .fill(AccessibilityColors.brandSecondary)
                    .decorativeFrame(size: 120)
                    .shadow(radius: 10)

                Image(systemName: "list.clipboard.fill")
                    .decorativeFont(size: 50)
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
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .fill(.ultraThinMaterial)
            )
        }
        .padding()
    }
    
    private var selectChildStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.circle.fill")
                .decorativeFont(size: 80)
                .foregroundColor(AccessibilityColors.brandPrimary)
            
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
                                                            .decorativeFont(size: 14)
                                                            .foregroundColor(.white)
                                                            .background(
                                                                Circle()
                                                                    .fill(Color.green)
                                                                    .decorativeFrame(size: 14)
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
                        RoundedRectangle(cornerRadius: AppRadius.small)
                            .fill(Color.green.opacity(0.1))
                    )
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .fill(.ultraThinMaterial)
            )
        }
        .padding()
    }
    
    private var taskGrid: some View {
        LazyVGrid(columns: TutorialTaskCardView.gridColumns(
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
        ), spacing: 12) {
            ForEach(recordViewModel.availableTasks, id: \.id) { task in
                TutorialTaskCardView(
                    task: task,
                    isSelected: recordViewModel.selectedTask?.id == task.id,
                    onTap: {
                        recordViewModel.selectTask(task)
                    }
                )
                // 1 列の LazyVGrid なので、帯はカードの次の行に入る
                if showsRecordActionBelow(task) {
                    recordActionPanel
                        .id(recordActionScrollTarget)
                }
            }
        }
        .padding(.horizontal)
    }

    private func showsRecordActionBelow(_ task: HelpTask) -> Bool {
        recordActionPlacement == .belowSelectedCard && recordViewModel.selectedTask?.id == task.id
    }

    // 「記録する」の帯をどこに出すか (#262)。一覧の中 (選んだカードの下) と一覧の下の 2 か所の条件を 1 つにまとめる
    private var recordActionPlacement: TutorialTaskCardView.RecordActionPlacement {
        TutorialTaskCardView.recordActionPlacement(
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize,
            hasSelectedChild: hasSelectedChild,
            hasSelectedTask: hasSelectedTask
        )
    }

    private var recordActionScrollTarget: String? {
        TutorialTaskCardView.recordActionScrollTarget(
            placement: recordActionPlacement,
            selectedTaskID: recordViewModel.selectedTask?.id
        )
    }

    private var recordActionPanel: some View {
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
            .successButton()
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
        .frame(maxWidth: TutorialTaskCardView.recordActionMaxWidth(isAccessibilitySize: dynamicTypeSize.isAccessibilitySize))
        .background(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(Color.green.opacity(0.1))
        )
    }

    private var selectTaskStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "checklist")
                .decorativeFont(size: 80)
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
                    if TutorialTaskCardView.usesNestedScroll(isAccessibilitySize: dynamicTypeSize.isAccessibilitySize) {
                        // 入れ子の一覧の idealHeight: TutorialStepContainer の ViewThatFits は理想の高さで「収まるか」を判定する。
                        // maxHeight だけだと 300 で見積もられ、既定サイズでも「記録準備完了」が出た時点で
                        // スクロール表示に切り替わる。理想の高さを約 1 行分 (130) と小さく申告し、既定サイズでは
                        // 今までどおり縮めて収める。200 では iPhone 17 (6.3 インチ) で収まらず切り替わった (#246 で実測)
                        ScrollView {
                            taskGrid
                        }
                        .frame(idealHeight: 130, maxHeight: 300)
                    } else {
                        taskGrid
                    }
                }
                
                if recordActionPlacement == .belowList {
                    recordActionPanel
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .fill(.ultraThinMaterial)
            )
        }
        .padding()
    }
    
    private var completionStep: some View {
        VStack(spacing: 24) {
            // #151 提案3: 円とアイコンを同じ倍率 (最大 1.3 倍) で育て、アイコンが円からはみ出さないようにする
            ZStack {
                Circle()
                    .fill(AccessibilityColors.brandPrimary)
                    .decorativeFrame(size: 120)
                    .shadow(radius: 10)

                Image(systemName: "trophy.fill")
                    .decorativeFont(size: 50)
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
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .fill(.ultraThinMaterial)
            )
        }
        .padding()
    }
    
    private var stepContent: some View {
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    // AX サイズでは 2 列・高さ 120 固定に名前が収まらず「下の…」と切れ、アイコンとチェックも
    // カードの外へはみ出していた (#253)。AX サイズのときだけ 1 列にし、カードの高さと名前の行数を
    // 中身に合わせる。既定サイズは今までどおり (撮影でピクセル一致を確認)。
    static func gridColumns(isAccessibilitySize: Bool) -> [GridItem] {
        Array(repeating: GridItem(.flexible()), count: isAccessibilitySize ? 1 : 2)
    }

    static func cardHeight(isAccessibilitySize: Bool) -> CGFloat? {
        isAccessibilitySize ? nil : 120
    }

    static func nameLineLimit(isAccessibilitySize: Bool) -> Int? {
        isAccessibilitySize ? nil : 2
    }

    // 1 列にするとカードの幅が名前の長さでばらばらになるため、AX サイズでは列いっぱいにそろえる。
    static func cardMaxWidth(isAccessibilitySize: Bool) -> CGFloat? {
        isAccessibilitySize ? .infinity : nil
    }

    // AX 最大では一覧の窓 (理想の高さ 130) にカードが 1 枚も丸ごと入らなかった (#253 で撮影)。
    // AX サイズでは一覧を入れ子にせず全件を並べ、収まらない分は TutorialStepContainer の縦スクロールに任せる。
    static func usesNestedScroll(isAccessibilitySize: Bool) -> Bool {
        !isAccessibilitySize
    }

    // 入れ子スクロールをやめると「記録する」が 10 枚のカードの下へ押し出され、選んだ直後に
    // 見えなくなった (#253 の最終レビュー)。AX サイズでは選んだカードのすぐ下に出す。
    static func placesRecordActionBelowSelectedCard(isAccessibilitySize: Bool) -> Bool {
        isAccessibilitySize
    }

    // 高さが中身に合わせて変わる AX サイズでは、選ぶたびにチェックの分だけカードが伸びて
    // 下のカードがずれる。未選択でも透明なチェックで高さを取っておく。
    static func reservesCheckmarkSpace(isAccessibilitySize: Bool) -> Bool {
        isAccessibilitySize
    }

    // 「記録する」の帯の表示条件 (#262)。子どもとタスクが選ばれたときだけ出し、AX サイズでは
    // 選んだカードのすぐ下、既定サイズでは一覧の下に出す。
    enum RecordActionPlacement: Equatable {
        case hidden, belowSelectedCard, belowList
    }

    static func recordActionPlacement(
        isAccessibilitySize: Bool,
        hasSelectedChild: Bool,
        hasSelectedTask: Bool
    ) -> RecordActionPlacement {
        guard hasSelectedChild && hasSelectedTask else { return .hidden }
        return placesRecordActionBelowSelectedCard(isAccessibilitySize: isAccessibilitySize)
            ? .belowSelectedCard : .belowList
    }

    // AX サイズでは帯がカードの間に入るので、カード (cardMaxWidth) と同じく列いっぱいにそろえる (#262)。
    static func recordActionMaxWidth(isAccessibilitySize: Bool) -> CGFloat? {
        isAccessibilitySize ? .infinity : nil
    }

    // 一番下のカードを選ぶと帯が画面の外に出る (#262)。帯がカードの下に入るときだけ、選んだタスクごとに
    // 別のスクロール先を返し、TutorialStepContainer がそこまでスクロールする。
    static func recordActionScrollTarget(placement: RecordActionPlacement, selectedTaskID: UUID?) -> String? {
        guard placement == .belowSelectedCard, let selectedTaskID else { return nil }
        return "recordAction-\(selectedTaskID.uuidString)"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // ZStack + 非拘束 Text / VoiceOver hidden / 円塗りトークンは TaskIconView に集約 (#200)
                TaskIconView(task: task, isSelected: isSelected)

                Text(task.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .lineLimit(Self.nameLineLimit(isAccessibilitySize: dynamicTypeSize.isAccessibilitySize))

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(AccessibilityColors.brandPrimary)
                        .accessibilityHidden(true)
                } else if Self.reservesCheckmarkSpace(isAccessibilitySize: dynamicTypeSize.isAccessibilitySize) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .hidden()
                        .accessibilityHidden(true)
                } else {
                    Spacer()
                        .frame(height: 20)
                }
            }
            .padding()
            .frame(
                maxWidth: Self.cardMaxWidth(isAccessibilitySize: dynamicTypeSize.isAccessibilitySize)
            )
            .frame(height: Self.cardHeight(isAccessibilitySize: dynamicTypeSize.isAccessibilitySize))
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    // #151: このカードはグラデ背景 + .ultraThinMaterial パネル (:345) の上に
                    // 乗っているため、不透明な systemBackgroundSecondary へ置き換えると
                    // 透過表現を潰してしまう。Tutorial 画面のダークモード方針
                    // (issue #151 本文「グラデ背景上の白文字は未検証」) が決まるまで据え置く。
                    .fill(isSelected ? AccessibilityColors.brandPrimary.opacity(0.1) : Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.large)
                            .stroke(isSelected ? AccessibilityColors.brandPrimary : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                .foregroundColor(AccessibilityColors.brandPrimary)
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