import Foundation

class TutorialService: ObservableObject {
    @Published var isFirstLaunch: Bool = true
    @Published var hasCompletedChildTutorial: Bool = false
    @Published var hasCompletedRecordTutorial: Bool = false
    @Published var showTutorial: Bool = false
    
    private let userDefaults = UserDefaults.standard
    
    private enum Keys: String {
        case hasLaunchedBefore = "hasLaunchedBefore"
        case hasCompletedChildTutorial = "hasCompletedChildTutorial"
        case hasCompletedRecordTutorial = "hasCompletedRecordTutorial"
    }
    
    init() {
        loadTutorialState()
        checkFirstLaunch()
    }
    
    func checkFirstLaunch() {
        // UIテスト実行時はチュートリアルをスキップ
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            hasCompletedChildTutorial = true
            hasCompletedRecordTutorial = true
            showTutorial = false
            return
        }
        
        isFirstLaunch = !userDefaults.bool(forKey: Keys.hasLaunchedBefore.rawValue)
        
        if isFirstLaunch {
            showTutorial = true
            userDefaults.set(true, forKey: Keys.hasLaunchedBefore.rawValue)
        } else {
            // 既存ユーザーでも、子供が登録されていない場合はチュートリアルを表示
            showTutorial = !hasCompletedChildTutorial
        }
    }
    
    func markChildTutorialCompleted() {
        hasCompletedChildTutorial = true
        userDefaults.set(true, forKey: Keys.hasCompletedChildTutorial.rawValue)
        saveTutorialState()
    }
    
    func markRecordTutorialCompleted() {
        hasCompletedRecordTutorial = true
        userDefaults.set(true, forKey: Keys.hasCompletedRecordTutorial.rawValue)
        saveTutorialState()
    }
    
    func completeTutorial() {
        showTutorial = false
        markChildTutorialCompleted()
        markRecordTutorialCompleted()
    }
    
    func resetTutorial() {
        // デバッグ用: チュートリアルをリセット
        isFirstLaunch = true
        hasCompletedChildTutorial = false
        hasCompletedRecordTutorial = false
        showTutorial = true
        
        userDefaults.removeObject(forKey: Keys.hasLaunchedBefore.rawValue)
        userDefaults.removeObject(forKey: Keys.hasCompletedChildTutorial.rawValue)
        userDefaults.removeObject(forKey: Keys.hasCompletedRecordTutorial.rawValue)
    }
    
    var shouldShowChildTutorial: Bool {
        return showTutorial && !hasCompletedChildTutorial
    }
    
    var shouldShowRecordTutorial: Bool {
        return showTutorial && hasCompletedChildTutorial && !hasCompletedRecordTutorial
    }
    
    private func loadTutorialState() {
        hasCompletedChildTutorial = userDefaults.bool(forKey: Keys.hasCompletedChildTutorial.rawValue)
        hasCompletedRecordTutorial = userDefaults.bool(forKey: Keys.hasCompletedRecordTutorial.rawValue)
    }
    
    private func saveTutorialState() {
        userDefaults.set(hasCompletedChildTutorial, forKey: Keys.hasCompletedChildTutorial.rawValue)
        userDefaults.set(hasCompletedRecordTutorial, forKey: Keys.hasCompletedRecordTutorial.rawValue)
    }
}