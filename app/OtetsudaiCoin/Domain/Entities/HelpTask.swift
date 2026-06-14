import Foundation

struct HelpTask: Equatable {
    let id: UUID
    let name: String
    let isActive: Bool
    let coinRate: Int
    let sortOrder: Int

    init(id: UUID, name: String, isActive: Bool, coinRate: Int = 10, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.coinRate = coinRate
        self.sortOrder = sortOrder
    }
    
    static func == (lhs: HelpTask, rhs: HelpTask) -> Bool {
        return lhs.id == rhs.id
    }
    
    func deactivate() -> HelpTask {
        return HelpTask(id: id, name: name, isActive: false, coinRate: coinRate, sortOrder: sortOrder)
    }

    func activate() -> HelpTask {
        return HelpTask(id: id, name: name, isActive: true, coinRate: coinRate, sortOrder: sortOrder)
    }

    func updateCoinRate(_ newRate: Int) -> HelpTask {
        return HelpTask(id: id, name: name, isActive: isActive, coinRate: newRate, sortOrder: sortOrder)
    }

    func updatingSortOrder(_ newOrder: Int) -> HelpTask {
        return HelpTask(id: id, name: name, isActive: isActive, coinRate: coinRate, sortOrder: newOrder)
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
    /// 既知の許容トレードオフ: en ロケでデフォルト名を「その en 訳と完全一致する文字列」へ
    /// 改名すると無変更とみなされ rename が破棄される(表示は元のまま)。display-time lookup の
    /// 設計上の帰結であり意図的。安易に「修正」しないこと。
    static func resolvePersistedName(editedText: String, original: HelpTask) -> String {
        let trimmed = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == original.displayName ? original.name : trimmed
    }

    static func defaultTasks() -> [HelpTask] {
        return defaultTaskNames.enumerated().map { index, name in
            HelpTask(id: UUID(), name: name, isActive: true, coinRate: 10, sortOrder: index)
        }
    }
}