import Foundation

@Observable
class TutorialService {
    var isFirstLaunch: Bool = true
    var hasCompletedChildTutorial: Bool = false
    var hasCompletedRecordTutorial: Bool = false
    var showTutorial: Bool = false
    
    private let userDefaults: UserDefaults

    private enum Keys: String {
        case hasLaunchedBefore = "hasLaunchedBefore"
        case hasCompletedChildTutorial = "hasCompletedChildTutorial"
        case hasCompletedRecordTutorial = "hasCompletedRecordTutorial"
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadTutorialState()
        checkFirstLaunch()
    }

    /// UIテスト起動時（`--uitesting` フラグ）かどうかを判定する pure helper。
    /// 判定ロジックを注入可能にして unit test で担保する。
    static func isUITesting(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains("--uitesting")
    }

    func checkFirstLaunch() {
        // UIテスト実行時はチュートリアルをスキップ
        if Self.isUITesting() {
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