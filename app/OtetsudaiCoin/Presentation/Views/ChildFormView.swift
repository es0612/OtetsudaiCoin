import SwiftUI

struct ChildFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ChildManagementViewModel
    
    let editingChild: Child?
    
    @State private var name: String = ""
    @State private var selectedThemeColor: String = "#FF5733"
    @State private var coinRate: String = "100"
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
                    
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        
                        TextField("コイン単価", text: $coinRate)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("コイン")
                            .foregroundColor(.secondary)
                    }
                    .accessibilityIdentifier("coin_rate_field")
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
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                            ForEach(viewModel.getAvailableThemeColors(), id: \.self) { color in
                                Button(action: {
                                    selectedThemeColor = color
                                    showingColorPicker = false
                                }) {
                                    Circle()
                                        .fill(Color(hex: color) ?? .gray)
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Circle()
                                                .stroke(selectedThemeColor == color ? .black : .clear, lineWidth: 3)
                                        )
                                        .shadow(radius: 1)
                                }
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
                            
                            Text("\(coinRate)コイン/回")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)
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
                    dismiss()
                }
            } message: {
                Text(viewModel.successMessage ?? "")
            }
        }
        .onAppear {
            setupInitialValues()
        }
    }
    
    private var isValidInput: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(coinRate) != nil &&
        Int(coinRate)! > 0
    }
    
    private func setupInitialValues() {
        if let child = editingChild {
            name = child.name
            selectedThemeColor = child.themeColor
            coinRate = String(child.coinRate)
        }
    }
    
    private func saveChild() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rate = Int(coinRate), rate > 0 else { return }
        
        Task {
            if let child = editingChild {
                await viewModel.updateChild(id: child.id, name: trimmedName, themeColor: selectedThemeColor, coinRate: rate)
            } else {
                await viewModel.addChild(name: trimmedName, themeColor: selectedThemeColor, coinRate: rate)
            }
        }
    }
}


#Preview {
    let context = PersistenceController.preview.container.viewContext
    let repository = CoreDataChildRepository(context: context)
    ChildFormView(viewModel: ChildManagementViewModel(childRepository: repository), editingChild: nil)
}