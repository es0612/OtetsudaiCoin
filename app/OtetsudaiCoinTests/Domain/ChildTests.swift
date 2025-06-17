import XCTest
@testable import OtetsudaiCoin

final class ChildTests: XCTestCase {

    func testChildInitialization() {
        let id = UUID()
        let name = "太郎"
        let themeColor = "#9C27B0"
        let coinRate = 100
        
        let child = Child(id: id, name: name, themeColor: themeColor, coinRate: coinRate)
        
        XCTAssertEqual(child.id, id)
        XCTAssertEqual(child.name, name)
        XCTAssertEqual(child.themeColor, themeColor)
        XCTAssertEqual(child.coinRate, coinRate)
    }
    
    func testChildEqualityById() {
        let id = UUID()
        let child1 = Child(id: id, name: "太郎", themeColor: "#9C27B0", coinRate: 100)
        let child2 = Child(id: id, name: "花子", themeColor: "#E91E63", coinRate: 150)
        
        XCTAssertEqual(child1, child2)
    }
    
    func testChildInequality() {
        let child1 = Child(id: UUID(), name: "太郎", themeColor: "#9C27B0", coinRate: 100)
        let child2 = Child(id: UUID(), name: "太郎", themeColor: "#9C27B0", coinRate: 100)
        
        XCTAssertNotEqual(child1, child2)
    }
    
    func testChildThemeColorValidation() {
        XCTAssertTrue(Child.isValidThemeColor("#9C27B0"))
        XCTAssertTrue(Child.isValidThemeColor("#E91E63"))
        XCTAssertFalse(Child.isValidThemeColor("purple"))
        XCTAssertFalse(Child.isValidThemeColor("#GGGGGG"))
        XCTAssertFalse(Child.isValidThemeColor(""))
    }
    
    func testChildCoinRateValidation() {
        XCTAssertTrue(Child.isValidCoinRate(50))
        XCTAssertTrue(Child.isValidCoinRate(100))
        XCTAssertTrue(Child.isValidCoinRate(500))
        XCTAssertFalse(Child.isValidCoinRate(0))
        XCTAssertFalse(Child.isValidCoinRate(-10))
    }
    
    func testChildDefaultCoinRate() {
        let child = Child(id: UUID(), name: "太郎", themeColor: "#9C27B0")
        XCTAssertEqual(child.coinRate, 100)
    }
}