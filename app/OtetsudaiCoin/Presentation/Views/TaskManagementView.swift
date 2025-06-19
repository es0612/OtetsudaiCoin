import SwiftUI

struct TaskManagementView: View {
    @ObservedObject var viewModel: TaskManagementViewModel
    @State private var showingAddTaskForm = false
    @State private var editingTask: HelpTask?
    @State private var showingDeleteAlert = false
    @State private var taskToDelete: HelpTask?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("読み込み中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section("お手伝いタスク一覧") {
                            ForEach(viewModel.tasks, id: \.id) { task in
                                TaskRowView(task: task) {
                                    editingTask = task
                                } onToggle: {
                                    Task {
                                        await viewModel.toggleTaskStatus(task)
                                    }
                                } onDelete: {
                                    taskToDelete = task
                                    showingDeleteAlert = true
                                }
                            }
                            
                            Button(action: {
                                showingAddTaskForm = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("新しいタスクを追加")
                                }
                            }
                            .primaryGradientButton()
                        }
                    }
                }
            }
            .navigationTitle("お手伝い管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                Task {
                    await viewModel.loadTasks()
                }
            }
        }
        .sheet(isPresented: $showingAddTaskForm) {
            TaskFormView(viewModel: viewModel, editingTask: nil)
        }
        .sheet(item: $editingTask) { task in
            TaskFormView(viewModel: viewModel, editingTask: task)
        }
        .alert("削除確認", isPresented: $showingDeleteAlert) {
            Button("削除", role: .destructive) {
                if let task = taskToDelete {
                    Task {
                        await viewModel.deleteTask(id: task.id)
                    }
                }
                taskToDelete = nil
            }
            Button("キャンセル", role: .cancel) {
                taskToDelete = nil
            }
        } message: {
            Text("\(taskToDelete?.name ?? "")を削除しますか？この操作は取り消せません。")
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
    }
}

struct TaskRowView: View {
    let task: HelpTask
    let onEdit: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: task.isActive ? "hands.sparkles.fill" : "hands.sparkles")
                .foregroundColor(task.isActive ? .blue : .gray)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.body)
                    .foregroundColor(task.isActive ? .primary : .secondary)
                
                Text(task.isActive ? "有効" : "無効")
                    .font(.caption)
                    .foregroundColor(task.isActive ? .green : .orange)
            }
            
            Spacer()
            
            Menu {
                Button(action: onEdit) {
                    Label("編集", systemImage: "pencil")
                }
                
                Button(action: onToggle) {
                    Label(task.isActive ? "無効にする" : "有効にする", 
                          systemImage: task.isActive ? "pause.circle" : "play.circle")
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

struct TaskFormView: View {
    @ObservedObject var viewModel: TaskManagementViewModel
    let editingTask: HelpTask?
    @State private var taskName: String = ""
    @State private var isActive: Bool = true
    @Environment(\.dismiss) private var dismiss
    
    var isEditing: Bool {
        editingTask != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("タスク情報") {
                    TextField("タスク名", text: $taskName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Toggle("有効", isOn: $isActive)
                }
                
                Section {
                    Button(action: {
                        if isEditing {
                            updateTask()
                        } else {
                            addTask()
                        }
                    }) {
                        Text(isEditing ? "更新" : "追加")
                    }
                    .successGradientButton(isDisabled: taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .disabled(taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle(isEditing ? "タスク編集" : "タスク追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let task = editingTask {
                    taskName = task.name
                    isActive = task.isActive
                }
            }
        }
    }
    
    private func addTask() {
        Task {
            await viewModel.addTask(name: taskName)
            if viewModel.errorMessage == nil {
                dismiss()
            }
        }
    }
    
    private func updateTask() {
        guard let editingTask = editingTask else { return }
        
        let updatedTask = HelpTask(
            id: editingTask.id,
            name: taskName.trimmingCharacters(in: .whitespacesAndNewlines),
            isActive: isActive
        )
        
        Task {
            await viewModel.updateTask(updatedTask)
            if viewModel.errorMessage == nil {
                dismiss()
            }
        }
    }
}

extension HelpTask: Identifiable {}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let repository = CoreDataHelpTaskRepository(context: context)
    TaskManagementView(viewModel: TaskManagementViewModel(helpTaskRepository: repository))
}