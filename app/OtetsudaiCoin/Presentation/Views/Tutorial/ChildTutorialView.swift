import SwiftUI

struct ChildTutorialView: View {
    @ObservedObject var tutorialService: TutorialService
    @ObservedObject var childManagementViewModel: ChildManagementViewModel
    @State private var currentStep = 0
    @State private var showChildForm = false
    @State private var hasAddedChild = false
    
    let totalSteps = 3
    
    var body: some View {
        ZStack {
            // 背景グラデーション
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // プログレスバー
                ProgressView(value: Double(currentStep + 1), total: Double(totalSteps))
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .padding()
                
                Spacer()
                
                // メインコンテンツ
                Group {
                    switch currentStep {
                    case 0:
                        welcomeStep
                    case 1:
                        addChildStep
                    case 2:
                        completionStep
                    default:
                        welcomeStep
                    }
                }
                .animation(.easeInOut(duration: 0.5), value: currentStep)
                
                Spacer()
                
                // ナビゲーションボタン
                navigationButtons
                    .padding()
            }
        }
        .sheet(isPresented: $showChildForm) {
            ChildFormView(viewModel: childManagementViewModel, editingChild: nil)
        }
        .onAppear {
            Task {
                await childManagementViewModel.loadChildren()
            }
        }
        .onChange(of: childManagementViewModel.children) { _, children in
            // SwiftUIの宣言的な仕組み：@Publishedプロパティの変更を自動監視
            hasAddedChild = !children.isEmpty
        }
    }
    
    private var welcomeStep: some View {
        VStack(spacing: 24) {
            // アニメーションアイコン
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)
                    .shadow(radius: 10)
                
                Image(systemName: "figure.2.and.child.holdinghands")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            
            Text("おてつだいコインへようこそ！")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("お子様のお手伝いを楽しく記録して、\nコインを貯めていきましょう！")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "person.badge.plus", title: "お子様を登録", description: "名前や好きな色を設定")
                FeatureRow(icon: "list.clipboard", title: "お手伝いを記録", description: "がんばった成果をコインに")
                FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "成長を確認", description: "統計で進捗をチェック")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
        .padding()
    }
    
    private var addChildStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("最初のお子様を\n登録しましょう")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text("お子様の名前と好きな色を設定して、\n専用のプロフィールを作成します")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if hasAddedChild {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("お子様が登録されました！")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.green.opacity(0.1))
                )
            } else {
                Button(action: {
                    showChildForm = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                        Text("お子様を追加")
                    }
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                    .shadow(radius: 8)
                }
                .scaleEffect(hasAddedChild ? 0.8 : 1.0)
                .opacity(hasAddedChild ? 0.5 : 1.0)
                .disabled(hasAddedChild)
            }
        }
        .padding()
    }
    
    private var completionStep: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.green, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)
                    .shadow(radius: 10)
                
                Image(systemName: "star.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            
            Text("準備完了です！")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("次はお手伝いの記録方法を\n学んでみましょう")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 12) {
                TutorialStep(number: "1", title: "記録タブを開く", description: "下部の「記録」ボタンをタップ")
                TutorialStep(number: "2", title: "お子様を選択", description: "登録したお子様を選ぶ")
                TutorialStep(number: "3", title: "お手伝いを選んで記録", description: "がんばったお手伝いを記録")
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
            
            Button(currentStep == totalSteps - 1 ? "完了" : "次へ") {
                if currentStep == totalSteps - 1 {
                    tutorialService.markChildTutorialCompleted()
                } else {
                    withAnimation {
                        currentStep += 1
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(currentStep == 1 && !hasAddedChild)
        }
    }
}

struct FeatureRow: View {
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

struct TutorialStep: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.blue)
                    .frame(width: 30, height: 30)
                
                Text(number)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
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
    let childManagementViewModel = ChildManagementViewModel(childRepository: childRepository)
    
    ChildTutorialView(
        tutorialService: TutorialService(),
        childManagementViewModel: childManagementViewModel
    )
}