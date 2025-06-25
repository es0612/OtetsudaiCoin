import XCTest
import Combine
@testable import OtetsudaiCoin

@MainActor
final class ChildManagementViewModelTests: XCTestCase {
    
    private var childRepository: MockChildRepository!
    private var viewModel: ChildManagementViewModel!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        childRepository = MockChildRepository()
        viewModel = ChildManagementViewModel(childRepository: childRepository)
        cancellables = []
    }
    
    override func tearDown() {
        cancellables.forEach { $0.cancel() }
        cancellables = nil
        viewModel = nil
        childRepository = nil
        super.tearDown()
    }
    
    func testLoadChildren() async {
        // Given
        let child1 = Child(id: UUID(), name: "太郎", themeColor: "#FF5733", coinRate: 100)
        let child2 = Child(id: UUID(), name: "花子", themeColor: "#33FF57", coinRate: 150)
        childRepository.children = [child1, child2]
        
        // When
        await viewModel.loadChildren()
        
        // Then
        XCTAssertEqual(viewModel.children.count, 2)
        XCTAssertEqual(viewModel.children[0].name, "太郎")
        XCTAssertEqual(viewModel.children[1].name, "花子")
        XCTAssertFalse(viewModel.viewState.isLoading)
        XCTAssertNil(viewModel.viewState.errorMessage)
    }
    
    func testLoadChildrenWithError() async {
        // Given
        childRepository.shouldThrowError = true
        
        // When
        await viewModel.loadChildren()
        
        // Then
        XCTAssertTrue(viewModel.children.isEmpty)
        XCTAssertFalse(viewModel.viewState.isLoading)
        XCTAssertNotNil(viewModel.viewState.errorMessage)
    }
    
    func testAddChild() async {
        // Given
        let name = "新しい子"
        let themeColor = "#9C27B0"
        let coinRate = 120
        
        // When
        await viewModel.addChild(name: name, themeColor: themeColor, coinRate: coinRate)
        
        // Then
        XCTAssertEqual(childRepository.savedChildren.count, 1)
        XCTAssertEqual(childRepository.savedChildren[0].name, name)
        XCTAssertEqual(childRepository.savedChildren[0].themeColor, themeColor)
        XCTAssertEqual(childRepository.savedChildren[0].coinRate, coinRate)
        XCTAssertNotNil(viewModel.viewState.successMessage)
    }
    
    func testAddChildWithInvalidData() async {
        // Given
        let name = ""
        let themeColor = "invalid"
        let coinRate = -10
        
        // When
        await viewModel.addChild(name: name, themeColor: themeColor, coinRate: coinRate)
        
        // Then
        XCTAssertTrue(childRepository.savedChildren.isEmpty)
        XCTAssertNotNil(viewModel.viewState.errorMessage)
    }
    
    func testUpdateChild() async {
        // Given
        let originalChild = Child(id: UUID(), name: "太郎", themeColor: "#FF5733", coinRate: 100)
        childRepository.children = [originalChild]
        await viewModel.loadChildren()
        
        let updatedName = "太郎くん"
        let updatedColor = "#9C27B0"
        let updatedRate = 150
        
        // When
        await viewModel.updateChild(id: originalChild.id, name: updatedName, themeColor: updatedColor, coinRate: updatedRate)
        
        // Then
        XCTAssertEqual(childRepository.updatedChildren.count, 1)
        XCTAssertEqual(childRepository.updatedChildren[0].name, updatedName)
        XCTAssertEqual(childRepository.updatedChildren[0].themeColor, updatedColor)
        XCTAssertEqual(childRepository.updatedChildren[0].coinRate, updatedRate)
        XCTAssertNotNil(viewModel.viewState.successMessage)
    }
    
    func testDeleteChild() async {
        // Given
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733", coinRate: 100)
        childRepository.children = [child]
        await viewModel.loadChildren()
        
        // When
        await viewModel.deleteChild(id: child.id)
        
        // Then
        XCTAssertEqual(childRepository.deletedChildIds.count, 1)
        XCTAssertEqual(childRepository.deletedChildIds[0], child.id)
        XCTAssertNotNil(viewModel.viewState.successMessage)
    }
    
    func testValidateChildData() {
        // Valid data
        XCTAssertTrue(viewModel.validateChildData(name: "太郎", themeColor: "#FF5733", coinRate: 100))
        
        // Invalid name
        XCTAssertFalse(viewModel.validateChildData(name: "", themeColor: "#FF5733", coinRate: 100))
        XCTAssertFalse(viewModel.validateChildData(name: "   ", themeColor: "#FF5733", coinRate: 100))
        
        // Invalid theme color
        XCTAssertFalse(viewModel.validateChildData(name: "太郎", themeColor: "invalid", coinRate: 100))
        
        // Invalid coin rate
        XCTAssertFalse(viewModel.validateChildData(name: "太郎", themeColor: "#FF5733", coinRate: 0))
        XCTAssertFalse(viewModel.validateChildData(name: "太郎", themeColor: "#FF5733", coinRate: -10))
    }
    
    func testClearMessages() {
        // Given
        viewModel.setError("エラーメッセージ")
        viewModel.setSuccess("成功メッセージ")
        
        // When
        viewModel.clearMessages()
        
        // Then
        XCTAssertNil(viewModel.viewState.errorMessage)
        XCTAssertNil(viewModel.viewState.successMessage)
    }
    
    func testGetAvailableThemeColors() {
        let colors = viewModel.getAvailableThemeColors()
        XCTAssertFalse(colors.isEmpty)
        XCTAssertTrue(colors.allSatisfy { Child.isValidThemeColor($0) })
    }
    
    func testThemeColorSelection() async {
        // Given
        let availableColors = viewModel.getAvailableThemeColors()
        let selectedColor = availableColors[5] // 6番目の色を選択
        let name = "テスト"
        let coinRate = 100
        
        // When
        await viewModel.addChild(name: name, themeColor: selectedColor, coinRate: coinRate)
        
        // Then
        XCTAssertEqual(childRepository.savedChildren.count, 1)
        let savedChild = childRepository.savedChildren[0]
        XCTAssertEqual(savedChild.themeColor, selectedColor, "選択したカラー(\(selectedColor))が正しく保存されるべき")
        
        // デバッグ情報を出力
        print("選択したカラー: \(selectedColor)")
        print("保存されたカラー: \(savedChild.themeColor)")
        print("利用可能なカラー: \(availableColors)")
    }
}

