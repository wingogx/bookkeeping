import Foundation
import Combine

protocol BudgetCalculationServiceProtocol {
    func calculateSpentAmount(for budget: BudgetEntity, transactions: [TransactionEntity]) -> Double
    func calculateRemainingBudget(for budget: BudgetEntity, transactions: [TransactionEntity]) -> Double
    func calculateProgress(for budget: BudgetEntity, transactions: [TransactionEntity]) -> Double
    func isOverBudget(for budget: BudgetEntity, transactions: [TransactionEntity]) -> Bool
    func calculateCategorySpending(transactions: [TransactionEntity]) -> [TransactionCategory: Double]
    func calculateDailyAverage(transactions: [TransactionEntity], in dateRange: DateInterval) -> Double
    func predictMonthlySpending(transactions: [TransactionEntity]) -> Double
}

class BudgetCalculationService: BudgetCalculationServiceProtocol {
    
    // MARK: - Budget Calculations
    func calculateSpentAmount(for budget: BudgetEntity, transactions: [TransactionEntity]) -> Double {
        let relevantTransactions = filterTransactions(transactions, for: budget)
        return relevantTransactions.reduce(0) { $0 + $1.amount }
    }
    
    func calculateRemainingBudget(for budget: BudgetEntity, transactions: [TransactionEntity]) -> Double {
        let spent = calculateSpentAmount(for: budget, transactions: transactions)
        return budget.amount - spent
    }
    
    func calculateProgress(for budget: BudgetEntity, transactions: [TransactionEntity]) -> Double {
        let spent = calculateSpentAmount(for: budget, transactions: transactions)
        return min(spent / budget.amount, 1.0)
    }
    
    func isOverBudget(for budget: BudgetEntity, transactions: [TransactionEntity]) -> Bool {
        return calculateRemainingBudget(for: budget, transactions: transactions) < 0
    }
    
    // MARK: - Category Analysis
    func calculateCategorySpending(transactions: [TransactionEntity]) -> [TransactionCategory: Double] {
        var categoryTotals: [TransactionCategory: Double] = [:]
        
        for transaction in transactions {
            categoryTotals[transaction.category, default: 0] += transaction.amount
        }
        
        return categoryTotals
    }
    
    // MARK: - Time-based Analysis
    func calculateDailyAverage(transactions: [TransactionEntity], in dateRange: DateInterval) -> Double {
        let relevantTransactions = transactions.filter { transaction in
            dateRange.contains(transaction.createdAt)
        }
        
        let totalAmount = relevantTransactions.reduce(0) { $0 + $1.amount }
        let dayCount = Calendar.current.dateComponents([.day], from: dateRange.start, to: dateRange.end).day ?? 1
        
        return totalAmount / Double(max(dayCount, 1))
    }
    
    func predictMonthlySpending(transactions: [TransactionEntity]) -> Double {
        let calendar = Calendar.current
        let now = Date()
        
        // 获取当前月份的开始日期
        guard let monthStart = calendar.dateInterval(of: .month, for: now)?.start else {
            return 0
        }
        
        // 计算当前月份已过去的天数
        let daysPassed = calendar.dateComponents([.day], from: monthStart, to: now).day ?? 1
        
        // 过滤当前月份的交易
        let currentMonthTransactions = transactions.filter { transaction in
            calendar.isDate(transaction.createdAt, equalTo: now, toGranularity: .month)
        }
        
        let currentSpending = currentMonthTransactions.reduce(0) { $0 + $1.amount }
        
        // 预测公式：(当前支出 / 已过天数) * 30
        let dailyAverage = currentSpending / Double(daysPassed)
        return dailyAverage * 30
    }
    
    // MARK: - Helper Methods
    private func filterTransactions(_ transactions: [TransactionEntity], for budget: BudgetEntity) -> [TransactionEntity] {
        return transactions.filter { transaction in
            // 检查时间范围
            guard transaction.createdAt >= budget.startDate && transaction.createdAt <= budget.endDate else {
                return false
            }
            
            // 如果预算有特定类别，只包含该类别的交易
            if let budgetCategory = budget.category {
                return transaction.category == budgetCategory
            }
            
            // 否则包含所有交易
            return true
        }
    }
}

