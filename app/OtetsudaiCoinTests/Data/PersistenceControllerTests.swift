import XCTest
import CoreData
@testable import OtetsudaiCoin

@MainActor
final class PersistenceControllerTests: XCTestCase {

    func test_storeLoadError_isNil_onSuccessfulInMemoryLoad() {
        // in-memory (/dev/null) は正常にロードできるので storeLoadError は nil。
        // テスト/プレビューで誤ってエラー UI が出ないことの保証も兼ねる。
        let controller = PersistenceController(inMemory: true)
        XCTAssertNil(
            controller.storeLoadError,
            "in-memory store should load cleanly; got \(String(describing: controller.storeLoadError))"
        )
    }

    func test_storeLoadError_isNonNil_whenStoreURLIsUnopenable() throws {
        // store URL を「既存ディレクトリ」に向けると SQLite open が失敗する。
        // この経路は load 失敗 + 同期 completion での捕捉を同時に実証する
        // (loadPersistentStores が async だった場合この assert が落ちて気づける)。
        // 特定の NSError domain/code には依存せず「non-nil であること」だけを見る。
        let dirURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dirURL) }

        let controller = PersistenceController(storeURLOverride: dirURL)

        XCTAssertNotNil(
            controller.storeLoadError,
            "expected a load error when store URL is a directory; storeLoadError=\(String(describing: controller.storeLoadError))"
        )
    }
}
