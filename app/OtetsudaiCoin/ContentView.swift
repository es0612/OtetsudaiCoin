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
    @State private var tutorialService = TutorialService()
    @State private var showSplashScreen = true
    
    // ファクトリーを使用した依存性注入
    private let repositoryFactory: RepositoryFactory
    private let viewModelFactory: ViewModelFactory
    
    @State private var childManagementViewModel: ChildManagementViewModel
    @State private var homeViewModel: HomeViewModel
    
    @MainActor
    init() {
        let context = PersistenceController.shared.container.viewContext
        self.repositoryFactory = RepositoryFactory(context: context)
        self.viewModelFactory = ViewModelFactory(repositoryFactory: repositoryFactory)
        
        _childManagementViewModel = State(wrappedValue: viewModelFactory.createChildManagementViewModel())
        _homeViewModel = State(wrappedValue: viewModelFactory.createHomeViewModel())
    }
    
    var body: some View {
        ZStack {
            if showSplashScreen {
                SplashScreenView {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        showSplashScreen = false
                    }
                }
                .transition(.opacity)
            } else {
                mainAppView
                    .transition(.opacity)
            }
        }
        .onAppear {
            setupInitialData()
        }
    }
    
    private var mainAppView: some View {
        TabView(selection: $selectedTab) {
            HomeView(viewModel: homeViewModel)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("ホーム")
                }
                .tag(0)
            
            RecordView(viewModel: viewModelFactory.createRecordViewModel())
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
                recordViewModel: viewModelFactory.createRecordViewModel()
            )
        }
        .onAppear {
            // スプラッシュスクリーン終了後にチュートリアルチェック
            tutorialService.checkFirstLaunch()
        }
    }
    
    
    
    private func setupInitialData() {
        // 初回起動時のサンプルデータセットアップ
        let childRepository = repositoryFactory.createChildRepository()
        let helpTaskRepository = repositoryFactory.createHelpTaskRepository()
        
        Task {
            do {
                // 既存データがあるかチェック
                let existingChildren = try await childRepository.findAll()
                let existingTasks = try await helpTaskRepository.findAll()
                
                // UIテスト実行時は事前にサンプルデータを作成
                if ProcessInfo.processInfo.arguments.contains("--uitesting") {
                    if existingChildren.isEmpty {
                        let sampleChildren = [
                            Child(id: UUID(), name: "太郎", themeColor: "#FF5733"),
                            Child(id: UUID(), name: "花子", themeColor: "#33FF57")
                        ]
                        for child in sampleChildren {
                            try await childRepository.save(child)
                        }
                    }
                }
                
                // 月末自動リセットをチェック
                let helpRecordRepository = repositoryFactory.createHelpRecordRepository()
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
