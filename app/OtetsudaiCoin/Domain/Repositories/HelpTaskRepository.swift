import Foundation

protocol HelpTaskRepository {
    func save(_ helpTask: HelpTask) async throws
    func findById(_ id: UUID) async throws -> HelpTask?
    func findAll() async throws -> [HelpTask]
    func findActive() async throws -> [HelpTask]
    func delete(_ id: UUID) async throws
    func update(_ helpTask: HelpTask) async throws
}