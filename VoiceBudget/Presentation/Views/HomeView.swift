import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var mainViewModel: MainViewModel
    @StateObject private var voiceRecordingViewModel = VoiceRecordingViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 预算状态卡片
                    if let budgetUsage = mainViewModel.budgetUsage {
                        BudgetStatusCard(budgetUsage: budgetUsage)
                    }
                    
                    // 语音记账按钮
                    VoiceRecordingButton()
                        .environmentObject(voiceRecordingViewModel)
                    
                    // 最近交易
                    RecentTransactionsSection(transactions: mainViewModel.recentTransactions)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("记账助手")
            .refreshable {
                mainViewModel.refreshData()
            }
        }
    }
}

struct BudgetStatusCard: View {
    let budgetUsage: BudgetUsage
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("本月预算")
                    .font(.headline)
                Spacer()
                Text(budgetUsage.status.displayText)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(budgetUsage.status.color.opacity(0.2))
                    .foregroundColor(budgetUsage.status.color)
                    .cornerRadius(8)
            }
            
            ProgressView(value: budgetUsage.usagePercentage / 100)
                .progressViewStyle(LinearProgressViewStyle())
                .accentColor(budgetUsage.status.color)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("已使用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥\(budgetUsage.usedAmount, specifier: "%.2f")")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("剩余")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥\(budgetUsage.remainingAmount, specifier: "%.2f")")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct VoiceRecordingButton: View {
    @EnvironmentObject private var voiceViewModel: VoiceRecordingViewModel
    
    var body: some View {
        Button(action: {
            voiceViewModel.toggleRecording()
        }) {
            ZStack {
                Circle()
                    .fill(voiceViewModel.isRecording ? Color.red : Color.blue)
                    .frame(width: 80, height: 80)
                    .scaleEffect(voiceViewModel.isRecording ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: voiceViewModel.isRecording)
                
                Image(systemName: voiceViewModel.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecentTransactionsSection: View {
    let transactions: [TransactionEntity]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近记录")
                    .font(.headline)
                Spacer()
                NavigationLink("查看全部", destination: TransactionListView())
                    .font(.caption)
            }
            
            if transactions.isEmpty {
                Text("暂无记录")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(transactions) { transaction in
                    TransactionRowView(transaction: transaction)
                }
            }
        }
    }
}

struct TransactionRowView: View {
    let transaction: TransactionEntity
    
    var body: some View {
        HStack {
            // 分类图标
            Text(getCategoryIcon(transaction.categoryID))
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.categoryName ?? transaction.categoryID)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let note = transaction.note {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("¥\(transaction.amount, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(transaction.date.formatted(.dateTime.month().day()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
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

// MARK: - Extensions

extension BudgetStatus {
    var displayText: String {
        switch self {
        case .safe: return "安全"
        case .warning: return "警告"
        case .exceeded: return "超支"
        }
    }
    
    var color: Color {
        switch self {
        case .safe: return .green
        case .warning: return .orange
        case .exceeded: return .red
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(MainViewModel())
    }
}