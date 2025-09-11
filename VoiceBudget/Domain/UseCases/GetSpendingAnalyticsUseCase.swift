import Foundation

/// 获取支出分析用例
public class GetSpendingAnalyticsUseCase {
    
    // MARK: - Dependencies
    
    private let transactionRepository: TransactionRepository
    
    // MARK: - Initialization
    
    public init(transactionRepository: TransactionRepository) {
        self.transactionRepository = transactionRepository
    }
    
    // MARK: - Request & Response
    
    public struct Request {
        public let startDate: Date
        public let endDate: Date
        public let categoryID: String?
        public let includeComparisons: Bool
        public let includeTrends: Bool
        
        public init(
            startDate: Date,
            endDate: Date,
            categoryID: String? = nil,
            includeComparisons: Bool = true,
            includeTrends: Bool = true
        ) {
            self.startDate = startDate
            self.endDate = endDate
            self.categoryID = categoryID
            self.includeComparisons = includeComparisons
            self.includeTrends = includeTrends
        }
    }
    
    public struct Response {
        public let success: Bool
        public let summary: TransactionSummary?
        public let categoryStatistics: [CategoryExpenseStatistics]
        public let dailyTrend: [DailyExpenseData]
        public let comparisons: PeriodComparison?
        public let insights: [SpendingInsight]
        public let error: UseCaseError?
        
        public init(
            success: Bool,
            summary: TransactionSummary? = nil,
            categoryStatistics: [CategoryExpenseStatistics] = [],
            dailyTrend: [DailyExpenseData] = [],
            comparisons: PeriodComparison? = nil,
            insights: [SpendingInsight] = [],
            error: UseCaseError? = nil
        ) {
            self.success = success
            self.summary = summary
            self.categoryStatistics = categoryStatistics
            self.dailyTrend = dailyTrend
            self.comparisons = comparisons
            self.insights = insights
            self.error = error
        }
    }
    
    public struct PeriodComparison {
        public let previousPeriodSummary: TransactionSummary
        public let totalChangeAmount: Decimal
        public let totalChangePercentage: Double
        public let categoryChanges: [CategoryChange]
        public let trend: SpendingTrend
        
        public struct CategoryChange {
            public let categoryID: String
            public let categoryName: String
            public let currentAmount: Decimal
            public let previousAmount: Decimal
            public let changeAmount: Decimal
            public let changePercentage: Double
        }
        
        public enum SpendingTrend {
            case increasing
            case decreasing
            case stable
        }
    }
    
    public struct SpendingInsight {
        public let type: InsightType
        public let title: String
        public let message: String
        public let priority: InsightPriority
        public let data: [String: Any]?
        
        public enum InsightType {
            case topCategory
            case unusualSpending
            case trendAlert
            case budgetImpact
            case recommendation
        }
        
        public enum InsightPriority {
            case low
            case medium
            case high
        }
    }
    
    // MARK: - Execution
    
