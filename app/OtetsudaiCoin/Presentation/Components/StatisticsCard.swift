import SwiftUI

enum StatisticsCardStyle {
    case large
    case compact
}

struct StatisticsCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let style: StatisticsCardStyle
    
    init(
        icon: String,
        title: String,
        value: String,
        subtitle: String,
        color: Color,
        style: StatisticsCardStyle = .large
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.color = color
        self.style = style
    }
    
    var body: some View {
        VStack(spacing: style.spacing) {
            Image(systemName: icon)
                .font(style.iconFont)
                .foregroundColor(color)
            
            Text(title)
                .font(style.titleFont)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(style.valueFont)
                .fontWeight(style.valueFontWeight)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(style.subtitleFont)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(style.padding)
        .background(
            RoundedRectangle(cornerRadius: style.cornerRadius)
                .fill(color.opacity(0.1))
        )
    }
}

private extension StatisticsCardStyle {
    var spacing: CGFloat {
        switch self {
        case .large: return 8
        case .compact: return 6
        }
    }
    
    var iconFont: Font {
        switch self {
        case .large: return .title2
        case .compact: return .title3
        }
    }
    
    var titleFont: Font {
        switch self {
        case .large: return .caption
        case .compact: return .caption2
        }
    }
    
    var valueFont: Font {
        switch self {
        case .large: return .title3
        case .compact: return .headline
        }
    }
    
    var valueFontWeight: Font.Weight {
        switch self {
        case .large: return .semibold
        case .compact: return .bold
        }
    }
    
    var subtitleFont: Font {
        switch self {
        case .large: return .caption
        case .compact: return .caption2
        }
    }
    
    var padding: EdgeInsets {
        switch self {
        case .large: return EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        case .compact: return EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .large: return 12
        case .compact: return 8
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 16) {
            StatisticsCard(
                icon: "star.fill",
                title: "今月の実績",
                value: "15",
                subtitle: "回がんばった！",
                color: .blue,
                style: .large
            )
            
            StatisticsCard(
                icon: "flame.fill",
                title: "連続記録",
                value: "5",
                subtitle: "日連続！",
                color: .orange,
                style: .large
            )
        }
        
        HStack(spacing: 16) {
            StatisticsCard(
                icon: "star.fill",
                title: "今月の実績",
                value: "15",
                subtitle: "回",
                color: .blue,
                style: .compact
            )
            
            StatisticsCard(
                icon: "flame.fill",
                title: "連続記録",
                value: "5",
                subtitle: "日",
                color: .orange,
                style: .compact
            )
        }
    }
    .padding()
}