import Foundation

protocol ChildRepository {
    func save(_ child: Child) async throws
    func findById(_ id: UUID) async throws -> Child?
    func findAll() async throws -> [Child]
    func delete(_ id: UUID) async throws
    func update(_ child: Child) async throws
}