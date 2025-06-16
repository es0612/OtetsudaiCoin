//
//  ContentView.swift
//  OtetsudaiCoin
//  
//  Created on 2025/06/15
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(viewModel: createHomeViewModel())
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("ホーム")
                }
                .tag(0)
            
            RecordView(viewModel: createRecordViewModel())
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("記録")
                }
                .tag(1)
        }
        .onAppear {
            setupInitialData()
        }
    }
    
    private func createHomeViewModel() -> HomeViewModel {
        let childRepository = CoreDataChildRepository(context: viewContext)
        let helpRecordRepository = CoreDataHelpRecordRepository(context: viewContext)
        let allowanceCalculator = AllowanceCalculator()
        
        return HomeViewModel(
            childRepository: childRepository,
            helpRecordRepository: helpRecordRepository,
            allowanceCalculator: allowanceCalculator
        )
    }
    
    private func createRecordViewModel() -> RecordViewModel {
        let childRepository = CoreDataChildRepository(context: viewContext)
        let helpTaskRepository = CoreDataHelpTaskRepository(context: viewContext)
        let helpRecordRepository = CoreDataHelpRecordRepository(context: viewContext)
        
        return RecordViewModel(
            childRepository: childRepository,
            helpTaskRepository: helpTaskRepository,
            helpRecordRepository: helpRecordRepository
        )
    }
    
    private func setupInitialData() {
        // 初回起動時のサンプルデータセットアップ
        let childRepository = CoreDataChildRepository(context: viewContext)
        let helpTaskRepository = CoreDataHelpTaskRepository(context: viewContext)
        
        Task {
            do {
                // 既存データがあるかチェック
                let existingChildren = try await childRepository.findAll()
                let existingTasks = try await helpTaskRepository.findAll()
                
                if existingChildren.isEmpty {
                    // サンプル子供データ追加
                    let child1 = Child(id: UUID(), name: "太郎", themeColor: "#FF5733")
                    let child2 = Child(id: UUID(), name: "花子", themeColor: "#33FF57")
                    
                    try await childRepository.save(child1)
                    try await childRepository.save(child2)
                }
                
                if existingTasks.isEmpty {
                    // デフォルトタスク追加
                    let defaultTasks = HelpTask.defaultTasks()
                    for task in defaultTasks {
                        try await helpTaskRepository.save(task)
                    }
                }
            } catch {
                print("初期データセットアップエラー: \(error)")
            }
        }
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
