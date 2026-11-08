import Foundation

/// おまけ (#279) に添えるほめスタンプ。
///
/// 保存されるのは `rawValue`（キー）で、表示文言ではない。
/// キーは一度出荷したら変えない — 変えると過去のおまけが「未知のスタンプ」になる (BonusStampTests が担保)。
/// 未知のキー（将来のスタンプや壊れた値）は `fallbackEmoji` / `fallbackTitle` で表示する。
enum BonusStamp: String, CaseIterable, Identifiable {
    case effort
    case thanks
    case steady
    case challenge

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .effort: return "🏅"
        case .thanks: return "💐"
        case .steady: return "🐢"
        case .challenge: return "🚀"
        }
    }

    var title: String {
        switch self {
        case .effort: return String(localized: "がんばったで賞")
        case .thanks: return String(localized: "ありがとう賞")
        case .steady: return String(localized: "まいにちコツコツ賞")
        case .challenge: return String(localized: "チャレンジ賞")
        }
    }

    static let fallbackEmoji = "🎁"

    static var fallbackTitle: String {
        String(localized: "おまけ")
    }
}
