import Foundation
import CoreData

@MainActor
class CoreDataAllowancePaymentRepository: AllowancePaymentRepository {
    private let context: NSManagedObjectContext
    private let persistenceController: PersistenceController

    init(context: NSManagedObjectContext, persistenceController: PersistenceController = .shared) {
        self.context = context
        self.persistenceController = persistenceController
    }

    /// InMemory 版と同じ upsert セマンティクス: id 一致で置換、無ければ新規作成。
    func save(_ payment: AllowancePayment) async throws {
        let request: NSFetchRequest<CDAllowancePayment> = CDAllowancePayment.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", payment.id as CVarArg)
        request.fetchLimit = 1

        let cdPayment = try context.fetch(request).first ?? CDAllowancePayment(context: context)
        apply(payment, to: cdPayment)

        try persistenceController.saveContext()
    }

    func findById(_ id: UUID) async throws -> AllowancePayment? {
        let request: NSFetchRequest<CDAllowancePayment> = CDAllowancePayment.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        let results = try context.fetch(request)
        return results.first?.toDomain()
    }

    func findAll() async throws -> [AllowancePayment] {
        let request: NSFetchRequest<CDAllowancePayment> = CDAllowancePayment.fetchRequest()
        let results = try context.fetch(request)
        return results.compactMap { $0.toDomain() }
    }

    func findByChildId(_ childId: UUID) async throws -> [AllowancePayment] {
        let request: NSFetchRequest<CDAllowancePayment> = CDAllowancePayment.fetchRequest()
        request.predicate = NSPredicate(format: "childId == %@", childId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "paidAt", ascending: false)]
        let results = try context.fetch(request)
        return results.compactMap { $0.toDomain() }
    }

    func findByChildIdAndMonth(_ childId: UUID, month: Int, year: Int) async throws -> AllowancePayment? {
        let request: NSFetchRequest<CDAllowancePayment> = CDAllowancePayment.fetchRequest()
        request.predicate = NSPredicate(
            format: "childId == %@ AND month == %d AND year == %d",
            childId as CVarArg, month, year
        )
        request.fetchLimit = 1

        let results = try context.fetch(request)
        return results.first?.toDomain()
    }

    func findByDateRange(from startDate: Date, to endDate: Date) async throws -> [AllowancePayment] {
        let request: NSFetchRequest<CDAllowancePayment> = CDAllowancePayment.fetchRequest()
        request.predicate = NSPredicate(
            format: "paidAt >= %@ AND paidAt <= %@",
            startDate as CVarArg, endDate as CVarArg
        )
        request.sortDescriptors = [NSSortDescriptor(key: "paidAt", ascending: false)]
        let results = try context.fetch(request)
        return results.compactMap { $0.toDomain() }
    }

    func delete(_ id: UUID) async throws {
        let request: NSFetchRequest<CDAllowancePayment> = CDAllowancePayment.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        let results = try context.fetch(request)
        for result in results {
            context.delete(result)
        }

        try persistenceController.saveContext()
    }

    func update(_ payment: AllowancePayment) async throws {
        // InMemory 版と同様、update は upsert として save に委譲する
        try await save(payment)
    }

    private func apply(_ payment: AllowancePayment, to cdPayment: CDAllowancePayment) {
        cdPayment.id = payment.id
        cdPayment.childId = payment.childId
        cdPayment.amount = Int32(payment.amount)
        cdPayment.month = Int16(payment.month)
        cdPayment.year = Int16(payment.year)
        cdPayment.paidAt = payment.paidAt
        cdPayment.note = payment.note
    }
}

extension CDAllowancePayment {
    func toDomain() -> AllowancePayment? {
        guard let id = self.id,
              let childId = self.childId,
              let paidAt = self.paidAt else {
            return nil
        }

        return AllowancePayment(
            id: id,
            childId: childId,
            amount: Int(self.amount),
            month: Int(self.month),
            year: Int(self.year),
            paidAt: paidAt,
            note: self.note
        )
    }
}
