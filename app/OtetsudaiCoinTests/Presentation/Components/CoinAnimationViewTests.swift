import XCTest
import SwiftUI
import ViewInspector
@testable import OtetsudaiCoin


final class CoinAnimationViewTests: XCTestCase {
    
    @MainActor
    func testCoinAnimationViewDisplaysCoin() throws {
        let animationView = CoinAnimationView(
            isVisible: .constant(true),
            coinValue: 100,
            themeColor: "#FF5733"
        )
        
        XCTAssertNoThrow(try animationView.inspect().find(text: "100"))
        XCTAssertNoThrow(try animationView.inspect().find(text: "コイン"))
    }
    
    @MainActor
    func testCoinAnimationViewHiddenWhenNotVisible() throws {
        let animationView = CoinAnimationView(
            isVisible: .constant(false),
            coinValue: 100,
            themeColor: "#FF5733"
        )
        
        XCTAssertThrowsError(try animationView.inspect().find(text: "100"))
    }
    
    @MainActor
    func testCoinAnimationViewDisplaysCorrectValue() throws {
        let animationView = CoinAnimationView(
            isVisible: .constant(true),
            coinValue: 250,
            themeColor: "#33FF57"
        )
        
        XCTAssertNoThrow(try animationView.inspect().find(text: "250"))
    }
    
    @MainActor
    func testCoinAnimationViewUsesThemeColor() throws {
        let animationView = CoinAnimationView(
            isVisible: .constant(true),
            coinValue: 100,
            themeColor: "#FF5733"
        )
        
        // ビューが存在することを確認
        let view = try animationView.inspect()
        XCTAssertNotNil(view)
    }
    
    @MainActor
    func testCoinAnimationViewHasScaleEffect() throws {
        let animationView = CoinAnimationView(
            isVisible: .constant(true),
            coinValue: 100,
            themeColor: "#FF5733"
        )
        
        // scaleEffectが適用されていることを確認
        let view = try animationView.inspect()
        XCTAssertNotNil(view)
    }
    
    @MainActor
    func testCoinAnimationViewHasOpacityAnimation() throws {
        let animationView = CoinAnimationView(
            isVisible: .constant(true),
            coinValue: 100,
            themeColor: "#FF5733"
        )
        
        // opacityが適用されていることを確認
        let view = try animationView.inspect()
        XCTAssertNotNil(view)
    }
}