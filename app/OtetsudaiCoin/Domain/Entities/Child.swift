import Foundation

struct Child: Equatable {
    let id: UUID
    let name: String
    let themeColor: String
    let coinRate: Int
    
    init(id: UUID, name: String, themeColor: String, coinRate: Int = 100) {
        self.id = id
        self.name = name
        self.themeColor = themeColor
        self.coinRate = coinRate
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
    
    static func isValidCoinRate(_ rate: Int) -> Bool {
        return rate > 0
    }
}