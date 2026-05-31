//
//  Persistence.swift
//  OtetsudaiCoin
//  
//  Created on 2025/06/15
//


import CoreData
import os.log

/// Core Dataの永続化エラー
enum PersistenceError: LocalizedError {
    case storeLoadingFailed(Error)
    case contextSaveFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .storeLoadingFailed(let error):
            return String(localized: "データベースの読み込みに失敗しました") + ": " + error.localizedDescription
        case .contextSaveFailed(let error):
            return String(localized: "データの保存に失敗しました") + ": " + error.localizedDescription
        }
    }
}

@MainActor
struct PersistenceController {
    // `shared` を @MainActor 隔離のままにすると nonisolated な init の default 引数
    // (`persistenceController: PersistenceController = .shared`) から同期参照できず
    // "main actor-isolated static property 'shared' can not be referenced from a
    // nonisolated context" 警告 (Swift 6 では error) を 3 つの CoreData リポジトリで出す。
    // 型は @MainActor 由来で Sendable なので `shared` を nonisolated 化すれば解消できる
    // (compiler も "nonisolated(unsafe) is unnecessary for Sendable type" と指摘)。
    // それには init を nonisolated 化する必要があり、init が参照する logger も併せて
    // 隔離解除する (logger=Sendable で平 nonisolated)。いずれも単一インスタンスの不変
    // `let` で挙動は不変 (#90)。
    nonisolated static let shared = PersistenceController()

    private nonisolated static let logger = Logger(subsystem: "com.asapapalab.OtetsudaiCoin", category: "CoreData")

    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for _ in 0..<10 {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
        }
        do {
            try viewContext.save()
        } catch {
            // プレビュー環境でのエラーハンドリング
            Self.logger.error("プレビューデータの保存に失敗しました: \(error.localizedDescription)")
            // プレビュー環境では続行可能
        }
        return result
    }()

    let container: NSPersistentContainer

    nonisolated init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "OtetsudaiCoin")
        if inMemory {
            guard let storeDescription = container.persistentStoreDescriptions.first else {
                Self.logger.error("永続ストア記述子が見つかりません")
                return
            }
            storeDescription.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error {
                // エラーログの出力
                Self.logger.error("Core Dataストアの読み込みに失敗しました: \(error.localizedDescription)")

                /*
                 本番環境では以下のような対応を検討:
                 * ストアファイルの削除と再作成
                 * ユーザーへのエラーメッセージ表示
                 * 代替データストアの使用
                 * エラー報告機能の活用
                 */
                
                // デバッグ環境では詳細なエラー情報を表示
                #if DEBUG
                let nsError = error as NSError
                print("Core Data エラー詳細: \(nsError), \(nsError.userInfo)")
                #endif
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // Core Dataのコンテキストがメインスレッドで動作することを保証
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    /// メインスレッドでのコンテキスト保存
    func saveContext() throws {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                Self.logger.error("コンテキストの保存に失敗しました: \(error.localizedDescription)")
                throw PersistenceError.contextSaveFailed(error)
            }
        }
    }
}
