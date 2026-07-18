import XCTest
@testable import OtetsudaiCoin

final class HelpTaskTests: XCTestCase {

    func testHelpTaskInitialization() {
        let id = UUID()
        let name = "食器を片付ける"
        let isActive = true
        
        let helpTask = HelpTask(id: id, name: name, isActive: isActive)
        
        XCTAssertEqual(helpTask.id, id)
        XCTAssertEqual(helpTask.name, name)
        XCTAssertEqual(helpTask.isActive, isActive)
    }
    
    func testHelpTaskEqualityById() {
        let id = UUID()
        let task1 = HelpTask(id: id, name: "食器を片付ける", isActive: true)
        let task2 = HelpTask(id: id, name: "お風呂を入れる", isActive: false)
        
        XCTAssertEqual(task1, task2)
    }
    
    func testHelpTaskInequality() {
        let task1 = HelpTask(id: UUID(), name: "食器を片付ける", isActive: true)
        let task2 = HelpTask(id: UUID(), name: "食器を片付ける", isActive: true)
        
        XCTAssertNotEqual(task1, task2)
    }
    
    func testHelpTaskDeactivate() {
        let task = HelpTask(id: UUID(), name: "食器を片付ける", isActive: true)
        let deactivatedTask = task.deactivate()
        
        XCTAssertTrue(task.isActive)
        XCTAssertFalse(deactivatedTask.isActive)
        XCTAssertEqual(task.id, deactivatedTask.id)
        XCTAssertEqual(task.name, deactivatedTask.name)
    }
    
    func testHelpTaskActivate() {
        let task = HelpTask(id: UUID(), name: "食器を片付ける", isActive: false)
        let activatedTask = task.activate()
        
        XCTAssertFalse(task.isActive)
        XCTAssertTrue(activatedTask.isActive)
        XCTAssertEqual(task.id, activatedTask.id)
        XCTAssertEqual(task.name, activatedTask.name)
    }
    
    func testDefaultHelpTasks() {
        let defaultTasks = HelpTask.defaultTasks()
        
        XCTAssertEqual(defaultTasks.count, 10)
        XCTAssertTrue(defaultTasks.allSatisfy { $0.isActive })
        
        let expectedNames = [
            "下の子の面倒を見る",
            "お風呂を入れる",
            "食器を出す",
            "食器を片付ける",
            "お片付けする",
            "玄関の靴を並べる",
            "ゴミ出しのお手伝い",
            "洗濯物を運ぶ",
            "テーブルを拭く",
            "自分の部屋の掃除"
        ]
        
        let actualNames = defaultTasks.map { $0.name }
        XCTAssertEqual(actualNames, expectedNames)
    }

    func testDisplayNamePassesThroughUserCreatedTask() {
        // ユーザー作成タスク（free text）は翻訳せず verbatim
        let task = HelpTask(id: UUID(), name: "ユーザー独自タスク", isActive: true)
        XCTAssertEqual(task.displayName, "ユーザー独自タスク")
    }

    func testEveryDefaultNameHasLocalizationEntry() {
        // 既知デフォルト名はすべて翻訳マップに登録されている（locale 非依存）
        XCTAssertTrue(
            HelpTask.defaultTaskNames.allSatisfy { HelpTask.defaultNameLocalizations[$0] != nil },
            "defaultTaskNames の全件が defaultNameLocalizations にエントリを持つべき"
        )
        XCTAssertEqual(HelpTask.defaultTaskNames.count, 10)
    }

    func testResolvePersistedNameUsesEditedTextWhenChanged() {
        let original = HelpTask(id: UUID(), name: "下の子の面倒を見る", isActive: true)
        XCTAssertEqual(HelpTask.resolvePersistedName(editedText: "新しいタスク名", original: original), "新しいタスク名")
    }

    func testResolvePersistedNameKeepsOriginalWhenUnchanged() {
        let original = HelpTask(id: UUID(), name: "テーブルを拭く", isActive: true)
        XCTAssertEqual(HelpTask.resolvePersistedName(editedText: original.displayName, original: original), "テーブルを拭く")
    }

    func testResolvePersistedNameTrimsWhitespace() {
        let original = HelpTask(id: UUID(), name: "お片付けする", isActive: true)
        XCTAssertEqual(HelpTask.resolvePersistedName(editedText: "  片付け  ", original: original), "片付け")
    }

    // MARK: - sortOrder (#122/#123)

    func testSortOrderDefaultsToZero() {
        let task = HelpTask(id: UUID(), name: "食器を片付ける", isActive: true)
        XCTAssertEqual(task.sortOrder, 0)
    }

    func testSortOrderIsPreservedByActivateDeactivateAndUpdateCoinRate() {
        let task = HelpTask(id: UUID(), name: "食器を片付ける", isActive: true, coinRate: 10, sortOrder: 5)

        XCTAssertEqual(task.deactivate().sortOrder, 5)
        XCTAssertEqual(task.activate().sortOrder, 5)
        XCTAssertEqual(task.updateCoinRate(20).sortOrder, 5)
    }

