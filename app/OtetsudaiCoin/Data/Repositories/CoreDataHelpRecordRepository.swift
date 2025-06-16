import Foundation
import CoreData

class CoreDataHelpRecordRepository: HelpRecordRepository {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func save(_ helpRecord: HelpRecord) async throws {
        let cdHelpRecord = CDHelpRecord(context: context)
        cdHelpRecord.id = helpRecord.id
        cdHelpRecord.recordedAt = helpRecord.recordedAt
        
        let childRequest: NSFetchRequest<CDChild> = CDChild.fetchRequest()
        childRequest.predicate = NSPredicate(format: "id == %@", helpRecord.childId as CVarArg)
        if let cdChild = try context.fetch(childRequest).first {
            cdHelpRecord.child = cdChild
        }
        
        let taskRequest: NSFetchRequest<CDHelpTask> = CDHelpTask.fetchRequest()
        taskRequest.predicate = NSPredicate(format: "id == %@", helpRecord.helpTaskId as CVarArg)
        if let cdHelpTask = try context.fetch(taskRequest).first {
            cdHelpRecord.helpTask = cdHelpTask
        }
        
        try context.save()
    }
    
    func findById(_ id: UUID) async throws -> HelpRecord? {
        let request: NSFetchRequest<CDHelpRecord> = CDHelpRecord.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        let results = try context.fetch(request)
        return results.first?.toDomain()
    }
    
    func findAll() async throws -> [HelpRecord] {
        let request: NSFetchRequest<CDHelpRecord> = CDHelpRecord.fetchRequest()
        let results = try context.fetch(request)
        return results.compactMap { $0.toDomain() }
    }
    
    func findByChildId(_ childId: UUID) async throws -> [HelpRecord] {
        let request: NSFetchRequest<CDHelpRecord> = CDHelpRecord.fetchRequest()
        request.predicate = NSPredicate(format: "child.id == %@", childId as CVarArg)
        let results = try context.fetch(request)
        return results.compactMap { $0.toDomain() }
    }
    
    func findByChildIdInCurrentMonth(_ childId: UUID) async throws -> [HelpRecord] {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
        
        let request: NSFetchRequest<CDHelpRecord> = CDHelpRecord.fetchRequest()
        request.predicate = NSPredicate(format: "child.id == %@ AND recordedAt >= %@ AND recordedAt < %@", 
                                      childId as CVarArg, startOfMonth as CVarArg, endOfMonth as CVarArg)
        let results = try context.fetch(request)
        return results.compactMap { $0.toDomain() }
    }
    
    func delete(_ id: UUID) async throws {
        let request: NSFetchRequest<CDHelpRecord> = CDHelpRecord.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        let results = try context.fetch(request)
        for result in results {
            context.delete(result)
        }
        
        try context.save()
    }
}

extension CDHelpRecord {
    func toDomain() -> HelpRecord? {
        guard let id = self.id,
              let recordedAt = self.recordedAt,
              let childId = self.child?.id,
              let helpTaskId = self.helpTask?.id else {
            return nil
        }
        
        return HelpRecord(id: id, childId: childId, helpTaskId: helpTaskId, recordedAt: recordedAt)
    }
}