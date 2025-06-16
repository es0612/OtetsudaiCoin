import Foundation
import CoreData

class CoreDataHelpTaskRepository: HelpTaskRepository {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func save(_ helpTask: HelpTask) async throws {
        let cdHelpTask = CDHelpTask(context: context)
        cdHelpTask.id = helpTask.id
        cdHelpTask.name = helpTask.name
        cdHelpTask.isActive = helpTask.isActive
        
        try context.save()
    }
    
    func findById(_ id: UUID) async throws -> HelpTask? {
        let request: NSFetchRequest<CDHelpTask> = CDHelpTask.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        let results = try context.fetch(request)
        return results.first?.toDomain()
    }
    
    func findAll() async throws -> [HelpTask] {
        let request: NSFetchRequest<CDHelpTask> = CDHelpTask.fetchRequest()
        let results = try context.fetch(request)
        return results.compactMap { $0.toDomain() }
    }
    
    func findActive() async throws -> [HelpTask] {
        let request: NSFetchRequest<CDHelpTask> = CDHelpTask.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        let results = try context.fetch(request)
        return results.compactMap { $0.toDomain() }
    }
    
    func delete(_ id: UUID) async throws {
        let request: NSFetchRequest<CDHelpTask> = CDHelpTask.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        let results = try context.fetch(request)
        for result in results {
            context.delete(result)
        }
        
        try context.save()
    }
    
    func update(_ helpTask: HelpTask) async throws {
        let request: NSFetchRequest<CDHelpTask> = CDHelpTask.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", helpTask.id as CVarArg)
        request.fetchLimit = 1
        
        let results = try context.fetch(request)
        if let cdHelpTask = results.first {
            cdHelpTask.name = helpTask.name
            cdHelpTask.isActive = helpTask.isActive
            try context.save()
        }
    }
}

extension CDHelpTask {
    func toDomain() -> HelpTask? {
        guard let id = self.id,
              let name = self.name else {
            return nil
        }
        
        return HelpTask(id: id, name: name, isActive: self.isActive)
    }
}