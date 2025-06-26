import Foundation

struct Child: Equatable {
    let id: UUID
    let name: String
    let themeColor: String
    
    init(id: UUID, name: String, themeColor: String) {
        self.id = id
        self.name = name
        self.themeColor = themeColor
    }
    
    static func == (lhs: Child, rhs: Child) -> Bool {
        return lhs.id == rhs.id
    }
    
    static func isValidThemeColor(_ color: String) -> Bool {
        guard !color.isEmpty, color.hasPrefix("#"), color.count == 7 else {
            return false
        }
        
        let hexChars = String(color.dropFirst())
        return hexChars.allSatisfy { char in
            return char.isHexDigit
        }
    }
    
}