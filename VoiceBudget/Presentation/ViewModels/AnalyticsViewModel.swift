import Foundation
import Combine

@MainActor
class AnalyticsViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private let getSpendingAnalyticsUseCase: GetSpendingAnalyticsUseCase
    
    // MARK: - Published Properties
    @Published var summary: TransactionSummary?
    @Published var categoryStatistics: [CategoryExpenseStatistics] = []
    @Published var dailyTrend: [DailyExpenseData] = []
    @Published var periodComparison: GetSpendingAnalyticsUseCase.PeriodComparison?
    @Published var insights: [GetSpendingAnalyticsUseCase.SpendingInsight] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var currentTimeRange: TimeRange = .thisMonth
    
    // MARK: - Initialization
    init() {
        let coreDataStack = CoreDataStack.shared
        let transactionRepository = CoreDataTransactionRepository(context: coreDataStack.viewContext)
        
        self.getSpendingAnalyticsUseCase = GetSpendingAnalyticsUseCase(
            transactionRepository: transactionRepository
        )
    }
    
    // MARK: - Public Methods
    
    func loadAnalytics() {
        Task {
            await loadAnalyticsData()
        }
    }
    
    func refresh() {
        Task {
            isLoading = true
            await loadAnalyticsData()
            isLoading = false
        }
    }
    
    func updateTimeRange(_ range: TimeRange) {
        currentTimeRange = range
        loadAnalytics()
    }
    
    // MARK: - Private Methods
    
    private func loadAnalyticsData() async {
        let dateRange = currentTimeRange.dateRange
        
        do {
            let request = GetSpendingAnalyticsUseCase.Request(
                startDate: dateRange.start,
                endDate: dateRange.end,
                includeComparisons: true,
                includeTrends: true
            )
            
            let response = try await getSpendingAnalyticsUseCase.execute(request)
            
            if response.success {
                summary = response.summary
                categoryStatistics = response.categoryStatistics
                dailyTrend = response.dailyTrend
                periodComparison = response.comparisons
                insights = response.insights
            } else {
                errorMessage = response.error?.localizedDescription
            }
        } catch {
            errorMessage = "加载分析数据失败: \(error.localizedDescription)"
        }
    }
}