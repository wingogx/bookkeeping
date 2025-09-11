import SwiftUI

struct BudgetManagementView: View {
    @StateObject private var viewModel = BudgetManagementViewModel()
    @State private var showingCreateBudgetSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // 预算概览卡片
                    BudgetOverviewCard(
                        totalBudget: viewModel.totalBudgetAmount,
                        totalSpent: viewModel.totalSpentAmount,
                        budgetCount: viewModel.budgets.count
                    )
                    .padding(.horizontal)
                    
                    // 预算列表
                    if viewModel.budgets.isEmpty {
                        EmptyBudgetView {
                            showingCreateBudgetSheet = true
                        }
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.budgetStatuses, id: \.budget.id) { status in
                                BudgetStatusCard(
                                    status: status,
                                    onEdit: {
                                        viewModel.editBudget(status.budget)
                                    },
                                    onDelete: {
                                        viewModel.deleteBudget(status.budget)
                                    }
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("预算管理")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateBudgetSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateBudgetSheet) {
                CreateBudgetView()
            }
            .sheet(item: $viewModel.editingBudget) { budget in
                EditBudgetView(budget: budget)
            }
            .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("确定") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
        .task {
            await viewModel.loadBudgets()
        }
        .refreshable {
            await viewModel.loadBudgets()
        }
    }
}

// MARK: - Budget Overview Card
struct BudgetOverviewCard: View {
    let totalBudget: Double
    let totalSpent: Double
    let budgetCount: Int
    
    private var remainingBudget: Double {
        totalBudget - totalSpent
    }
    
    private var overallProgress: Double {
        totalBudget > 0 ? totalSpent / totalBudget : 0
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("总预算")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("¥\(totalBudget, specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("剩余")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("¥\(remainingBudget, specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(remainingBudget >= 0 ? .primary : .red)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("已花费")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("¥\(totalSpent, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("活跃预算")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(budgetCount)个")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            // 总体进度条
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("总体进度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(overallProgress * 100, specifier: "%.1f")%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(overallProgress > 1 ? .red : (overallProgress > 0.8 ? .orange : .green))
                            .frame(width: min(geometry.size.width * overallProgress, geometry.size.width), height: 8)
                            .cornerRadius(4)
                            .animation(.easeInOut(duration: 0.5), value: overallProgress)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Budget Status Card
struct BudgetStatusCard: View {
    let status: BudgetStatus
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private var progressColor: Color {
        if status.isOverBudget {
            return .red
        } else if status.progress > 0.8 {
            return .orange
        } else {
            return .green
        }
    }
    
    private var statusIcon: String {
        if status.isOverBudget {
            return "exclamationmark.triangle.fill"
        } else if status.progress > 0.8 {
            return "clock.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 头部信息
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(status.budget.type.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let category = status.budget.category {
                            Text("· \(category.displayName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: statusIcon)
                            .foregroundColor(progressColor)
                    }
                    
                    Text("\(status.budget.startDate, formatter: dateFormatter) - \(status.budget.endDate, formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 金额信息
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("预算")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥\(status.budget.amount, specifier: "%.2f")")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 4) {
                    Text("已花费")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥\(status.spentAmount, specifier: "%.2f")")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(status.isOverBudget ? "超支" : "剩余")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥\(abs(status.remainingAmount), specifier: "%.2f")")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(status.isOverBudget ? .red : .primary)
                }
            }
            
            // 进度条
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(progressColor)
                            .frame(width: min(geometry.size.width * status.progress, geometry.size.width), height: 8)
                            .cornerRadius(4)
                            .animation(.easeInOut(duration: 0.5), value: status.progress)
                    }
                }
                .frame(height: 8)
                
                HStack {
                    Text("\(status.progress * 100, specifier: "%.1f")%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // 剩余天数
                    if status.budget.endDate > Date() {
                        let remainingDays = Calendar.current.dateComponents([.day], from: Date(), to: status.budget.endDate).day ?? 0
                        Text("剩余\(remainingDays)天")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("已过期")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }
}

// MARK: - Empty Budget View
struct EmptyBudgetView: View {
    let onCreateBudget: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "chart.pie")
                .font(.system(size: 64))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("还没有设置预算")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("创建预算可以帮助您更好地控制支出")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("创建第一个预算") {
                onCreateBudget()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(25)
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    BudgetManagementView()
}