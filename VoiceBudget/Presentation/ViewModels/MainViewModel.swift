import Foundation
import Combine

@MainActor
class MainViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private let transactionRepository: TransactionRepository
    private let budgetRepository: BudgetRepository
    private let preferenceRepository: UserPreferenceRepository
    
    // MARK: - Use Cases
    private let createTransactionUseCase: CreateTransactionUseCase
    private let getBudgetStatusUseCase: GetBudgetStatusUseCase
    private let getSpendingAnalyticsUseCase: GetSpendingAnalyticsUseCase
    
    // MARK: - Published Properties
    @Published var currentBudget: BudgetEntity?
    @Published var budgetUsage: BudgetUsage?
    @Published var recentTransactions: [TransactionEntity] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        let coreDataStack = CoreDataStack.shared
        self.transactionRepository = CoreDataTransactionRepository(context: coreDataStack.viewContext)
        self.budgetRepository = CoreDataBudgetRepository(context: coreDataStack.viewContext)
        self.preferenceRepository = UserDefaultsPreferenceRepository()
        
        self.createTransactionUseCase = CreateTransactionUseCase(
            transactionRepository: transactionRepository,
            budgetRepository: budgetRepository
        )
        
        self.getBudgetStatusUseCase = GetBudgetStatusUseCase(
            budgetRepository: budgetRepository,
            transactionRepository: transactionRepository
        )
        
        self.getSpendingAnalyticsUseCase = GetSpendingAnalyticsUseCase(
            transactionRepository: transactionRepository
        )
        
        loadInitialData()
    }
    
    // MARK: - Public Methods
    
    func loadInitialData() {
        Task {
            await loadCurrentBudget()
            await loadRecentTransactions()
        }
    }
    
    func refreshData() {
        Task {
            isLoading = true
            await loadCurrentBudget()
            await loadRecentTransactions()
            isLoading = false
        }
    }
    
    // MARK: - Private Methods
    
    private func loadCurrentBudget() async {
        do {
            let request = GetBudgetStatusUseCase.Request()
            let response = try await getBudgetStatusUseCase.execute(request)
            
            if response.success {
                currentBudget = response.budget
                budgetUsage = response.budgetUsage
            }
        } catch {
            errorMessage = "加载预算信息失败: \(error.localizedDescription)"
        }
    }
    
    private func loadRecentTransactions() async {
        do {
            recentTransactions = try await transactionRepository.getRecentTransactions(limit: 5)
        } catch {
            errorMessage = "加载最近记录失败: \(error.localizedDescription)"
        }
    }
}