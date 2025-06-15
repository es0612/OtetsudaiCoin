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
}