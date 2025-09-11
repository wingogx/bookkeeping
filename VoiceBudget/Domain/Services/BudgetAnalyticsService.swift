import Foundation
import Combine

/// 预算分析服务
/// 负责计算预算使用情况、消费统计和趋势分析
public class BudgetAnalyticsService: ObservableObject {
    
    // MARK: - Dependencies
    private let transactionRepository: TransactionRepositoryProtocol
    private let budgetRepository: BudgetRepositoryProtocol
    private let calendar = Calendar.current
    
    // MARK: - Published Properties
    @Published public var currentBudgetUsage: BudgetUsage?
    @Published public var categoryStatistics: [CategoryStatistic] = []
    @Published public var spendingTrend: [DailySpending] = []
    @Published public var budgetAlert: BudgetAlert?
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    public init(
        transactionRepository: TransactionRepositoryProtocol,
        budgetRepository: BudgetRepositoryProtocol
    ) {
        self.transactionRepository = transactionRepository
        self.budgetRepository = budgetRepository
        
        setupDataBinding()
    }
    
    // MARK: - Private Setup
    private func setupDataBinding() {
        // 监听交易数据变化，自动更新统计
        transactionRepository.findAll()
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] _ in
                    Task { @MainActor in
                        await self?.refreshAllAnalytics()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// 刷新所有分析数据
    @MainActor
    public func refreshAllAnalytics() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.updateCurrentBudgetUsage() }
            group.addTask { await self.updateCategoryStatistics() }
            group.addTask { await self.updateSpendingTrend() }
            group.addTask { await self.checkBudgetAlerts() }
        }
    }
    
    /// 获取指定预算的使用情况
    public func getBudgetUsage(for budgetId: UUID) -> AnyPublisher<BudgetUsage?, Error> {
        return budgetRepository.findById(budgetId)
            .flatMap { [weak self] budget -> AnyPublisher<BudgetUsage?, Error> in
                guard let self = self, let budget = budget else {
                    return Just(nil).setFailureType(to: Error.self).eraseToAnyPublisher()
                }
                
                return self.calculateBudgetUsage(for: budget)
            }
            .eraseToAnyPublisher()
    }
    
    /// 获取分类统计
    public func getCategoryStatistics(
        startDate: Date,
        endDate: Date
    ) -> AnyPublisher<[CategoryStatistic], Error> {
        return transactionRepository.getCategoryStatistics(startDate, endDate)
    }
    
    /// 获取消费趋势
    public func getSpendingTrend(days: Int) -> AnyPublisher<[DailySpending], Error> {
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            return Fail(error: AnalyticsError.invalidDateRange)
                .eraseToAnyPublisher()
        }
        
        return transactionRepository.findByDateRange(startDate, endDate)
            .map { [weak self] transactions -> [DailySpending] in
                guard let self = self else { return [] }
                return self.calculateDailySpending(transactions: transactions, days: days, endDate: endDate)
            }
            .eraseToAnyPublisher()
    }
    
    /// 获取预算建议
    public func getBudgetRecommendations() -> AnyPublisher<[BudgetRecommendation], Error> {
        return Publishers.CombineLatest(
            budgetRepository.findActiveBudget(),
            getCurrentMonthTransactions()
        )
        .map { [weak self] budget, transactions -> [BudgetRecommendation] in
            guard let self = self, let budget = budget else { return [] }
            return self.generateBudgetRecommendations(budget: budget, transactions: transactions)
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Budget Management Methods (Required by Audit)
    
    /// 创建新预算
    public func createBudget(
        totalAmount: Decimal,
        period: BudgetPeriod,
        categories: [String: Decimal] = [:]
    ) -> AnyPublisher<BudgetEntity, Error> {
        let budget = BudgetEntity(
            id: UUID(),
            totalAmount: totalAmount,
            period: period,
            startDate: Date(),
            endDate: calculateEndDate(for: period, startDate: Date()),
            categories: categories,
            isActive: true,
            createdAt: Date()
        )
        
        return budgetRepository.create(budget)
            .handleEvents(receiveOutput: { [weak self] _ in
                Task { @MainActor in
                    await self?.updateCurrentBudgetUsage()
                }
            })
            .eraseToAnyPublisher()
    }
    
    /// 更新预算
    public func updateBudget(
        _ budget: BudgetEntity,
        totalAmount: Decimal? = nil,
        categories: [String: Decimal]? = nil
    ) -> AnyPublisher<BudgetEntity, Error> {
        var updatedBudget = budget
        
        if let totalAmount = totalAmount {
            updatedBudget.totalAmount = totalAmount
        }
        
        if let categories = categories {
            updatedBudget.categories = categories
        }
        
        updatedBudget.updatedAt = Date()
        
        return budgetRepository.update(updatedBudget)
            .handleEvents(receiveOutput: { [weak self] _ in
                Task { @MainActor in
                    await self?.updateCurrentBudgetUsage()
                }
            })
            .eraseToAnyPublisher()
    }
    
    /// 计算预算使用情况
    public func calculateUsage(for budget: BudgetEntity) -> AnyPublisher<BudgetUsage, Error> {
        return calculateBudgetUsage(for: budget)
    }
    
    /// 生成预算建议
    public func generateRecommendations(for budget: BudgetEntity) -> AnyPublisher<[BudgetRecommendation], Error> {
        return getCurrentMonthTransactions()
            .map { [weak self] transactions in
                guard let self = self else { return [] }
                return self.generateBudgetRecommendations(budget: budget, transactions: transactions)
            }
            .eraseToAnyPublisher()
    }
    
    private func calculateEndDate(for period: BudgetPeriod, startDate: Date) -> Date {
        let calendar = Calendar.current
        switch period {
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: startDate) ?? startDate
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: startDate) ?? startDate
        }
    }
    
    // MARK: - Private Analytics Methods
    
    @MainActor
    private func updateCurrentBudgetUsage() async {
        do {
            let activeBudget = try await budgetRepository.findActiveBudget().async()
            
            if let budget = activeBudget {
                let usage = try await calculateBudgetUsage(for: budget).async()
                self.currentBudgetUsage = usage
            } else {
                self.currentBudgetUsage = nil
            }
        } catch {
            print("Failed to update budget usage: \(error)")
        }
    }
    
    @MainActor
    private func updateCategoryStatistics() async {
        let startOfMonth = calendar.startOfMonth(for: Date())
        let endOfMonth = calendar.endOfMonth(for: Date())
        
        do {
            let statistics = try await transactionRepository
                .getCategoryStatistics(startOfMonth, endOfMonth)
                .async()
            
            self.categoryStatistics = statistics
        } catch {
            print("Failed to update category statistics: \(error)")
        }
    }
    
    @MainActor
    private func updateSpendingTrend() async {
        do {
            let trend = try await getSpendingTrend(days: 30).async()
            self.spendingTrend = trend
        } catch {
            print("Failed to update spending trend: \(error)")
        }
    }
    
    @MainActor
    private func checkBudgetAlerts() async {
        guard let usage = currentBudgetUsage else { return }
        
        // 检查是否需要预算警告
        if usage.usagePercentage >= 90 {
            self.budgetAlert = BudgetAlert(
                type: .critical,
                message: "预算即将用完！还剩¥\(usage.remainingAmount)",
                usagePercentage: usage.usagePercentage
            )
        } else if usage.usagePercentage >= 75 {
            self.budgetAlert = BudgetAlert(
                type: .warning,
                message: "预算使用已达\(String(format: "%.0f", usage.usagePercentage))%",
                usagePercentage: usage.usagePercentage
            )
        } else {
            self.budgetAlert = nil
        }
    }
    
    private func calculateBudgetUsage(for budget: BudgetEntity) -> AnyPublisher<BudgetUsage?, Error> {
        return transactionRepository.findByDateRange(budget.startDate, budget.endDate)
            .map { transactions -> BudgetUsage in
                let usedAmount = transactions
                    .filter { !$0.isDeleted }
                    .reduce(Decimal(0)) { $0 + $1.amount }
                
                let remainingAmount = budget.totalAmount - usedAmount
                let usagePercentage = budget.totalAmount > 0 ? 
                    Double(truncating: (usedAmount / budget.totalAmount) as NSNumber) * 100 : 0
                
                // 按分类统计
                var categoryBreakdown: [String: Decimal] = [:]
                for transaction in transactions.filter({ !$0.isDeleted }) {
                    categoryBreakdown[transaction.categoryID, default: 0] += transaction.amount
                }
                
                return BudgetUsage(
                    budgetId: budget.id,
                    totalBudget: budget.totalAmount,
                    usedAmount: usedAmount,
                    remainingAmount: remainingAmount,
                    usagePercentage: usagePercentage,
                    categoryBreakdown: categoryBreakdown
                )
            }
            .eraseToAnyPublisher()
    }
    
    private func calculateDailySpending(
        transactions: [TransactionEntity],
        days: Int,
        endDate: Date
    ) -> [DailySpending] {
        var dailySpending: [Date: Decimal] = [:]
        
        // 初始化所有日期为0
        for i in 0..<days {
            if let date = calendar.date(byAdding: .day, value: -i, to: endDate) {
                let dayStart = calendar.startOfDay(for: date)
                dailySpending[dayStart] = 0
            }
        }
        
        // 统计每日支出
        for transaction in transactions.filter({ !$0.isDeleted }) {
            let dayStart = calendar.startOfDay(for: transaction.date)
            dailySpending[dayStart, default: 0] += transaction.amount
        }
        
        return dailySpending.map { (date, amount) in
            DailySpending(date: date, amount: amount)
        }.sorted { $0.date < $1.date }
    }
    
    private func getCurrentMonthTransactions() -> AnyPublisher<[TransactionEntity], Error> {
        let startOfMonth = calendar.startOfMonth(for: Date())
        let endOfMonth = calendar.endOfMonth(for: Date())
        
        return transactionRepository.findByDateRange(startOfMonth, endOfMonth)
    }
    
    private func generateBudgetRecommendations(
        budget: BudgetEntity,
        transactions: [TransactionEntity]
    ) -> [BudgetRecommendation] {
        var recommendations: [BudgetRecommendation] = []
        
        let usedAmount = transactions
            .filter { !$0.isDeleted }
            .reduce(Decimal(0)) { $0 + $1.amount }
        
        let usagePercentage = budget.totalAmount > 0 ?
            Double(truncating: (usedAmount / budget.totalAmount) as NSNumber) * 100 : 0
        
        // 计算剩余天数
        let remainingDays = calendar.dateComponents([.day], from: Date(), to: budget.endDate).day ?? 0
        
        if remainingDays > 0 {
            let remainingAmount = budget.totalAmount - usedAmount
            let recommendedDailySpending = remainingAmount / Decimal(remainingDays)
            
            if usagePercentage > 80 {
                recommendations.append(BudgetRecommendation(
                    type: .reduceSpending,
                    title: "控制支出",
                    message: "建议每日支出不超过¥\(recommendedDailySpending)",
                    priority: .high
                ))
            }
            
            // 分析最大支出分类
            let categoryTotals = Dictionary(grouping: transactions.filter { !$0.isDeleted }) { $0.categoryID }
                .mapValues { $0.reduce(Decimal(0)) { $0 + $1.amount } }
            
            if let topCategory = categoryTotals.max(by: { $0.value < $1.value }) {
                recommendations.append(BudgetRecommendation(
                    type: .optimizeCategory,
                    title: "优化支出分类",
                    message: "您在\(topCategory.key)上花费较多（¥\(topCategory.value)），可以考虑优化",
                    priority: .medium
                ))
            }
        }
        
        return recommendations
    }
}

