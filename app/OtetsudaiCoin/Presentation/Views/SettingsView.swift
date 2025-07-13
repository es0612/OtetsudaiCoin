import SwiftUI
import StoreKit

struct SettingsView: View {
    @Bindable var viewModel: ChildManagementViewModel
    @State private var showingAddChildForm = false
    @State private var editingChild: Child?
    @State private var showingDeleteAlert = false
    @State private var childToDelete: Child?
    @State private var showingTaskManagement = false
    @State private var tutorialService = TutorialService()
    @State private var taskManagementViewModel: TaskManagementViewModel
    
    #if DEBUG
    @State private var isGeneratingData = false
    @State private var isClearingData = false
    @State private var showingSampleDataAlert = false
    @State private var sampleDataAlertMessage = ""
    #endif
    
    @MainActor
    init(viewModel: ChildManagementViewModel) {
        self.viewModel = viewModel
        let context = PersistenceController.shared.container.viewContext
        let taskRepository = CoreDataHelpTaskRepository(context: context)
        self._taskManagementViewModel = State(wrappedValue: TaskManagementViewModel(helpTaskRepository: taskRepository))
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("お子様管理") {
                    ForEach(viewModel.children, id: \.id) { child in
                        ChildRowView(child: child) {
                            editingChild = child
                        } onDelete: {
                            childToDelete = child
                            showingDeleteAlert = true
                        }
                    }
                    
                    Button(action: {
                        showingAddChildForm = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("新しい子供を追加")
                        }
                    }
                    .primaryGradientButton()
                    .accessibilityIdentifier("add_child_button")
                }
                
                Section("お手伝い管理") {
                    Button(action: {
                        showingTaskManagement = true
                    }) {
                        HStack {
                            Image(systemName: "list.bullet.clipboard")
                                .foregroundColor(.blue)
                            Text("お手伝いリストを編集")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                
                #if DEBUG
                Section("開発者向け") {
                    Button(action: {
                        generateSampleData()
                    }) {
                        HStack {
                            if isGeneratingData {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "chart.bar.doc.horizontal")
                                    .foregroundColor(.green)
                            }
                            Text("3ヶ月分サンプルデータ生成")
                            Spacer()
                        }
                    }
                    .foregroundColor(.primary)
                    .disabled(isGeneratingData)
                    
                    Button(action: {
                        clearRecordsOnly()
                    }) {
                        HStack {
                            if isClearingData {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "trash.circle")
                                    .foregroundColor(.orange)
                            }
                            Text("記録データのみ削除")
                            Spacer()
                        }
                    }
                    .foregroundColor(.primary)
                    .disabled(isClearingData)
                    
                    Button(action: {
                        clearAllData()
                    }) {
                        HStack {
                            if isClearingData {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.red)
                            }
                            Text("全データ削除")
                            Spacer()
                        }
                    }
                    .foregroundColor(.red)
                    .disabled(isClearingData)
                }
                #endif
                
                Section("ヘルプ") {
                    Button(action: {
                        tutorialService.resetTutorial()
                    }) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.orange)
                            Text("チュートリアルを再表示")
                            Spacer()
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Section("アプリ情報") {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("バージョン")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        requestAppReview()
                    }) {
                        HStack {
                            Image(systemName: "star.circle")
                                .foregroundColor(.yellow)
                            Text("アプリを評価")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("設定")
            .refreshable {
                await viewModel.loadChildren()
            }
            .onAppear {
                Task {
                    await viewModel.loadChildren()
                }
            }
        }
        .sheet(isPresented: $showingAddChildForm) {
            ChildFormView(viewModel: viewModel, editingChild: nil)
        }
        .sheet(item: $editingChild) { child in
            ChildFormView(viewModel: viewModel, editingChild: child)
        }
        .sheet(isPresented: $showingTaskManagement) {
            TaskManagementView(viewModel: taskManagementViewModel)
        }
        .alert("削除確認", isPresented: $showingDeleteAlert) {
            Button("削除", role: .destructive) {
                if let child = childToDelete {
                    Task {
                        await viewModel.deleteChild(id: child.id)
                    }
                }
                childToDelete = nil
            }
            Button("キャンセル", role: .cancel) {
                childToDelete = nil
            }
        } message: {
            Text(childToDelete?.name ?? "" + "を削除しますか？この操作は取り消せません。")
        }
        .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearMessages()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert("成功", isPresented: .constant(viewModel.successMessage != nil)) {
            Button("OK") {
                viewModel.clearMessages()
            }
        } message: {
            Text(viewModel.successMessage ?? "")
        }
        #if DEBUG
        .alert("サンプルデータ", isPresented: $showingSampleDataAlert) {
            Button("OK") {
                showingSampleDataAlert = false
                sampleDataAlertMessage = ""
            }
        } message: {
            Text(sampleDataAlertMessage)
        }
        #endif
        .fullScreenCover(isPresented: $tutorialService.showTutorial) {
            let context = PersistenceController.shared.container.viewContext
            let childRepository = CoreDataChildRepository(context: context)
            let taskRepository = CoreDataHelpTaskRepository(context: context)
            let recordRepository = CoreDataHelpRecordRepository(context: context)
            
            TutorialContainerView(
                tutorialService: tutorialService,
                childManagementViewModel: ChildManagementViewModel(childRepository: childRepository),
                recordViewModel: RecordViewModel(
                    childRepository: childRepository,
                    helpTaskRepository: taskRepository,
                    helpRecordRepository: recordRepository
                )
            )
        }
    }
    
