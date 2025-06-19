import Foundation

protocol AllowancePaymentRepository {
    func save(_ payment: AllowancePayment) async throws
    func findById(_ id: UUID) async throws -> AllowancePayment?
    func findAll() async throws -> [AllowancePayment]
    func findByChildId(_ childId: UUID) async throws -> [AllowancePayment]
    func findByChildIdAndMonth(_ childId: UUID, month: Int, year: Int) async throws -> AllowancePayment?
    func findByDateRange(from startDate: Date, to endDate: Date) async throws -> [AllowancePayment]
    func delete(_ id: UUID) async throws
    func update(_ payment: AllowancePayment) async throws
}