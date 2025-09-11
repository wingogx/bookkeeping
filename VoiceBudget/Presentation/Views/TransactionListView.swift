import SwiftUI

struct TransactionListView: View {
    @StateObject private var viewModel = TransactionListViewModel()
    @State private var showingAddTransaction = false
    
    var body: some View {
        NavigationView {
            VStack {
                // 搜索栏
                SearchBar(text: $viewModel.searchText)
                
                // 筛选选项
                FilterRow(viewModel: viewModel)
                
                // 交易列表
                List {
                    ForEach(viewModel.transactions) { transaction in
                        TransactionRowView(transaction: transaction)
                            .swipeActions(edge: .trailing) {
                                Button("删除", role: .destructive) {
                                    viewModel.deleteTransaction(transaction)
                                }
                            }
                    }
                    
                    if viewModel.hasMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .onAppear {
                                viewModel.loadMore()
                            }
                    }
                }
                .refreshable {
                    viewModel.refresh()
                }
            }
            .navigationTitle("交易记录")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("添加") {
                        showingAddTransaction = true
                    }
                }
            }
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionView()
            }
            .onAppear {
                viewModel.loadTransactions()
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索交易记录...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(.horizontal)
    }
}

struct FilterRow: View {
    @ObservedObject var viewModel: TransactionListViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterChip(title: "全部", isSelected: viewModel.selectedCategory == nil) {
                    viewModel.selectedCategory = nil
                }
                
                ForEach(CategoryEntity.beginnerCategories) { category in
                    FilterChip(title: category.name, isSelected: viewModel.selectedCategory == category.id) {
                        viewModel.selectedCategory = category.id
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AddTransactionViewModel()
    
    var body: some View {
        NavigationView {
            Form {
                Section("金额") {
                    TextField("请输入金额", value: $viewModel.amount, format: .currency(code: "CNY"))
                        .keyboardType(.decimalPad)
                }
                
                Section("分类") {
                    Picker("选择分类", selection: $viewModel.selectedCategoryID) {
                        ForEach(CategoryEntity.beginnerCategories) { category in
                            Text(category.name).tag(category.id)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("备注") {
                    TextField("添加备注（可选）", text: $viewModel.note)
                }
                
                Section("日期") {
                    DatePicker("交易日期", selection: $viewModel.date, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("添加交易")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        viewModel.saveTransaction {
                            dismiss()
                        }
                    }
                    .disabled(!viewModel.isValid)
                }
            }
        }
    }
}

@MainActor
class TransactionListViewModel: ObservableObject {
    @Published var transactions: [TransactionEntity] = []
    @Published var searchText = "" {
        didSet {
            searchTransactions()
        }
    }
    @Published var selectedCategory: String? {
        didSet {
            loadTransactions()
        }
    }
    @Published var isLoading = false
    @Published var hasMore = false
    
    private let transactionRepository: TransactionRepository
    private let getTransactionHistoryUseCase: GetTransactionHistoryUseCase
    private var currentOffset = 0
    private let pageSize = 20
    
    init() {
        let coreDataStack = CoreDataStack.shared
        self.transactionRepository = CoreDataTransactionRepository(context: coreDataStack.viewContext)
        self.getTransactionHistoryUseCase = GetTransactionHistoryUseCase(transactionRepository: transactionRepository)
    }
    
    func loadTransactions() {
        currentOffset = 0
        loadTransactionsInternal(reset: true)
    }
    
    func loadMore() {
        guard !isLoading && hasMore else { return }
        currentOffset += pageSize
        loadTransactionsInternal(reset: false)
    }
    
    func refresh() {
        loadTransactions()
    }
    
    func deleteTransaction(_ transaction: TransactionEntity) {
        Task {
            do {
                try await transactionRepository.deleteTransaction(id: transaction.id)
                await MainActor.run {
                    transactions.removeAll { $0.id == transaction.id }
                }
            } catch {
                print("删除失败: \(error)")
            }
        }
    }
    
    private func loadTransactionsInternal(reset: Bool) {
        guard !isLoading else { return }
        
        isLoading = true
        
        Task {
            do {
                let request = GetTransactionHistoryUseCase.Request(
                    categoryID: selectedCategory,
                    limit: pageSize,
                    offset: currentOffset
                )
                
                let response = try await getTransactionHistoryUseCase.execute(request)
                
                await MainActor.run {
                    isLoading = false
                    
                    if response.success {
                        if reset {
                            transactions = response.transactions
                        } else {
                            transactions.append(contentsOf: response.transactions)
                        }
                        hasMore = response.hasMore
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    private func searchTransactions() {
        guard !searchText.isEmpty else {
            loadTransactions()
            return
        }
        
        Task {
            do {
                let results = try await transactionRepository.searchTransactions(searchText: searchText)
                await MainActor.run {
                    transactions = results
                    hasMore = false
                }
            } catch {
                print("搜索失败: \(error)")
            }
        }
    }
}

@MainActor
class AddTransactionViewModel: ObservableObject {
    @Published var amount: Decimal = 0
    @Published var selectedCategoryID = CategoryEntity.beginnerCategories.first?.id ?? ""
    @Published var note = ""
    @Published var date = Date()
    
    private let createTransactionUseCase: CreateTransactionUseCase
    
    var isValid: Bool {
        amount > 0 && !selectedCategoryID.isEmpty
    }
    
    init() {
        let coreDataStack = CoreDataStack.shared
        let transactionRepository = CoreDataTransactionRepository(context: coreDataStack.viewContext)
        let budgetRepository = CoreDataBudgetRepository(context: coreDataStack.viewContext)
        
        self.createTransactionUseCase = CreateTransactionUseCase(
            transactionRepository: transactionRepository,
            budgetRepository: budgetRepository
        )
    }
    
    func saveTransaction(completion: @escaping () -> Void) {
        guard isValid else { return }
        
        Task {
            do {
                let request = CreateTransactionUseCase.Request(
                    amount: amount,
                    categoryID: selectedCategoryID,
                    note: note.isEmpty ? nil : note,
                    date: date,
                    source: .manual
                )
                
                let response = try await createTransactionUseCase.execute(request)
                
                await MainActor.run {
                    if response.success {
                        completion()
                    }
                }
            } catch {
                print("保存失败: \(error)")
            }
        }
    }
}

struct TransactionListView_Previews: PreviewProvider {
    static var previews: some View {
        TransactionListView()
    }
}