// MARK: - Supporting Types

public struct DailySpending {
    public let date: Date
    public let amount: Decimal
    
    public init(date: Date, amount: Decimal) {
        self.date = date
        self.amount = amount
    }
}

public struct BudgetAlert {
    public enum AlertType {
        case warning
        case critical
    }
    
    public let type: AlertType
    public let message: String
    public let usagePercentage: Double
    
    public init(type: AlertType, message: String, usagePercentage: Double) {
        self.type = type
        self.message = message
        self.usagePercentage = usagePercentage
    }
}

public struct BudgetRecommendation {
    public enum RecommendationType {
        case reduceSpending
        case optimizeCategory
        case adjustBudget
    }
    
    public enum Priority {
        case low
        case medium
        case high
    }
    
    public let type: RecommendationType
    public let title: String
    public let message: String
    public let priority: Priority
    
    public init(type: RecommendationType, title: String, message: String, priority: Priority) {
        self.type = type
        self.title = title
        self.message = message
        self.priority = priority
    }
}

public enum AnalyticsError: Error {
    case invalidDateRange
    case calculationFailed
    case noBudgetFound
    
    public var localizedDescription: String {
        switch self {
        case .invalidDateRange:
            return "日期范围无效"
        case .calculationFailed:
            return "计算失败"
        case .noBudgetFound:
            return "未找到预算"
        }
    }
}

// MARK: - Calendar Extensions
extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
    
    func endOfMonth(for date: Date) -> Date {
        guard let startOfMonth = self.date(from: dateComponents([.year, .month], from: date)),
              let endOfMonth = self.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return date
        }
        return Calendar.current.startOfDay(for: endOfMonth)
    }
}

// MARK: - Publisher Extensions
extension Publisher {
    func async() async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            
            cancellable = first()
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        case .finished:
                            break
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { value in
                        continuation.resume(returning: value)
                        cancellable?.cancel()
                    }
                )
        }
    }
}