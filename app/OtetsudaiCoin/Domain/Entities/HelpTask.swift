import Foundation

struct HelpTask: Equatable {
    let id: UUID
    let name: String
    let isActive: Bool
    let coinRate: Int
    
    init(id: UUID, name: String, isActive: Bool, coinRate: Int = 10) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.coinRate = coinRate
    }
    
    static func == (lhs: HelpTask, rhs: HelpTask) -> Bool {
        return lhs.id == rhs.id
    }
    
    func deactivate() -> HelpTask {
        return HelpTask(id: id, name: name, isActive: false, coinRate: coinRate)
    }
    
    func activate() -> HelpTask {
        return HelpTask(id: id, name: name, isActive: true, coinRate: coinRate)
    }
    
    func updateCoinRate(_ newRate: Int) -> HelpTask {
        return HelpTask(id: id, name: name, isActive: isActive, coinRate: newRate)
    }

    static let defaultTaskNames: [String] = [
        "下の子の面倒を見る",
        "お風呂を入れる",
        "食器を出す",
        "食器を片付ける",
        "お片付けする",
        "玄関の靴を並べる",
        "ゴミ出しのお手伝い",
        "洗濯物を運ぶ",
        "テーブルを拭く",
        "自分の部屋の掃除"
    ]

    // defaultTaskNames と同期必須（en訳は .xcstrings で付与）。
    // Swift dict 側の漏れ → testEveryDefaultNameHasLocalizationEntry が検出
    // xcstrings の en 翻訳漏れ → testDefaultHelpTaskNamesHaveEnglishTranslation が検出
    static let defaultNameLocalizations: [String: LocalizedStringResource] = [
        "下の子の面倒を見る": "下の子の面倒を見る",
        "お風呂を入れる": "お風呂を入れる",
        "食器を出す": "食器を出す",
        "食器を片付ける": "食器を片付ける",
        "お片付けする": "お片付けする",
        "玄関の靴を並べる": "玄関の靴を並べる",
        "ゴミ出しのお手伝い": "ゴミ出しのお手伝い",
        "洗濯物を運ぶ": "洗濯物を運ぶ",
        "テーブルを拭く": "テーブルを拭く",
        "自分の部屋の掃除": "自分の部屋の掃除"
    ]

    var displayName: String {
        guard let resource = HelpTask.defaultNameLocalizations[name] else {
            return name // ユーザー作成・改名済みデフォルトは verbatim
        }
        return String(localized: resource) // en→翻訳 / ja→no-op
    }

    /// 編集フォームの保存名を解決する。表示値(displayName)のまま無変更で保存された場合は
    /// 元の保存名(name)を維持し、デフォルト名のロケール追従(翻訳)を壊さない。
    static func resolvePersistedName(editedText: String, original: HelpTask) -> String {
        let trimmed = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == original.displayName ? original.name : trimmed
    }

    static func defaultTasks() -> [HelpTask] {
        return defaultTaskNames.map { name in
            HelpTask(id: UUID(), name: name, isActive: true, coinRate: 10)
        }
    }
}