import Foundation

protocol HelpTaskRepository {
    func save(_ helpTask: HelpTask) async throws
    func findById(_ id: UUID) async throws -> HelpTask?
    func findAll() async throws -> [HelpTask]
    func findActive() async throws -> [HelpTask]
    func delete(_ id: UUID) async throws
    func update(_ helpTask: HelpTask) async throws

    /// orderedIds の並び順で sortOrder を 0..n-1 に採番して一括保存する。
    /// orderedIds に含まれない task の sortOrder は変更しない。
    func updateSortOrders(_ orderedIds: [UUID]) async throws
}