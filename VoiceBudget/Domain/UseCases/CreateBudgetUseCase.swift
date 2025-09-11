import Foundation

/// 创建预算用例
public class CreateBudgetUseCase {
    
    // MARK: - Dependencies
    
    private let budgetRepository: BudgetRepository
    private let preferenceRepository: UserPreferenceRepository
    
    // MARK: - Initialization
    
    public init(
        budgetRepository: BudgetRepository,
        preferenceRepository: UserPreferenceRepository
    ) {
        self.budgetRepository = budgetRepository
        self.preferenceRepository = preferenceRepository
    }
    
    // MARK: - Request & Response
    
    public struct Request {
        public let name: String
        public let totalAmount: Decimal
        public let period: BudgetEntity.BudgetPeriod
        public let startDate: Date?
        public let categoryAllocations: [BudgetEntity.BudgetCategoryAllocation]
        public let isActive: Bool
        
        public init(
            name: String,
            totalAmount: Decimal,
            period: BudgetEntity.BudgetPeriod,
            startDate: Date? = nil,
            categoryAllocations: [BudgetEntity.BudgetCategoryAllocation],
            isActive: Bool = true
        ) {
            self.name = name
            self.totalAmount = totalAmount
            self.period = period
            self.startDate = startDate
            self.categoryAllocations = categoryAllocations
            self.isActive = isActive
        }
    }
    
    public struct Response {
        public let success: Bool
        public let budget: BudgetEntity?
        public let validationResult: BudgetValidationResult?
        public let conflictWarning: String?
        public let error: UseCaseError?
        
        public init(
            success: Bool,
            budget: BudgetEntity? = nil,
            validationResult: BudgetValidationResult? = nil,
            conflictWarning: String? = nil,
            error: UseCaseError? = nil
        ) {
            self.success = success
            self.budget = budget
            self.validationResult = validationResult
            self.conflictWarning = conflictWarning
            self.error = error
        }
    }
    
    // MARK: - Execution
    
    public func execute(_ request: Request) async throws -> Response {
        
        do {
            // Calculate date range
            let (startDate, endDate) = calculateDateRange(
                period: request.period,
                startDate: request.startDate
            )
            
            // Create budget entity
            let budget = BudgetEntity(
                id: UUID(),
                name: request.name,
                totalAmount: request.totalAmount,
                period: request.period,
                startDate: startDate,
                endDate: endDate,
                categoryAllocations: request.categoryAllocations,
                isActive: request.isActive
            )
            
            // Validate budget
            let validationResult = try await budgetRepository.validateBudgetAllocation(budget)
            if !validationResult.isValid {
                return Response(
                    success: false,
                    validationResult: validationResult,
                    error: .invalidInput(validationResult.errors.first?.message ?? "预算配置无效")
                )
            }
            
            // Check for conflicts
            let hasConflict = try await budgetRepository.checkBudgetConflict(budget)
            var conflictWarning: String?
            
            if hasConflict {
                if request.isActive {
                    conflictWarning = "存在相同周期的激活预算，创建此预算将停用其他预算"
                } else {
                    conflictWarning = "存在相同周期的预算"
                }
            }
            
            // Create budget
            let createdBudget = try await budgetRepository.createBudget(budget)
            
            // If the budget is active, deactivate others
            if request.isActive {
                try await budgetRepository.activateBudget(id: createdBudget.id)
            }
            
            // Update user preferences
            try await updateRelatedPreferences(budget: createdBudget)
            
            return Response(
                success: true,
                budget: createdBudget,
                validationResult: validationResult,
                conflictWarning: conflictWarning
            )
            
        } catch {
            let useCaseError: UseCaseError
            
            if let repoError = error as? RepositoryError {
                useCaseError = .repositoryError(repoError.localizedDescription)
            } else {
                useCaseError = .unexpected(error.localizedDescription)
            }
            
            return Response(success: false, error: useCaseError)
        }
    }
    
    // MARK: - Private Methods
    
    private func calculateDateRange(
        period: BudgetEntity.BudgetPeriod,
        startDate: Date?
    ) -> (Date, Date) {
        let calendar = Calendar.current
        let effectiveStartDate = startDate ?? Date()
        
        let startOfPeriod: Date
        let endOfPeriod: Date
        
        switch period {
        case .week:
            startOfPeriod = calendar.startOfDay(for: calendar.dateInterval(of: .weekOfYear, for: effectiveStartDate)?.start ?? effectiveStartDate)
            endOfPeriod = calendar.date(byAdding: .day, value: 6, to: startOfPeriod) ?? startOfPeriod
            
        case .month:
            startOfPeriod = calendar.startOfDay(for: calendar.dateInterval(of: .month, for: effectiveStartDate)?.start ?? effectiveStartDate)
            endOfPeriod = calendar.date(byAdding: .month, value: 1, to: startOfPeriod)?.addingTimeInterval(-1) ?? startOfPeriod
        }
        
        return (startOfPeriod, endOfPeriod)
    }
    
    private func updateRelatedPreferences(budget: BudgetEntity) async throws {
        // Update default budget period preference
        try await preferenceRepository.setValue(budget.period, for: .defaultBudgetPeriod)
        
        // Update budget warning threshold if not set
        let currentThreshold = try await preferenceRepository.getDouble(for: .budgetWarningThreshold, defaultValue: 0.8)
        if currentThreshold == 0.8 {
            try await preferenceRepository.setDouble(0.8, for: .budgetWarningThreshold)
        }
    }
}