import SwiftUI

struct MonthlyResultsPopupView: View {
    let results: [MonthlyResult]
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // 背景
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // メインコンテンツ
            VStack(spacing: 20) {
                // ヘッダー
                VStack(spacing: 8) {
                    Image(systemName: "trophy.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                    
                    Text("今月のお小遣い支払い完了！")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("今月もよくがんばりました")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 結果一覧
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(results, id: \.child.id) { result in
                            ResultCard(result: result)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 300)
                
                // ボタン
                Button(action: onDismiss) {
                    Text("確認しました")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 20)
            )
            .padding()
        }
    }
}

struct ResultCard: View {
    let result: MonthlyResult
    
    var body: some View {
        VStack(spacing: 12) {
            // 子供の情報
            HStack {
                Circle()
                    .fill(Color(hex: result.child.themeColor) ?? .blue)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(result.child.name.prefix(1)))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.child.name)
                        .font(.headline)
                    
                    Text("\(result.month)月の結果")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // 統計情報
            HStack {
                StatItem(
                    title: "お手伝い",
                    value: "\(result.totalRecords)回",
                    icon: "star.fill",
                    color: .orange
                )
                
                Spacer()
                
                StatItem(
                    title: "連続記録",
                    value: "\(result.consecutiveDays)日",
                    icon: "flame.fill",
                    color: .red
                )
                
                Spacer()
                
                StatItem(
                    title: "お小遣い",
                    value: "\(result.monthlyAllowance)コイン",
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

#Preview {
    let sampleResults = [
        MonthlyResult(
            child: Child(id: UUID(), name: "太郎", themeColor: "#FF5733", coinRate: 100),
            totalRecords: 15,
            monthlyAllowance: 1500,
            consecutiveDays: 7,
            month: 6,
            year: 2025
        ),
        MonthlyResult(
            child: Child(id: UUID(), name: "花子", themeColor: "#33FF57", coinRate: 120),
            totalRecords: 12,
            monthlyAllowance: 1440,
            consecutiveDays: 5,
            month: 6,
            year: 2025
        )
    ]
    
    MonthlyResultsPopupView(results: sampleResults) {
        // Do nothing in preview
    }
}