import Foundation
import Combine

@MainActor
class BudgetViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private let budgetRepository: BudgetRepository
    private let getBudgetStatusUseCase: GetBudgetStatusUseCase
    
    // MARK: - Published Properties
    @Published var currentBudget: BudgetEntity?
    @Published var budgetUsage: BudgetUsage?
    @Published var categoryUsages: [CategoryBudgetUsage] = []
    @Published var executionTrend: [BudgetExecutionData] = []
    @Published var recommendations: [GetBudgetStatusUseCase.BudgetRecommendation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Initialization
    init() {
        let coreDataStack = CoreDataStack.shared
        let transactionRepository = CoreDataTransactionRepository(context: coreDataStack.viewContext)
        self.budgetRepository = CoreDataBudgetRepository(context: coreDataStack.viewContext)
        
        self.getBudgetStatusUseCase = GetBudgetStatusUseCase(
            budgetRepository: budgetRepository,
            transactionRepository: transactionRepository
        )
    }
    
    // MARK: - Public Methods
    
    func loadBudgetData() {
        Task {
            await loadCurrentBudgetStatus()
        }
    }
    
    func refresh() {
        Task {
            isLoading = true
            await loadCurrentBudgetStatus()
            isLoading = false
        }
    }
    
    // MARK: - Private Methods
    
    private func loadCurrentBudgetStatus() async {
        do {
            let request = GetBudgetStatusUseCase.Request(
                includeTrend: true,
                includeCategoryBreakdown: true
            )
            
            let response = try await getBudgetStatusUseCase.execute(request)
            
            if response.success {
                currentBudget = response.budget
                budgetUsage = response.budgetUsage
                categoryUsages = response.categoryUsages
                executionTrend = response.executionTrend
                recommendations = response.recommendations
            } else {
                errorMessage = response.error?.localizedDescription
            }
        } catch {
            errorMessage = "加载预算数据失败: \(error.localizedDescription)"
        }
    }
}

@MainActor
class CreateBudgetViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private let createBudgetUseCase: CreateBudgetUseCase
    
    // MARK: - Published Properties
    @Published var name = ""
    @Published var totalAmount: Decimal = 0
    @Published var period: BudgetEntity.BudgetPeriod = .month
    @Published var categoryAllocations: [BudgetEntity.BudgetCategoryAllocation] = []
    @Published var isCreating = false
    @Published var errorMessage: String?
    
    // MARK: - Computed Properties
    var totalAllocated: Decimal {
        categoryAllocations.reduce(0) { $0 + $1.allocatedAmount }
    }
    
    var isAllocationValid: Bool {
        abs(totalAllocated - totalAmount) < 0.01
    }
    
    var isValid: Bool {
        !name.isEmpty && totalAmount > 0 && isAllocationValid
    }
    
    // MARK: - Initialization
    init() {
        let coreDataStack = CoreDataStack.shared
        let budgetRepository = CoreDataBudgetRepository(context: coreDataStack.viewContext)
        let preferenceRepository = UserDefaultsPreferenceRepository()
        
        self.createBudgetUseCase = CreateBudgetUseCase(
            budgetRepository: budgetRepository,
            preferenceRepository: preferenceRepository
        )
        
        setupDefaultAllocations()
    }
    
    // MARK: - Public Methods
    
    func createBudget(completion: @escaping () -> Void) {
        guard isValid else { return }
        
        isCreating = true
        
        Task {
            do {
                let request = CreateBudgetUseCase.Request(
                    name: name,
                    totalAmount: totalAmount,
                    period: period,
                    categoryAllocations: categoryAllocations
                )
                
                let response = try await createBudgetUseCase.execute(request)
                
                await MainActor.run {
                    isCreating = false
                    
                    if response.success {
                        completion()
                    } else {
                        errorMessage = response.error?.localizedDescription
                    }
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultAllocations() {
        categoryAllocations = CategoryEntity.beginnerCategories.map { category in
            BudgetEntity.BudgetCategoryAllocation(
                categoryID: category.id,
                categoryName: category.name,
                allocatedAmount: 0
            )
        }
    }
}