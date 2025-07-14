import Foundation
import CoreData

class CoreDataHelpTaskRepository: HelpTaskRepository {
    private let viewContext: NSManagedObjectContext
    private let persistenceController: PersistenceController
    
    init(context: NSManagedObjectContext, persistenceController: PersistenceController = .shared) {
        self.viewContext = context
        self.persistenceController = persistenceController
        DebugLogger.info("CoreDataHelpTaskRepository initialized")
    }
    
    private func createBackgroundContext() -> NSManagedObjectContext {
        DebugLogger.debug("Creating background context for Core Data operations")
        let context = persistenceController.container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    func save(_ helpTask: HelpTask) async throws {
        DebugLogger.logTaskStart(taskName: "save HelpTask")
        let startTime = Date()
        
        try await withCheckedThrowingContinuation { continuation in
            let backgroundContext = createBackgroundContext()
            
            backgroundContext.perform {
                do {
                    DebugLogger.logCoreDataOperation("Creating CDHelpTask", context: "ID: \(helpTask.id)")
                    let cdHelpTask = CDHelpTask(context: backgroundContext)
                    cdHelpTask.id = helpTask.id
                    cdHelpTask.name = helpTask.name
                    cdHelpTask.isActive = helpTask.isActive
                    cdHelpTask.coinRate = Int32(helpTask.coinRate)
                    
                    DebugLogger.logCoreDataOperation("Saving context")
                    try backgroundContext.save()
                    
                    DebugLogger.logTaskEnd(taskName: "save HelpTask", duration: Date().timeIntervalSince(startTime), success: true)
                    continuation.resume()
                } catch {
                    DebugLogger.logTaskEnd(taskName: "save HelpTask", duration: Date().timeIntervalSince(startTime), success: false, error: error)
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func findById(_ id: UUID) async throws -> HelpTask? {
        DebugLogger.logTaskStart(taskName: "findById HelpTask")
        let startTime = Date()
        
        return try await withCheckedThrowingContinuation { continuation in
            let backgroundContext = createBackgroundContext()
            
            backgroundContext.perform {
                do {
                    DebugLogger.logCoreDataOperation("Fetching HelpTask by ID", context: "ID: \(id)")
                    let request: NSFetchRequest<CDHelpTask> = CDHelpTask.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    request.fetchLimit = 1
                    
                    let results = try backgroundContext.fetch(request)
                    let helpTask = results.first?.toDomain()
                    
                    DebugLogger.logCoreDataOperation("findById completed", context: "Found: \(helpTask != nil)", success: true)
                    DebugLogger.logTaskEnd(taskName: "findById HelpTask", duration: Date().timeIntervalSince(startTime), success: true)
                    continuation.resume(returning: helpTask)
                } catch {
                    DebugLogger.logTaskEnd(taskName: "findById HelpTask", duration: Date().timeIntervalSince(startTime), success: false, error: error)
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func findAll() async throws -> [HelpTask] {
        DebugLogger.logTaskStart(taskName: "findAll HelpTasks")
        let startTime = Date()
        
        return try await withCheckedThrowingContinuation { continuation in
            let backgroundContext = createBackgroundContext()
            
            backgroundContext.perform {
                do {
                    DebugLogger.logCoreDataOperation("Fetching all HelpTasks")
                    let request: NSFetchRequest<CDHelpTask> = CDHelpTask.fetchRequest()
                    let results = try backgroundContext.fetch(request)
                    let helpTasks = results.compactMap { $0.toDomain() }
                    
                    DebugLogger.logCoreDataOperation("findAll completed", context: "Count: \(helpTasks.count)", success: true)
                    DebugLogger.logTaskEnd(taskName: "findAll HelpTasks", duration: Date().timeIntervalSince(startTime), success: true)
                    continuation.resume(returning: helpTasks)
                } catch {
                    DebugLogger.logTaskEnd(taskName: "findAll HelpTasks", duration: Date().timeIntervalSince(startTime), success: false, error: error)
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func findActive() async throws -> [HelpTask] {
        DebugLogger.logTaskStart(taskName: "findActive HelpTasks")
        let startTime = Date()
        
        return try await withCheckedThrowingContinuation { continuation in
            let backgroundContext = createBackgroundContext()
            
            backgroundContext.perform {
                do {
                    DebugLogger.logCoreDataOperation("Fetching active HelpTasks")
                    let request: NSFetchRequest<CDHelpTask> = CDHelpTask.fetchRequest()
                    request.predicate = NSPredicate(format: "isActive == YES")
                    let results = try backgroundContext.fetch(request)
                    let helpTasks = results.compactMap { $0.toDomain() }
                    
                    DebugLogger.logCoreDataOperation("findActive completed", context: "Active tasks count: \(helpTasks.count)", success: true)
                    DebugLogger.logTaskEnd(taskName: "findActive HelpTasks", duration: Date().timeIntervalSince(startTime), success: true)
                    continuation.resume(returning: helpTasks)
                } catch {
                    DebugLogger.logCoreDataOperation("findActive failed", error: error)
                    DebugLogger.logTaskEnd(taskName: "findActive HelpTasks", duration: Date().timeIntervalSince(startTime), success: false, error: error)
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func delete(_ id: UUID) async throws {
        DebugLogger.logTaskStart(taskName: "delete HelpTask")
        let startTime = Date()
        
        try await withCheckedThrowingContinuation { continuation in
            let backgroundContext = createBackgroundContext()
            
            backgroundContext.perform {
                do {
                    DebugLogger.logCoreDataOperation("Deleting HelpTask", context: "ID: \(id)")
                    let request: NSFetchRequest<CDHelpTask> = CDHelpTask.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    
                    let results = try backgroundContext.fetch(request)
                    for result in results {
                        backgroundContext.delete(result)
                    }
                    
                    try backgroundContext.save()
                    
                    DebugLogger.logCoreDataOperation("delete completed", context: "Deleted: \(results.count) items", success: true)
                    DebugLogger.logTaskEnd(taskName: "delete HelpTask", duration: Date().timeIntervalSince(startTime), success: true)
                    continuation.resume()
                } catch {
                    DebugLogger.logTaskEnd(taskName: "delete HelpTask", duration: Date().timeIntervalSince(startTime), success: false, error: error)
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func update(_ helpTask: HelpTask) async throws {
        DebugLogger.logTaskStart(taskName: "update HelpTask")
        let startTime = Date()
        
        try await withCheckedThrowingContinuation { continuation in
            let backgroundContext = createBackgroundContext()
            
            backgroundContext.perform {
                do {
                    DebugLogger.logCoreDataOperation("Updating HelpTask", context: "ID: \(helpTask.id)")
                    let request: NSFetchRequest<CDHelpTask> = CDHelpTask.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", helpTask.id as CVarArg)
                    request.fetchLimit = 1
                    
                    let results = try backgroundContext.fetch(request)
                    if let cdHelpTask = results.first {
                        cdHelpTask.name = helpTask.name
                        cdHelpTask.isActive = helpTask.isActive
                        cdHelpTask.coinRate = Int32(helpTask.coinRate)
                        try backgroundContext.save()
                        
                        DebugLogger.logCoreDataOperation("update completed", context: "Updated task: \(helpTask.name)", success: true)
                    } else {
                        DebugLogger.logCoreDataOperation("update failed", context: "Task not found for ID: \(helpTask.id)", success: false)
                    }
                    
                    DebugLogger.logTaskEnd(taskName: "update HelpTask", duration: Date().timeIntervalSince(startTime), success: true)
                    continuation.resume()
                } catch {
                    DebugLogger.logTaskEnd(taskName: "update HelpTask", duration: Date().timeIntervalSince(startTime), success: false, error: error)
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

extension CDHelpTask {
    func toDomain() -> HelpTask? {
        guard let id = self.id,
              let name = self.name else {
            return nil
        }
        
        return HelpTask(id: id, name: name, isActive: self.isActive, coinRate: Int(self.coinRate))
    }
}