import SwiftUI

/// 交易确认视图
/// 显示语音识别结果并允许用户编辑确认
struct TransactionConfirmationView: View {
    let suggestion: VoiceTransactionService.TransactionSuggestion
    let onConfirm: () -> Void
    let onEdit: (Decimal?, String?, TransactionCategory?) -> Void
    let onCancel: () -> Void
    
    @State private var editingAmount: String = ""
    @State private var editingDescription: String = ""
    @State private var selectedCategory: TransactionCategory
    @State private var isEditing = false
    @Environment(\.dismiss) private var dismiss
    
    init(
        suggestion: VoiceTransactionService.TransactionSuggestion,
        onConfirm: @escaping () -> Void,
        onEdit: @escaping (Decimal?, String?, TransactionCategory?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.suggestion = suggestion
        self.onConfirm = onConfirm
        self.onEdit = onEdit
        self.onCancel = onCancel
        
        self._selectedCategory = State(initialValue: suggestion.category)
        self._editingAmount = State(initialValue: suggestion.amount?.description ?? "")
        self._editingDescription = State(initialValue: suggestion.description ?? "")
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 原始语音文本
                    VStack(alignment: .leading, spacing: 10) {
                        Text("识别结果")
                            .font(.headline)
                        
                        Text("「\(suggestion.originalText)」")
                            .font(.body)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        
                        HStack {
                            Text("置信度")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.1f%%", suggestion.confidence * 100))
                                .font(.caption)
                                .foregroundColor(suggestion.confidence > 0.8 ? .green : .orange)
                        }
                    }
                    
                    // 交易详情
                    VStack(spacing: 15) {
                        Text("交易详情")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // 金额
                        VStack(alignment: .leading, spacing: 8) {
                            Text("金额")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if isEditing {
                                TextField("请输入金额", text: $editingAmount)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.decimalPad)
                            } else {
                                HStack {
                                    Text("¥\(suggestion.amount?.description ?? "未识别")")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)
                                    Spacer()
                                    Button("编辑") {
                                        isEditing = true
                                    }
                                    .font(.caption)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                        
                        // 分类
                        VStack(alignment: .leading, spacing: 8) {
                            Text("分类")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if isEditing {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(TransactionCategory.allCases, id: \.self) { category in
                                            CategoryButton(
                                                category: category,
                                                isSelected: selectedCategory == category
                                            ) {
                                                selectedCategory = category
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            } else {
                                HStack {
                                    Text(suggestion.category.icon)
                                        .font(.title2)
                                    Text(suggestion.category.localizedName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Button("更改") {
                                        isEditing = true
                                    }
                                    .font(.caption)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                        
                        // 描述
                        VStack(alignment: .leading, spacing: 8) {
                            Text("备注")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if isEditing {
                                TextField("添加备注（可选）", text: $editingDescription)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            } else {
                                HStack {
                                    Text(suggestion.description?.isEmpty == false ? suggestion.description! : "无备注")
                                        .font(.body)
                                        .foregroundColor(suggestion.description?.isEmpty == false ? .primary : .secondary)
                                    Spacer()
                                    Button("编辑") {
                                        isEditing = true
                                    }
                                    .font(.caption)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                        
                        // 日期时间
                        HStack {
                            Text("时间")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text(suggestion.date, style: .date)
                                .font(.body)
                            Text(suggestion.date, style: .time)
                                .font(.body)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("确认记账")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        Button("完成") {
                            applyEdits()
                            isEditing = false
                        }
                    } else {
                        Button("确认") {
                            onConfirm()
                        }
                        .fontWeight(.semibold)
                        .disabled(suggestion.amount == nil || suggestion.amount! <= 0)
                    }
                }
            }
        }
    }
    
    private func applyEdits() {
        let newAmount = Decimal(string: editingAmount)
        let newDescription = editingDescription.isEmpty ? nil : editingDescription
        
        onEdit(newAmount, newDescription, selectedCategory)
    }
}

// MARK: - Category Button
struct CategoryButton: View {
    let category: TransactionCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(category.icon)
                    .font(.title2)
                Text(category.localizedName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Transaction Category Extension
extension TransactionCategory: CaseIterable {
    public static var allCases: [TransactionCategory] {
        return [.food, .transport, .shopping, .entertainment, .healthcare, .education, .utilities, .other]
    }
}

#Preview {
    TransactionConfirmationView(
        suggestion: VoiceTransactionService.TransactionSuggestion(
            originalText: "今天午餐花了38块",
            category: .food,
            amount: 38,
            description: "午餐",
            confidence: 0.9
        ),
        onConfirm: {},
        onEdit: { _, _, _ in },
        onCancel: {}
    )
}