//
//  OtetsudaiCoinApp.swift
//  OtetsudaiCoin
//  
//  Created on 2025/06/15
//


import SwiftUI

@main
struct OtetsudaiCoinApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            if persistenceController.storeLoadError != nil {
                // ストア未 attach で全データが空に見える状態。アプリへ入れず、
                // 再起動を促すブロッキング画面を出す（Issue #131）。
                StoreLoadErrorView()
            } else {
                ContentView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }
        }
    }
}
