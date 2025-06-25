import SwiftUI

struct HelpRecordEditView: View {
    @ObservedObject var viewModel: HelpRecordEditViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
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
        .onAppear {
            viewModel.loadData()
        }
        .onChange(of: viewModel.viewState.successMessage) { _, successMessage in
            if successMessage != nil {
                dismiss()
            }
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
            viewState: viewModel.viewState,
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
                    Text("読み込み中...")
                        .foregroundColor(.secondary)
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
    let context = PersistenceController.preview.container.viewContext
    let helpRecordRepository = CoreDataHelpRecordRepository(context: context)
    let helpTaskRepository = CoreDataHelpTaskRepository(context: context)
    
    let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733", coinRate: 100)
    let record = HelpRecord(id: UUID(), childId: child.id, helpTaskId: UUID(), recordedAt: Date())
    
    let viewModel = HelpRecordEditViewModel(
        helpRecord: record,
        child: child,
        helpRecordRepository: helpRecordRepository,
        helpTaskRepository: helpTaskRepository
    )
    
    HelpRecordEditView(viewModel: viewModel)
}