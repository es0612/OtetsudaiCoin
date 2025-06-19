import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: ChildManagementViewModel
    @State private var showingAddChildForm = false
    @State private var editingChild: Child?
    @State private var showingDeleteAlert = false
    @State private var childToDelete: Child?
    @State private var showingTaskManagement = false
    @StateObject private var tutorialService = TutorialService()
    @StateObject private var taskManagementViewModel: TaskManagementViewModel
    
    init(viewModel: ChildManagementViewModel) {
        self.viewModel = viewModel
        let context = PersistenceController.shared.container.viewContext
        let taskRepository = CoreDataHelpTaskRepository(context: context)
        self._taskManagementViewModel = StateObject(wrappedValue: TaskManagementViewModel(helpTaskRepository: taskRepository))
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
                
                Text("\(child.coinRate)コイン/回")
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