//
//  DeviceInfo.swift
//  OtetsudaiCoin
//  
//  Created on 2025/07/30
//

import SwiftUI
import UIKit

struct DeviceInfo {
    
    /// 現在のデバイスがiPadかどうかを判定
    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    /// 現在のデバイスがiPhoneかどうかを判定
    static var isIPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
    
    /// iPad用のコンテンツ最大幅（読みやすさを考慮）
    static let ipadMaxContentWidth: CGFloat = 800
    
    /// コンテンツの推奨幅を取得
    /// - Parameter screenWidth: 画面幅
    /// - Returns: 推奨コンテンツ幅
    static func preferredContentWidth(screenWidth: CGFloat) -> CGFloat {
        if isIPad {
            return min(screenWidth * 0.8, ipadMaxContentWidth)
        } else {
            return screenWidth
        }
    }
    
    /// 統計カードのグリッド列数を取得
    /// - Parameter horizontalSizeClass: 水平サイズクラス
    /// - Returns: 推奨列数
    static func statisticsCardColumns(for horizontalSizeClass: UserInterfaceSizeClass?) -> Int {
        if isIPad && horizontalSizeClass == .regular {
            return 4  // iPad横向きまたは大画面
        } else if isIPad {
            return 3  // iPad縦向き
        } else {
            return 2  // iPhone
        }
    }
    
    /// コンテンツパディング値を取得
    static var contentPadding: CGFloat {
        if isIPad {
            return 24
        } else {
            return 16
        }
    }
    
    /// 統計カードのスペーシング値を取得
    static var statisticsCardSpacing: CGFloat {
        if isIPad {
            return 20
        } else {
            return 16
        }
    }
}

/// View拡張でデバイス対応のレイアウト調整を簡単に適用
extension View {
    
    /// iPad対応のコンテンツ幅制限を適用
    func adaptiveContentWidth() -> some View {
        GeometryReader { geometry in
            HStack {
                Spacer()
                self
                    .frame(
                        maxWidth: DeviceInfo.preferredContentWidth(screenWidth: geometry.size.width)
                    )
                Spacer()
            }
        }
    }
    
    /// デバイス対応のパディングを適用
    func adaptivePadding() -> some View {
        self.padding(DeviceInfo.contentPadding)
    }
}