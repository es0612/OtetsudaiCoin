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
    @StateObject private var tutorialService = TutorialService()
    @StateObject private var homeViewModel = HomeViewModel(
        childRepository: CoreDataChildRepository(context: PersistenceController.shared.container.viewContext),
        helpRecordRepository: CoreDataHelpRecordRepository(context: PersistenceController.shared.container.viewContext),
        allowanceCalculator: AllowanceCalculator()
    )
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(viewModel: homeViewModel)
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
            
            SettingsView(viewModel: createChildManagementViewModel())
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("設定")
                }
                .tag(2)
        }
        .onChange(of: selectedTab) { newTab in
            if newTab == 0 {
                // SwiftUIの宣言的な仕組み：ホームタブに戻った際の自動更新
                homeViewModel.refreshData()
            }
        }
        .fullScreenCover(isPresented: $tutorialService.showTutorial) {
            TutorialContainerView(
                tutorialService: tutorialService,
                childManagementViewModel: createChildManagementViewModel(),
                recordViewModel: createRecordViewModel()
            )
        }
        .onAppear {
            setupInitialData()
            tutorialService.checkFirstLaunch()
        }
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
    
    private func createChildManagementViewModel() -> ChildManagementViewModel {
        let childRepository = CoreDataChildRepository(context: viewContext)
        
        return ChildManagementViewModel(childRepository: childRepository)
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
                
                // 子供データは初期作成しない（チュートリアルで追加）
                
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