    private func requestAppReview() {
        if #available(iOS 18.0, *) {
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                AppStore.requestReview(in: scene)
            }
        } else {
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
    }
    
    #if DEBUG
    private func generateSampleData() {
        isGeneratingData = true
        
        Task {
            do {
                let context = PersistenceController.shared.container.viewContext
                let childRepository = CoreDataChildRepository(context: context)
                let taskRepository = CoreDataHelpTaskRepository(context: context)
                let recordRepository = CoreDataHelpRecordRepository(context: context)
                
                let sampleDataService = SampleDataService(
                    childRepository: childRepository,
                    helpTaskRepository: taskRepository,
                    helpRecordRepository: recordRepository
                )
                
                try await sampleDataService.generateSampleData()
                
                // 子供リストを更新
                await viewModel.loadChildren()
                
                await MainActor.run {
                    isGeneratingData = false
                    sampleDataAlertMessage = "3ヶ月分のサンプルデータを生成しました！\n\n・子供: 2人\n・お手伝いタスク: 6個\n・記録: 過去3ヶ月分"
                    showingSampleDataAlert = true
                }
            } catch {
                await MainActor.run {
                    isGeneratingData = false
                    sampleDataAlertMessage = "サンプルデータの生成に失敗しました: \(error.localizedDescription)"
                    showingSampleDataAlert = true
                }
            }
        }
    }
    
    private func clearRecordsOnly() {
        isClearingData = true
        
        Task {
            do {
                let context = PersistenceController.shared.container.viewContext
                let childRepository = CoreDataChildRepository(context: context)
                let taskRepository = CoreDataHelpTaskRepository(context: context)
                let recordRepository = CoreDataHelpRecordRepository(context: context)
                
                let sampleDataService = SampleDataService(
                    childRepository: childRepository,
                    helpTaskRepository: taskRepository,
                    helpRecordRepository: recordRepository
                )
                
                try await sampleDataService.clearRecordsOnly()
                
                await MainActor.run {
                    isClearingData = false
                    sampleDataAlertMessage = "記録データのみ削除しました。\n子供とタスクデータは保持されています。"
                    showingSampleDataAlert = true
                }
            } catch {
                await MainActor.run {
                    isClearingData = false
                    sampleDataAlertMessage = "データの削除に失敗しました: \(error.localizedDescription)"
                    showingSampleDataAlert = true
                }
            }
        }
    }
    
    private func clearAllData() {
        isClearingData = true
        
        Task {
            do {
                let context = PersistenceController.shared.container.viewContext
                let childRepository = CoreDataChildRepository(context: context)
                let taskRepository = CoreDataHelpTaskRepository(context: context)
                let recordRepository = CoreDataHelpRecordRepository(context: context)
                
                let sampleDataService = SampleDataService(
                    childRepository: childRepository,
                    helpTaskRepository: taskRepository,
                    helpRecordRepository: recordRepository
                )
                
                try await sampleDataService.clearAllData()
                
                // 子供リストを更新
                await viewModel.loadChildren()
                
                await MainActor.run {
                    isClearingData = false
                    sampleDataAlertMessage = "全データを削除しました。\n子供、タスク、記録のすべてが削除されました。"
                    showingSampleDataAlert = true
                }
            } catch {
                await MainActor.run {
                    isClearingData = false
                    sampleDataAlertMessage = "データの削除に失敗しました: \(error.localizedDescription)"
                    showingSampleDataAlert = true
                }
            }
        }
    }
    #endif
}

struct ChildRowView: View {
    let child: Child
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color(hex: child.themeColor) ?? .blue)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(child.name.prefix(1)))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
                .shadow(radius: 2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(child.name)
                    .font(.headline)
                
                Text("お手伝い頑張り中")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Menu {
                Button(action: onEdit) {
                    Label("編集", systemImage: "pencil")
                }
                
                Button(action: onDelete) {
                    Label("削除", systemImage: "trash")
                }
                .foregroundColor(.red)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.secondary)
                    .font(.title2)
            }
        }
        .padding(.vertical, 4)
    }
}

extension Child: Identifiable {}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let repository = CoreDataChildRepository(context: context)
    SettingsView(viewModel: ChildManagementViewModel(childRepository: repository))
}