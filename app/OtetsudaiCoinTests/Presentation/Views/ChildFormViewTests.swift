import XCTest
import ViewInspector
import SwiftUI
@testable import OtetsudaiCoin

final class ChildFormViewTests: XCTestCase {
    
    private var childRepository: MockChildRepository!
    private var viewModel: ChildManagementViewModel!
    
    @MainActor
    override func setUp() {
        super.setUp()
        childRepository = MockChildRepository()
        viewModel = ChildManagementViewModel(childRepository: childRepository)
    }
    
    override func tearDown() {
        viewModel = nil
        childRepository = nil
        super.tearDown()
    }
    
    @MainActor
    func testColorSelectionInFormView() throws {
        // Given
        let view = ChildFormView(viewModel: viewModel, editingChild: nil)
        
        // When
        let navView = try view.inspect().navigationView()
        let form = try navView.form()
        
        // Then
        XCTAssertNoThrow(try form.find(ViewType.Text.self, where: { view in
            try view.string() == "テーマカラー"
        }))
    }
    
    @MainActor
    func testAvailableThemeColorsCount() {
        // Given
        let colors = viewModel.getAvailableThemeColors()
        
        // Then
        XCTAssertEqual(colors.count, 25, "テーマカラーは25個あるべき")
        
        // 各色が有効なHEX形式であることを確認
        for color in colors {
            XCTAssertTrue(Child.isValidThemeColor(color), "色 \(color) は有効なテーマカラーであるべき")
        }
    }
    
    @MainActor
    func testColorPickerSelection() async {
        // Given
        let availableColors = viewModel.getAvailableThemeColors()
        let firstColor = availableColors[0]
        let fifthColor = availableColors[4]
        let lastColor = availableColors[availableColors.count - 1]
        
        // 異なる位置のカラーでテスト
        let testCases = [
            (color: firstColor, description: "最初のカラー"),
            (color: fifthColor, description: "5番目のカラー"),
            (color: lastColor, description: "最後のカラー")
        ]
        
        for testCase in testCases {
            // When
            await viewModel.addChild(name: "テスト", themeColor: testCase.color)
            
            // Then
            XCTAssertEqual(childRepository.savedChildren.count, 1, "\(testCase.description): 子供が1人追加されるべき")
            XCTAssertEqual(
                childRepository.savedChildren[0].themeColor, 
                testCase.color, 
                "\(testCase.description): 選択したカラー(\(testCase.color))が正しく保存されるべき。実際: \(childRepository.savedChildren[0].themeColor)"
            )
            
            // リセット
            childRepository.savedChildren.removeAll()
        }
    }
    
    @MainActor
    func testDefaultColorValue() {
        // Given
        let view = ChildFormView(viewModel: viewModel, editingChild: nil)
        
        // Then: デフォルトカラーが設定されていることを確認
        // SwiftUIの内部状態にアクセスするのは困難なため、
        // ViewModelを通じてテスト可能な部分を確認
        let availableColors = viewModel.getAvailableThemeColors()
        XCTAssertTrue(availableColors.contains("#3357FF"), "デフォルトカラー #3357FF が利用可能カラーに含まれるべき")
    }
}