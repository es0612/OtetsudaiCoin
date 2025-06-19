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
    
    // 共通のRepositoryインスタンス
    private var sharedChildRepository: ChildRepository {
        CoreDataChildRepository(context: PersistenceController.shared.container.viewContext)
    }
    
    @StateObject private var childManagementViewModel: ChildManagementViewModel
    @StateObject private var homeViewModel: HomeViewModel
    
    init() {
        let childRepo = CoreDataChildRepository(context: PersistenceController.shared.container.viewContext)
        let helpRecordRepo = CoreDataHelpRecordRepository(context: PersistenceController.shared.container.viewContext)
        let allowancePaymentRepo = InMemoryAllowancePaymentRepository() // 一時的にメモリ実装を使用
        
        _childManagementViewModel = StateObject(wrappedValue: ChildManagementViewModel(childRepository: childRepo))
        _homeViewModel = StateObject(wrappedValue: HomeViewModel(
            childRepository: childRepo,
            helpRecordRepository: helpRecordRepo,
            allowanceCalculator: AllowanceCalculator(),
            allowancePaymentRepository: allowancePaymentRepo
        ))
    }
    
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
            
            SettingsView(viewModel: childManagementViewModel)
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("設定")
                }
                .tag(2)
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == 0 {
                // SwiftUIの宣言的な仕組み：ホームタブに戻った際の自動更新
                homeViewModel.refreshData()
            }
        }
        .fullScreenCover(isPresented: $tutorialService.showTutorial) {
            TutorialContainerView(
                tutorialService: tutorialService,
                childManagementViewModel: childManagementViewModel,
                recordViewModel: createRecordViewModel()
            )
        }
        .onAppear {
            setupInitialData()
            tutorialService.checkFirstLaunch()
        }
    }
    
    
    private func createRecordViewModel() -> RecordViewModel {
        let helpTaskRepository = CoreDataHelpTaskRepository(context: viewContext)
        let helpRecordRepository = CoreDataHelpRecordRepository(context: viewContext)
        let childRepository = CoreDataChildRepository(context: PersistenceController.shared.container.viewContext)
        
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
                
                // UIテスト実行時は事前にサンプルデータを作成
                if ProcessInfo.processInfo.arguments.contains("--uitesting") {
                    if existingChildren.isEmpty {
                        let sampleChildren = [
                            Child(id: UUID(), name: "太郎", themeColor: "#FF5733", coinRate: 100),
                            Child(id: UUID(), name: "花子", themeColor: "#33FF57", coinRate: 120)
                        ]
                        for child in sampleChildren {
                            try await childRepository.save(child)
                        }
                    }
                }
                
                // 月末自動リセットをチェック
                let helpRecordRepository = CoreDataHelpRecordRepository(context: viewContext)
                let monthlyResetService = MonthlyResetService(helpRecordRepository: helpRecordRepository)
                try await monthlyResetService.checkAndPerformMonthlyReset()
                
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
