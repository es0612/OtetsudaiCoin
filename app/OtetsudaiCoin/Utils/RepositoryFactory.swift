//
//  RepositoryFactory.swift
//  OtetsudaiCoin
//
//  Created on 2025/07/10
//

import Foundation
import CoreData

/// Repositoryインスタンスを一元管理するファクトリークラス
@MainActor
class RepositoryFactory {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Repository Creation
    
    func createChildRepository() -> ChildRepository {
        CoreDataChildRepository(context: context)
    }
    
    func createHelpTaskRepository() -> HelpTaskRepository {
        CoreDataHelpTaskRepository(context: context)
    }
    
    func createHelpRecordRepository() -> HelpRecordRepository {
        CoreDataHelpRecordRepository(context: context)
    }
    
    func createAllowancePaymentRepository() -> AllowancePaymentRepository {
        // TODO: 本格運用時はCoreDataベースの実装に変更を検討
        InMemoryAllowancePaymentRepository.shared
    }
}

/// ViewModelを作成するためのファクトリークラス
@MainActor
class ViewModelFactory {
    private let repositoryFactory: RepositoryFactory
    
    init(repositoryFactory: RepositoryFactory) {
        self.repositoryFactory = repositoryFactory
    }
    
    // MARK: - ViewModel Creation
    
    func createChildManagementViewModel() -> ChildManagementViewModel {
        ChildManagementViewModel(
            childRepository: repositoryFactory.createChildRepository()
        )
    }
    
    func createHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            childRepository: repositoryFactory.createChildRepository(),
            helpRecordRepository: repositoryFactory.createHelpRecordRepository(),
            helpTaskRepository: repositoryFactory.createHelpTaskRepository(),
            allowanceCalculator: AllowanceCalculator(),
            allowancePaymentRepository: repositoryFactory.createAllowancePaymentRepository()
        )
    }
    
    func createRecordViewModel() -> RecordViewModel {
        RecordViewModel(
            childRepository: repositoryFactory.createChildRepository(),
            helpTaskRepository: repositoryFactory.createHelpTaskRepository(),
            helpRecordRepository: repositoryFactory.createHelpRecordRepository()
        )
    }
    
    func createHelpHistoryViewModel() -> HelpHistoryViewModel {
        HelpHistoryViewModel(
            helpRecordRepository: repositoryFactory.createHelpRecordRepository(),
            helpTaskRepository: repositoryFactory.createHelpTaskRepository(),
            childRepository: repositoryFactory.createChildRepository()
        )
    }
    
    func createTaskManagementViewModel() -> TaskManagementViewModel {
        TaskManagementViewModel(
            helpTaskRepository: repositoryFactory.createHelpTaskRepository()
        )
    }
    
    func createMonthlyHistoryViewModel() -> MonthlyHistoryViewModel {
        MonthlyHistoryViewModel(
            helpRecordRepository: repositoryFactory.createHelpRecordRepository(),
            allowancePaymentRepository: repositoryFactory.createAllowancePaymentRepository(),
            helpTaskRepository: repositoryFactory.createHelpTaskRepository(),
            allowanceCalculator: AllowanceCalculator()
        )
    }
    
    func createHelpRecordEditViewModel(
        helpRecord: HelpRecord,
        child: Child
    ) -> HelpRecordEditViewModel {
        HelpRecordEditViewModel(
            helpRecord: helpRecord,
            child: child,
            helpRecordRepository: repositoryFactory.createHelpRecordRepository(),
            helpTaskRepository: repositoryFactory.createHelpTaskRepository()
        )
    }
}