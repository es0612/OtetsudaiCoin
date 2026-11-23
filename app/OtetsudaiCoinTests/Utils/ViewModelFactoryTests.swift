import XCTest
import CoreData
@testable import OtetsudaiCoin

/// ViewModelFactory の配線 (#310 (a))。
@MainActor
final class ViewModelFactoryTests: XCTestCase {
    private var persistenceController: PersistenceController!

    override func setUp() {
        super.setUp()
        persistenceController = PersistenceController(inMemory: true)
    }

    override func tearDown() {
        persistenceController = nil
        super.tearDown()
    }

    /// 設定画面の子どもの削除確認は、ContentView がこの factory で作る ViewModel の件数を使う。
    /// 記録の repository を渡し忘れると件数が nil になり、警告が出ないまま記録ごと消える。
    func test_childManagementViewModel_canCountRecords() async {
        let context = persistenceController.container.viewContext
        // repository の save は PersistenceController.shared に保存するため、
        // in-memory の context に直接入れる (fetch は未保存の挿入も返す)。
        // `CDChild(context:)` はテストでモデルが 2 つ読まれていると entity を決められないので、名前で入れる
        let childId = UUID()
        let cdChild = insert(CDChild.self, "CDChild", into: context)
        cdChild.id = childId
        cdChild.name = "太郎"
        cdChild.themeColor = "#E8590C"
        let cdTask = insert(CDHelpTask.self, "CDHelpTask", into: context)
        cdTask.id = UUID()
        cdTask.name = "お皿洗い"
        cdTask.isActive = true
        let cdRecord = insert(CDHelpRecord.self, "CDHelpRecord", into: context)
        cdRecord.id = UUID()
        cdRecord.recordedAt = Date(timeIntervalSince1970: 1_781_316_000)
        cdRecord.child = cdChild
        cdRecord.helpTask = cdTask

        let factory = ViewModelFactory(repositoryFactory: RepositoryFactory(context: context))
        let viewModel = factory.createChildManagementViewModel()

        let count = await viewModel.recordCount(forChildId: childId)

        XCTAssertEqual(count, 1)
    }

    private func insert<T: NSManagedObject>(_ type: T.Type, _ entityName: String, into context: NSManagedObjectContext) -> T {
        NSEntityDescription.insertNewObject(forEntityName: entityName, into: context) as! T
    }
}
