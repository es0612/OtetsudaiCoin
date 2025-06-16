import XCTest
import CoreData
@testable import OtetsudaiCoin

final class CoreDataChildRepositoryTests: XCTestCase {
    private var repository: CoreDataChildRepository!
    private var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        
        let persistentContainer = NSPersistentContainer(name: "OtetsudaiCoin")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        persistentContainer.persistentStoreDescriptions = [description]
        
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load store: \(error)")
            }
        }
        
        context = persistentContainer.viewContext
        repository = CoreDataChildRepository(context: context)
    }
    
    override func tearDown() {
        repository = nil
        context = nil
        super.tearDown()
    }
    
    func testSaveAndFindById() async throws {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        
        try await repository.save(child)
        let foundChild = try await repository.findById(child.id)
        
        XCTAssertEqual(foundChild, child)
    }
    
    func testFindAll() async throws {
        let child1 = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let child2 = Child(id: UUID(), name: "花子", themeColor: "#33FF57")
        
        try await repository.save(child1)
        try await repository.save(child2)
        
        let allChildren = try await repository.findAll()
        
        XCTAssertEqual(allChildren.count, 2)
        XCTAssertTrue(allChildren.contains(child1))
        XCTAssertTrue(allChildren.contains(child2))
    }
    
    func testUpdate() async throws {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        try await repository.save(child)
        
        let updatedChild = Child(id: child.id, name: "太郎くん", themeColor: "#3357FF")
        try await repository.update(updatedChild)
        
        let foundChild = try await repository.findById(child.id)
        XCTAssertEqual(foundChild, updatedChild)
    }
    
    func testDelete() async throws {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        try await repository.save(child)
        
        try await repository.delete(child.id)
        
        let foundChild = try await repository.findById(child.id)
        XCTAssertNil(foundChild)
    }
}