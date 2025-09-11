import SwiftUI

struct TransactionRow: View {
    let transaction: TransactionEntity
    let onDelete: () -> Void
    let onEdit: () -> Void
    
    private var categoryIcon: String {
        switch transaction.category {
        case .food: return "fork.knife"
        case .transport: return "car"
        case .entertainment: return "gamecontroller"
        case .shopping: return "bag"
        case .health: return "heart"
        case .other: return "questionmark.circle"
        }
    }
    
    private var categoryColor: Color {
        switch transaction.category {
        case .food: return .orange
        case .transport: return .blue
        case .entertainment: return .purple
        case .shopping: return .green
        case .health: return .red
        case .other: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 类别图标
            Image(systemName: categoryIcon)
                .font(.title2)
                .foregroundColor(categoryColor)
                .frame(width: 30, height: 30)
            
            // 交易信息
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.note ?? "无备注")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(transaction.category.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(transaction.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 金额
            VStack(alignment: .trailing) {
                Text("¥\(transaction.amount, specifier: "%.2f")")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if transaction.isFromVoice {
                    Image(systemName: "mic.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing) {
            Button("删除", role: .destructive) {
                onDelete()
            }
            
            Button("编辑") {
                onEdit()
            }
            .accentColor(.blue)
        }
    }
}

#Preview {
    TransactionRow(
        transaction: TransactionEntity(
            id: UUID(),
            amount: 25.50,
            category: .food,
            note: "午餐",
            createdAt: Date(),
            isFromVoice: true
        ),
        onDelete: {},
        onEdit: {}
    )
    .padding()
}