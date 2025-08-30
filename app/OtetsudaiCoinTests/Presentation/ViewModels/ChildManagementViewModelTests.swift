import XCTest
@testable import OtetsudaiCoin

final class ChildManagementViewModelTests: XCTestCase {
    
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
    func testLoadChildren() async {
        // Given
        let child1 = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        let child2 = Child(id: UUID(), name: "花子", themeColor: "#33FF57")
        childRepository.children = [child1, child2]
        
        // When
        await viewModel.loadChildren()
        
        // Then
        XCTAssertEqual(viewModel.children.count, 2)
        XCTAssertEqual(viewModel.children[0].name, "太郎")
        XCTAssertEqual(viewModel.children[1].name, "花子")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    @MainActor
    func testLoadChildrenWithError() async {
        // Given
        childRepository.shouldThrowError = true
        
        // When
        await viewModel.loadChildren()
        
        // Then
        XCTAssertTrue(viewModel.children.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
    @MainActor
    func testAddChild() async {
        // Given
        let name = "新しい子"
        let themeColor = "#9C27B0"
        
        // When
        await viewModel.addChild(name: name, themeColor: themeColor)
        
        // Then
        XCTAssertEqual(childRepository.savedChildren.count, 1)
        XCTAssertEqual(childRepository.savedChildren[0].name, name)
        XCTAssertEqual(childRepository.savedChildren[0].themeColor, themeColor)
        // coinRateはChildエンティティから削除されました
        XCTAssertNotNil(viewModel.successMessage)
    }
    
    @MainActor
    func testAddChildWithInvalidData() async {
        // Given
        let name = ""
        let themeColor = "invalid"
        
        // When
        await viewModel.addChild(name: name, themeColor: themeColor)
        
        // Then
        XCTAssertTrue(childRepository.savedChildren.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
    @MainActor
    func testUpdateChild() async {
        // Given
        let originalChild = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        childRepository.children = [originalChild]
        await viewModel.loadChildren()
        
        let updatedName = "太郎くん"
        let updatedColor = "#9C27B0"
        
        // When
        await viewModel.updateChild(id: originalChild.id, name: updatedName, themeColor: updatedColor)
        
        // Then
        XCTAssertEqual(childRepository.updatedChildren.count, 1)
        XCTAssertEqual(childRepository.updatedChildren[0].name, updatedName)
        XCTAssertEqual(childRepository.updatedChildren[0].themeColor, updatedColor)
        // coinRateはChildエンティティから削除されました
        XCTAssertNotNil(viewModel.successMessage)
    }
    
    @MainActor
    func testDeleteChild() async {
        // Given
        let child = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
        childRepository.children = [child]
        await viewModel.loadChildren()
        
        // When
        await viewModel.deleteChild(id: child.id)
        
        // Then
        XCTAssertEqual(childRepository.deletedChildIds.count, 1)
        XCTAssertEqual(childRepository.deletedChildIds[0], child.id)
        XCTAssertNotNil(viewModel.successMessage)
    }
    
    @MainActor
    func testValidateChildData() {
        // Valid data
        XCTAssertTrue(viewModel.validateChildData(name: "太郎", themeColor: "#FF5733"))
        
        // Invalid name
        XCTAssertFalse(viewModel.validateChildData(name: "", themeColor: "#FF5733"))
        XCTAssertFalse(viewModel.validateChildData(name: "   ", themeColor: "#FF5733"))
        
        // Invalid theme color
        XCTAssertFalse(viewModel.validateChildData(name: "太郎", themeColor: "invalid"))
        
        // coinRateの検証はChildエンティティから削除されました
    }
    
    @MainActor
    func testClearMessages() {
        // Given
        viewModel.setError("エラーメッセージ")
        viewModel.setSuccess("成功メッセージ")
        
        // When
        viewModel.clearMessages()
        
        // Then
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.successMessage)
    }
    
    @MainActor
    func testGetAvailableThemeColors() {
        let colors = viewModel.getAvailableThemeColors()
        XCTAssertFalse(colors.isEmpty)
        XCTAssertTrue(colors.allSatisfy { Child.isValidThemeColor($0) })
    }
    
    @MainActor
    func testThemeColorSelection() async {
        // Given
        let availableColors = viewModel.getAvailableThemeColors()
        let selectedColor = availableColors[5] // 6番目の色を選択
        let name = "テスト"
        
        // When
        await viewModel.addChild(name: name, themeColor: selectedColor)
        
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
