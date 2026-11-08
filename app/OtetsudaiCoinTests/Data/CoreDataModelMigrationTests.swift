import XCTest
import CoreData
@testable import OtetsudaiCoin

/// Core Data モデルの軽量マイグレーションを、実際の SQLite ストアで検証する。
///
/// - 既存ユーザーの端末には v4 までのモデルで書かれたストアが残っている。v5 で
///   `CDAllowancePayment` におまけの 2 属性を足しても、そのストアが開けて既存の支払いが
///   そのまま読めることを証明する (#279)。
/// - in-memory ストアはマイグレーションしないので、一時ディレクトリの SQLite を使う。
/// - v4 のモデルで書いたストアは、まず現行モデルと「非互換」であることを確かめる。
///   これが無いと「そもそもマイグレーションが起きていない」ケースでも green になる。
@MainActor
final class CoreDataModelMigrationTests: XCTestCase {
    private var tempDirectory: URL!
    private var storeURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        storeURL = tempDirectory.appendingPathComponent("v4.sqlite")
    }

    override func tearDownWithError() throws {
        // ディレクトリごと消すので -wal / -shm やマイグレーションの残骸もまとめて片付く
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        storeURL = nil
        try super.tearDownWithError()
    }

    // MARK: - Fixtures

    /// 2025-06-15 12:00 固定（実行日非依存）
    private func fixedPaidAt() -> Date {
        Calendar.current.date(from: DateComponents(year: 2025, month: 6, day: 15, hour: 12))!
    }

    /// コンパイル済みの v4 モデル (`OtetsudaiCoin.momd/OtetsudaiCoin 4.mom`) を読む。
    /// test host は app なので `Bundle(for:)` は app bundle を指す。
    private func loadV4Model() throws -> NSManagedObjectModel {
        let momdURL = try XCTUnwrap(
            Bundle(for: CDAllowancePayment.self).url(forResource: "OtetsudaiCoin", withExtension: "momd"),
            "OtetsudaiCoin.momd が app bundle に見つからない"
        )
        let v4URL = momdURL.appendingPathComponent("OtetsudaiCoin 4.mom")
        return try XCTUnwrap(NSManagedObjectModel(contentsOf: v4URL), "OtetsudaiCoin 4.mom を読めない")
    }

    /// v4 モデルで SQLite ストアを作り、支払いを 1 件書いて閉じる。
    ///
    /// 生成クラス `CDAllowancePayment` は現行モデルでコンパイルされているので使わず、
    /// v4 の entity description から素の `NSManagedObject` を作って `setValue(_:forKey:)` で入れる。
    /// v4 のモデルと coordinator はこの関数の中で寿命を終える（現行モデルと同じ
    /// `representedClassName` を持つので、同時に生かしておくと entity 解決が曖昧になる）。
    private func writeV4Store(paymentId: UUID, childId: UUID, amount: Int32) throws {
        let model = try loadV4Model()
        XCTAssertNil(
            model.entitiesByName["CDAllowancePayment"]?.attributesByName["bonusAmount"],
            "v4 モデルに bonusAmount があってはいけない（fixture が v4 でなくなっている）"
        )

        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: nil
        )

        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        let entity = try XCTUnwrap(model.entitiesByName["CDAllowancePayment"])
        let payment = NSManagedObject(entity: entity, insertInto: context)
        payment.setValue(paymentId, forKey: "id")
        payment.setValue(childId, forKey: "childId")
        payment.setValue(amount, forKey: "amount")
        payment.setValue(Int16(6), forKey: "month")
        payment.setValue(Int16(2025), forKey: "year")
        payment.setValue(fixedPaidAt(), forKey: "paidAt")
        payment.setValue("6月分", forKey: "note")
        try context.save()

        try coordinator.remove(store)
    }

    private func storeMetadata() throws -> [String: Any] {
        try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType, at: storeURL, options: nil
        )
    }

    // MARK: - v4 → 現行モデル

    func testV4StoreOpensUnderCurrentModelWithNoBonus() throws {
        let paymentId = UUID()
        let childId = UUID()
        try writeV4Store(paymentId: paymentId, childId: childId, amount: 300)

        // 前提: v4 で書いたストアは現行モデルとは非互換（= マイグレーションが必要）。
        // 現行モデルが v4 のままなら、ここで落ちて「マイグレーションを検証していない」と分かる。
        let currentModel = try XCTUnwrap(NSPersistentContainer(name: "OtetsudaiCoin").managedObjectModel)
        XCTAssertFalse(
            currentModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: try storeMetadata()),
            "v4 ストアが現行モデルと互換 = 現行モデルが v4 のまま。マイグレーションが検証できていない"
        )

        // 本番と同じ load 経路（自動マイグレーション・推論マッピングは既定で ON）
        let controller = PersistenceController(storeURLOverride: storeURL)

        XCTAssertNil(controller.storeLoadError, "v4 ストアを現行モデルで開けない: \(String(describing: controller.storeLoadError))")
        XCTAssertEqual(controller.container.persistentStoreCoordinator.persistentStores.count, 1)
        XCTAssertTrue(
            currentModel.isConfiguration(withName: nil, compatibleWithStoreMetadata: try storeMetadata()),
            "load 後もストアが現行モデルに上がっていない"
        )

        let request: NSFetchRequest<CDAllowancePayment> = CDAllowancePayment.fetchRequest()
        let results = try controller.container.viewContext.fetch(request)
        XCTAssertEqual(results.count, 1)

        let migrated = try XCTUnwrap(results.first?.toDomain())
        XCTAssertEqual(migrated.id, paymentId)
        XCTAssertEqual(migrated.childId, childId)
        XCTAssertEqual(migrated.amount, 300)
        XCTAssertEqual(migrated.month, 6)
        XCTAssertEqual(migrated.year, 2025)
        XCTAssertEqual(migrated.paidAt, fixedPaidAt())
        XCTAssertEqual(migrated.note, "6月分")
        XCTAssertEqual(migrated.bonusAmount, 0, "v4 に無かった属性は既定値 0 で読める")
        XCTAssertNil(migrated.bonusStampKey, "v4 に無かった属性は nil で読める")
    }
}
