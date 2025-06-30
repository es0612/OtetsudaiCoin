import SwiftUI

struct TutorialContainerView: View {
    @Bindable var tutorialService: TutorialService
    @Bindable var childManagementViewModel: ChildManagementViewModel
    @Bindable var recordViewModel: RecordViewModel
    
    var body: some View {
        Group {
            if tutorialService.shouldShowChildTutorial {
                ChildTutorialView(
                    tutorialService: tutorialService,
                    childManagementViewModel: childManagementViewModel
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            } else if tutorialService.shouldShowRecordTutorial {
                RecordTutorialView(
                    tutorialService: tutorialService,
                    recordViewModel: recordViewModel
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .animation(.easeInOut(duration: 0.6), value: tutorialService.shouldShowChildTutorial)
        .animation(.easeInOut(duration: 0.6), value: tutorialService.shouldShowRecordTutorial)
        .onChange(of: tutorialService.shouldShowRecordTutorial) { oldValue, newValue in
            if oldValue == false && newValue == true {
                // チュートリアル開始時のみデータを読み込み（重複実行を防ぐ）
                DispatchQueue.main.async {
                    recordViewModel.resetSessionState()
                    recordViewModel.loadData()
                }
            }
        }
    }
}

#Preview {
    @State var previewChildManagementViewModel: ChildManagementViewModel?
    @State var previewRecordViewModel: RecordViewModel?
    
    Group {
        if let childVM = previewChildManagementViewModel,
           let recordVM = previewRecordViewModel {
            TutorialContainerView(
                tutorialService: TutorialService(),
                childManagementViewModel: childVM,
                recordViewModel: recordVM
            )
        } else {
            Text("Loading...")
        }
    }
    .task {
        await MainActor.run {
            let context = PersistenceController.preview.container.viewContext
            let childRepository = CoreDataChildRepository(context: context)
            let taskRepository = CoreDataHelpTaskRepository(context: context)
            let recordRepository = CoreDataHelpRecordRepository(context: context)
            
            previewChildManagementViewModel = ChildManagementViewModel(childRepository: childRepository)
            previewRecordViewModel = RecordViewModel(
                childRepository: childRepository,
                helpTaskRepository: taskRepository,
                helpRecordRepository: recordRepository
            )
        }
    }
}