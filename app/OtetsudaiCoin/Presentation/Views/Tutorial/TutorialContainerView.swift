import SwiftUI

struct TutorialContainerView: View {
    @ObservedObject var tutorialService: TutorialService
    @ObservedObject var childManagementViewModel: ChildManagementViewModel
    @ObservedObject var recordViewModel: RecordViewModel
    
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
        .onChange(of: tutorialService.shouldShowRecordTutorial) { _, newValue in
            if newValue {
                // SwiftUIの宣言的な仕組みを活用してデータ同期
                recordViewModel.loadData()
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let childRepository = CoreDataChildRepository(context: context)
    let taskRepository = CoreDataHelpTaskRepository(context: context)
    let recordRepository = CoreDataHelpRecordRepository(context: context)
    
    let childManagementViewModel = ChildManagementViewModel(childRepository: childRepository)
    let recordViewModel = RecordViewModel(
        childRepository: childRepository,
        helpTaskRepository: taskRepository,
        helpRecordRepository: recordRepository
    )
    
    let tutorialService = TutorialService()
    
    TutorialContainerView(
        tutorialService: tutorialService,
        childManagementViewModel: childManagementViewModel,
        recordViewModel: recordViewModel
    )
}