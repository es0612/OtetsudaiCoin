//
//  SkeletonViews.swift
//  OtetsudaiCoin
//
//  Created on 2025/07/10
//

import SwiftUI

/// スケルトンローディング画面のコンポーネント
struct SkeletonViews {
    
    // MARK: - Base Skeleton Components
    
    /// 基本的なスケルトンビュー
    struct SkeletonBox: View {
        let width: CGFloat?
        let height: CGFloat
        let cornerRadius: CGFloat
        
        @State private var isAnimating = false
        
        init(width: CGFloat? = nil, height: CGFloat, cornerRadius: CGFloat = AppRadius.small) {
            self.width = width
            self.height = height
            self.cornerRadius = cornerRadius
        }
        
        var body: some View {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.gray.opacity(0.1),
                            Color.gray.opacity(0.3),
                            Color.gray.opacity(0.1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width, height: height)
                .cornerRadius(cornerRadius)
                .scaleEffect(x: isAnimating ? 1.0 : 0.95, y: 1.0, anchor: .leading)
                .opacity(isAnimating ? 1.0 : 0.6)
                .animation(
                    Animation.easeInOut(duration: 1.2)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
                .onAppear {
                    isAnimating = true
                }
        }
    }
    
    /// 円形のスケルトンビュー
    struct SkeletonCircle: View {
        let size: CGFloat
        @State private var isAnimating = false
        
        var body: some View {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.gray.opacity(0.1),
                            Color.gray.opacity(0.3),
                            Color.gray.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .scaleEffect(isAnimating ? 1.05 : 0.95)
                .opacity(isAnimating ? 1.0 : 0.6)
                .animation(
                    Animation.easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
                .onAppear {
                    isAnimating = true
                }
        }
    }
    
    /// テキスト行のスケルトンビュー
    struct SkeletonTextLine: View {
        let width: CGFloat?
        let height: CGFloat
        
        init(width: CGFloat? = nil, height: CGFloat = 16) {
            self.width = width
            self.height = height
        }
        
        var body: some View {
            SkeletonBox(width: width, height: height, cornerRadius: height / 2)
        }
    }
    
    // MARK: - Composite Skeleton Components
    
    /// 統計カード用スケルトン
    struct StatsCardSkeleton: View {
        var body: some View {
            VStack(spacing: 12) {
                HStack {
                    SkeletonCircle(size: 24)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonTextLine(width: 80, height: 16)
                    SkeletonTextLine(width: 60, height: 24)
                    SkeletonTextLine(width: 70, height: 14)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large)
                    .fill(Color(.systemBackground))
                    .appShadow(AppShadow.cardElevated)
            )
        }
    }
    
    /// リスト項目用スケルトン
    struct ListItemSkeleton: View {
        var body: some View {
            HStack(spacing: 12) {
                SkeletonCircle(size: 40)
                
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonTextLine(width: 120, height: 16)
                    SkeletonTextLine(width: 80, height: 14)
                }
                
                Spacer()
                
                SkeletonBox(width: 24, height: 24, cornerRadius: AppRadius.medium)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .fill(Color(.systemBackground))
                    .appShadow(AppShadow.card)
            )
        }
    }
    
    // MARK: - Screen-specific Skeletons
    
    /// ホーム画面用スケルトン
    struct HomeViewSkeleton: View {
        var body: some View {
            ScrollView {
                VStack(spacing: 20) {
                    // 選択された子供の統計情報
                    VStack(spacing: 20) {
                        VStack(spacing: 12) {
                            SkeletonCircle(size: 80)
                            SkeletonTextLine(width: 150, height: 20)
                        }
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            ForEach(0..<4, id: \.self) { _ in
                                StatsCardSkeleton()
                            }
                        }
                        
                        // お小遣い支払いボタン
                        SkeletonBox(width: nil, height: 50, cornerRadius: 25)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.xLarge)
                            .fill(Color(.systemBackground))
                            .appShadow(AppShadow.floating)
                    )
                    .padding(.horizontal)
                    
                    // 子供リスト
                    VStack(alignment: .leading, spacing: 12) {
                        SkeletonTextLine(width: 100, height: 18)
                            .padding(.horizontal)
                        
                        LazyVStack(spacing: 8) {
                            ForEach(0..<3, id: \.self) { _ in
                                ListItemSkeleton()
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }
}