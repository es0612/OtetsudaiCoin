import Foundation
import Combine

/// アプリ内通知の名前を定義
extension Notification.Name {
    static let helpRecordUpdated = Notification.Name("helpRecordUpdated")
    static let childrenUpdated = Notification.Name("childrenUpdated")
    static let tasksUpdated = Notification.Name("tasksUpdated")
}

/// アプリ内通知を一元管理するクラス
@Observable
class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    /// お手伝い記録が更新されたことを通知
    func notifyHelpRecordUpdated() {
        NotificationCenter.default.post(name: .helpRecordUpdated, object: nil)
    }
    
    /// 子供データが更新されたことを通知
    func notifyChildrenUpdated() {
        NotificationCenter.default.post(name: .childrenUpdated, object: nil)
    }
    
    /// タスクデータが更新されたことを通知
    func notifyTasksUpdated() {
        NotificationCenter.default.post(name: .tasksUpdated, object: nil)
    }
    
    /// お手伝い記録更新の監視を設定
    /// - Parameters:
    ///   - action: 通知受信時に実行するアクション
    ///   - cancellables: Cancellableを格納するSet
    func observeHelpRecordUpdates(
        action: @escaping () -> Void,
        cancellables: inout Set<AnyCancellable>
    ) {
        NotificationCenter.default
            .publisher(for: .helpRecordUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // メモリリーク防止のためweak参照を使用し、同期実行でタスク生成を避ける
                guard self != nil else { return }
                action()
            }
            .store(in: &cancellables)
    }
    
    /// 子供データ更新の監視を設定
    /// - Parameters:
    ///   - action: 通知受信時に実行するアクション
    ///   - cancellables: Cancellableを格納するSet
    func observeChildrenUpdates(
        action: @escaping () -> Void,
        cancellables: inout Set<AnyCancellable>
    ) {
        NotificationCenter.default
            .publisher(for: .childrenUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // メモリリーク防止のためweak参照を使用し、同期実行でタスク生成を避ける
                guard self != nil else { return }
                action()
            }
            .store(in: &cancellables)
    }
    
    /// タスクデータ更新の監視を設定
    /// - Parameters:
    ///   - action: 通知受信時に実行するアクション
    ///   - cancellables: Cancellableを格納するSet
    func observeTasksUpdates(
        action: @escaping () -> Void,
        cancellables: inout Set<AnyCancellable>
    ) {
        NotificationCenter.default
            .publisher(for: .tasksUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // メモリリーク防止のためweak参照を使用し、同期実行でタスク生成を避ける
                guard self != nil else { return }
                action()
            }
            .store(in: &cancellables)
    }
}