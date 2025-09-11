import SwiftUI

struct AnalyticsView: View {
    @StateObject private var viewModel = AnalyticsViewModel()
    @State private var selectedTimeRange: TimeRange = .thisMonth
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 时间选择器
                    TimeRangeSelector(selectedRange: $selectedTimeRange)
                        .onChange(of: selectedTimeRange) { newRange in
                            viewModel.updateTimeRange(newRange)
                        }
                    
                    if let summary = viewModel.summary {
                        // 支出概览卡片
                        SpendingSummaryCard(summary: summary)
                        
                        // 分类统计
                        if !viewModel.categoryStatistics.isEmpty {
                            CategoryStatisticsSection(statistics: viewModel.categoryStatistics)
                        }
                        
                        // 趋势图表
                        if !viewModel.dailyTrend.isEmpty {
                            SpendingTrendChart(trendData: viewModel.dailyTrend)
                        }
                        
                        // 对比分析
                        if let comparison = viewModel.periodComparison {
                            PeriodComparisonSection(comparison: comparison)
                        }
                        
                        // 支出洞察
                        if !viewModel.insights.isEmpty {
                            InsightsSection(insights: viewModel.insights)
                        }
                    } else if viewModel.isLoading {
                        ProgressView("加载分析数据...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        NoDataView()
                    }
                }
                .padding()
            }
            .navigationTitle("支出分析")
            .refreshable {
                viewModel.refresh()
            }
            .onAppear {
                viewModel.loadAnalytics()
            }
        }
    }
}

struct TimeRangeSelector: View {
    @Binding var selectedRange: TimeRange
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    TimeRangeChip(
                        title: range.displayName,
                        isSelected: selectedRange == range
                    ) {
                        selectedRange = range
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct TimeRangeChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct SpendingSummaryCard: View {
    let summary: TransactionSummary
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("支出概览")
                    .font(.headline)
                Spacer()
                Text("\(summary.periodStartDate.formatted(.dateTime.month().day())) - \(summary.periodEndDate.formatted(.dateTime.month().day()))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 30) {
                VStack {
                    Text("总支出")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥\(summary.totalAmount, specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                VStack {
                    Text("笔数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(summary.transactionCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                VStack {
                    Text("平均")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥\(summary.averageAmount, specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct CategoryStatisticsSection: View {
    let statistics: [CategoryExpenseStatistics]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("分类统计")
                .font(.headline)
            
            // 饼图占位符
            PieChartPlaceholder(statistics: statistics)
            
            // 分类列表
            ForEach(statistics) { stat in
                CategoryStatRow(statistic: stat)
            }
        }
    }
}

struct PieChartPlaceholder: View {
    let statistics: [CategoryExpenseStatistics]
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 150, height: 150)
                
                Text("饼图占位符")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("各分类支出占比")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }
}

struct CategoryStatRow: View {
    let statistic: CategoryExpenseStatistics
    
    var body: some View {
        HStack {
            // 分类图标和名称
            HStack(spacing: 8) {
                Text(getCategoryIcon(statistic.categoryID))
                    .font(.title3)
                
                Text(statistic.categoryName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            // 统计信息
            VStack(alignment: .trailing, spacing: 2) {
                Text("¥\(statistic.totalAmount, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 4) {
                    Text("\(statistic.transactionCount) 笔")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(statistic.percentage))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func getCategoryIcon(_ categoryID: String) -> String {
        switch categoryID {
        case "dining": return "🍽"
        case "transportation": return "🚗"
        case "shopping": return "🛍"
        case "entertainment": return "🎬"
        case "medical": return "🏥"
        case "education": return "📚"
        case "living": return "🏠"
        default: return "🤷‍♀️"
        }
    }
}

struct SpendingTrendChart: View {
    let trendData: [DailyExpenseData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("支出趋势")
                .font(.headline)
            
            // 简化的趋势图表
            VStack(spacing: 8) {
                HStack {
                    Text("最高: ¥\(trendData.map(\.totalAmount).max() ?? 0, specifier: "%.0f")")
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Spacer()
                    
                    Text("最低: ¥\(trendData.map(\.totalAmount).min() ?? 0, specifier: "%.0f")")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                Rectangle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(height: 100)
                    .overlay(
                        Text("趋势图表占位符")
                            .foregroundColor(.secondary)
                    )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct PeriodComparisonSection: View {
    let comparison: GetSpendingAnalyticsUseCase.PeriodComparison
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("对比分析")
                .font(.headline)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("与上期对比")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: comparison.trend == .increasing ? "arrow.up" : 
                              comparison.trend == .decreasing ? "arrow.down" : "minus")
                            .foregroundColor(comparison.trend == .increasing ? .red : 
                                           comparison.trend == .decreasing ? .green : .gray)
                        
                        Text("¥\(abs(comparison.totalChangeAmount), specifier: "%.2f")")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("(\(abs(comparison.totalChangePercentage), specifier: "%.1f")%)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text(comparison.trend.displayText)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(comparison.trend.color.opacity(0.2))
                    .foregroundColor(comparison.trend.color)
                    .cornerRadius(8)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct InsightsSection: View {
    let insights: [GetSpendingAnalyticsUseCase.SpendingInsight]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("支出洞察")
                .font(.headline)
            
            ForEach(Array(insights.enumerated()), id: \.offset) { index, insight in
                InsightCard(insight: insight)
            }
        }
    }
}

struct InsightCard: View {
    let insight: GetSpendingAnalyticsUseCase.SpendingInsight
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.type.iconName)
                .foregroundColor(insight.priority.color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(insight.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(insight.priority.color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct NoDataView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("暂无数据")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("开始记账后将显示分析数据")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Supporting Types

enum TimeRange: CaseIterable {
    case thisWeek
    case thisMonth
    case lastMonth
    case last3Months
    case thisYear
    
    var displayName: String {
        switch self {
        case .thisWeek: return "本周"
        case .thisMonth: return "本月"
        case .lastMonth: return "上月"
        case .last3Months: return "近3月"
        case .thisYear: return "今年"
        }
    }
    
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return (startOfWeek, now)
            
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return (startOfMonth, now)
            
        case .lastMonth:
            let startOfThisMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth) ?? now
            let endOfLastMonth = calendar.date(byAdding: .day, value: -1, to: startOfThisMonth) ?? now
            return (startOfLastMonth, endOfLastMonth)
            
        case .last3Months:
            let start = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            return (start, now)
            
        case .thisYear:
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            return (startOfYear, now)
        }
    }
}

// MARK: - Extensions

extension GetSpendingAnalyticsUseCase.PeriodComparison.SpendingTrend {
    var displayText: String {
        switch self {
        case .increasing: return "支出增加"
        case .decreasing: return "支出减少"
        case .stable: return "支出稳定"
        }
    }
    
    var color: Color {
        switch self {
        case .increasing: return .red
        case .decreasing: return .green
        case .stable: return .gray
        }
    }
}

extension GetSpendingAnalyticsUseCase.SpendingInsight.InsightType {
    var iconName: String {
        switch self {
        case .topCategory: return "chart.pie"
        case .unusualSpending: return "exclamationmark.triangle"
        case .trendAlert: return "arrow.up.right"
        case .budgetImpact: return "dollarsign.circle"
        case .recommendation: return "lightbulb"
        }
    }
}

extension GetSpendingAnalyticsUseCase.SpendingInsight.InsightPriority {
    var color: Color {
        switch self {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }
}

struct AnalyticsView_Previews: PreviewProvider {
    static var previews: some View {
        AnalyticsView()
    }
}