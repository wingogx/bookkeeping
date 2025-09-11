import Foundation

/// 获取预算状态用例
public class GetBudgetStatusUseCase {
    
    // MARK: - Dependencies
    
    private let budgetRepository: BudgetRepository
    private let transactionRepository: TransactionRepository
    
    // MARK: - Initialization
    
    public init(
        budgetRepository: BudgetRepository,
        transactionRepository: TransactionRepository
    ) {
        self.budgetRepository = budgetRepository
        self.transactionRepository = transactionRepository
    }
    
    // MARK: - Request & Response
    
    public struct Request {
        public let budgetID: UUID?
        public let upToDate: Date
        public let includeTrend: Bool
        public let includeCategoryBreakdown: Bool
        
        public init(
            budgetID: UUID? = nil,
            upToDate: Date = Date(),
            includeTrend: Bool = false,
            includeCategoryBreakdown: Bool = true
        ) {
            self.budgetID = budgetID
            self.upToDate = upToDate
            self.includeTrend = includeTrend
            self.includeCategoryBreakdown = includeCategoryBreakdown
        }
    }
    
    public struct Response {
        public let success: Bool
        public let budget: BudgetEntity?
        public let budgetUsage: BudgetUsage?
        public let categoryUsages: [CategoryBudgetUsage]
        public let executionTrend: [BudgetExecutionData]
        public let recommendations: [BudgetRecommendation]
        public let error: UseCaseError?
        
        public init(
            success: Bool,
            budget: BudgetEntity? = nil,
            budgetUsage: BudgetUsage? = nil,
            categoryUsages: [CategoryBudgetUsage] = [],
            executionTrend: [BudgetExecutionData] = [],
            recommendations: [BudgetRecommendation] = [],
            error: UseCaseError? = nil
        ) {
            self.success = success
            self.budget = budget
            self.budgetUsage = budgetUsage
            self.categoryUsages = categoryUsages
            self.executionTrend = executionTrend
            self.recommendations = recommendations
            self.error = error
        }
    }
    
    public struct BudgetRecommendation {
        public let type: RecommendationType
        public let title: String
        public let message: String
        public let priority: Priority
        
        public enum RecommendationType {
            case reduceSpending
            case adjustAllocation
            case createNewBudget
            case reviewGoals
        }
        
        public enum Priority {
            case low
            case medium
            case high
            case urgent
        }
        
        public init(type: RecommendationType, title: String, message: String, priority: Priority) {
            self.type = type
            self.title = title
            self.message = message
            self.priority = priority
        }
    }
    
    // MARK: - Execution
    
    public func execute(_ request: Request) async throws -> Response {
        
        do {
            // Get budget (current if ID not specified)
            let budget: BudgetEntity?
            if let budgetID = request.budgetID {
                budget = try await budgetRepository.getBudget(by: budgetID)
            } else {
                budget = try await budgetRepository.getCurrentBudget()
            }
            
            guard let budget = budget else {
                return Response(
                    success: false,
                    error: .invalidInput("未找到指定的预算")
                )
            }
            
            // Get budget usage
            let budgetUsage = try await budgetRepository.getBudgetUsage(
                budgetID: budget.id,
                upToDate: request.upToDate
            )
            
            // Get category breakdown if requested
            var categoryUsages: [CategoryBudgetUsage] = []
            if request.includeCategoryBreakdown {
                categoryUsages = try await budgetRepository.getCategoryBudgetUsage(
                    budgetID: budget.id,
                    upToDate: request.upToDate
                )
            }
            
            // Get execution trend if requested
            var executionTrend: [BudgetExecutionData] = []
            if request.includeTrend {
                executionTrend = try await budgetRepository.getBudgetExecutionTrend(budgetID: budget.id)
            }
            
            // Generate recommendations
            let recommendations = generateRecommendations(
                budget: budget,
                usage: budgetUsage,
                categoryUsages: categoryUsages
            )
            
            return Response(
                success: true,
                budget: budget,
                budgetUsage: budgetUsage,
                categoryUsages: categoryUsages,
                executionTrend: executionTrend,
                recommendations: recommendations
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
    
    private func generateRecommendations(
        budget: BudgetEntity,
        usage: BudgetUsage,
        categoryUsages: [CategoryBudgetUsage]
    ) -> [BudgetRecommendation] {
        
        var recommendations: [BudgetRecommendation] = []
        
        // Budget exceeded recommendations
        if usage.status == .exceeded {
            recommendations.append(BudgetRecommendation(
                type: .reduceSpending,
                title: "预算超支",
                message: "本期预算已超支，建议减少非必要支出",
                priority: .urgent
            ))
        }
        
        // Warning threshold recommendations
        else if usage.status == .warning {
            if !usage.isOnTrack {
                recommendations.append(BudgetRecommendation(
                    type: .reduceSpending,
                    title: "预算预警",
                    message: "按当前支出速度，可能会超出预算",
                    priority: .high
                ))
            }
        }
        
        // Category allocation recommendations
        let overSpentCategories = categoryUsages.filter { $0.status == .exceeded }
        if !overSpentCategories.isEmpty {
            let categoryNames = overSpentCategories.map { $0.categoryName }.joined(separator: "、")
            recommendations.append(BudgetRecommendation(
                type: .adjustAllocation,
                title: "分类预算调整",
                message: "\(categoryNames) 分类已超预算，考虑调整分配",
                priority: .medium
            ))
        }
        
        // Under-utilized categories
        let underUtilizedCategories = categoryUsages.filter { 
            $0.usagePercentage < 50 && usage.daysRemaining < 7 
        }
        if !underUtilizedCategories.isEmpty && usage.status != .exceeded {
            let categoryNames = underUtilizedCategories.map { $0.categoryName }.joined(separator: "、")
            recommendations.append(BudgetRecommendation(
                type: .adjustAllocation,
                title: "预算优化建议",
                message: "\(categoryNames) 分类预算使用较少，可考虑重新分配",
                priority: .low
            ))
        }
        
        // End of period recommendations
        if usage.daysRemaining <= 3 && usage.status == .safe {
            let remaining = usage.remainingAmount
            if remaining > 0 {
                recommendations.append(BudgetRecommendation(
                    type: .reviewGoals,
                    title: "预算结余",
                    message: "预算周期即将结束，还有¥\(remaining)结余",
                    priority: .low
                ))
            }
        }
        
        // New budget period approaching
        if usage.daysRemaining <= 1 {
            recommendations.append(BudgetRecommendation(
                type: .createNewBudget,
                title: "新预算周期",
                message: "当前预算周期即将结束，建议设置新的预算",
                priority: .medium
            ))
        }
        
        return recommendations.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
}

// MARK: - Priority Extension

extension GetBudgetStatusUseCase.BudgetRecommendation.Priority {
    var rawValue: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .urgent: return 4
        }
    }
}