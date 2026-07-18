import SwiftUI

struct TaskManagementView: View {
    @Bindable var viewModel: TaskManagementViewModel
    @State private var showingAddTaskForm = false
    @State private var editingTask: HelpTask?
    @State private var showingDeleteAlert = false
    @State private var taskToDelete: HelpTask?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
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
                            .onMove { source, destination in
                                // 同期 reorder で snap-back を防ぎ、永続化のみ非同期へ
                                let reordered = viewModel.reorderTasks(from: source, to: destination)
                                Task {
                                    await viewModel.persistReorder(reordered)
                                }
                            }

                            TaskListActionButtons(
                                canSortByFrequency: viewModel.canSortByFrequency,
                                onAdd: { showingAddTaskForm = true },
                                onSortByFrequency: {
                                    Task {
                                        await viewModel.sortByFrequency()
                                    }
                                }
                            )
                        }
                    }
                }

                BannerAdView()
                    .frame(height: 50)
            }
            .navigationTitle("お手伝い管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
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
            Text("\(taskToDelete?.displayName ?? "")を削除しますか？この操作は取り消せません。")
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
                Text(task.displayName)
                    .font(.body)
                    .foregroundColor(task.isActive ? .primary : .secondary)
                
                HStack(spacing: 8) {
                    Text(task.isActive ? "有効" : "無効")
                        .font(.caption)
                        .foregroundColor(task.isActive ? .green : .orange)
                    
                    Text("\(task.coinRate)コイン")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
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
    @Bindable var viewModel: TaskManagementViewModel
    let editingTask: HelpTask?
    @State private var taskName: String = ""
    @State private var isActive: Bool = true
    @State private var coinRate: Int = 10
    @State private var selectedIcon: String?
    @Environment(\.dismiss) private var dismiss
    
    var isEditing: Bool {
        editingTask != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("タスク情報") {
                    TextField("タスク名", text: $taskName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    HStack {
                        Text("コイン単価")
                        Spacer()
                        TextField("単価", value: $coinRate, format: .number)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                        Text("コイン")
                            .foregroundColor(.secondary)
                    }
                    
                    Toggle("有効", isOn: $isActive)
                }

                Section("アイコン") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                        ForEach(TaskIconCatalog.presets, id: \.self) { emoji in
                            Button {
                                selectedIcon = emoji
                            } label: {
                                Text(emoji)
                                    .font(.title2)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .stroke(selectedIcon == emoji ? AccessibilityColors.brandPrimary : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityLabel(Text(emoji))
                            .accessibilityAddTraits(selectedIcon == emoji ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
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
                    .successButton(isDisabled: taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                    taskName = task.displayName
                    isActive = task.isActive
                    coinRate = task.coinRate
                    selectedIcon = task.displayIcon
                }
            }
        }
    }

    private func addTask() {
        Task {
            await viewModel.addTask(name: taskName, coinRate: coinRate, icon: selectedIcon)
            if viewModel.errorMessage == nil {
                dismiss()
            }
        }
    }

    private func updateTask() {
        guard let editingTask = editingTask else { return }

        let resolvedName = HelpTask.resolvePersistedName(editedText: taskName, original: editingTask)
        let updatedTask = HelpTask(
            id: editingTask.id,
            name: resolvedName,
            isActive: isActive,
            coinRate: coinRate,
            sortOrder: editingTask.sortOrder,
            icon: HelpTask.resolvePersistedIcon(selected: selectedIcon, original: editingTask, resolvedName: resolvedName)
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
    let recordRepository = CoreDataHelpRecordRepository(context: context)
    TaskManagementView(viewModel: TaskManagementViewModel(helpTaskRepository: repository, helpRecordRepository: recordRepository))
}