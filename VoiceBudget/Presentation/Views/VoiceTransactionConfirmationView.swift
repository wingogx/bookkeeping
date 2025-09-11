import SwiftUI

struct VoiceTransactionConfirmationView: View {
    let recognizedText: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var amount: String = ""
    @State private var category: TransactionCategory = .other
    @State private var note: String = ""
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 语音识别结果
                VStack(alignment: .leading, spacing: 12) {
                    Text("语音识别结果")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("\"\(recognizedText)\"")
                        .font(.title3)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                        )
                }
                
                // 智能解析提示
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "brain")
                            .foregroundColor(.blue)
                        Text("AI智能解析")
                            .font(.headline)
                        Spacer()
                    }
                    
                    // 金额输入
                    VStack(alignment: .leading, spacing: 8) {
                        Text("金额")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("¥")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            
                            TextField("0.00", text: $amount)
                                .font(.title2)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    
                    // 类别选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("分类")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        CategoryPicker(selectedCategory: $category)
                    }
                    
                    // 备注
                    VStack(alignment: .leading, spacing: 8) {
                        Text("备注")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("添加备注...", text: $note)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // 日期选择
                    VStack(alignment: .leading, spacing: 8) {
                        Text("日期")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        DatePicker("", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(CompactDatePickerStyle())
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(16)
                
                Spacer()
                
                // 操作按钮
                HStack(spacing: 16) {
                    Button("取消") {
                        onCancel()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                    .foregroundColor(.primary)
                    
                    Button("确认记账") {
                        onConfirm()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .disabled(amount.isEmpty)
                }
            }
            .padding()
            .navigationTitle("确认交易")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            parseVoiceInput()
        }
    }
    
    private func parseVoiceInput() {
        // 简单的语音解析逻辑，后续可以用更智能的AI解析
        let text = recognizedText.lowercased()
        
        // 解析金额
        if let amountMatch = text.range(of: "\\d+(\\.\\d+)?", options: .regularExpression) {
            amount = String(text[amountMatch])
        }
        
        // 解析类别
        if text.contains("吃饭") || text.contains("午餐") || text.contains("晚餐") || text.contains("早餐") {
            category = .food
        } else if text.contains("打车") || text.contains("地铁") || text.contains("公交") {
            category = .transport
        } else if text.contains("电影") || text.contains("游戏") || text.contains("娱乐") {
            category = .entertainment
        } else if text.contains("购物") || text.contains("买") {
            category = .shopping
        } else if text.contains("医院") || text.contains("药") || text.contains("健康") {
            category = .health
        }
        
        // 设置备注为原始文本（去掉金额部分）
        note = recognizedText
    }
}

struct CategoryPicker: View {
    @Binding var selectedCategory: TransactionCategory
    
    private let categories: [TransactionCategory] = [.food, .transport, .entertainment, .shopping, .health, .other]
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
            ForEach(categories, id: \.self) { category in
                CategoryCell(
                    category: category,
                    isSelected: selectedCategory == category
                ) {
                    selectedCategory = category
                }
            }
        }
    }
}

struct CategoryCell: View {
    let category: TransactionCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    private var categoryIcon: String {
        switch category {
        case .food: return "fork.knife"
        case .transport: return "car"
        case .entertainment: return "gamecontroller"
        case .shopping: return "bag"
        case .health: return "heart"
        case .other: return "questionmark.circle"
        }
    }
    
    private var categoryColor: Color {
        switch category {
        case .food: return .orange
        case .transport: return .blue
        case .entertainment: return .purple
        case .shopping: return .green
        case .health: return .red
        case .other: return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: categoryIcon)
                .font(.title2)
                .foregroundColor(isSelected ? .white : categoryColor)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(isSelected ? categoryColor : categoryColor.opacity(0.1))
                )
            
            Text(category.displayName)
                .font(.caption)
                .foregroundColor(isSelected ? categoryColor : .secondary)
                .fontWeight(isSelected ? .semibold : .regular)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? categoryColor.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? categoryColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                )
        )
        .onTapGesture {
            onTap()
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

#Preview {
    VoiceTransactionConfirmationView(
        recognizedText: "午餐花了25块钱",
        onConfirm: {},
        onCancel: {}
    )
}