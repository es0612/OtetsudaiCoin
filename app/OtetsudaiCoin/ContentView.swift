//
//  ContentView.swift
//  OtetsudaiCoin
//  
//  Created on 2025/06/15
//

import SwiftUI
import CoreData
import UserNotifications

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = 0
    @State private var tutorialService = TutorialService()
    // Skip the cosmetic splash under UI testing so screenshots / automation never
    // race its fade-out animation (Issue #97). Mirrors the --uitesting tutorial skip
    // in TutorialService. The splash never appears in ASC screenshots anyway.
    @State private var showSplashScreen = !ProcessInfo.processInfo.arguments.contains("--uitesting")
    
    // ファクトリーを使用した依存性注入
    private let repositoryFactory: RepositoryFactory
    private let viewModelFactory: ViewModelFactory
    
    @State private var childManagementViewModel: ChildManagementViewModel
    @State private var homeViewModel: HomeViewModel
    @State private var recordViewModel: RecordViewModel
    @State private var paymentReminderService: PaymentReminderNotificationService

    @MainActor
    init() {
        let context = PersistenceController.shared.container.viewContext
        self.repositoryFactory = RepositoryFactory(context: context)
        self.viewModelFactory = ViewModelFactory(repositoryFactory: repositoryFactory)

        _childManagementViewModel = State(wrappedValue: viewModelFactory.createChildManagementViewModel())
        _homeViewModel = State(wrappedValue: viewModelFactory.createHomeViewModel())
        // body 再評価のたびに生成すると記録途中の選択状態が失われるため、
        // 他の ViewModel と同様に @State で一度だけ生成する (Issue #152)
        _recordViewModel = State(wrappedValue: viewModelFactory.createRecordViewModel())

        let paymentService = PaymentReminderNotificationService(
            notificationCenter: UNUserNotificationCenter.current(),
            userDefaults: .standard,
            unpaidDetector: UnpaidAllowanceDetectorService(),
            childRepository: repositoryFactory.createChildRepository(),
            helpRecordRepository: repositoryFactory.createHelpRecordRepository(),
            allowancePaymentRepository: repositoryFactory.createAllowancePaymentRepository(),
            helpTaskRepository: repositoryFactory.createHelpTaskRepository()
        )
        _paymentReminderService = State(wrappedValue: paymentService)
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
            
            RecordView(viewModel: recordViewModel)
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
            tutorialService.checkFirstLaunch()
        }
        .onReceive(Foundation.NotificationCenter.default.publisher(for: .navigateToRecord)) { _ in
            selectedTab = 1
        }
        .onReceive(Foundation.NotificationCenter.default.publisher(for: .navigateToHome)) { _ in
            selectedTab = 0
        }
    }
    
    
    
    private func setupInitialData() {
        // 初回起動時のサンプルデータセットアップ
        let childRepository = repositoryFactory.createChildRepository()
        let helpTaskRepository = repositoryFactory.createHelpTaskRepository()
        
        Task {
            do {
                // 支払い履歴の UserDefaults → Core Data one-shot 移行 (Issue #142)。
                // store のロード失敗時に走らせると移行が空振りしてフラグだけ立つ事故に
                // なり得るため、storeLoadError == nil を確認してから実行する
                // (フラグ自体も移行成功時のみ立つ二重ガード)。後続の
                // paymentReminderService.reschedule() が支払い履歴を読むため先頭で行う。
                if PersistenceController.shared.storeLoadError == nil {
                    let migrationService = AllowancePaymentMigrationService(
                        repository: repositoryFactory.createAllowancePaymentRepository()
                    )
                    await migrationService.migrateIfNeeded()
                }

                // 既存データがあるかチェック
                let existingChildren = try await childRepository.findAll()
                let existingTasks = try await helpTaskRepository.findAll()
                
                // UIテスト実行時は事前にサンプルデータを作成
                if ProcessInfo.processInfo.arguments.contains("--uitesting") {
                    if existingChildren.isEmpty {
                        let sampleChildren = [
                            Child(id: UUID(), name: "太郎", themeColor: "#E8590C"),
                            Child(id: UUID(), name: "花子", themeColor: "#099268")
                        ]
                        for child in sampleChildren {
                            try await childRepository.save(child)
                        }
                        // Notify observers so HomeViewModel reloads the seeded
                        // children. Seeding goes straight through the repository
                        // (not ChildManagementViewModel, which would notify), so
                        // without this a cold launch renders Home before the async
                        // seed finishes and never reloads. The splash used to mask
                        // this by delaying Home's first load (Issue #97 splash-skip
                        // exposed it).
                        NotificationManager.shared.notifyChildrenUpdated()
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

                // 支払いリマインドの起動時 reschedule
                do {
                    try await paymentReminderService.reschedule()
                } catch {
                    DebugLogger.error("支払いリマインド reschedule エラー: \(error)")
                }
            } catch {
                DebugLogger.error("初期データセットアップエラー: \(error)")
            }
        }
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
