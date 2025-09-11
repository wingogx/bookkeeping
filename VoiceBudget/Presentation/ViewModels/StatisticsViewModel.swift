import Foundation
import Combine

@MainActor
class StatisticsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var totalSpent: Double = 0
    @Published var transactionCount: Int = 0
    @Published var averageTransaction: Double = 0
    @Published var dailyAverage: Double = 0
    @Published var categorySpending: [CategorySpendingData] = []
    @Published var spendingTrend: [TrendData] = []
    @Published var spendingInsights: [String] = []
    @Published var budgetComparison: [BudgetComparisonData] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let statisticsService: StatisticsServiceProtocol
    private let getTransactionHistoryUseCase: GetTransactionHistoryUseCase
    private let getBudgetStatusUseCase: GetBudgetStatusUseCase
    
    // MARK: - Initialization
    init(
        statisticsService: StatisticsServiceProtocol = StatisticsService(),
        getTransactionHistoryUseCase: GetTransactionHistoryUseCase = DIContainer.shared.resolve(),
        getBudgetStatusUseCase: GetBudgetStatusUseCase = DIContainer.shared.resolve()
    ) {
        self.statisticsService = statisticsService
        self.getTransactionHistoryUseCase = getTransactionHistoryUseCase
        self.getBudgetStatusUseCase = getBudgetStatusUseCase
    }
    
    // MARK: - Public Methods
    func loadStatistics(for timeRange: TimeRange) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let (startDate, endDate) = getDateRange(for: timeRange)
            
            // 加载交易数据
            let transactions = try await getTransactionHistoryUseCase.execute(
                startDate: startDate,
                endDate: endDate,
                category: nil,
                limit: nil
            )
            
            // 计算统计数据
            await calculateStatistics(from: transactions, timeRange: timeRange)
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func exportReport() {
        // TODO: 实现报表导出
        print("Exporting report...")
    }
    
    func shareData() {
        // TODO: 实现数据分享
        print("Sharing data...")
    }
    
    // MARK: - Private Methods
    private func calculateStatistics(from transactions: [TransactionEntity], timeRange: TimeRange) async {
        totalSpent = transactions.reduce(0) { $0 + $1.amount }
        transactionCount = transactions.count
        averageTransaction = transactionCount > 0 ? totalSpent / Double(transactionCount) : 0
        
        // 计算日均支出
        let (startDate, endDate) = getDateRange(for: timeRange)
        if let start = startDate, let end = endDate {
            let dateInterval = DateInterval(start: start, end: end)
            dailyAverage = statisticsService.calculateDailyAverage(
                transactions: transactions,
                in: dateInterval
            )
        }
        
        // 计算类别支出
        let categoryAnalysis = statisticsService.generateCategoryAnalysis(transactions: transactions)
        categorySpending = categoryAnalysis.categorySpending.map { category, amount in
            CategorySpendingData(
                category: category,
                amount: amount,
                color: colorForCategory(category)
            )
        }.sorted { $0.amount > $1.amount }
        
        // 生成支出趋势
        spendingTrend = generateTrendData(from: transactions, timeRange: timeRange)
        
        // 生成洞察
        let spendingPattern = SmartCategoryService().analyzeSpendingPattern(transactions: transactions)
        spendingInsights = spendingPattern.insights
    }
    
    private func generateTrendData(from transactions: [TransactionEntity], timeRange: TimeRange) -> [TrendData] {
        let calendar = Calendar.current
        let (startDate, endDate) = getDateRange(for: timeRange)
        
        guard let start = startDate, let end = endDate else { return [] }
        
        var trendData: [TrendData] = []
        var currentDate = start
        
        while currentDate <= end {
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            
            let dayTransactions = transactions.filter { transaction in
                transaction.createdAt >= currentDate && transaction.createdAt < dayEnd
            }
            
            let dayTotal = dayTransactions.reduce(0) { $0 + $1.amount }
            trendData.append(TrendData(date: currentDate, amount: dayTotal))
            
            currentDate = dayEnd
        }
        
        return trendData
    }
    
    private func getDateRange(for timeRange: TimeRange) -> (Date?, Date?) {
        let calendar = Calendar.current
        let now = Date()
        
        switch timeRange {
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek ?? now)
            return (startOfWeek, endOfWeek)
            
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth ?? now)
            return (startOfMonth, endOfMonth)
            
        case .lastMonth:
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            let startOfLastMonth = calendar.dateInterval(of: .month, for: lastMonth)?.start
            let endOfLastMonth = calendar.date(byAdding: .month, value: 1, to: startOfLastMonth ?? now)
            return (startOfLastMonth, endOfLastMonth)
            
        case .last3Months:
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now)
            return (threeMonthsAgo, now)
            
        case .thisYear:
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start
            let endOfYear = calendar.date(byAdding: .year, value: 1, to: startOfYear ?? now)
            return (startOfYear, endOfYear)
        }
    }
    
    private func colorForCategory(_ category: TransactionCategory) -> Color {
        switch category {
        case .food: return .orange
        case .transport: return .blue
        case .entertainment: return .purple
        case .shopping: return .green
        case .health: return .red
        case .other: return .gray
        }
    }
}

// MARK: - Data Models
struct CategorySpendingData {
    let category: TransactionCategory
    let amount: Double
    let color: Color
}

struct TrendData {
    let date: Date
    let amount: Double
}

struct BudgetComparisonData {
    let budgetName: String
    let budgetAmount: Double
    let spentAmount: Double
    let category: TransactionCategory
}

struct SpendingInsightsCard: View {
    let insights: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("消费洞察")
                .font(.headline)
                .padding(.horizontal, 4)
            
            if insights.isEmpty {
                Text("暂无洞察数据")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(insights, id: \.self) { insight in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            
                            Text(insight)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

struct BudgetComparisonChart: View {
    let budgetData: [BudgetComparisonData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("预算对比")
                .font(.headline)
                .padding(.horizontal, 4)
            
            VStack(spacing: 12) {
                ForEach(budgetData, id: \.budgetName) { data in
                    BudgetComparisonRow(data: data)
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

struct BudgetComparisonRow: View {
    let data: BudgetComparisonData
    
    private var progress: Double {
        data.budgetAmount > 0 ? data.spentAmount / data.budgetAmount : 0
    }
    
    private var progressColor: Color {
        if progress > 1.0 {
            return .red
        } else if progress > 0.8 {
            return .orange
        } else {
            return .green
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(data.budgetName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("¥\(data.spentAmount, specifier: "%.2f") / ¥\(data.budgetAmount, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(progress * 100, specifier: "%.1f")%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(progressColor)
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(progressColor)
                        .frame(width: min(geometry.size.width * progress, geometry.size.width), height: 6)
                        .cornerRadius(3)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 6)
        }
    }
}