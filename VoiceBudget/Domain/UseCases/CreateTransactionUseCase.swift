import Foundation

/// 创建交易记录用例
public class CreateTransactionUseCase {
    
    // MARK: - Dependencies
    
    private let transactionRepository: TransactionRepository
    private let budgetRepository: BudgetRepository
    
    // MARK: - Initialization
    
    public init(
        transactionRepository: TransactionRepository,
        budgetRepository: BudgetRepository
    ) {
        self.transactionRepository = transactionRepository
        self.budgetRepository = budgetRepository
    }
    
    // MARK: - Request & Response
    
    public struct Request {
        public let amount: Decimal
        public let categoryID: String
        public let note: String?
        public let date: Date
        public let source: TransactionEntity.TransactionSource
        public let voiceNote: Data?
        
        public init(
            amount: Decimal,
            categoryID: String,
            note: String? = nil,
            date: Date = Date(),
            source: TransactionEntity.TransactionSource,
            voiceNote: Data? = nil
        ) {
            self.amount = amount
            self.categoryID = categoryID
            self.note = note
            self.date = date
            self.source = source
            self.voiceNote = voiceNote
        }
    }
    
    public struct Response {
        public let success: Bool
        public let transaction: TransactionEntity?
        public let budgetImpact: BudgetImpact?
        public let error: UseCaseError?
        public let warnings: [UseCaseWarning]
        
        public init(
            success: Bool,
            transaction: TransactionEntity? = nil,
            budgetImpact: BudgetImpact? = nil,
            error: UseCaseError? = nil,
            warnings: [UseCaseWarning] = []
        ) {
            self.success = success
            self.transaction = transaction
            self.budgetImpact = budgetImpact
            self.error = error
            self.warnings = warnings
        }
    }
    
    public struct BudgetImpact {
        public let budgetID: UUID?
        public let remainingBudget: Decimal
        public let usagePercentage: Double
        public let categoryRemainingBudget: Decimal?
        public let categoryUsagePercentage: Double?
        public let status: BudgetStatus
        public let exceedsWarningThreshold: Bool
        
        public init(
            budgetID: UUID?,
            remainingBudget: Decimal,
            usagePercentage: Double,
            categoryRemainingBudget: Decimal? = nil,
            categoryUsagePercentage: Double? = nil,
            status: BudgetStatus,
            exceedsWarningThreshold: Bool
        ) {
            self.budgetID = budgetID
            self.remainingBudget = remainingBudget
            self.usagePercentage = usagePercentage
            self.categoryRemainingBudget = categoryRemainingBudget
            self.categoryUsagePercentage = categoryUsagePercentage
            self.status = status
            self.exceedsWarningThreshold = exceedsWarningThreshold
        }
    }
    
    // MARK: - Execution
    
