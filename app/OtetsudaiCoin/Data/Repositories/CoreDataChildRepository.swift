import Foundation
import CoreData

@MainActor
class CoreDataChildRepository: ChildRepository {
    private let context: NSManagedObjectContext
    private let persistenceController: PersistenceController
    
    init(context: NSManagedObjectContext, persistenceController: PersistenceController = .shared) {
        self.context = context
        self.persistenceController = persistenceController
    }
    
    func save(_ child: Child) async throws {
        let cdChild = CDChild(context: context)
        cdChild.id = child.id
        cdChild.name = child.name
        cdChild.themeColor = child.themeColor
        
        try persistenceController.saveContext()
    }
    
    func findById(_ id: UUID) async throws -> Child? {
        let request: NSFetchRequest<CDChild> = CDChild.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        let results = try context.fetch(request)
        return results.first?.toDomain()
    }
    
    func findAll() async throws -> [Child] {
        let request: NSFetchRequest<CDChild> = CDChild.fetchRequest()
        let results = try context.fetch(request)
        return results.compactMap { $0.toDomain() }
    }
    
    func delete(_ id: UUID) async throws {
        let request: NSFetchRequest<CDChild> = CDChild.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        let results = try context.fetch(request)
        for result in results {
            context.delete(result)
        }
        
        try persistenceController.saveContext()
    }
    
    func update(_ child: Child) async throws {
        let request: NSFetchRequest<CDChild> = CDChild.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", child.id as CVarArg)
        request.fetchLimit = 1
        
        let results = try context.fetch(request)
        if let cdChild = results.first {
            cdChild.name = child.name
            cdChild.themeColor = child.themeColor
            try persistenceController.saveContext()
        }
    }
}

extension CDChild {
    func toDomain() -> Child? {
        guard let id = self.id,
              let name = self.name,
              let themeColor = self.themeColor else {
            return nil
        }
        
        return Child(id: id, name: name, themeColor: themeColor)
    }
}