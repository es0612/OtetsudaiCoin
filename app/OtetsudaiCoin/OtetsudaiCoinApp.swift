//
//  OtetsudaiCoinApp.swift
//  OtetsudaiCoin
//  
//  Created on 2025/06/15
//


import SwiftUI

@main
struct OtetsudaiCoinApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