    func testUpdatingSortOrderReturnsCopyWithNewOrder() {
        let task = HelpTask(id: UUID(), name: "食器を片付ける", isActive: true, coinRate: 10, sortOrder: 1)
        let moved = task.updatingSortOrder(3)

        XCTAssertEqual(moved.sortOrder, 3)
        XCTAssertEqual(moved.id, task.id)
        XCTAssertEqual(moved.name, task.name)
        XCTAssertEqual(moved.isActive, task.isActive)
        XCTAssertEqual(moved.coinRate, task.coinRate)
    }

    func testDefaultTasksHaveSequentialSortOrder() {
        let tasks = HelpTask.defaultTasks()
        XCTAssertEqual(tasks.map(\.sortOrder), Array(0..<HelpTask.defaultTaskNames.count))
    }

    // MARK: - icon (#148)

    func testDisplayIconUsesExplicitIcon() {
        let task = HelpTask(id: UUID(), name: "お風呂を入れる", isActive: true, icon: "🚿")
        XCTAssertEqual(task.displayIcon, "🚿")
    }

    func testDisplayIconFallsBackToDefaultDictionary() {
        let task = HelpTask(id: UUID(), name: "お風呂を入れる", isActive: true)
        XCTAssertEqual(task.displayIcon, "🛁")
    }

    func testDisplayIconFallsBackToSparklesForUnknownName() {
        let task = HelpTask(id: UUID(), name: "ユーザー作成タスク", isActive: true)
        XCTAssertEqual(task.displayIcon, "✨")
    }

    func testCopyMethodsPreserveIcon() {
        let task = HelpTask(id: UUID(), name: "テスト", isActive: true, icon: "🧹")
        XCTAssertEqual(task.deactivate().icon, "🧹")
        XCTAssertEqual(task.activate().icon, "🧹")
        XCTAssertEqual(task.updateCoinRate(20).icon, "🧹")
        XCTAssertEqual(task.updatingSortOrder(5).icon, "🧹")
    }

    func testUpdatingIconReplacesIcon() {
        let task = HelpTask(id: UUID(), name: "テスト", isActive: true, icon: "🧹")
        XCTAssertEqual(task.updatingIcon("🧺").icon, "🧺")
        XCTAssertNil(task.updatingIcon(nil).icon)
    }

    func testEveryDefaultNameHasIconEntry() {
        // defaultTaskNames と defaultIconsByName のキー集合が完全一致すること
        XCTAssertEqual(
            Set(HelpTask.defaultTaskNames),
            Set(HelpTask.defaultIconsByName.keys),
            "keys: \(HelpTask.defaultIconsByName.keys.sorted())"
        )
    }

    func testResolvePersistedIconKeepsNilWhenUnchangedDefault() {
        // icon 未設定のデフォルトタスクで、表示中の絵文字をそのまま選んで保存 → nil 維持
        // (将来デフォルト絵文字を変えても DB 書き換えなしで追従させるため)
        let original = HelpTask(id: UUID(), name: "お風呂を入れる", isActive: true)
        XCTAssertNil(HelpTask.resolvePersistedIcon(selected: "🛁", original: original, resolvedName: original.name))
    }

    func testResolvePersistedIconStoresExplicitSelection() {
        let original = HelpTask(id: UUID(), name: "お風呂を入れる", isActive: true)
        XCTAssertEqual(HelpTask.resolvePersistedIcon(selected: "🧹", original: original, resolvedName: original.name), "🧹")
        // 明示 icon 済みタスクは同じ絵文字を選び直しても明示のまま維持
        let explicit = HelpTask(id: UUID(), name: "お風呂を入れる", isActive: true, icon: "🛁")
        XCTAssertEqual(HelpTask.resolvePersistedIcon(selected: "🛁", original: explicit, resolvedName: explicit.name), "🛁")
    }

    func testResolvePersistedIconPersistsExplicitlyWhenDefaultTaskRenamed() {
        // rename でフォールバック先が変わる場合、表示中の絵文字を明示保存する (WYSIWYG)
        let original = HelpTask(id: UUID(), name: "お風呂を入れる", isActive: true)
        let resolved = HelpTask.resolvePersistedIcon(selected: "🛁", original: original, resolvedName: "お風呂そうじ")
        XCTAssertEqual(resolved, "🛁")
    }

    func testResolvePersistedIconNilSelectionKeepsExistingIcon() {
        let explicit = HelpTask(id: UUID(), name: "テスト", isActive: true, icon: "🧹")
        XCTAssertEqual(HelpTask.resolvePersistedIcon(selected: nil, original: explicit, resolvedName: "テスト"), "🧹")
    }
}
