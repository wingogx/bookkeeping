import Foundation
import Combine

/// 预算分析服务
/// 提供预算统计、趋势分析和智能建议
public class BudgetAnalyticsService: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var todaySpent: Decimal = 0
    @Published public var monthlySpent: Decimal = 0
    @Published public var monthlyBudget: Decimal = 3000
    @Published public var remainingBudget: Decimal = 0
    @Published public var budgetProgress: Double = 0
    @Published public var categoryStatistics: [CategoryStatistic] = []
    @Published public var dailyTrends: [DayTrend] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    // MARK: - Data Models
    public struct DayTrend {
        public let date: Date
        public let amount: Decimal
        public let dayName: String
        
        public init(date: Date, amount: Decimal) {
            self.date = date
            self.amount = amount
            
            let formatter = DateFormatter()
            formatter.dateFormat = "E"
            self.dayName = formatter.string(from: date)
        }
    }
    
    public struct BudgetSummary {
        public let totalBudget: Decimal
        public let totalSpent: Decimal
        public let remaining: Decimal
        public let progress: Double
        public let daysLeft: Int
        public let averageDailySpent: Decimal
        public let recommendedDailyBudget: Decimal
        
        public init(totalBudget: Decimal, totalSpent: Decimal, daysLeft: Int) {
            self.totalBudget = totalBudget
            self.totalSpent = totalSpent
            self.remaining = max(totalBudget - totalSpent, 0)
            self.progress = totalBudget > 0 ? Double(truncating: totalSpent as NSNumber) / Double(truncating: totalBudget as NSNumber) : 0
            self.daysLeft = max(daysLeft, 1)
            
            let currentDate = Date()
            let calendar = Calendar.current
            let startOfMonth = calendar.dateInterval(of: .month, for: currentDate)?.start ?? currentDate
            let daysPassed = calendar.dateComponents([.day], from: startOfMonth, to: currentDate).day ?? 1
            
            self.averageDailySpent = daysPassed > 0 ? totalSpent / Decimal(daysPassed) : 0
            self.recommendedDailyBudget = self.daysLeft > 0 ? self.remaining / Decimal(self.daysLeft) : 0
        }
    }
    
    // MARK: - Dependencies
    private let transactionRepository: TransactionRepositoryProtocol
    private let budgetRepository: BudgetRepositoryProtocol?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    public init(
        transactionRepository: TransactionRepositoryProtocol,
        budgetRepository: BudgetRepositoryProtocol? = nil
    ) {
        self.transactionRepository = transactionRepository
        self.budgetRepository = budgetRepository
        
        setupPeriodicUpdates()
        refreshData()
    }
    
    // MARK: - Public Methods
    public func refreshData() {
        isLoading = true
        errorMessage = nil
        
        let today = Date()
        let calendar = Calendar.current
        
        // 今日范围
        let startOfToday = calendar.startOfDay(for: today)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? today
        
        // 本月范围
        let monthInterval = calendar.dateInterval(of: .month, for: today)
        let startOfMonth = monthInterval?.start ?? startOfToday
        let endOfMonth = monthInterval?.end ?? endOfToday
        
        // 并发获取数据
        Publishers.Zip4(
            getTodayTotal(startOfToday, endOfToday),
            getMonthlyTotal(startOfMonth, endOfMonth),
            getCategoryStats(startOfMonth, endOfMonth),
            getDailyTrends(startOfMonth, endOfMonth)
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            },
            receiveValue: { [weak self] todayTotal, monthlyTotal, categoryStats, trends in
                self?.updateData(
                    todayTotal: todayTotal,
                    monthlyTotal: monthlyTotal,
                    categoryStats: categoryStats,
                    trends: trends
                )
            }
        )
        .store(in: &cancellables)
    }
    
    public func getBudgetSummary() -> BudgetSummary {
        let calendar = Calendar.current
        let today = Date()
        let endOfMonth = calendar.dateInterval(of: .month, for: today)?.end ?? today
        let daysLeft = calendar.dateComponents([.day], from: today, to: endOfMonth).day ?? 0
        
        return BudgetSummary(
            totalBudget: monthlyBudget,
            totalSpent: monthlySpent,
            daysLeft: daysLeft
        )
    }
    
    public func setCategoryBudget(_ categoryID: String, amount: Decimal) {
        // 这里应该通过budgetRepository设置分类预算
        // 暂时更新本地状态
        DispatchQueue.main.async { [weak self] in
            self?.refreshData()
        }
    }
    
    public func setMonthlyBudget(_ amount: Decimal) {
        monthlyBudget = amount
        updateBudgetCalculations()
        
        // 保存到本地存储或后端
        UserDefaults.standard.set(amount.description, forKey: "monthlyBudget")
    }
    
    // MARK: - Private Methods
    private func setupPeriodicUpdates() {
        // 每分钟更新一次数据（实际应用中可以调整频率）
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)
    }
    
    private func getTodayTotal(_ startDate: Date, _ endDate: Date) -> AnyPublisher<Decimal, Error> {
        return transactionRepository.getTotalByDateRange(startDate, endDate)
    }
    
    private func getMonthlyTotal(_ startDate: Date, _ endDate: Date) -> AnyPublisher<Decimal, Error> {
        return transactionRepository.getTotalByDateRange(startDate, endDate)
    }
    
    private func getCategoryStats(_ startDate: Date, _ endDate: Date) -> AnyPublisher<[CategoryStatistic], Error> {
        return transactionRepository.getCategoryStatistics(startDate, endDate)
    }
    
    private func getDailyTrends(_ startDate: Date, _ endDate: Date) -> AnyPublisher<[DayTrend], Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(AnalyticsError.serviceUnavailable))
                return
            }
            
            let calendar = Calendar.current
            var trends: [DayTrend] = []
            
            // 获取最近7天的数据
            for i in 0..<7 {
                if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                    let dayStart = calendar.startOfDay(for: date)
                    let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
                    
                    self.transactionRepository.getTotalByDateRange(dayStart, dayEnd)
                        .sink(
                            receiveCompletion: { _ in },
                            receiveValue: { amount in
                                trends.append(DayTrend(date: date, amount: amount))
                            }
                        )
                        .store(in: &self.cancellables)
                }
            }
            
            // 排序并返回
            trends.sort { $0.date < $1.date }
            promise(.success(trends))
        }
        .eraseToAnyPublisher()
    }
    
    private func updateData(
        todayTotal: Decimal,
        monthlyTotal: Decimal,
        categoryStats: [CategoryStatistic],
        trends: [DayTrend]
    ) {
        self.todaySpent = todayTotal
        self.monthlySpent = monthlyTotal
        self.categoryStatistics = categoryStats
        self.dailyTrends = trends
        
        updateBudgetCalculations()
    }
    
    private func updateBudgetCalculations() {
        remainingBudget = max(monthlyBudget - monthlySpent, 0)
        budgetProgress = monthlyBudget > 0 ? Double(truncating: monthlySpent as NSNumber) / Double(truncating: monthlyBudget as NSNumber) : 0
        
        // 限制进度条在 0-1 之间
        budgetProgress = min(max(budgetProgress, 0), 1)
    }
    
    // MARK: - Smart Recommendations
    public func getSpendingRecommendations() -> [SpendingRecommendation] {
        var recommendations: [SpendingRecommendation] = []
        let summary = getBudgetSummary()
        
        // 预算超支警告
        if summary.progress > 0.8 {
            recommendations.append(SpendingRecommendation(
                type: .warning,
                title: "预算即将用完",
                message: "本月已使用 \(Int(summary.progress * 100))% 的预算，建议控制支出",
                priority: .high
            ))
        }
        
        // 日均支出建议
        if summary.averageDailySpent > summary.recommendedDailyBudget && summary.daysLeft > 0 {
            recommendations.append(SpendingRecommendation(
                type: .suggestion,
                title: "建议降低日均支出",
                message: "为了不超预算，建议日均支出控制在 ¥\(summary.recommendedDailyBudget) 以内",
                priority: .medium
            ))
        }
        
        // 分类支出建议
        if let topCategory = categoryStatistics.first, topCategory.totalAmount > monthlyBudget * 0.4 {
            recommendations.append(SpendingRecommendation(
                type: .info,
                title: "\(topCategory.categoryName) 支出较高",
                message: "本月在 \(topCategory.categoryName) 上花费了 ¥\(topCategory.totalAmount)，占预算的 \(Int((topCategory.totalAmount / monthlyBudget) * 100))%",
                priority: .low
            ))
        }
        
        return recommendations.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
}

