import SwiftUI
import Charts

struct StatisticsView: View {
    @StateObject private var viewModel = StatisticsViewModel()
    @State private var selectedTimeRange: TimeRange = .thisMonth
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // 时间范围选择器
                    TimeRangeSelector(selectedRange: $selectedTimeRange)
                        .padding(.horizontal)
                    
                    // 总览卡片
                    StatisticsOverviewCard(
                        totalSpent: viewModel.totalSpent,
                        transactionCount: viewModel.transactionCount,
                        averageTransaction: viewModel.averageTransaction,
                        dailyAverage: viewModel.dailyAverage
                    )
                    .padding(.horizontal)
                    
                    // 类别支出饼图
                    CategorySpendingChart(
                        categoryData: viewModel.categorySpending
                    )
                    .padding(.horizontal)
                    
                    // 支出趋势图
                    SpendingTrendChart(
                        trendData: viewModel.spendingTrend
                    )
                    .padding(.horizontal)
                    
                    // 详细分析
                    SpendingInsightsCard(
                        insights: viewModel.spendingInsights
                    )
                    .padding(.horizontal)
                    
                    // 预算对比
                    if !viewModel.budgetComparison.isEmpty {
                        BudgetComparisonChart(
                            budgetData: viewModel.budgetComparison
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("统计分析")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("导出报表") {
                            viewModel.exportReport()
                        }
                        Button("分享数据") {
                            viewModel.shareData()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .task {
            await viewModel.loadStatistics(for: selectedTimeRange)
        }
        .onChange(of: selectedTimeRange) { newValue in
            Task {
                await viewModel.loadStatistics(for: newValue)
            }
        }
        .refreshable {
            await viewModel.loadStatistics(for: selectedTimeRange)
        }
    }
}

// MARK: - Time Range Selector
struct TimeRangeSelector: View {
    @Binding var selectedRange: TimeRange
    
    private let ranges: [TimeRange] = [.thisWeek, .thisMonth, .lastMonth, .last3Months, .thisYear]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ranges, id: \.self) { range in
                    TimeRangeButton(
                        range: range,
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

struct TimeRangeButton: View {
    let range: TimeRange
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            Text(range.displayName)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.2))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Statistics Overview Card
struct StatisticsOverviewCard: View {
    let totalSpent: Double
    let transactionCount: Int
    let averageTransaction: Double
    let dailyAverage: Double
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                StatMetric(
                    title: "总支出",
                    value: "¥\(totalSpent, specifier: "%.2f")",
                    icon: "creditcard",
                    color: .blue
                )
                
                Spacer()
                
                StatMetric(
                    title: "交易笔数",
                    value: "\(transactionCount)",
                    icon: "list.bullet",
                    color: .green
                )
            }
            
            HStack {
                StatMetric(
                    title: "平均单笔",
                    value: "¥\(averageTransaction, specifier: "%.2f")",
                    icon: "chart.bar",
                    color: .orange
                )
                
                Spacer()
                
                StatMetric(
                    title: "日均支出",
                    value: "¥\(dailyAverage, specifier: "%.2f")",
                    icon: "calendar",
                    color: .purple
                )
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

struct StatMetric: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Spacer()
        }
    }
}

// MARK: - Category Spending Chart
struct CategorySpendingChart: View {
    let categoryData: [CategorySpendingData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("支出分类")
                .font(.headline)
                .padding(.horizontal, 4)
            
            if #available(iOS 16.0, *) {
                Chart(categoryData, id: \.category) { data in
                    SectorMark(
                        angle: .value("Amount", data.amount),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundColor(data.color)
                    .opacity(0.8)
                }
                .frame(height: 200)
                .chartBackground { chartProxy in
                    Text("¥\(categoryData.reduce(0) { $0 + $1.amount }, specifier: "%.0f")")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            } else {
                // iOS 15 fallback - 简单的条形图
                VStack(spacing: 8) {
                    ForEach(categoryData, id: \.category) { data in
                        CategoryBar(data: data, total: categoryData.reduce(0) { $0 + $1.amount })
                    }
                }
            }
            
            // 图例
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(categoryData, id: \.category) { data in
                    HStack {
                        Circle()
                            .fill(data.color)
                            .frame(width: 8, height: 8)
                        
                        Text(data.category.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("¥\(data.amount, specifier: "%.0f")")
                            .font(.caption)
                            .fontWeight(.medium)
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

struct CategoryBar: View {
    let data: CategorySpendingData
    let total: Double
    
    private var percentage: Double {
        total > 0 ? (data.amount / total) * 100 : 0
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                HStack {
                    Circle()
                        .fill(data.color)
                        .frame(width: 8, height: 8)
                    
                    Text(data.category.displayName)
                        .font(.subheadline)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("¥\(data.amount, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("\(percentage, specifier: "%.1f")%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(data.color)
                        .frame(width: geometry.size.width * (percentage / 100), height: 4)
                        .cornerRadius(2)
                        .animation(.easeInOut(duration: 0.5), value: percentage)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Spending Trend Chart
struct SpendingTrendChart: View {
    let trendData: [TrendData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("支出趋势")
                .font(.headline)
                .padding(.horizontal, 4)
            
            if #available(iOS 16.0, *) {
                Chart(trendData, id: \.date) { data in
                    LineMark(
                        x: .value("Date", data.date),
                        y: .value("Amount", data.amount)
                    )
                    .foregroundColor(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    AreaMark(
                        x: .value("Date", data.date),
                        y: .value("Amount", data.amount)
                    )
                    .foregroundColor(.blue.opacity(0.1))
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7))
                }
            } else {
                // iOS 15 fallback
                Text("支出趋势图需要 iOS 16+")
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Time Range Enum
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
}

#Preview {
    StatisticsView()
}