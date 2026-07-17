import SwiftUI

extension Color {
    /// HEX文字列からColorを初期化
    /// - Parameter hex: "#FF5733"形式のHEX文字列
    init?(hex: String) {
        guard hex.hasPrefix("#"), hex.count == 7 else { return nil }
        
        let hexColor = String(hex.dropFirst())
        guard let value = UInt64(hexColor, radix: 16) else { return nil }
        
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        
        self.init(red: red, green: green, blue: blue)
    }
    
    /// カラーコントラスト比を計算（アクセシビリティ向上）
    /// - Parameter other: 比較対象の色
    /// - Returns: コントラスト比（1.0〜21.0）
    func contrastRatio(with other: Color) -> Double {
        let luminance1 = self.relativeLuminance()
        let luminance2 = other.relativeLuminance()
        
        let lighter = max(luminance1, luminance2)
        let darker = min(luminance1, luminance2)
        
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    /// WCAG AAコンプライアンス（コントラスト比4.5:1以上）をチェック
    /// - Parameter backgroundColor: 背景色
    /// - Returns: アクセシビリティ基準を満たすかどうか
    func isAccessible(on backgroundColor: Color) -> Bool {
        return contrastRatio(with: backgroundColor) >= 4.5
    }
    
    /// 相対輝度を計算(WCAG 2.1 定義)
    private func relativeLuminance() -> Double {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return 0.5
        }

        func linearize(_ component: CGFloat) -> Double {
            let value = Double(component)
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
    }
}