// MARK: - Spending Recommendation
public struct SpendingRecommendation {
    public enum RecommendationType {
        case warning
        case suggestion
        case info
    }
    
    public enum Priority: Int {
        case high = 3
        case medium = 2
        case low = 1
    }
    
    public let type: RecommendationType
    public let title: String
    public let message: String
    public let priority: Priority
    
    public var color: String {
        switch type {
        case .warning: return "red"
        case .suggestion: return "orange"
        case .info: return "blue"
        }
    }
    
    public var icon: String {
        switch type {
        case .warning: return "exclamationmark.triangle.fill"
        case .suggestion: return "lightbulb.fill"
        case .info: return "info.circle.fill"
        }
    }
}

// MARK: - Analytics Errors
public enum AnalyticsError: LocalizedError {
    case serviceUnavailable
    case dataIncomplete
    
    public var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            return "分析服务暂不可用"
        case .dataIncomplete:
            return "数据不完整"
        }
    }
}

// MARK: - UserDefaults Extension
extension BudgetAnalyticsService {
    
    private func loadSavedBudget() {
        if let savedBudget = UserDefaults.standard.string(forKey: "monthlyBudget"),
           let amount = Decimal(string: savedBudget) {
            monthlyBudget = amount
        }
    }
    
    public func resetBudgetData() {
        UserDefaults.standard.removeObject(forKey: "monthlyBudget")
        monthlyBudget = 3000
        refreshData()
    }
}