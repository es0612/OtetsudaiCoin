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

    /// ストア読み込みに失敗した場合のエラー（成功時は nil）。
    /// 失敗時はストアが attach されず全リポジトリが空返し / write 失敗になるため、
    /// アプリ root でこの値を見てエラー画面へ切り替える（Issue #131）。
    let storeLoadError: Error?

    nonisolated init(inMemory: Bool = false) {
        let storeURLOverride: URL?
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--force-store-load-failure") {
            // 視覚確認用: store URL を開けない URL に向けて load を故意に失敗させる
            storeURLOverride = Self.unopenableStoreURL()
        } else {
            storeURLOverride = inMemory ? URL(fileURLWithPath: "/dev/null") : nil
        }
        #else
        storeURLOverride = inMemory ? URL(fileURLWithPath: "/dev/null") : nil
        #endif
        self.init(storeURLOverride: storeURLOverride)
    }

    /// 指定イニシャライザ兼テスト seam。`storeURLOverride` に開けない URL（既存ディレクトリ等）を
    /// 渡すと load 失敗経路を決定的に再現できる。`nil` なら既定のストア記述子をそのまま使う。
    nonisolated init(storeURLOverride: URL?) {
        let container = NSPersistentContainer(name: "OtetsudaiCoin")
        if let storeURLOverride {
            if let storeDescription = container.persistentStoreDescriptions.first {
                // OtetsudaiCoin モデルは永続ストアが 1 つのため .first のみ書き換える。
                storeDescription.url = storeURLOverride
            } else {
                // モデル名が有効なら記述子は必ず 1 つ以上ある。空なら override が無視され
                // test seam / DEBUG visual-check の前提（指定 URL で load 失敗）が崩れるため、
                // 黙ってフォールバックせず気づけるようにする（early-return は不可: stored property 未初期化になる）。
                assertionFailure("persistentStoreDescriptions が空のため storeURLOverride を適用できません")
                Self.logger.error("persistentStoreDescriptions が空のため storeURLOverride を適用できません")
            }
        }

        var loadError: Error?
        container.loadPersistentStores { _, error in
            if let error = error {
                // ストア読み込み失敗。ログを残しつつエラーを捕捉して上位（root view）へ伝える。
                // local SQLite store は同期ロードのため、この closure は
                // loadPersistentStores の return 前に同期実行される（PersistenceControllerTests で実証）。
                Self.logger.error("Core Dataストアの読み込みに失敗しました: \(error.localizedDescription)")
                loadError = error
                let nsError = error as NSError
                DebugLogger.error("Core Data エラー詳細: \(nsError), \(nsError.userInfo)")
            }
        }

        self.container = container
        self.storeLoadError = loadError
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    #if DEBUG
    /// `--force-store-load-failure` 用: SQLite が開けない URL（既存ディレクトリ）を返す。
    private nonisolated static func unopenableStoreURL() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("force-store-load-failure", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    #endif
    
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
