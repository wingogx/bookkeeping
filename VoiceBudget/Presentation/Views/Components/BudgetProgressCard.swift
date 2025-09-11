import SwiftUI

struct BudgetProgressCard: View {
    let budget: BudgetEntity
    let spent: Double
    
    private var remaining: Double {
        budget.amount - spent
    }
    
    private var progress: Double {
        spent / budget.amount
    }
    
    private var progressColor: Color {
        switch progress {
        case 0..<0.7: return .green
        case 0.7..<0.9: return .orange
        default: return .red
        }
    }
    
    private var statusText: String {
        if remaining > 0 {
            return "剩余 ¥\(remaining, specifier: "%.2f")"
        } else {
            return "超支 ¥\(abs(remaining), specifier: "%.2f")"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题和时间范围
            HStack {
                VStack(alignment: .leading) {
                    Text(budget.type.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(budget.startDate, formatter: dateFormatter) - \(budget.endDate, formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("¥\(budget.amount, specifier: "%.2f")")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            // 进度条
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("已花费")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(statusText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(remaining > 0 ? .primary : .red)
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)
                        
                        Rectangle()
                            .fill(progressColor)
                            .frame(width: min(geometry.size.width * progress, geometry.size.width), height: 8)
                            .cornerRadius(4)
                            .animation(.easeInOut(duration: 0.5), value: progress)
                    }
                }
                .frame(height: 8)
                
                HStack {
                    Text("¥\(spent, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(progress * 100, specifier: "%.1f")%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }
}

#Preview {
    BudgetProgressCard(
        budget: BudgetEntity(
            id: UUID(),
            amount: 1000,
            type: .monthly,
            category: .food,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        ),
        spent: 650
    )
    .padding()
}