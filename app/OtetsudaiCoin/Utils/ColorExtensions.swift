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
    
    /// 相対輝度を計算
    private func relativeLuminance() -> Double {
        // SwiftUIのColorからRGB値を取得するのは複雑なため、
        // 簡易的な実装として近似値を使用
        // 実際のプロダクションでは、UIColorを経由してRGB値を取得することを推奨
        
        // HEX文字列が利用可能な場合の処理を想定
        // より正確な実装が必要な場合は、UIColorのconvertion機能を使用
        return 0.5 // 暫定値 - 実装時に適切な計算に置き換え
    }
}