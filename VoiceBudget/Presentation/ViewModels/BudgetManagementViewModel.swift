import Foundation
import Combine

@MainActor
class BudgetManagementViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var budgets: [BudgetEntity] = []
    @Published var budgetStatuses: [BudgetStatus] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var editingBudget: BudgetEntity?
    
    // MARK: - Dependencies
    private let getBudgetStatusUseCase: GetBudgetStatusUseCase
    private let createBudgetUseCase: CreateBudgetUseCase
    private let deleteBudgetUseCase: DeleteBudgetUseCase
    private let updateBudgetUseCase: UpdateBudgetUseCase
    private let getBudgetsUseCase: GetBudgetsUseCase
    
    // MARK: - Computed Properties
    var totalBudgetAmount: Double {
        budgets.reduce(0) { $0 + $1.amount }
    }
    
    var totalSpentAmount: Double {
        budgetStatuses.reduce(0) { $0 + $1.spentAmount }
    }
    
    // MARK: - Initialization
    init(
        getBudgetStatusUseCase: GetBudgetStatusUseCase = DIContainer.shared.resolve(),
        createBudgetUseCase: CreateBudgetUseCase = DIContainer.shared.resolve(),
        deleteBudgetUseCase: DeleteBudgetUseCase = DIContainer.shared.resolve(),
        updateBudgetUseCase: UpdateBudgetUseCase = DIContainer.shared.resolve(),
        getBudgetsUseCase: GetBudgetsUseCase = DIContainer.shared.resolve()
    ) {
        self.getBudgetStatusUseCase = getBudgetStatusUseCase
        self.createBudgetUseCase = createBudgetUseCase
        self.deleteBudgetUseCase = deleteBudgetUseCase
        self.updateBudgetUseCase = updateBudgetUseCase
        self.getBudgetsUseCase = getBudgetsUseCase
    }
    
    // MARK: - Public Methods
    func loadBudgets() async {
        isLoading = true
        errorMessage = nil
        
        do {
            budgets = try await getBudgetsUseCase.execute()
            await loadBudgetStatuses()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func editBudget(_ budget: BudgetEntity) {
        editingBudget = budget
    }
    
    func deleteBudget(_ budget: BudgetEntity) {
        Task {
            do {
                try await deleteBudgetUseCase.execute(budgetId: budget.id)
                await loadBudgets()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func createBudget(_ budget: BudgetEntity) {
        Task {
            do {
                try await createBudgetUseCase.execute(budget: budget)
                await loadBudgets()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func updateBudget(_ budget: BudgetEntity) {
        Task {
            do {
                try await updateBudgetUseCase.execute(budget: budget)
                await loadBudgets()
                editingBudget = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Private Methods
    private func loadBudgetStatuses() async {
        var statuses: [BudgetStatus] = []
        
        for budget in budgets {
            do {
                let status = try await getBudgetStatusUseCase.execute(budgetId: budget.id)
                statuses.append(status)
            } catch {
                print("Failed to load status for budget \(budget.id): \(error)")
            }
        }
        
        budgetStatuses = statuses
    }
}

// MARK: - Additional Use Cases (需要实现)
protocol GetBudgetsUseCase {
    func execute() async throws -> [BudgetEntity]
}

protocol DeleteBudgetUseCase {
    func execute(budgetId: UUID) async throws
}

protocol UpdateBudgetUseCase {
    func execute(budget: BudgetEntity) async throws
}

class GetBudgetsUseCaseImpl: GetBudgetsUseCase {
    private let budgetRepository: BudgetRepository
    
    init(budgetRepository: BudgetRepository) {
        self.budgetRepository = budgetRepository
    }
    
    func execute() async throws -> [BudgetEntity] {
        return try await budgetRepository.getAllBudgets()
    }
}

class DeleteBudgetUseCaseImpl: DeleteBudgetUseCase {
    private let budgetRepository: BudgetRepository
    
    init(budgetRepository: BudgetRepository) {
        self.budgetRepository = budgetRepository
    }
    
    func execute(budgetId: UUID) async throws {
        try await budgetRepository.delete(budgetId: budgetId)
    }
}

class UpdateBudgetUseCaseImpl: UpdateBudgetUseCase {
    private let budgetRepository: BudgetRepository
    
    init(budgetRepository: BudgetRepository) {
        self.budgetRepository = budgetRepository
    }
    
    func execute(budget: BudgetEntity) async throws {
        try await budgetRepository.update(budget: budget)
    }
}