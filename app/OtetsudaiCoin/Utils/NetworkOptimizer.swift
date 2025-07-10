//
//  NetworkOptimizer.swift
//  OtetsudaiCoin
//
//  Created on 2025/07/10
//

import Foundation
import Network
import SwiftUI

/// ネットワーク効率化・最適化ユーティリティ
class NetworkOptimizer: ObservableObject {
    
    // MARK: - プロパティ
    
    @Published var isConnected: Bool = false
    @Published var connectionType: ConnectionType = .unknown
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    // MARK: - シングルトン
    
    static let shared = NetworkOptimizer()
    
    private init() {
        startNetworkMonitoring()
    }
    
    // MARK: - ネットワーク監視
    
    /// ネットワーク監視を開始
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateNetworkStatus(path: path)
            }
        }
        
        monitor.start(queue: queue)
    }
    
    /// ネットワーク状態の更新
    /// - Parameter path: ネットワークパス情報
    private func updateNetworkStatus(path: NWPath) {
        isConnected = path.status == .satisfied
        
        // 接続タイプの判定
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else {
            connectionType = .unknown
        }
    }
    
    // MARK: - 最適化されたリクエスト
    
    /// 最適化されたHTTPリクエスト
    /// - Parameter url: リクエストURL
    /// - Returns: レスポンスデータ
    func optimizedRequest(url: URL) async throws -> Data {
        // ネットワーク状態に応じたリクエスト作成
        let request = createOptimizedRequest(url: url)
        
        // リクエスト実行
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }
    
    /// 最適化されたリクエスト作成
    /// - Parameter url: リクエストURL
    /// - Returns: 最適化されたURLRequest
    private func createOptimizedRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        
        // 接続タイプに応じたタイムアウト設定
        switch connectionType {
        case .wifi:
            request.timeoutInterval = 10.0
        case .cellular:
            request.timeoutInterval = 20.0
        case .unknown:
            request.timeoutInterval = 30.0
        }
        
        // セルラー接続時の圧縮設定
        if connectionType == .cellular {
            request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        }
        
        return request
    }
}

// MARK: - 列挙型

enum ConnectionType {
    case wifi
    case cellular
    case unknown
}

enum NetworkError: Error {
    case noData
    case invalidResponse
    case timeout
    case noConnection
}

// MARK: - ネットワークキャッシュ

class NetworkCache {
    static let shared = NetworkCache()
    
    private let cache = NSCache<NSString, NSData>()
    
    private init() {
        setupCache()
    }
    
    private func setupCache() {
        // メモリキャッシュの設定
        cache.totalCostLimit = 10 * 1024 * 1024 // 10MB
        cache.countLimit = 100
    }
    
    /// キャッシュデータの取得
    /// - Parameter url: URL
    /// - Returns: キャッシュされたデータ
    func getCachedData(for url: URL) -> Data? {
        let key = url.absoluteString as NSString
        return cache.object(forKey: key) as Data?
    }
    
    /// データをキャッシュに保存
    /// - Parameters:
    ///   - data: キャッシュするデータ
    ///   - url: URL
    func cacheData(_ data: Data, for url: URL) {
        let key = url.absoluteString as NSString
        let cost = data.count
        cache.setObject(data as NSData, forKey: key, cost: cost)
    }
    
    /// キャッシュをクリア
    func clearCache() {
        cache.removeAllObjects()
    }
}

// MARK: - ネットワーク状態インジケーター

struct NetworkStatusIndicator: View {
    @StateObject private var optimizer = NetworkOptimizer.shared
    
    var body: some View {
        HStack {
            Circle()
                .fill(optimizer.isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var statusText: String {
        if !optimizer.isConnected {
            return "オフライン"
        }
        
        switch optimizer.connectionType {
        case .wifi:
            return "Wi-Fi"
        case .cellular:
            return "モバイル"
        case .unknown:
            return "接続中"
        }
    }
}

// MARK: - View Extensions

extension View {
    /// ネットワーク最適化を適用
    func networkOptimized() -> some View {
        self.onAppear {
            // ネットワーク監視は自動的に開始される
        }
    }
}