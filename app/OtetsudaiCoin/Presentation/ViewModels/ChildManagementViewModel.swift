import Foundation
import Combine


@MainActor
class ChildManagementViewModel: BaseViewModel {
    var children: [Child] = []
    
    private let childRepository: ChildRepository
    private var loadChildrenTask: Task<Void, Never>?
    
    private let themeColors: [String] = [
        "#FF5733", "#33FF57", "#3357FF", "#FF33F1", "#F1FF33",
        "#FF8333", "#33FFF1", "#8333FF", "#F133FF", "#33FF83",
        "#E91E63", "#9C27B0", "#673AB7", "#3F51B5", "#2196F3",
        "#00BCD4", "#009688", "#4CAF50", "#8BC34A", "#CDDC39",
        "#FFEB3B", "#FFC107", "#FF9800", "#FF5722", "#795548"
    ]
    
    init(childRepository: ChildRepository) {
        self.childRepository = childRepository
        super.init()
    }
    
    // deinitでは@MainActorプロパティにアクセスできないため削除
    // タスクはViewModelのライフサイクルとともに自動的にキャンセルされる
    
    func loadChildren() async {
        // 実行中のタスクをキャンセル
        loadChildrenTask?.cancel()
        
        setLoading(true)
        
        loadChildrenTask = Task {
            do {
                let loadedChildren = try await childRepository.findAll()
                
                // タスクがキャンセルされていないか確認
                guard !Task.isCancelled else { return }
                
                children = loadedChildren
                setLoading(false)
            } catch {
                guard !Task.isCancelled else { return }
                setUserFriendlyError(error)
            }
        }
        
        // タスクの完了を待つ
        await loadChildrenTask?.value
    }
    
    func addChild(name: String, themeColor: String) async {
        guard validateChildData(name: name, themeColor: themeColor) else {
            setError("入力データが無効です")
            return
        }
        
        // 名前の重複チェック
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if children.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            setError("同じ名前の子供が既に登録されています")
            return
        }
        
        clearMessages()
        
        let child = Child(id: UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines), themeColor: themeColor)
        
        do {
            try await childRepository.save(child)
            
            // UI更新を即座に反映
            children.append(child)
            
            // 確実にデータを再読み込み
            await loadChildren()
            
            // データ更新の通知
            NotificationManager.shared.notifyChildrenUpdated()
            
            setSuccess("\(name)を追加しました")
        } catch {
            setUserFriendlyError(error)
        }
    }
    
    func updateChild(id: UUID, name: String, themeColor: String) async {
        guard validateChildData(name: name, themeColor: themeColor) else {
            setError("入力データが無効です")
            return
        }
        
        clearMessages()
        
        let updatedChild = Child(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines), themeColor: themeColor)
        
        do {
            try await childRepository.update(updatedChild)
            await loadChildren()
            
            // データ更新の通知
            NotificationManager.shared.notifyChildrenUpdated()
            
            setSuccess("\(name)の情報を更新しました")
        } catch {
            setUserFriendlyError(error)
        }
    }
    
    func deleteChild(id: UUID) async {
        guard let child = children.first(where: { $0.id == id }) else {
            setError("削除対象の子供が見つかりません")
            return
        }
        
        clearMessages()
        
        do {
            try await childRepository.delete(id)
            await loadChildren()
            
            // データ更新の通知
            NotificationManager.shared.notifyChildrenUpdated()
            
            setSuccess("\(child.name)を削除しました")
        } catch {
            setUserFriendlyError(error)
        }
    }
    
    func validateChildData(name: String, themeColor: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else { return false }
        guard Child.isValidThemeColor(themeColor) else { return false }
        
        return true
    }
    
    func getAvailableThemeColors() -> [String] {
        return themeColors
    }
}