    public func execute(_ request: Request) async throws -> Response {
        
        do {
            // Get basic summary
            let summary = try await transactionRepository.getTransactionSummary(
                startDate: request.startDate,
                endDate: request.endDate,
                categoryID: request.categoryID
            )
            
            // Get category statistics
            let categoryStatistics = try await transactionRepository.getCategoryExpenseStatistics(
                startDate: request.startDate,
                endDate: request.endDate
            )
            
            // Get daily trend if requested
            var dailyTrend: [DailyExpenseData] = []
            if request.includeTrends {
                dailyTrend = try await transactionRepository.getDailyExpenseTrend(
                    startDate: request.startDate,
                    endDate: request.endDate
                )
            }
            
            // Get period comparison if requested
            var comparisons: PeriodComparison?
            if request.includeComparisons {
                comparisons = try await generatePeriodComparison(
                    currentStart: request.startDate,
                    currentEnd: request.endDate,
                    currentSummary: summary,
                    currentCategoryStats: categoryStatistics
                )
            }
            
            // Generate insights
            let insights = generateSpendingInsights(
                summary: summary,
                categoryStatistics: categoryStatistics,
                dailyTrend: dailyTrend,
                comparisons: comparisons
            )
            
            return Response(
                success: true,
                summary: summary,
                categoryStatistics: categoryStatistics,
                dailyTrend: dailyTrend,
                comparisons: comparisons,
                insights: insights
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
    
    private func generatePeriodComparison(
        currentStart: Date,
        currentEnd: Date,
        currentSummary: TransactionSummary,
        currentCategoryStats: [CategoryExpenseStatistics]
    ) async throws -> PeriodComparison {
        
        // Calculate previous period dates
        let daysDifference = Calendar.current.dateComponents([.day], from: currentStart, to: currentEnd).day ?? 0
        let previousEnd = Calendar.current.date(byAdding: .day, value: -1, to: currentStart) ?? currentStart
        let previousStart = Calendar.current.date(byAdding: .day, value: -daysDifference, to: previousEnd) ?? previousEnd
        
        // Get previous period data
        let previousSummary = try await transactionRepository.getTransactionSummary(
            startDate: previousStart,
            endDate: previousEnd,
            categoryID: nil
        )
        
        let previousCategoryStats = try await transactionRepository.getCategoryExpenseStatistics(
            startDate: previousStart,
            endDate: previousEnd
        )
        
        // Calculate changes
        let totalChangeAmount = currentSummary.totalAmount - previousSummary.totalAmount
        let totalChangePercentage = previousSummary.totalAmount > 0 ?
            Double(truncating: (totalChangeAmount / previousSummary.totalAmount) as NSDecimalNumber) * 100 : 0
        
        // Calculate category changes
        let categoryChanges = calculateCategoryChanges(
            current: currentCategoryStats,
            previous: previousCategoryStats
        )
        
        // Determine overall trend
        let trend: PeriodComparison.SpendingTrend
        if totalChangePercentage > 10 {
            trend = .increasing
        } else if totalChangePercentage < -10 {
            trend = .decreasing
        } else {
            trend = .stable
        }
        
        return PeriodComparison(
            previousPeriodSummary: previousSummary,
            totalChangeAmount: totalChangeAmount,
            totalChangePercentage: totalChangePercentage,
            categoryChanges: categoryChanges,
            trend: trend
        )
    }
    
    private func calculateCategoryChanges(
        current: [CategoryExpenseStatistics],
        previous: [CategoryExpenseStatistics]
    ) -> [PeriodComparison.CategoryChange] {
        
        let previousByCategory = Dictionary(uniqueKeysWithValues: previous.map { ($0.categoryID, $0) })
        
        return current.map { currentStat in
            let previousAmount = previousByCategory[currentStat.categoryID]?.totalAmount ?? 0
            let changeAmount = currentStat.totalAmount - previousAmount
            let changePercentage = previousAmount > 0 ?
                Double(truncating: (changeAmount / previousAmount) as NSDecimalNumber) * 100 : 0
            
            return PeriodComparison.CategoryChange(
                categoryID: currentStat.categoryID,
                categoryName: currentStat.categoryName,
                currentAmount: currentStat.totalAmount,
                previousAmount: previousAmount,
                changeAmount: changeAmount,
                changePercentage: changePercentage
            )
        }
    }
    
    private func generateSpendingInsights(
        summary: TransactionSummary,
        categoryStatistics: [CategoryExpenseStatistics],
        dailyTrend: [DailyExpenseData],
        comparisons: PeriodComparison?
    ) -> [SpendingInsight] {
        
        var insights: [SpendingInsight] = []
        
        // Top spending category insight
        if let topCategory = categoryStatistics.first {
            insights.append(SpendingInsight(
                type: .topCategory,
                title: "最大支出分类",
                message: "\(topCategory.categoryName) 是您的最大支出分类，占总支出的 \(Int(topCategory.percentage))%",
                priority: .medium,
                data: [
                    "categoryID": topCategory.categoryID,
                    "amount": topCategory.totalAmount,
                    "percentage": topCategory.percentage
                ]
            ))
        }
        
        // Unusual spending pattern
        if let avgAmount = dailyTrend.last?.totalAmount, avgAmount > summary.averageAmount * 2 {
            insights.append(SpendingInsight(
                type: .unusualSpending,
                title: "异常支出提醒",
                message: "最近一天的支出比平均水平高出很多",
                priority: .high,
                data: ["amount": avgAmount]
            ))
        }
        
        // Period comparison insights
        if let comparison = comparisons {
            switch comparison.trend {
            case .increasing:
                if comparison.totalChangePercentage > 20 {
                    insights.append(SpendingInsight(
                        type: .trendAlert,
                        title: "支出增长提醒",
                        message: "相比上个周期，支出增长了 \(Int(comparison.totalChangePercentage))%",
                        priority: .high,
                        data: ["changePercentage": comparison.totalChangePercentage]
                    ))
                }
            case .decreasing:
                if abs(comparison.totalChangePercentage) > 15 {
                    insights.append(SpendingInsight(
                        type: .recommendation,
                        title: "节省成果",
                        message: "相比上个周期，您节省了 ¥\(abs(comparison.totalChangeAmount))",
                        priority: .low,
                        data: ["savedAmount": abs(comparison.totalChangeAmount)]
                    ))
                }
            case .stable:
                insights.append(SpendingInsight(
                    type: .recommendation,
                    title: "支出稳定",
                    message: "您的支出控制得很好，保持稳定",
                    priority: .low,
                    data: nil
                ))
            }
            
            // Category-specific insights
            let significantCategoryChanges = comparison.categoryChanges.filter { abs($0.changePercentage) > 30 }
            for change in significantCategoryChanges.prefix(2) {
                let changeType = change.changeAmount > 0 ? "增加" : "减少"
                insights.append(SpendingInsight(
                    type: .trendAlert,
                    title: "\(change.categoryName)支出变化",
                    message: "\(change.categoryName)支出\(changeType)了\(Int(abs(change.changePercentage)))%",
                    priority: .medium,
                    data: [
                        "categoryID": change.categoryID,
                        "changeAmount": change.changeAmount,
                        "changePercentage": change.changePercentage
                    ]
                ))
            }
        }
        
        // Transaction frequency insight
        let avgDailyTransactions = Double(summary.transactionCount) / Double(dailyTrend.count)
        if avgDailyTransactions < 1 {
            insights.append(SpendingInsight(
                type: .recommendation,
                title: "记账频率",
                message: "建议更频繁地记录支出，以获得更准确的分析",
                priority: .low,
                data: ["avgDailyTransactions": avgDailyTransactions]
            ))
        }
        
        // Sort insights by priority
        return insights.sorted { insight1, insight2 in
            let priority1 = insight1.priority.rawValue
            let priority2 = insight2.priority.rawValue
            return priority1 > priority2
        }
    }
}

// MARK: - Extensions

extension GetSpendingAnalyticsUseCase.SpendingInsight.InsightPriority {
    var rawValue: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }
}