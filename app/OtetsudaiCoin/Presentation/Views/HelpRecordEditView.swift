import SwiftUI

struct HelpRecordEditView: View {
    @Bindable var viewModel: HelpRecordEditViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                taskSelectionSection
                dateTimeSection
                actionSection
            }
            .navigationTitle("記録を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        viewModel.saveChanges()
                    }
                    .disabled(!viewModel.hasChanges || viewModel.isLoading)
                    .fontWeight(.semibold)
                }
            })
        }
        .onChange(of: viewModel.successMessage) { _, successMessage in
            if successMessage != nil {
                DebugLogger.info("Success message received, dismissing view: \(successMessage ?? "unknown")")
                dismiss()
            }
        }
        .onAppear {
            DebugLogger.info("HelpRecordEditView appeared")
            viewModel.loadData()
        }
        .onDisappear {
            DebugLogger.info("HelpRecordEditView disappeared")
        }
        .alert("削除確認", isPresented: $showingDeleteAlert) {
            Button("削除", role: .destructive) {
                viewModel.deleteRecord()
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("この記録を削除しますか？この操作は取り消せません。")
        }
        .commonAlerts(
            errorMessage: viewModel.errorMessage,
            successMessage: viewModel.successMessage,
            onErrorDismiss: { viewModel.clearMessages() },
            onSuccessDismiss: { 
                viewModel.clearMessages()
                dismiss()
            }
        )
    }
    
    private var taskSelectionSection: some View {
        Section(header: Text("お手伝い内容")) {
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                        .onAppear {
                            DebugLogger.debug("ProgressView appeared - showing loading state")
                        }
                    Text("読み込み中...")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else if viewModel.availableTasks.isEmpty {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.title2)
                    Text("利用可能なタスクがありません")
                        .foregroundColor(.secondary)
                        .font(.caption)
                        .onAppear {
                            DebugLogger.warning("No available tasks message displayed to user")
                        }
                    Button("再読み込み") {
                        DebugLogger.info("Manual refresh button tapped by user")
                        viewModel.loadData()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
                .padding(.vertical, 8)
            } else {
                ForEach(viewModel.availableTasks, id: \.id) { task in
                    TaskSelectionRow(
                        task: task,
                        isSelected: viewModel.selectedTask?.id == task.id,
                        onSelect: {
                            viewModel.selectedTask = task
                        }
                    )
                }
            }
        }
    }
    
    private var dateTimeSection: some View {
        Section(header: Text("記録日時")) {
            DatePicker(
                "日時",
                selection: $viewModel.recordedDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(CompactDatePickerStyle())
        }
    }
    
    private var actionSection: some View {
        Section {
            // 保存ボタン
            Button(action: {
                viewModel.saveChanges()
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("変更を保存")
                }
            }
            .primaryGradientButton(isDisabled: !viewModel.hasChanges || viewModel.isLoading)
            .disabled(!viewModel.hasChanges || viewModel.isLoading)
            
            // 削除ボタン
            Button(action: {
                showingDeleteAlert = true
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("記録を削除")
                }
            }
            .warningGradientButton(isDisabled: viewModel.isLoading)
            .disabled(viewModel.isLoading)
        }
    }
}

struct TaskSelectionRow: View {
    let task: HelpTask
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                // タスクアイコン
                Image(systemName: "hands.sparkles")
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : .blue)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.blue : Color.blue.opacity(0.1))
                    )
                
                // タスク情報
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("お手伝いタスク")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // 選択インジケータ
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    @Previewable @State var previewViewModel: HelpRecordEditViewModel?
    
    Group {
        if let viewModel = previewViewModel {
            HelpRecordEditView(viewModel: viewModel)
        } else {
            Text("Loading...")
        }
    }
    .task {
        await MainActor.run {
            let context = PersistenceController.preview.container.viewContext
            let helpRecordRepository = CoreDataHelpRecordRepository(context: context)
            let helpTaskRepository = CoreDataHelpTaskRepository(context: context)
            
            let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
            let record = HelpRecord(id: UUID(), childId: child.id, helpTaskId: UUID(), recordedAt: Date())
            
            previewViewModel = HelpRecordEditViewModel(
                helpRecord: record,
                child: child,
                helpRecordRepository: helpRecordRepository,
                helpTaskRepository: helpTaskRepository
            )
        }
    }
}