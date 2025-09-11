import SwiftUI

struct BudgetView: View {
    @StateObject private var viewModel = BudgetViewModel()
    @State private var showingCreateBudget = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let budget = viewModel.currentBudget,
                       let usage = viewModel.budgetUsage {
                        // 当前预算概览
                        BudgetOverviewCard(budget: budget, usage: usage)
                        
                        // 分类预算使用情况
                        CategoryBudgetSection(categoryUsages: viewModel.categoryUsages)
                        
                        // 预算执行趋势
                        if !viewModel.executionTrend.isEmpty {
                            BudgetTrendChart(trendData: viewModel.executionTrend)
                        }
                        
                        // 预算建议
                        if !viewModel.recommendations.isEmpty {
                            RecommendationsSection(recommendations: viewModel.recommendations)
                        }
                    } else {
                        // 无预算状态
                        NoBudgetView {
                            showingCreateBudget = true
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("预算管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("创建新预算") {
                            showingCreateBudget = true
                        }
                        
                        if viewModel.currentBudget != nil {
                            Button("编辑当前预算") {
                                // TODO: 编辑预算
                            }
                            
                            Button("预算历史") {
                                // TODO: 预算历史
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateBudget) {
                CreateBudgetView()
            }
            .refreshable {
                viewModel.refresh()
            }
            .onAppear {
                viewModel.loadBudgetData()
            }
        }
    }
}

struct BudgetOverviewCard: View {
    let budget: BudgetEntity
    let usage: BudgetUsage
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(budget.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Text(budget.period.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
            
            // 进度圆环
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                
                Circle()
                    .trim(from: 0, to: min(usage.usagePercentage / 100, 1.0))
                    .stroke(usage.status.color, lineWidth: 8)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: usage.usagePercentage)
                
                VStack {
                    Text("\(Int(usage.usagePercentage))%")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("已使用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 120, height: 120)
            
            HStack(spacing: 30) {
                VStack {
                    Text("总预算")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥\(usage.totalBudget, specifier: "%.0f")")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                VStack {
                    Text("已用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥\(usage.usedAmount, specifier: "%.2f")")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(usage.status.color)
                }
                
                VStack {
                    Text("剩余")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥\(usage.remainingAmount, specifier: "%.2f")")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(usage.remainingAmount >= 0 ? .green : .red)
                }
            }
            
            // 天数信息
            HStack {
                Text("剩余 \(usage.daysRemaining) 天")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(usage.isOnTrack ? "按计划进行" : "可能超支")
                    .font(.caption)
                    .foregroundColor(usage.isOnTrack ? .green : .orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct CategoryBudgetSection: View {
    let categoryUsages: [CategoryBudgetUsage]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("分类预算")
                .font(.headline)
            
            ForEach(categoryUsages) { categoryUsage in
                CategoryBudgetRow(categoryUsage: categoryUsage)
            }
        }
    }
}

struct CategoryBudgetRow: View {
    let categoryUsage: CategoryBudgetUsage
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(getCategoryIcon(categoryUsage.categoryID))
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(categoryUsage.categoryName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("\(categoryUsage.transactionCount) 笔交易")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("¥\(categoryUsage.usedAmount, specifier: "%.0f") / ¥\(categoryUsage.allocatedAmount, specifier: "%.0f")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("\(Int(categoryUsage.usagePercentage))%")
                        .font(.caption)
                        .foregroundColor(categoryUsage.status.color)
                }
            }
            
            ProgressView(value: categoryUsage.usagePercentage / 100)
                .progressViewStyle(LinearProgressViewStyle())
                .accentColor(categoryUsage.status.color)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
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

struct BudgetTrendChart: View {
    let trendData: [BudgetExecutionData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("支出趋势")
                .font(.headline)
            
            // 简化的趋势图表
            VStack {
                Text("图表占位符")
                    .foregroundColor(.secondary)
                Text("显示每日累计支出 vs 目标支出")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct RecommendationsSection: View {
    let recommendations: [GetBudgetStatusUseCase.BudgetRecommendation]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("预算建议")
                .font(.headline)
            
            ForEach(Array(recommendations.enumerated()), id: \.offset) { index, recommendation in
                RecommendationCard(recommendation: recommendation)
            }
        }
    }
}

struct RecommendationCard: View {
    let recommendation: GetBudgetStatusUseCase.BudgetRecommendation
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: recommendation.priority.iconName)
                .foregroundColor(recommendation.priority.color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(recommendation.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(recommendation.priority.color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct NoBudgetView: View {
    let onCreateBudget: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.pie")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("还没有预算")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("创建预算来更好地管理您的支出")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("创建第一个预算") {
                onCreateBudget()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CreateBudgetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CreateBudgetViewModel()
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    TextField("预算名称", text: $viewModel.name)
                    
                    TextField("总金额", value: $viewModel.totalAmount, format: .currency(code: "CNY"))
                        .keyboardType(.decimalPad)
                    
                    Picker("预算周期", selection: $viewModel.period) {
                        Text("周预算").tag(BudgetEntity.BudgetPeriod.week)
                        Text("月预算").tag(BudgetEntity.BudgetPeriod.month)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("分类分配") {
                    ForEach($viewModel.categoryAllocations, id: \.categoryID) { $allocation in
                        HStack {
                            Text(allocation.categoryName)
                            Spacer()
                            TextField("金额", value: $allocation.allocatedAmount, format: .currency(code: "CNY"))
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 120)
                        }
                    }
                    
                    HStack {
                        Text("总计")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("¥\(viewModel.totalAllocated, specifier: "%.2f")")
                            .fontWeight(.semibold)
                            .foregroundColor(viewModel.isAllocationValid ? .primary : .red)
                    }
                }
            }
            .navigationTitle("创建预算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("创建") {
                        viewModel.createBudget {
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.isValid)
                }
            }
        }
    }
}

// MARK: - Extensions

extension BudgetEntity.BudgetPeriod {
    var displayName: String {
        switch self {
        case .week: return "周预算"
        case .month: return "月预算"
        }
    }
}

extension GetBudgetStatusUseCase.BudgetRecommendation.Priority {
    var iconName: String {
        switch self {
        case .low: return "info.circle"
        case .medium: return "exclamationmark.triangle"
        case .high: return "exclamationmark.triangle.fill"
        case .urgent: return "exclamationmark.octagon.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        case .urgent: return .red
        }
    }
}

struct BudgetView_Previews: PreviewProvider {
    static var previews: some View {
        BudgetView()
    }
}