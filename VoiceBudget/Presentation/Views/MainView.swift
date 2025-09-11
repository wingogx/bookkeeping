import SwiftUI

struct MainView: View {
    @StateObject private var viewModel: MainViewModel
    @State private var selectedTab: Tab = .home
    
    init(viewModel: MainViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "house")
                    Text("首页")
                }
                .tag(Tab.home)
            
            TransactionListView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("记录")
                }
                .tag(Tab.transactions)
            
            BudgetManagementView()
                .tabItem {
                    Image(systemName: "chart.pie")
                    Text("预算")
                }
                .tag(Tab.budget)
            
            StatisticsView()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("统计")
                }
                .tag(Tab.statistics)
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("设置")
                }
                .tag(Tab.settings)
        }
        .overlay(
            VoiceRecordButton(
                isRecording: $viewModel.isRecording,
                onStartRecording: {
                    viewModel.startVoiceRecording()
                },
                onStopRecording: {
                    viewModel.stopVoiceRecording()
                }
            )
            .offset(y: -80),
            alignment: .bottom
        )
        .sheet(isPresented: $viewModel.showingVoiceTransactionSheet) {
            VoiceTransactionConfirmationView(
                recognizedText: viewModel.recognizedText,
                onConfirm: {
                    viewModel.processVoiceInput()
                },
                onCancel: {
                    viewModel.recognizedText = ""
                    viewModel.showingVoiceTransactionSheet = false
                }
            )
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
        .task {
            await viewModel.refreshData()
        }
    }
}

enum Tab {
    case home
    case transactions
    case budget
    case statistics
    case settings
}

struct HomeView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 总体预算卡片
                    OverallBudgetCard(
                        totalBudget: viewModel.totalBudgetAmount,
                        totalSpent: viewModel.totalSpentAmount,
                        progress: viewModel.overallProgress,
                        isOverBudget: viewModel.isOverBudget
                    )
                    
                    // 预算进度列表
                    if !viewModel.budgetStatuses.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("预算进度")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(viewModel.budgetStatuses, id: \.budget.id) { status in
                                BudgetProgressCard(
                                    budget: status.budget,
                                    spent: status.spentAmount
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // 最近交易
                    if !viewModel.recentTransactions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("最近交易")
                                    .font(.headline)
                                
                                Spacer()
                                
                                NavigationLink("查看全部") {
                                    TransactionListView()
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                            .padding(.horizontal)
                            
                            ForEach(viewModel.recentTransactions.prefix(5), id: \.id) { transaction in
                                TransactionRow(
                                    transaction: transaction,
                                    onDelete: {
                                        viewModel.deleteTransaction(transaction)
                                    },
                                    onEdit: {
                                        viewModel.editTransaction(transaction)
                                    }
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    Spacer(minLength: 100) // 为语音按钮留空间
                }
                .padding(.vertical)
            }
            .navigationTitle("VoiceBudget")
            .refreshable {
                await viewModel.refreshData()
            }
        }
        .overlay(
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.3))
                }
            }
        )
    }
}

struct OverallBudgetCard: View {
    let totalBudget: Double
    let totalSpent: Double
    let progress: Double
    let isOverBudget: Bool
    
    private var remaining: Double {
        totalBudget - totalSpent
    }
    
    private var progressColor: Color {
        if isOverBudget {
            return .red
        } else if progress > 0.8 {
            return .orange
        } else {
            return .green
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("本月总预算")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("¥\(totalBudget, specifier: "%.2f")")
                        .font(.title)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(isOverBudget ? "已超支" : "剩余")
                        .font(.subheadline)
                        .foregroundColor(isOverBudget ? .red : .secondary)
                    
                    Text("¥\(abs(remaining), specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(isOverBudget ? .red : .primary)
                }
            }
            
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)
                        .cornerRadius(6)
                    
                    Rectangle()
                        .fill(progressColor)
                        .frame(width: min(geometry.size.width * progress, geometry.size.width), height: 12)
                        .cornerRadius(6)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 12)
            
            HStack {
                Text("已花费 ¥\(totalSpent, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(progress * 100, specifier: "%.1f")%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        .padding(.horizontal)
    }
}

#Preview {
    MainView(viewModel: MainViewModel(
        processVoiceInputUseCase: ProcessVoiceInputUseCase(
            transactionRepository: CoreDataTransactionRepository(),
            smartCategoryService: SmartCategoryService()
        ),
        getBudgetStatusUseCase: GetBudgetStatusUseCase(
            budgetRepository: CoreDataBudgetRepository(),
            transactionRepository: CoreDataTransactionRepository()
        ),
        getTransactionHistoryUseCase: GetTransactionHistoryUseCase(
            transactionRepository: CoreDataTransactionRepository()
        )
    ))
}