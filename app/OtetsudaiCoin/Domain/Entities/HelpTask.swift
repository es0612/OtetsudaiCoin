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
    
    static func defaultTasks() -> [HelpTask] {
        let taskNames = [
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
        
        return taskNames.map { name in
            HelpTask(id: UUID(), name: name, isActive: true, coinRate: 10)
        }
    }
}