import Foundation

protocol HelpRecordRepository {
    func save(_ helpRecord: HelpRecord) async throws
    func findById(_ id: UUID) async throws -> HelpRecord?
    func findAll() async throws -> [HelpRecord]
    func findByChildId(_ childId: UUID) async throws -> [HelpRecord]
    func findByChildIdInCurrentMonth(_ childId: UUID) async throws -> [HelpRecord]
    func delete(_ id: UUID) async throws
}