// MARK: - Statistics Service
protocol StatisticsServiceProtocol {
    func generateSpendingReport(transactions: [TransactionEntity], dateRange: DateInterval) -> SpendingReport
    func generateBudgetReport(budgets: [BudgetEntity], transactions: [TransactionEntity]) -> BudgetReport
    func generateCategoryAnalysis(transactions: [TransactionEntity]) -> CategoryAnalysis
}

class StatisticsService: StatisticsServiceProtocol {
    private let budgetCalculationService: BudgetCalculationServiceProtocol
    
    init(budgetCalculationService: BudgetCalculationServiceProtocol = BudgetCalculationService()) {
        self.budgetCalculationService = budgetCalculationService
    }
    
    func generateSpendingReport(transactions: [TransactionEntity], dateRange: DateInterval) -> SpendingReport {
        let relevantTransactions = transactions.filter { transaction in
            dateRange.contains(transaction.createdAt)
        }
        
        let totalAmount = relevantTransactions.reduce(0) { $0 + $1.amount }
        let transactionCount = relevantTransactions.count
        let averageAmount = transactionCount > 0 ? totalAmount / Double(transactionCount) : 0
        let dailyAverage = budgetCalculationService.calculateDailyAverage(
            transactions: relevantTransactions,
            in: dateRange
        )
        
        let categoryBreakdown = budgetCalculationService.calculateCategorySpending(
            transactions: relevantTransactions
        )
        
        return SpendingReport(
            totalAmount: totalAmount,
            transactionCount: transactionCount,
            averageTransactionAmount: averageAmount,
            dailyAverage: dailyAverage,
            categoryBreakdown: categoryBreakdown,
            dateRange: dateRange
        )
    }
    
    func generateBudgetReport(budgets: [BudgetEntity], transactions: [TransactionEntity]) -> BudgetReport {
        var budgetStatuses: [BudgetStatus] = []
        
        for budget in budgets {
            let spent = budgetCalculationService.calculateSpentAmount(for: budget, transactions: transactions)
            let remaining = budgetCalculationService.calculateRemainingBudget(for: budget, transactions: transactions)
            let progress = budgetCalculationService.calculateProgress(for: budget, transactions: transactions)
            let isOverBudget = budgetCalculationService.isOverBudget(for: budget, transactions: transactions)
            
            let status = BudgetStatus(
                budget: budget,
                spentAmount: spent,
                remainingAmount: remaining,
                progress: progress,
                isOverBudget: isOverBudget
            )
            budgetStatuses.append(status)
        }
        
        return BudgetReport(budgetStatuses: budgetStatuses)
    }
    
    func generateCategoryAnalysis(transactions: [TransactionEntity]) -> CategoryAnalysis {
        let categorySpending = budgetCalculationService.calculateCategorySpending(transactions: transactions)
        let totalSpending = categorySpending.values.reduce(0, +)
        
        var categoryPercentages: [TransactionCategory: Double] = [:]
        for (category, amount) in categorySpending {
            categoryPercentages[category] = totalSpending > 0 ? (amount / totalSpending) * 100 : 0
        }
        
        return CategoryAnalysis(
            categorySpending: categorySpending,
            categoryPercentages: categoryPercentages,
            totalSpending: totalSpending
        )
    }
}

// MARK: - Data Models for Reports
struct SpendingReport {
    let totalAmount: Double
    let transactionCount: Int
    let averageTransactionAmount: Double
    let dailyAverage: Double
    let categoryBreakdown: [TransactionCategory: Double]
    let dateRange: DateInterval
}

struct BudgetReport {
    let budgetStatuses: [BudgetStatus]
}

struct BudgetStatus {
    let budget: BudgetEntity
    let spentAmount: Double
    let remainingAmount: Double
    let progress: Double
    let isOverBudget: Bool
}

struct CategoryAnalysis {
    let categorySpending: [TransactionCategory: Double]
    let categoryPercentages: [TransactionCategory: Double]
    let totalSpending: Double
}