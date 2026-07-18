import Foundation

#if DEBUG
/// 開発用サンプルデータ管理サービス
/// リリースビルドには含まれません
class SampleDataService {
    private let childRepository: ChildRepository
    private let helpTaskRepository: HelpTaskRepository
    private let helpRecordRepository: HelpRecordRepository
    
    init(
        childRepository: ChildRepository,
        helpTaskRepository: HelpTaskRepository,
        helpRecordRepository: HelpRecordRepository
    ) {
        self.childRepository = childRepository
        self.helpTaskRepository = helpTaskRepository
        self.helpRecordRepository = helpRecordRepository
    }
    
    /// 3ヶ月分のサンプルデータを生成
    func generateSampleData() async throws {
        // サンプル子供データ
        let children = [
            Child(id: UUID(), name: "太郎", themeColor: "#E8590C"),
            Child(id: UUID(), name: "花子", themeColor: "#099268")
        ]
        
        // サンプルタスクデータ（sortOrder 連番付き）
        let helpTasks = Self.sampleHelpTasks()
        
        // 子供を保存
        for child in children {
            try await childRepository.save(child)
        }
        
        // タスクを保存
        for task in helpTasks {
            try await helpTaskRepository.save(task)
        }
        
        // 過去3ヶ月分のお手伝い記録を生成
        let calendar = Calendar.current
        let now = Date()
        let startDate = calendar.date(byAdding: .month, value: -3, to: now) ?? now
        
        var records: [HelpRecord] = []
        
        // 日付を3ヶ月前から現在まで繰り返し
        var currentDate = startDate
        while currentDate <= now {
            // 各日で0〜4回のお手伝い記録を生成（ランダム）
            let recordsPerDay = Int.random(in: 0...4)
            
            for _ in 0..<recordsPerDay {
                guard let randomChild = children.randomElement(),
                      let randomTask = helpTasks.randomElement() else {
                    continue // 配列が空の場合は次の反復へ
                }
                
                // その日の中でランダムな時間に設定
                let randomHour = Int.random(in: 7...20)
                let randomMinute = Int.random(in: 0...59)
                
                var dateComponents = calendar.dateComponents([.year, .month, .day], from: currentDate)
                dateComponents.hour = randomHour
                dateComponents.minute = randomMinute
                
                if let recordDate = calendar.date(from: dateComponents) {
                    let record = HelpRecord(
                        id: UUID(),
                        childId: randomChild.id,
                        helpTaskId: randomTask.id,
                        recordedAt: recordDate
                    )
                    records.append(record)
                }
            }
            
            // 次の日に進む
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        // 記録を保存
        for record in records {
            try await helpRecordRepository.save(record)
        }
        
        DebugLogger.debug("📊 サンプルデータを生成しました: 子供 \(children.count)人 / タスク \(helpTasks.count)個 / 記録 \(records.count)件（過去3ヶ月分）")
    }
    
    /// 全てのサンプルデータを削除
    func clearAllData() async throws {
        // 全てのお手伝い記録を削除
        let allRecords = try await helpRecordRepository.findAll()
        for record in allRecords {
            try await helpRecordRepository.delete(record.id)
        }
        
        // 全てのタスクを削除
        let allTasks = try await helpTaskRepository.findAll()
        for task in allTasks {
            try await helpTaskRepository.delete(task.id)
        }
        
        // 全ての子供を削除
        let allChildren = try await childRepository.findAll()
        for child in allChildren {
            try await childRepository.delete(child.id)
        }
        
        DebugLogger.debug("🗑️ 全てのデータを削除しました")
    }
    
    /// 記録のみを削除（子供とタスクは保持）
    func clearRecordsOnly() async throws {
        let allRecords = try await helpRecordRepository.findAll()
        for record in allRecords {
            try await helpRecordRepository.delete(record.id)
        }

        DebugLogger.debug("🗑️ 記録データのみ削除しました（\(allRecords.count)件）")
    }

    /// サンプルタスク定義。sortOrder を 0 始まりの連番で付与し、
    /// 並べ替え機能の DEBUG 検証時に決定的な初期順序を保証する (#130-⑥)。
    static func sampleHelpTasks() -> [HelpTask] {
        let specs: [(name: String, coinRate: Int)] = [
            ("洗い物", 10),
            ("洗濯物たたみ", 15),
            ("掃除機かけ", 20),
            ("おもちゃの片付け", 5),
            ("お風呂掃除", 25),
            ("ゴミ出し", 10)
        ]
        return specs.enumerated().map { index, spec in
            HelpTask(id: UUID(), name: spec.name, isActive: true, coinRate: spec.coinRate, sortOrder: index)
        }
    }
}
#endif
