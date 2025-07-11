//
//  Persistence.swift
//  OtetsudaiCoin
//  
//  Created on 2025/06/15
//


import CoreData
import os.log
import Combine

/// Core Dataの永続化エラー
enum PersistenceError: LocalizedError {
    case storeLoadingFailed(Error)
    case contextSaveFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .storeLoadingFailed(let error):
            return "データベースの読み込みに失敗しました: \(error.localizedDescription)"
        case .contextSaveFailed(let error):
            return "データの保存に失敗しました: \(error.localizedDescription)"
        }
    }
}

@MainActor
struct PersistenceController {
    static let shared = PersistenceController()
    
    private static let logger = Logger(subsystem: "com.asapapalab.OtetsudaiCoin", category: "CoreData")
    
    /// 永続化エラーを通知するPublisher
    static let errorPublisher = PassthroughSubject<PersistenceError, Never>()

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

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "OtetsudaiCoin")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error {
                // エラーログの出力
                Self.logger.error("Core Dataストアの読み込みに失敗しました: \(error.localizedDescription)")
                
                // エラーを通知
                Self.errorPublisher.send(.storeLoadingFailed(error))
                
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
                Self.errorPublisher.send(.contextSaveFailed(error))
                throw PersistenceError.contextSaveFailed(error)
            }
        }
    }
}
