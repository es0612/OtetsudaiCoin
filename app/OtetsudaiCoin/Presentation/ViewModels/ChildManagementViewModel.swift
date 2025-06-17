import Foundation
import Combine

@MainActor
class ChildManagementViewModel: ObservableObject {
    @Published var children: [Child] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    private let childRepository: ChildRepository
    
    private let themeColors: [String] = [
        "#FF5733", "#33FF57", "#3357FF", "#FF33F1", "#F1FF33",
        "#FF8333", "#33FFF1", "#8333FF", "#F133FF", "#33FF83",
        "#E91E63", "#9C27B0", "#673AB7", "#3F51B5", "#2196F3",
        "#00BCD4", "#009688", "#4CAF50", "#8BC34A", "#CDDC39",
        "#FFEB3B", "#FFC107", "#FF9800", "#FF5722", "#795548"
    ]
    
    init(childRepository: ChildRepository) {
        self.childRepository = childRepository
    }
    
    func loadChildren() async {
        isLoading = true
        errorMessage = nil
        
        do {
            children = try await childRepository.findAll()
        } catch {
            errorMessage = "子供情報の読み込みに失敗しました: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func addChild(name: String, themeColor: String, coinRate: Int) async {
        guard validateChildData(name: name, themeColor: themeColor, coinRate: coinRate) else {
            errorMessage = "入力データが無効です"
            return
        }
        
        errorMessage = nil
        successMessage = nil
        
        let child = Child(id: UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines), themeColor: themeColor, coinRate: coinRate)
        
        do {
            try await childRepository.save(child)
            await loadChildren()
            successMessage = "\(name)を追加しました"
        } catch {
            errorMessage = "子供の追加に失敗しました: \(error.localizedDescription)"
        }
    }
    
    func updateChild(id: UUID, name: String, themeColor: String, coinRate: Int) async {
        guard validateChildData(name: name, themeColor: themeColor, coinRate: coinRate) else {
            errorMessage = "入力データが無効です"
            return
        }
        
        errorMessage = nil
        successMessage = nil
        
        let updatedChild = Child(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), themeColor: themeColor, coinRate: coinRate)
        
        do {
            try await childRepository.update(updatedChild)
            await loadChildren()
            successMessage = "\(name)の情報を更新しました"
        } catch {
            errorMessage = "子供の更新に失敗しました: \(error.localizedDescription)"
        }
    }
    
    func deleteChild(id: UUID) async {
        guard let child = children.first(where: { $0.id == id }) else {
            errorMessage = "削除対象の子供が見つかりません"
            return
        }
        
        errorMessage = nil
        successMessage = nil
        
        do {
            try await childRepository.delete(id)
            await loadChildren()
            successMessage = "\(child.name)を削除しました"
        } catch {
            errorMessage = "子供の削除に失敗しました: \(error.localizedDescription)"
        }
    }
    
    func validateChildData(name: String, themeColor: String, coinRate: Int) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else { return false }
        guard Child.isValidThemeColor(themeColor) else { return false }
        guard Child.isValidCoinRate(coinRate) else { return false }
        
        return true
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
    
    func getAvailableThemeColors() -> [String] {
        return themeColors
    }
}