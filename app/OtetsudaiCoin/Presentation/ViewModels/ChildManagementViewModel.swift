import Foundation

@MainActor
@Observable
class ChildManagementViewModel: BaseViewModel {
    var children: [Child] = []
    
    private let childRepository: ChildRepository
    private var loadChildrenTask: Task<Void, Never>?
    
    private let themeColors: [String] = [
        "#E8590C", // ブランドオレンジ
        "#FAB005", // ハニーイエロー
        "#66A80F", // ライム
        "#2F9E44", // グリーン
        "#099268", // ブランドティール
        "#0C8599", // シアン
        "#1C7ED6", // ブルー
        "#3B5BDB", // インディゴ
        "#7048E8", // バイオレット
        "#AE3EC9", // グレープ
        "#D6336C", // ピンク
        "#E03131"  // レッド
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
                setLoading(false)
            }
        }
        
        // タスクの完了を待つ
        await loadChildrenTask?.value
    }
    
    func addChild(name: String, themeColor: String) async {
        guard validateChildData(name: name, themeColor: themeColor) else {
            setError(String(localized: "入力データが無効です"))
            return
        }

        // 名前の重複チェック
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if children.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            setError(String(localized: "同じ名前の子供が既に登録されています"))
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
            setError(String(localized: "入力データが無効です"))
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
            setError(String(localized: "削除対象の子供が見つかりません"))
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