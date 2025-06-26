import SwiftUI

struct ChildFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ChildManagementViewModel
    
    let editingChild: Child?
    
    @State private var name: String = ""
    @State private var selectedThemeColor: String = "#3357FF"
    @State private var showingColorPicker = false
    
    private var isEditing: Bool {
        editingChild != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本情報") {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        TextField("お子様のお名前", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .accessibilityIdentifier("name_field")
                    
                }
                
                Section("テーマカラー") {
                    Button(action: {
                        showingColorPicker.toggle()
                    }) {
                        HStack {
                            Circle()
                                .fill(Color(hex: selectedThemeColor) ?? .blue)
                                .frame(width: 40, height: 40)
                                .shadow(radius: 2)
                            
                            Text("カラーを選択")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .accessibilityIdentifier("color_picker_button")
                    
                    if showingColorPicker {
                        let colors = viewModel.getAvailableThemeColors()
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                            ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                                ColorSelectionButton(
                                    color: color,
                                    isSelected: selectedThemeColor == color,
                                    onSelect: {
                                        selectedThemeColor = color
                                        showingColorPicker = false
                                    }
                                )
                                .accessibilityIdentifier("color_option_\(index)")
                            }
                        }
                        .padding()
                    }
                }
                
                Section("プレビュー") {
                    HStack {
                        Circle()
                            .fill(Color(hex: selectedThemeColor) ?? .blue)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Text(name.isEmpty ? "?" : String(name.prefix(1)))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                            .shadow(radius: 3)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name.isEmpty ? "お名前未入力" : name)
                                .font(.headline)
                                .foregroundColor(name.isEmpty ? .secondary : .primary)
                            
                            Text("お手伝い単価設定済み")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    Button(action: saveChild) {
                        HStack {
                            Image(systemName: isEditing ? "checkmark.circle.fill" : "plus.circle.fill")
                            Text(isEditing ? "更新" : "追加")
                        }
                    }
                    .primaryGradientButton(isDisabled: !isValidInput)
                    .disabled(!isValidInput)
                    .accessibilityIdentifier("main_save_button")
                }
            }
            .navigationTitle(isEditing ? "子供情報編集" : "新しい子供追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .accessibilityIdentifier("cancel_button")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "更新" : "追加") {
                        saveChild()
                    }
                    .disabled(!isValidInput)
                    .accessibilityIdentifier("save_button")
                }
            }
            .alert("エラー", isPresented: .constant(viewModel.viewState.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearErrorMessage()
                }
            } message: {
                Text(viewModel.viewState.errorMessage ?? "")
            }
            .alert("成功", isPresented: .constant(viewModel.viewState.successMessage != nil)) {
                Button("OK") {
                    viewModel.clearMessages()
                    dismiss()
                }
            } message: {
                Text(viewModel.viewState.successMessage ?? "")
            }
        }
        .onAppear {
            setupInitialValues()
            viewModel.clearMessages()
        }
    }
    
    private var isValidInput: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func setupInitialValues() {
        if let child = editingChild {
            name = child.name
            selectedThemeColor = child.themeColor
        }
    }
    
    private func saveChild() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Task {
            if let child = editingChild {
                await viewModel.updateChild(id: child.id, name: trimmedName, themeColor: selectedThemeColor)
            } else {
                await viewModel.addChild(name: trimmedName, themeColor: selectedThemeColor)
            }
        }
    }
}

struct ColorSelectionButton: View {
    let color: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            Circle()
                .fill(Color(hex: color) ?? .gray)
                .frame(width: 50, height: 50)
                .overlay(
                    Circle()
                        .stroke(isSelected ? .black : .clear, lineWidth: 3)
                )
                .shadow(radius: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let repository = CoreDataChildRepository(context: context)
    ChildFormView(viewModel: ChildManagementViewModel(childRepository: repository), editingChild: nil)
}