    public func execute(_ request: Request) async throws -> Response {
        
        // Validation
        let validationResult = validateRequest(request)
        if let error = validationResult.error {
            return Response(success: false, error: error)
        }
        
        do {
            // Create transaction entity
            let transactionID = UUID()
            let transaction = TransactionEntity(
                id: transactionID,
                amount: request.amount,
                categoryID: request.categoryID,
                categoryName: lookupCategoryName(request.categoryID),
                note: request.note,
                date: request.date,
                source: request.source,
                voiceNote: request.voiceNote
            )
            
            // Validate against current budget
            let budgetValidation = try await validateAgainstBudget(transaction)
            var warnings = validationResult.warnings + budgetValidation.warnings
            
            // Check if transaction should be blocked due to budget constraints
            if budgetValidation.shouldBlock {
                return Response(
                    success: false,
                    error: .budgetExceeded(budgetValidation.message ?? "预算不足"),
                    warnings: warnings
                )
            }
            
            // Save transaction
            let savedTransaction = try await transactionRepository.createTransaction(transaction)
            
            // Calculate budget impact
            let budgetImpact = try await calculateBudgetImpact(for: savedTransaction)
            
            // Add budget warning if necessary
            if let impact = budgetImpact, impact.exceedsWarningThreshold {
                warnings.append(.budgetWarning("预算使用已超过警告阈值"))
            }
            
            return Response(
                success: true,
                transaction: savedTransaction,
                budgetImpact: budgetImpact,
                warnings: warnings
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
    
    private func validateRequest(_ request: Request) -> (error: UseCaseError?, warnings: [UseCaseWarning]) {
        var warnings: [UseCaseWarning] = []
        
        // Validate amount
        if request.amount <= 0 {
            return (.invalidInput("交易金额必须大于0"), warnings)
        }
        
        if request.amount > 999999 {
            return (.invalidInput("交易金额过大"), warnings)
        }
        
        // Validate category
        if request.categoryID.isEmpty {
            return (.invalidInput("必须选择分类"), warnings)
        }
        
        // Validate date
        if request.date > Date().addingTimeInterval(24 * 60 * 60) { // Not more than 24 hours in future
            return (.invalidInput("交易日期不能是未来时间"), warnings)
        }
        
        // Warnings for large amounts
        if request.amount > 1000 {
            warnings.append(.unusualAmount("交易金额较大，请确认"))
        }
        
        // Warning for very old dates
        if request.date < Calendar.current.date(byAdding: .day, value: -30, to: Date())! {
            warnings.append(.oldDate("交易日期较早，请确认"))
        }
        
        return (nil, warnings)
    }
    
    private func validateAgainstBudget(_ transaction: TransactionEntity) async throws -> (shouldBlock: Bool, message: String?, warnings: [UseCaseWarning]) {
        var warnings: [UseCaseWarning] = []
        
        // Get current active budget
        guard let currentBudget = try await budgetRepository.getCurrentBudget() else {
            warnings.append(.noBudget("当前没有激活的预算"))
            return (false, nil, warnings)
        }
        
        // Check if transaction falls within budget period
        if transaction.date < currentBudget.startDate || transaction.date > currentBudget.endDate {
            warnings.append(.outsideBudgetPeriod("交易日期超出预算周期"))
            return (false, nil, warnings)
        }
        
        // Get current budget usage
        let budgetUsage = try await budgetRepository.getBudgetUsage(budgetID: currentBudget.id)
        
        // Check if adding this transaction would exceed budget
        let newUsedAmount = budgetUsage.usedAmount + transaction.amount
        let newUsagePercentage = Double(truncating: (newUsedAmount / currentBudget.totalAmount) as NSDecimalNumber) * 100
        
        // Hard limit: 120% of budget
        if newUsagePercentage > 120 {
            return (true, "添加此交易将严重超出预算限制", warnings)
        }
        
        // Check category budget if available
        if let categoryAllocation = currentBudget.categoryAllocations.first(where: { $0.categoryID == transaction.categoryID }) {
            let categoryUsages = try await budgetRepository.getCategoryBudgetUsage(budgetID: currentBudget.id)
            if let categoryUsage = categoryUsages.first(where: { $0.categoryID == transaction.categoryID }) {
                let newCategoryUsed = categoryUsage.usedAmount + transaction.amount
                let newCategoryPercentage = Double(truncating: (newCategoryUsed / categoryAllocation.allocatedAmount) as NSDecimalNumber) * 100
                
                if newCategoryPercentage > 100 {
                    warnings.append(.categoryBudgetExceeded("分类预算将被超出"))
                }
            }
        }
        
        return (false, nil, warnings)
    }
    
    private func calculateBudgetImpact(for transaction: TransactionEntity) async throws -> BudgetImpact? {
        // Get current active budget
        guard let currentBudget = try await budgetRepository.getCurrentBudget() else {
            return nil
        }
        
        // Check if transaction falls within budget period
        guard transaction.date >= currentBudget.startDate && transaction.date <= currentBudget.endDate else {
            return nil
        }
        
        // Get updated budget usage
        let budgetUsage = try await budgetRepository.getBudgetUsage(budgetID: currentBudget.id)
        
        // Get category impact if available
        var categoryRemainingBudget: Decimal?
        var categoryUsagePercentage: Double?
        
        let categoryUsages = try await budgetRepository.getCategoryBudgetUsage(budgetID: currentBudget.id)
        if let categoryUsage = categoryUsages.first(where: { $0.categoryID == transaction.categoryID }) {
            categoryRemainingBudget = categoryUsage.remainingAmount
            categoryUsagePercentage = categoryUsage.usagePercentage
        }
        
        return BudgetImpact(
            budgetID: currentBudget.id,
            remainingBudget: budgetUsage.remainingAmount,
            usagePercentage: budgetUsage.usagePercentage,
            categoryRemainingBudget: categoryRemainingBudget,
            categoryUsagePercentage: categoryUsagePercentage,
            status: budgetUsage.status,
            exceedsWarningThreshold: budgetUsage.usagePercentage >= 80
        )
    }
    
    private func lookupCategoryName(_ categoryID: String) -> String {
        // Look up category name from predefined categories
        let allCategories = CategoryEntity.beginnerCategories + CategoryEntity.advancedCategories
        return allCategories.first { $0.id == categoryID }?.name ?? categoryID
    }
}

// MARK: - Error Types

public enum UseCaseError: Error {
    case invalidInput(String)
    case budgetExceeded(String)
    case repositoryError(String)
    case networkError(String)
    case authenticationError(String)
    case unexpected(String)
}

extension UseCaseError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return "输入错误: \(message)"
        case .budgetExceeded(let message):
            return "预算超限: \(message)"
        case .repositoryError(let message):
            return "数据错误: \(message)"
        case .networkError(let message):
            return "网络错误: \(message)"
        case .authenticationError(let message):
            return "认证错误: \(message)"
        case .unexpected(let message):
            return "未知错误: \(message)"
        }
    }
}

// MARK: - Warning Types

public enum UseCaseWarning {
    case unusualAmount(String)
    case oldDate(String)
    case noBudget(String)
    case outsideBudgetPeriod(String)
    case budgetWarning(String)
    case categoryBudgetExceeded(String)
    
    public var message: String {
        switch self {
        case .unusualAmount(let msg), .oldDate(let msg), .noBudget(let msg), 
             .outsideBudgetPeriod(let msg), .budgetWarning(let msg), .categoryBudgetExceeded(let msg):
            return msg
        }
    }
}