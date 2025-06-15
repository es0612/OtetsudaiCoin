import XCTest
@testable import OtetsudaiCoin

final class ChildTests: XCTestCase {

    func testChildInitialization() {
        let id = UUID()
        let name = "太郎"
        let themeColor = "#9C27B0"
        
        let child = Child(id: id, name: name, themeColor: themeColor)
        
        XCTAssertEqual(child.id, id)
        XCTAssertEqual(child.name, name)
        XCTAssertEqual(child.themeColor, themeColor)
    }
    
    func testChildEqualityById() {
        let id = UUID()
        let child1 = Child(id: id, name: "太郎", themeColor: "#9C27B0")
        let child2 = Child(id: id, name: "花子", themeColor: "#E91E63")
        
        XCTAssertEqual(child1, child2)
    }
    
    func testChildInequality() {
        let child1 = Child(id: UUID(), name: "太郎", themeColor: "#9C27B0")
        let child2 = Child(id: UUID(), name: "太郎", themeColor: "#9C27B0")
        
        XCTAssertNotEqual(child1, child2)
    }
    
    func testChildThemeColorValidation() {
        XCTAssertTrue(Child.isValidThemeColor("#9C27B0"))
        XCTAssertTrue(Child.isValidThemeColor("#E91E63"))
        XCTAssertFalse(Child.isValidThemeColor("purple"))
        XCTAssertFalse(Child.isValidThemeColor("#GGGGGG"))
        XCTAssertFalse(Child.isValidThemeColor(""))
    }
}