import SwiftUI
import Combine

/// 历史记录界面
/// 显示所有交易记录，支持搜索、筛选、编辑和删除
public struct HistoryView: View {
    
    @EnvironmentObject private var transactionRepository: CoreDataTransactionRepository
    @StateObject private var historyViewModel = HistoryViewModel()
    
    @State private var selectedTransaction: TransactionEntity?
    @State private var showingEditSheet = false
    @State private var showingFilterSheet = false
    @State private var searchText = ""
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - 搜索栏
                searchBar
                
                // MARK: - 筛选和排序控件
                filterControls
                
                // MARK: - 交易列表
                transactionList
            }
            .navigationTitle("交易记录")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingFilterSheet = true
                    }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    
                    Menu("更多") {
                        Button("导出记录") {
                            historyViewModel.exportTransactions()
                        }
                        Button("清空已删除") {
                            historyViewModel.clearDeletedTransactions()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                if let transaction = selectedTransaction {
                    TransactionEditView(transaction: transaction) { updatedTransaction in
                        historyViewModel.updateTransaction(updatedTransaction)
                    }
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheet(filter: $historyViewModel.currentFilter) { filter in
                    Task {
                        await historyViewModel.applyFilter(filter)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索交易记录...")
            .onSubmit(of: .search) {
                Task {
                    await historyViewModel.searchTransactions(searchText)
                }
            }
            .onChange(of: searchText) { newValue in
                if newValue.isEmpty {
                    Task {
                        await historyViewModel.clearSearch()
                    }
                }
            }
        }
        .task {
            await historyViewModel.loadTransactions()
        }
        .refreshable {
            await historyViewModel.refreshTransactions()
        }
    }
    
    // MARK: - 搜索栏
    private var searchBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索交易记录...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
            )
            .padding(.horizontal)
            
            // 快速筛选标签
            if !historyViewModel.activeFilterTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(historyViewModel.activeFilterTags, id: \.self) { tag in
                            FilterTag(text: tag) {
                                historyViewModel.removeFilterTag(tag)
                            }
                        }
                        
                        Button("清除全部") {
                            historyViewModel.clearAllFilters()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - 筛选和排序控件
    private var filterControls: some View {
        HStack {
            // 排序选择
            Menu {
                Button("按时间降序") {
                    historyViewModel.sortBy(.dateDescending)
                }
                Button("按时间升序") {
                    historyViewModel.sortBy(.dateAscending)
                }
                Button("按金额降序") {
                    historyViewModel.sortBy(.amountDescending)
                }
                Button("按金额升序") {
                    historyViewModel.sortBy(.amountAscending)
                }
            } label: {
                HStack(spacing: 4) {
                    Text(historyViewModel.currentSortOption.displayName)
                        .font(.subheadline)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }
            
            Spacer()
            
            // 显示统计
            if !historyViewModel.transactions.isEmpty {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(historyViewModel.transactions.count) 条记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let totalAmount = historyViewModel.totalAmount {
                        Text("总计：¥\(totalAmount, specifier: "%.2f")")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(totalAmount >= 0 ? .green : .red)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
    
    // MARK: - 交易列表
    private var transactionList: some View {
        Group {
            if historyViewModel.isLoading {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if historyViewModel.transactions.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(historyViewModel.groupedTransactions, id: \.date) { group in
                        Section(header: sectionHeader(for: group)) {
                            ForEach(group.transactions) { transaction in
                                TransactionRow(
                                    transaction: transaction,
                                    onTap: {
                                        selectedTransaction = transaction
                                        showingEditSheet = true
                                    },
                                    onDelete: {
                                        historyViewModel.deleteTransaction(transaction)
                                    }
                                )
                                .swipeActions(edge: .trailing) {
                                    Button("删除", role: .destructive) {
                                        historyViewModel.deleteTransaction(transaction)
                                    }
                                    
                                    Button("编辑") {
                                        selectedTransaction = transaction
                                        showingEditSheet = true
                                    }
                                    .tint(.blue)
                                }
                                .swipeActions(edge: .leading) {
                                    Button("复制") {
                                        historyViewModel.duplicateTransaction(transaction)
                                    }
                                    .tint(.green)
                                }
                            }
                        }
                    }
                    
                    // 加载更多指示器
                    if historyViewModel.hasMoreTransactions {
                        HStack {
                            Spacer()
                            ProgressView("加载更多...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding()
                        .onAppear {
                            Task {
                                await historyViewModel.loadMoreTransactions()
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("暂无交易记录")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            if searchText.isEmpty && historyViewModel.currentFilter.isEmpty {
                Text("开始使用语音记账功能\n记录您的第一笔交易吧")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                VStack(spacing: 8) {
                    Text("没有找到匹配的记录")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Button("清除筛选条件") {
                        searchText = ""
                        historyViewModel.clearAllFilters()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func sectionHeader(for group: TransactionGroup) -> some View {
        HStack {
            Text(group.displayDate)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(group.transactions.count) 笔")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if group.totalAmount != 0 {
                    Text("¥\(group.totalAmount, specifier: "%.2f")")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(group.totalAmount >= 0 ? .green : .red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting Views

/// 筛选标签
private struct FilterTag: View {
    let text: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .cornerRadius(12)
    }
}

/// 交易行视图
private struct TransactionRow: View {
    let transaction: TransactionEntity
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 分类图标
                Circle()
                    .fill(transaction.category.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: transaction.category.iconName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(transaction.category.color)
                    )
                
                // 交易信息
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(transaction.description)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text("\(transaction.amount >= 0 ? "+" : "")¥\(transaction.amount, specifier: "%.2f")")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(transaction.amount >= 0 ? .green : .primary)
                    }
                    
                    HStack {
                        Text(transaction.category.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if transaction.source == .voice {
                            Image(systemName: "mic.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        Text(transaction.date, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button("编辑") {
                onTap()
            }
            
            Button("删除", role: .destructive) {
                onDelete()
            }
        }
    }
}

/// 筛选面板
private struct FilterSheet: View {
    @Binding var filter: TransactionFilter
    let onApply: (TransactionFilter) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempFilter: TransactionFilter
    
    init(filter: Binding<TransactionFilter>, onApply: @escaping (TransactionFilter) -> Void) {
        self._filter = filter
        self.onApply = onApply
        self._tempFilter = State(initialValue: filter.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            List {
                // 日期范围
                Section("日期范围") {
                    DatePicker("开始日期", selection: $tempFilter.startDate, displayedComponents: .date)
                    DatePicker("结束日期", selection: $tempFilter.endDate, displayedComponents: .date)
                }
                
                // 分类筛选
                Section("分类") {
                    ForEach(TransactionCategory.allCases, id: \.self) { category in
                        HStack {
                            Text(category.displayName)
                            Spacer()
                            if tempFilter.categories.contains(category) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if tempFilter.categories.contains(category) {
                                tempFilter.categories.remove(category)
                            } else {
                                tempFilter.categories.insert(category)
                            }
                        }
                    }
                }
                
                // 金额范围
                Section("金额范围") {
                    HStack {
                        Text("最小金额")
                        Spacer()
                        TextField("0", value: $tempFilter.minAmount, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("最大金额")
                        Spacer()
                        TextField("无限制", value: $tempFilter.maxAmount, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 100)
                    }
                }
                
                // 数据源
                Section("数据源") {
                    HStack {
                        Text("语音记账")
                        Spacer()
                        Toggle("", isOn: $tempFilter.includeVoiceTransactions)
                    }
                    
                    HStack {
                        Text("手动输入")
                        Spacer()
                        Toggle("", isOn: $tempFilter.includeManualTransactions)
                    }
                }
            }
            .navigationTitle("筛选条件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("重置") {
                        tempFilter = TransactionFilter()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("应用") {
                        filter = tempFilter
                        onApply(tempFilter)
                        dismiss()
                    }
                }
            }
        }
    }
}

/// 交易编辑视图
private struct TransactionEditView: View {
    let transaction: TransactionEntity
    let onSave: (TransactionEntity) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var amount: Double
    @State private var description: String
    @State private var category: TransactionCategory
    @State private var date: Date
    
    init(transaction: TransactionEntity, onSave: @escaping (TransactionEntity) -> Void) {
        self.transaction = transaction
        self.onSave = onSave
        self._amount = State(initialValue: transaction.amount)
        self._description = State(initialValue: transaction.description)
        self._category = State(initialValue: transaction.category)
        self._date = State(initialValue: transaction.date)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("基本信息") {
                    HStack {
                        Text("金额")
                        Spacer()
                        TextField("0.00", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 120)
                    }
                    
                    HStack {
                        Text("描述")
                        Spacer()
                        TextField("请输入描述", text: $description)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 200)
                    }
                    
                    Picker("分类", selection: $category) {
                        ForEach(TransactionCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    
                    DatePicker("日期", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("编辑交易")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        var updatedTransaction = transaction
                        updatedTransaction.amount = amount
                        updatedTransaction.description = description
                        updatedTransaction.category = category
                        updatedTransaction.date = date
                        onSave(updatedTransaction)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Types

public struct TransactionGroup {
    let date: Date
    let transactions: [TransactionEntity]
    
    var displayDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        
        if Calendar.current.isDateInToday(date) {
            return "今天"
        } else if Calendar.current.isDateInYesterday(date) {
            return "昨天"
        } else if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year) {
            formatter.dateFormat = "M月d日"
        } else {
            formatter.dateFormat = "yyyy年M月d日"
        }
        
        return formatter.string(from: date)
    }
    
    var totalAmount: Double {
        transactions.reduce(0) { $0 + $1.amount }
    }
}

public struct TransactionFilter {
    var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    var endDate = Date()
    var categories: Set<TransactionCategory> = Set(TransactionCategory.allCases)
    var minAmount: Double? = nil
    var maxAmount: Double? = nil
    var includeVoiceTransactions = true
    var includeManualTransactions = true
    
    var isEmpty: Bool {
        categories == Set(TransactionCategory.allCases) &&
        minAmount == nil &&
        maxAmount == nil &&
        includeVoiceTransactions &&
        includeManualTransactions
    }
}

public enum SortOption: CaseIterable {
    case dateDescending
    case dateAscending
    case amountDescending
    case amountAscending
    
    var displayName: String {
        switch self {
        case .dateDescending: return "时间↓"
        case .dateAscending: return "时间↑"
        case .amountDescending: return "金额↓"
        case .amountAscending: return "金额↑"
        }
    }
}

// MARK: - ViewModel

@MainActor
public class HistoryViewModel: ObservableObject {
    @Published var transactions: [TransactionEntity] = []
    @Published var groupedTransactions: [TransactionGroup] = []
    @Published var currentFilter = TransactionFilter()
    @Published var currentSortOption: SortOption = .dateDescending
    @Published var activeFilterTags: [String] = []
    @Published var isLoading = false
    @Published var hasMoreTransactions = false
    
    private var currentPage = 0
    private let pageSize = 50
    
    var totalAmount: Double? {
        guard !transactions.isEmpty else { return nil }
        return transactions.reduce(0) { $0 + $1.amount }
    }
    
    public func loadTransactions() async {
        isLoading = true
        currentPage = 0
        
        // 模拟数据加载
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        transactions = generateMockTransactions()
        updateGroupedTransactions()
        updateActiveFilterTags()
        
        isLoading = false
        hasMoreTransactions = transactions.count >= pageSize
    }
    
    public func loadMoreTransactions() async {
        guard !isLoading && hasMoreTransactions else { return }
        
        isLoading = true
        currentPage += 1
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        let newTransactions = generateMockTransactions(page: currentPage)
        transactions.append(contentsOf: newTransactions)
        updateGroupedTransactions()
        
        hasMoreTransactions = newTransactions.count >= pageSize
        isLoading = false
    }
    
    public func refreshTransactions() async {
        await loadTransactions()
    }
    
    public func searchTransactions(_ query: String) async {
        // 实现搜索逻辑
        if query.isEmpty {
            await loadTransactions()
        } else {
            let filtered = transactions.filter { transaction in
                transaction.description.localizedCaseInsensitiveContains(query) ||
                transaction.category.displayName.localizedCaseInsensitiveContains(query)
            }
            transactions = filtered
            updateGroupedTransactions()
        }
    }
    
    public func clearSearch() async {
        await loadTransactions()
    }
    
    public func applyFilter(_ filter: TransactionFilter) async {
        currentFilter = filter
        await loadTransactions()
    }
    
    public func clearAllFilters() {
        currentFilter = TransactionFilter()
        activeFilterTags.removeAll()
        Task {
            await loadTransactions()
        }
    }
    
    public func removeFilterTag(_ tag: String) {
        activeFilterTags.removeAll { $0 == tag }
        // 更新对应的筛选条件
        Task {
            await loadTransactions()
        }
    }
    
    public func sortBy(_ option: SortOption) {
        currentSortOption = option
        
        switch option {
        case .dateDescending:
            transactions.sort { $0.date > $1.date }
        case .dateAscending:
            transactions.sort { $0.date < $1.date }
        case .amountDescending:
            transactions.sort { $0.amount > $1.amount }
        case .amountAscending:
            transactions.sort { $0.amount < $1.amount }
        }
        
        updateGroupedTransactions()
    }
    
    public func deleteTransaction(_ transaction: TransactionEntity) {
        transactions.removeAll { $0.id == transaction.id }
        updateGroupedTransactions()
    }
    
    public func updateTransaction(_ transaction: TransactionEntity) {
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions[index] = transaction
            updateGroupedTransactions()
        }
    }
    
    public func duplicateTransaction(_ transaction: TransactionEntity) {
        var newTransaction = transaction
        newTransaction.id = UUID()
        newTransaction.date = Date()
        transactions.insert(newTransaction, at: 0)
        updateGroupedTransactions()
    }
    
    public func exportTransactions() {
        // 实现导出功能
    }
    
    public func clearDeletedTransactions() {
        // 实现清理已删除交易的功能
    }
    
    private func updateGroupedTransactions() {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        
        groupedTransactions = grouped.map { date, transactions in
            TransactionGroup(date: date, transactions: transactions.sorted { $0.date > $1.date })
        }.sorted { $0.date > $1.date }
    }
    
    private func updateActiveFilterTags() {
        activeFilterTags.removeAll()
        
        if !currentFilter.isEmpty {
            if currentFilter.categories.count < TransactionCategory.allCases.count {
                activeFilterTags.append("已选分类")
            }
            
            if currentFilter.minAmount != nil || currentFilter.maxAmount != nil {
                activeFilterTags.append("金额范围")
            }
            
            if !currentFilter.includeVoiceTransactions || !currentFilter.includeManualTransactions {
                activeFilterTags.append("数据源")
            }
        }
    }
    
    private func generateMockTransactions(page: Int = 0) -> [TransactionEntity] {
        let categories = TransactionCategory.allCases
        let sources: [TransactionSource] = [.voice, .manual]
        var transactions: [TransactionEntity] = []
        
        let startIndex = page * pageSize
        let endIndex = startIndex + pageSize
        
        for i in startIndex..<endIndex {
            let daysAgo = i / 3
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            
            let transaction = TransactionEntity(
                id: UUID(),
                amount: Double.random(in: -500...50),
                description: generateRandomDescription(),
                category: categories.randomElement()!,
                date: date,
                source: sources.randomElement()!,
                isDeleted: false
            )
            
            transactions.append(transaction)
        }
        
        return transactions.sorted { $0.date > $1.date }
    }
    
    private func generateRandomDescription() -> String {
        let descriptions = [
            "午餐", "晚餐", "咖啡", "地铁", "打车", "购物", "电影",
            "超市", "水果", "奶茶", "早餐", "加油", "停车", "书籍",
            "服装", "化妆品", "理发", "健身", "医药费", "话费"
        ]
        return descriptions.randomElement()!
    }
}

// MARK: - Extensions

extension TransactionCategory {
    var color: Color {
        switch self {
        case .food: return .orange
        case .transport: return .blue
        case .shopping: return .pink
        case .entertainment: return .purple
        case .healthcare: return .red
        case .education: return .green
        case .utilities: return .cyan
        case .other: return .gray
        }
    }
    
    var iconName: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .shopping: return "bag.fill"
        case .entertainment: return "gamecontroller.fill"
        case .healthcare: return "cross.fill"
        case .education: return "book.fill"
        case .utilities: return "house.fill"
        case .other: return "ellipsis"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
            .environmentObject(CoreDataTransactionRepository(
                coreDataStack: CoreDataStack.shared
            ))
    }
}
#endif