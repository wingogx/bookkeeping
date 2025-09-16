import SwiftUI
import Speech
import AVFoundation
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Import Intelligent Models
// Import all intelligent feature types from the models directory
// MARK: - App Entry Point
@main
struct VoiceBudgetApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(DataManager.shared)
        }
    }
}

// MARK: - Data Models
struct Transaction: Identifiable, Codable {
    let id: UUID
    let amount: Double
    let category: String
    let note: String
    let date: Date
    let isExpense: Bool

    init(amount: Double, category: String, note: String, date: Date, isExpense: Bool) {
        self.id = UUID()
        self.amount = amount
        self.category = category
        self.note = note
        self.date = date
        self.isExpense = isExpense
    }
}

// MARK: - Achievement System
struct Achievement: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let icon: String
    let isUnlocked: Bool
    let unlockedAt: Date?
    let type: AchievementType

    enum AchievementType: String, Codable {
        case firstRecord = "first_record"
        case streak3 = "streak_3"
        case streak7 = "streak_7"
        case streak15 = "streak_15"
        case streak30 = "streak_30"
        case budgetSaver = "budget_saver"
        case budgetMaster = "budget_master"
        case budgetControl = "budget_control"
    }

    init(name: String, description: String, icon: String, type: AchievementType, isUnlocked: Bool = false, unlockedAt: Date? = nil) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.icon = icon
        self.type = type
        self.isUnlocked = isUnlocked
        self.unlockedAt = unlockedAt
    }

    // 添加带id的完整初始化器
    init(id: UUID = UUID(), name: String, description: String, icon: String, type: AchievementType, isUnlocked: Bool = false, unlockedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.type = type
        self.isUnlocked = isUnlocked
        self.unlockedAt = unlockedAt
    }
}

// MARK: - User Stats
struct UserStats: Codable {
    var totalTransactions: Int = 0
    var currentStreak: Int = 0
    var maxStreak: Int = 0
    var lastRecordDate: Date?
    var totalSaved: Double = 0
    var monthsWithoutOverspend: Int = 0

    init() {}
}

// MARK: - App Settings
struct AppSettings: Codable {
    var notificationsEnabled: Bool = false
    var morningReminderEnabled: Bool = true
    var afternoonReminderEnabled: Bool = true
    var eveningReminderEnabled: Bool = true
    var morningReminderTime: String = "10:00"
    var afternoonReminderTime: String = "15:00"
    var eveningReminderTime: String = "21:00"
    var budgetWarningEnabled: Bool = true
    var weeklyReportEnabled: Bool = true

    static let `default` = AppSettings()
}

// MARK: - Export Data Models
struct ExportData {
    enum DateRange: String, CaseIterable {
        case allTime = "all_time"
        case lastMonth = "last_month"
        case lastThreeMonths = "last_three_months"
        case thisYear = "this_year"
        case thisMonth = "this_month"

        var displayName: String {
            switch self {
            case .allTime: return "全部时间"
            case .lastMonth: return "最近一个月"
            case .lastThreeMonths: return "最近三个月"
            case .thisYear: return "本年度"
            case .thisMonth: return "本月"
            }
        }
    }

    enum ExportFormat: String, CaseIterable {
        case csv = "csv"
        case txt = "txt"

        var displayName: String {
            switch self {
            case .csv: return "CSV格式"
            case .txt: return "文本格式"
            }
        }

        var fileExtension: String {
            return rawValue
        }
    }
}

// MARK: - Custom Budget Model
struct CustomBudget: Codable, Identifiable {
    let id: UUID
    var name: String
    var startDate: Date
    var endDate: Date
    var totalLimit: Double
    var categoryLimits: [String: Double]?
    var description: String?

    init(name: String, startDate: Date, endDate: Date, totalLimit: Double, categoryLimits: [String: Double]? = nil, description: String? = nil) {
        self.id = UUID()
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.totalLimit = totalLimit
        self.categoryLimits = categoryLimits
        self.description = description
    }

    var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }

    func getUsedAmount(from transactions: [Transaction]) -> Double {
        return transactions
            .filter { transaction in
                transaction.date >= startDate &&
                transaction.date <= endDate &&
                transaction.isExpense
            }
            .reduce(0) { $0 + $1.amount }
    }

    func getCategoryUsage(from transactions: [Transaction]) -> [String: Double] {
        let relevantTransactions = transactions.filter { transaction in
            transaction.date >= startDate &&
            transaction.date <= endDate &&
            transaction.isExpense
        }

        var usage: [String: Double] = [:]
        for transaction in relevantTransactions {
            usage[transaction.category, default: 0] += transaction.amount
        }
        return usage
    }
}

struct Budget: Codable {
    var monthlyLimit: Double
    var categoryLimits: [String: Double]
    var customBudgets: [CustomBudget]

    static let `default` = Budget(
        monthlyLimit: 3000,
        categoryLimits: [
            "餐饮": 1000,
            "交通": 500,
            "购物": 800,
            "娱乐": 400,
            "其他": 300
        ],
        customBudgets: []
    )
}

// MARK: - Intelligent Feature Models

// MARK: - Smart Recommendation Models
struct SmartCategoryRecommendation: Codable, Equatable {
    let category: String
    let confidence: Double
    let reason: String
    let isIncome: Bool
    let alternativeCategories: [String]

    // 兼容旧版本API的初始化方法
    init(category: String, confidence: Double, reason: String, isIncome: Bool) {
        self.category = category
        self.confidence = confidence
        self.reason = reason
        self.isIncome = isIncome
        self.alternativeCategories = []
    }

    // 新版本API的初始化方法
    init(category: String, confidence: Double, reason: String, isIncome: Bool, alternativeCategories: [String]) {
        self.category = category
        self.confidence = confidence
        self.reason = reason
        self.isIncome = isIncome
        self.alternativeCategories = alternativeCategories
    }

    static func == (lhs: SmartCategoryRecommendation, rhs: SmartCategoryRecommendation) -> Bool {
        return lhs.category == rhs.category &&
               abs(lhs.confidence - rhs.confidence) < 0.001 &&
               lhs.reason == rhs.reason &&
               lhs.isIncome == rhs.isIncome
    }

    enum ReasonType: String, Codable {
        case timePattern = "time_pattern"
        case amountPattern = "amount_pattern"
        case frequencyPattern = "frequency_pattern"
        case contextPattern = "context_pattern"
        case historicalData = "historical_data"
    }
}

// MARK: - Anomaly Detection Models
struct AnomalyDetectionResult: Codable {
    let transactionId: UUID
    let anomalyType: AnomalyType
    let severity: AnomalySeverity
    let description: String
    let suggestions: [String]
    let confidence: Double

    // 兼容旧版本的便利属性
    var types: [AnomalyType] { [anomalyType] }

    enum AnomalyType: String, Codable {
        case largeAmount = "large_amount"
        case unusualAmount = "unusual_amount"
        case unusualTime = "unusual_time"
        case duplicate = "duplicate"
        case duplicateTransaction = "duplicate_transaction"
        case categoryMismatch = "category_mismatch"
        case unusualCategory = "unusual_category"
    }

    enum AnomalySeverity: String, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"
    }

    // 兼容旧版本API的初始化方法
    init(types: [AnomalyType], severity: Double, description: String, suggestions: [String]) {
        self.transactionId = UUID()
        self.anomalyType = types.first ?? .largeAmount
        self.severity = severity > 0.75 ? .high : (severity > 0.5 ? .medium : .low)
        self.description = description
        self.suggestions = suggestions
        self.confidence = severity
    }

    // 新版本API的初始化方法
    init(transactionId: UUID, anomalyType: AnomalyType, severity: AnomalySeverity, description: String, suggestions: [String], confidence: Double = 0.8) {
        self.transactionId = transactionId
        self.anomalyType = anomalyType
        self.severity = severity
        self.description = description
        self.suggestions = suggestions
        self.confidence = confidence
    }
}

// MARK: - Smart Insights Models
struct SmartInsight: Codable {
    let id: UUID
    let title: String
    let description: String
    let type: InsightType
    let priority: Int
    let actionable: Bool
    let potentialBenefit: String
    let generatedAt: Date

    // 兼容旧版本的便利属性
    var actionSuggestions: [String] { [potentialBenefit] }
    var potentialSaving: Double { 0.0 }

    enum InsightType: String, Codable {
        case spendingPattern = "spending_pattern"
        case incomeOpportunity = "income_opportunity"
        case budgetOptimization = "budget_optimization"
        case habitImprovement = "habit_improvement"
        case goalRecommendation = "goal_recommendation"
    }

    // 兼容旧版本API的初始化方法
    init(type: String, description: String, actionSuggestions: [String] = [],
         priority: Int = 3, potentialSaving: Double = 0) {
        self.id = UUID()
        self.title = type
        self.description = description
        self.type = InsightType(rawValue: type) ?? .habitImprovement
        self.priority = priority
        self.actionable = !actionSuggestions.isEmpty
        self.potentialBenefit = actionSuggestions.first ?? "无具体建议"
        self.generatedAt = Date()
    }

    // 新版本API的初始化方法
    init(title: String, description: String, type: InsightType, priority: Int = 3, actionable: Bool = true, potentialBenefit: String) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.type = type
        self.priority = priority
        self.actionable = actionable
        self.potentialBenefit = potentialBenefit
        self.generatedAt = Date()
    }
}

// MARK: - User Learning Models
// 注意：UserLearningData已在后面重新定义，此处移除旧版本定义以避免冲突

// MARK: - Data Manager
class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published var transactions: [Transaction] = []
    @Published var budget = Budget.default
    @Published var expenseCategories: [String] = ["餐饮", "交通", "购物", "娱乐", "租房水电", "生活", "医疗", "教育", "其他"]
    @Published var incomeCategories: [String] = ["工资薪酬", "投资收益", "副业兼职", "奖金补贴", "退款返现", "转账收入", "其他收入"]
    @Published var achievements: [Achievement] = []
    @Published var userStats = UserStats()
    @Published var showAchievementAlert = false
    @Published var newAchievement: Achievement?
    @Published var appSettings = AppSettings.default

    // 向后兼容的便利属性
    var categories: [String] {
        return expenseCategories + incomeCategories
    }

    private let transactionsKey = "transactions"
    private let budgetKey = "budget"
    private let categoriesKey = "categories" // 保留用于数据迁移
    private let expenseCategoriesKey = "expenseCategories"
    private let incomeCategoriesKey = "incomeCategories"
    private let achievementsKey = "achievements"
    private let userStatsKey = "userStats"
    private let appSettingsKey = "appSettings"
    
    init() {
        loadData()
        initializeAchievements()
        // 修正旧的退款记录
        fixOldRefundRecords()
    }
    
    // 添加交易
    func addTransaction(_ transaction: Transaction) {
        transactions.append(transaction)
        updateUserStats()
        checkAchievements()
        checkBudgetWarnings(for: transaction)
        checkCustomBudgetWarnings(for: transaction)
        // 优化：只保存相关数据
        saveSpecificData([.transactions, .userStats, .achievements])
    }

    // 删除交易
    func deleteTransaction(_ transaction: Transaction) {
        transactions.removeAll { $0.id == transaction.id }
        // 优化：只保存交易数据
        saveSpecificData([.transactions])
    }
    
    // MARK: - 日期工具方法

    /// 检查两个日期是否在同一天
    private func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.startOfDay(for: date1) == calendar.startOfDay(for: date2)
    }

    /// 检查日期是否在当前月份
    private func isCurrentMonth(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        let nowComponents = calendar.dateComponents([.year, .month], from: now)
        let dateComponents = calendar.dateComponents([.year, .month], from: date)
        return nowComponents.year == dateComponents.year && nowComponents.month == dateComponents.month
    }

    /// 获取指定日期范围内的交易
    private func getTransactions(
        from startDate: Date? = nil,
        to endDate: Date? = nil,
        category: String? = nil,
        isExpense: Bool? = nil
    ) -> [Transaction] {
        return transactions.filter { transaction in
            // 日期范围过滤
            if let start = startDate, transaction.date < start { return false }
            if let end = endDate, transaction.date > end { return false }

            // 分类过滤
            if let cat = category, transaction.category != cat { return false }

            // 收支类型过滤
            if let expense = isExpense, transaction.isExpense != expense { return false }

            return true
        }
    }

    /// 获取当前月份的天数
    private func getCurrentMonthDays() -> Int {
        let calendar = Calendar.current
        let now = Date()
        return calendar.component(.day, from: now)
    }

    /// 获取日均支出
    var dailyAverageExpense: Double {
        let days = Double(getCurrentMonthDays())
        return days > 0 ? monthlyExpense / days : 0
    }

    /// 计算两个日期之间的天数差
    private func daysBetween(_ startDate: Date, _ endDate: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// 获取今天的开始时间
    private func startOfToday() -> Date {
        return Calendar.current.startOfDay(for: Date())
    }

    /// 计算剩余天数（用于自定义预算）
    func daysRemaining(until endDate: Date) -> Int {
        let today = startOfToday()
        let endOfDay = Calendar.current.startOfDay(for: endDate)
        return max(daysBetween(today, endOfDay), 0)
    }

    // MARK: - 数据查询方法

    // 修正旧的退款记录（将错误标记为支出的退款记录修正为收入）
    func fixOldRefundRecords() {
        let refundKeywords = ["退款", "退钱", "退费", "退回", "退了", "返钱", "返款", "返了", "赔偿", "补偿"]
        var hasChanges = false

        for i in 0..<transactions.count {
            let transaction = transactions[i]
            // 检查是否是被错误标记为支出的退款记录
            if transaction.isExpense {
                // 检查备注、分类或者是否是明显的退款
                let isRefund = refundKeywords.contains { keyword in
                    transaction.note.contains(keyword) || transaction.category.contains(keyword)
                }

                // 特殊处理：检查是否是"昨天购物"这类记录，且金额是常见的退款金额
                let isPotentialRefund = transaction.category == "购物" &&
                                       (transaction.amount == 18.8 || transaction.amount == 18.80 ||
                                        transaction.amount == 200.0 || transaction.amount == 200 ||
                                        transaction.amount == 500.0 || transaction.amount == 500) &&
                                       transaction.date > Date().addingTimeInterval(-7 * 24 * 60 * 60) // 最近7天的记录

                if isRefund || isPotentialRefund {
                    // 创建修正后的交易记录
                    transactions[i] = Transaction(
                        amount: transaction.amount,
                        category: transaction.category,
                        note: transaction.note.contains("退") ? transaction.note : "\(transaction.note) (退款)",
                        date: transaction.date,
                        isExpense: false // 修正为收入
                    )
                    hasChanges = true
                    print("🔧 修正退款记录: \(transaction.note) - ¥\(transaction.amount) - 从支出改为收入")
                }
            }
        }

        if hasChanges {
            saveData()
            print("✅ 退款记录修正完成，共修正 \(hasChanges ? "部分" : "0") 条记录")
        } else {
            print("ℹ️ 没有需要修正的退款记录")
        }
    }

    // 获取今日交易
    var todayTransactions: [Transaction] {
        let today = Date()
        return transactions.filter { isSameDay($0.date, today) }
    }

    // 获取本月支出
    var monthlyExpense: Double {
        return transactions
            .filter { isCurrentMonth($0.date) && $0.isExpense }
            .reduce(0) { $0 + $1.amount }
    }

    // 获取分类支出
    func getCategoryExpense(category: String) -> Double {
        return transactions
            .filter { isCurrentMonth($0.date) && $0.isExpense && $0.category == category }
            .reduce(0) { $0 + $1.amount }
    }

    // 获取本月交易
    var thisMonthTransactions: [Transaction] {
        return transactions.filter { isCurrentMonth($0.date) }
    }
    
    // 分类管理方法
    func addCategory(_ category: String, isExpense: Bool = true) {
        if category.isEmpty { return }

        if isExpense {
            if !expenseCategories.contains(category) {
                expenseCategories.append(category)
                saveSpecificData([.expenseCategories])
            }
        } else {
            if !incomeCategories.contains(category) {
                incomeCategories.append(category)
                saveSpecificData([.incomeCategories])
            }
        }
    }

    // 向后兼容的方法
    func addCategory(_ category: String) {
        addCategory(category, isExpense: true)
    }

    func deleteCategory(_ category: String) {
        // 检查是否有交易使用此分类
        let hasTransactions = transactions.contains { $0.category == category }
        if !hasTransactions {
            // 从对应的分类列表中移除
            if expenseCategories.contains(category) {
                expenseCategories.removeAll { $0 == category }
                // 从预算中移除此分类
                budget.categoryLimits.removeValue(forKey: category)
                saveSpecificData([.expenseCategories, .budget])
            } else if incomeCategories.contains(category) {
                incomeCategories.removeAll { $0 == category }
                saveSpecificData([.incomeCategories])
            }
        }
    }
    
    func updateCategory(oldName: String, newName: String) {
        guard !newName.isEmpty,
              oldName != newName,
              !categories.contains(newName) else {
            print("⚠️ 分类更新失败: 无效的参数或分类名已存在")
            return
        }

        // 1. 更新对应的分类列表
        if let index = expenseCategories.firstIndex(of: oldName) {
            expenseCategories[index] = newName
        } else if let index = incomeCategories.firstIndex(of: oldName) {
            incomeCategories[index] = newName
        } else {
            print("⚠️ 分类更新失败: 未找到分类")
            return
        }

        // 2. 安全地创建新的交易数组
        transactions = transactions.compactMap { transaction in
            if transaction.category == oldName {
                return Transaction(
                    amount: transaction.amount,
                    category: newName,
                    note: transaction.note,
                    date: transaction.date,
                    isExpense: transaction.isExpense
                )
            }
            return transaction
        }

        // 3. 更新预算设置
        if let limit = budget.categoryLimits[oldName] {
            budget.categoryLimits[newName] = limit
            budget.categoryLimits.removeValue(forKey: oldName)
        }

        // 4. 保存数据
        saveData()
        print("✅ 分类更新成功: \(oldName) → \(newName)")
    }
    
    // 保存数据
    func saveData() {
        saveAllData()
    }

    // 保存所有数据
    private func saveAllData() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        saveDataItem(transactions, key: transactionsKey, encoder: encoder, itemName: "交易记录")
        saveDataItem(budget, key: budgetKey, encoder: encoder, itemName: "预算设置")
        saveDataItem(expenseCategories, key: expenseCategoriesKey, encoder: encoder, itemName: "支出分类列表")
        saveDataItem(incomeCategories, key: incomeCategoriesKey, encoder: encoder, itemName: "收入分类列表")
        saveDataItem(achievements, key: achievementsKey, encoder: encoder, itemName: "成就数据")
        saveDataItem(userStats, key: userStatsKey, encoder: encoder, itemName: "用户统计")
        saveDataItem(appSettings, key: appSettingsKey, encoder: encoder, itemName: "应用设置")
    }

    // 选择性保存 - 提高性能
    enum DataType {
        case transactions, budget, categories, expenseCategories, incomeCategories, achievements, userStats, appSettings
    }

    func saveSpecificData(_ types: Set<DataType>) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        for type in types {
            switch type {
            case .transactions:
                saveDataItem(transactions, key: transactionsKey, encoder: encoder, itemName: "交易记录")
            case .budget:
                saveDataItem(budget, key: budgetKey, encoder: encoder, itemName: "预算设置")
            case .categories:
                // 保持向后兼容，同时保存新格式
                saveDataItem(expenseCategories, key: expenseCategoriesKey, encoder: encoder, itemName: "支出分类列表")
                saveDataItem(incomeCategories, key: incomeCategoriesKey, encoder: encoder, itemName: "收入分类列表")
            case .expenseCategories:
                saveDataItem(expenseCategories, key: expenseCategoriesKey, encoder: encoder, itemName: "支出分类列表")
            case .incomeCategories:
                saveDataItem(incomeCategories, key: incomeCategoriesKey, encoder: encoder, itemName: "收入分类列表")
            case .achievements:
                saveDataItem(achievements, key: achievementsKey, encoder: encoder, itemName: "成就数据")
            case .userStats:
                saveDataItem(userStats, key: userStatsKey, encoder: encoder, itemName: "用户统计")
            case .appSettings:
                saveDataItem(appSettings, key: appSettingsKey, encoder: encoder, itemName: "应用设置")
            }
        }
    }

    private func saveDataItem<T: Codable>(_ item: T, key: String, encoder: JSONEncoder, itemName: String) {
        do {
            let encoded = try encoder.encode(item)
            UserDefaults.standard.set(encoded, forKey: key)
            // print("✅ \(itemName)保存成功")
        } catch {
            print("❌ \(itemName)保存失败: \(error.localizedDescription)")
            // 尝试备份保存
            if let fallbackData = try? JSONEncoder().encode(item) {
                UserDefaults.standard.set(fallbackData, forKey: "\(key)_backup")
                print("💾 \(itemName)已保存到备份位置")
            }
        }
    }
    
    // 加载数据
    private func loadData() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        transactions = loadDataItem([Transaction].self, key: transactionsKey, decoder: decoder, defaultValue: [], itemName: "交易记录")
        budget = loadDataItem(Budget.self, key: budgetKey, decoder: decoder, defaultValue: Budget.default, itemName: "预算设置")
        achievements = loadDataItem([Achievement].self, key: achievementsKey, decoder: decoder, defaultValue: [], itemName: "成就数据")
        userStats = loadDataItem(UserStats.self, key: userStatsKey, decoder: decoder, defaultValue: UserStats(), itemName: "用户统计")
        appSettings = loadDataItem(AppSettings.self, key: appSettingsKey, decoder: decoder, defaultValue: AppSettings.default, itemName: "应用设置")

        // 数据迁移逻辑
        migrateCategories(decoder: decoder)
    }

    // 分类数据迁移方法
    private func migrateCategories(decoder: JSONDecoder) {
        // 检查是否已经迁移过
        let hasNewFormat = UserDefaults.standard.data(forKey: expenseCategoriesKey) != nil

        if hasNewFormat {
            // 已迁移，直接加载新格式数据
            expenseCategories = loadDataItem([String].self, key: expenseCategoriesKey, decoder: decoder, defaultValue: ["餐饮", "交通", "购物", "娱乐", "租房水电", "生活", "医疗", "教育", "其他"], itemName: "支出分类列表")
            incomeCategories = loadDataItem([String].self, key: incomeCategoriesKey, decoder: decoder, defaultValue: ["工资薪酬", "投资收益", "副业兼职", "奖金补贴", "退款返现", "转账收入", "其他收入"], itemName: "收入分类列表")
        } else {
            // 执行数据迁移
            let oldCategories = loadDataItem([String].self, key: categoriesKey, decoder: decoder, defaultValue: ["餐饮", "交通", "购物", "娱乐", "租房水电", "生活", "医疗", "教育", "其他"], itemName: "旧分类列表")

            // 将旧分类迁移为支出分类
            expenseCategories = oldCategories

            // 设置默认收入分类
            incomeCategories = ["工资薪酬", "投资收益", "副业兼职", "奖金补贴", "退款返现", "转账收入", "其他收入"]

            // 保存新格式数据
            saveSpecificData([.expenseCategories, .incomeCategories])

            print("✅ 分类数据迁移完成：支出分类 \(expenseCategories.count) 个，收入分类 \(incomeCategories.count) 个")
        }
    }

    private func loadDataItem<T: Codable>(_ type: T.Type, key: String, decoder: JSONDecoder, defaultValue: T, itemName: String) -> T {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            print("📝 \(itemName): 使用默认值")
            return defaultValue
        }

        do {
            let decoded = try decoder.decode(type, from: data)
            // print("✅ \(itemName)加载成功")
            return decoded
        } catch {
            print("❌ \(itemName)加载失败: \(error.localizedDescription)")

            // 尝试从备份加载
            if let backupData = UserDefaults.standard.data(forKey: "\(key)_backup"),
               let backupDecoded = try? decoder.decode(type, from: backupData) {
                print("💾 从备份恢复\(itemName)成功")
                return backupDecoded
            }

            // 尝试使用默认解码器
            if let fallbackDecoded = try? JSONDecoder().decode(type, from: data) {
                print("🔄 使用备用解码器恢复\(itemName)成功")
                return fallbackDecoded
            }

            print("⚠️ \(itemName)恢复失败，使用默认值")
            return defaultValue
        }
    }

    // MARK: - Achievement Management
    private func initializeAchievements() {
        if achievements.isEmpty {
            achievements = [
                Achievement(name: "记账新手", description: "完成首次记账", icon: "⭐", type: .firstRecord),
                Achievement(name: "坚持小达人", description: "连续记账3天", icon: "🔥", type: .streak3),
                Achievement(name: "记账达人", description: "连续记账7天", icon: "👑", type: .streak7),
                Achievement(name: "习惯大师", description: "连续记账15天", icon: "🏆", type: .streak15),
                Achievement(name: "记账之王", description: "连续记账30天", icon: "🏅", type: .streak30),
                Achievement(name: "省钱能手", description: "月支出比上月减少", icon: "💰", type: .budgetSaver),
                Achievement(name: "预算达人", description: "首次设置预算", icon: "📊", type: .budgetMaster),
                Achievement(name: "控制大师", description: "连续3个月预算不超支", icon: "🛡️", type: .budgetControl)
            ]
            saveData()
        }
    }

    private func updateUserStats() {
        userStats.totalTransactions += 1

        let today = startOfToday()
        let lastRecordDay = userStats.lastRecordDate.map { Calendar.current.startOfDay(for: $0) }

        if let lastDay = lastRecordDay {
            let daysDifference = daysBetween(lastDay, today)

            if daysDifference == 1 {
                // 连续记账
                userStats.currentStreak += 1
            } else if daysDifference > 1 {
                // 连击中断
                userStats.currentStreak = 1
            }
            // daysDifference == 0 表示同一天，不增加连击
        } else {
            // 第一次记账
            userStats.currentStreak = 1
        }

        userStats.maxStreak = max(userStats.maxStreak, userStats.currentStreak)
        userStats.lastRecordDate = Date()
    }

    private func checkAchievements() {
        var newlyUnlocked: [Achievement] = []

        for i in 0..<achievements.count {
            if !achievements[i].isUnlocked {
                let shouldUnlock = checkAchievementCondition(achievements[i].type)
                if shouldUnlock {
                    achievements[i] = Achievement(
                        name: achievements[i].name,
                        description: achievements[i].description,
                        icon: achievements[i].icon,
                        type: achievements[i].type,
                        isUnlocked: true,
                        unlockedAt: Date()
                    )
                    newlyUnlocked.append(achievements[i])
                }
            }
        }

        if !newlyUnlocked.isEmpty {
            newAchievement = newlyUnlocked.first
            showAchievementAlert = true
        }
    }

    private func checkAchievementCondition(_ type: Achievement.AchievementType) -> Bool {
        switch type {
        case .firstRecord:
            return userStats.totalTransactions >= 1
        case .streak3:
            return userStats.currentStreak >= 3
        case .streak7:
            return userStats.currentStreak >= 7
        case .streak15:
            return userStats.currentStreak >= 15
        case .streak30:
            return userStats.currentStreak >= 30
        case .budgetSaver:
            // 简化实现，暂时返回false
            return false
        case .budgetMaster:
            return budget.monthlyLimit > 0
        case .budgetControl:
            // 简化实现，暂时返回false
            return false
        }
    }

    // MARK: - Custom Budget Management

    // 添加自定义预算
    func addCustomBudget(_ customBudget: CustomBudget) {
        budget.customBudgets.append(customBudget)

        // 设置到期提醒
        NotificationManager.shared.scheduleCustomBudgetExpiryReminder(customBudget: customBudget)

        saveData()
    }

    // 删除自定义预算
    func deleteCustomBudget(_ customBudget: CustomBudget) {
        budget.customBudgets.removeAll { $0.id == customBudget.id }

        // 取消相关通知
        NotificationManager.shared.cancelCustomBudgetNotifications(budgetId: customBudget.id)

        saveData()
    }

    // 删除自定义预算 (通过索引)
    func deleteCustomBudget(at index: Int) {
        guard index >= 0 && index < budget.customBudgets.count else { return }

        let budgetToDelete = budget.customBudgets[index]
        budget.customBudgets.remove(at: index)

        // 取消相关通知
        NotificationManager.shared.cancelCustomBudgetNotifications(budgetId: budgetToDelete.id)

        saveData()
    }

    // 更新自定义预算
    func updateCustomBudget(_ updatedBudget: CustomBudget) {
        if let index = budget.customBudgets.firstIndex(where: { $0.id == updatedBudget.id }) {
            budget.customBudgets[index] = updatedBudget
            saveData()
        }
    }

    // 获取活跃的自定义预算
    func getActiveCustomBudgets() -> [CustomBudget] {
        return budget.customBudgets.filter { $0.isActive }
    }

    // 获取所有自定义预算 (按活跃状态排序)
    func getAllCustomBudgets() -> [CustomBudget] {
        return budget.customBudgets.sorted { budget1, budget2 in
            if budget1.isActive && !budget2.isActive {
                return true
            } else if !budget1.isActive && budget2.isActive {
                return false
            }
            return budget1.startDate > budget2.startDate
        }
    }

    // 检查预算名称是否重复
    func isCustomBudgetNameDuplicate(_ name: String, excludingId: UUID? = nil) -> Bool {
        return budget.customBudgets.contains { budget in
            budget.name == name && budget.id != excludingId
        }
    }

    // 获取自定义预算的使用情况统计
    func getCustomBudgetStats(_ customBudget: CustomBudget) -> (usedAmount: Double, percentage: Double, daysRemaining: Int) {
        let usedAmount = customBudget.getUsedAmount(from: transactions)
        let percentage = customBudget.totalLimit > 0 ? min(usedAmount / customBudget.totalLimit, 1.0) : 0

        let daysRemaining = self.daysRemaining(until: customBudget.endDate)

        return (usedAmount, percentage, daysRemaining)
    }

    // 清理过期的自定义预算
    func cleanupExpiredCustomBudgets() {
        let calendar = Calendar.current
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date()) ?? Date()

        let initialCount = budget.customBudgets.count
        budget.customBudgets.removeAll { customBudget in
            !customBudget.isActive && customBudget.endDate < threeDaysAgo
        }

        if budget.customBudgets.count != initialCount {
            saveData()
        }
    }

    // MARK: - Export Functionality
    func getTransactionsForExport(dateRange: ExportData.DateRange) -> [Transaction] {
        let calendar = Calendar.current
        let now = Date()

        switch dateRange {
        case .allTime:
            return transactions

        case .thisMonth:
            let month = calendar.component(.month, from: now)
            let year = calendar.component(.year, from: now)
            return transactions.filter { transaction in
                let tMonth = calendar.component(.month, from: transaction.date)
                let tYear = calendar.component(.year, from: transaction.date)
                return tMonth == month && tYear == year
            }

        case .lastMonth:
            // 最近30天的交易，而不是上个自然月
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return transactions.filter { $0.date >= thirtyDaysAgo }

        case .lastThreeMonths:
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            return transactions.filter { $0.date >= threeMonthsAgo }

        case .thisYear:
            let year = calendar.component(.year, from: now)
            return transactions.filter { transaction in
                let tYear = calendar.component(.year, from: transaction.date)
                return tYear == year
            }
        }
    }

    func exportDataAsCSV(transactions: [Transaction]) -> String {
        var csv = "日期,类型,金额,分类,备注\n"

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "zh_CN")

        for transaction in transactions.sorted(by: { $0.date > $1.date }) {
            let dateString = formatter.string(from: transaction.date)
            let typeString = transaction.isExpense ? "支出" : "收入"
            let amountString = String(format: "%.2f", transaction.amount)
            let categoryString = transaction.category
            let noteString = transaction.note.replacingOccurrences(of: ",", with: "，") // 替换逗号避免 CSV 格式问题

            csv += "\(dateString),\(typeString),\(amountString),\(categoryString),\(noteString)\n"
        }

        return csv
    }

    func exportDataAsText(transactions: [Transaction]) -> String {
        var text = "记账数据导出\n"
        text += "===================\n\n"

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日 HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")

        let groupedTransactions = Dictionary(grouping: transactions.sorted(by: { $0.date > $1.date })) { transaction in
            Calendar.current.dateInterval(of: .day, for: transaction.date)?.start ?? transaction.date
        }

        let sortedKeys = groupedTransactions.keys.sorted(by: >)

        for date in sortedKeys {
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "yyyy年M月d日"
            dayFormatter.locale = Locale(identifier: "zh_CN")
            text += dayFormatter.string(from: date) + "\n"
            text += "-----------\n"

            let dayTransactions = groupedTransactions[date] ?? []
            var dayTotal: Double = 0

            for transaction in dayTransactions {
                let timeString = formatter.string(from: transaction.date).components(separatedBy: " ")[1]
                let typeString = transaction.isExpense ? "支出" : "收入"
                let amountString = String(format: "%.2f", transaction.amount)
                text += "\(timeString) [\(typeString)] ¥\(amountString) - \(transaction.category)\n"
                text += "  备注: \(transaction.note)\n"

                if transaction.isExpense {
                    dayTotal += transaction.amount
                }
            }

            text += "当日支出小计: ¥\(String(format: "%.2f", dayTotal))\n\n"
        }

        let totalExpense = transactions.filter { $0.isExpense }.reduce(0) { $0 + $1.amount }
        let totalIncome = transactions.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount }

        text += "===================\n"
        text += "总统计:\n"
        text += "总支出: ¥\(String(format: "%.2f", totalExpense))\n"
        text += "总收入: ¥\(String(format: "%.2f", totalIncome))\n"
        text += "净支出: ¥\(String(format: "%.2f", totalExpense - totalIncome))\n"

        return text
    }

    // MARK: - Budget Warning System
    private func checkBudgetWarnings(for transaction: Transaction) {
        guard transaction.isExpense && appSettings.budgetWarningEnabled else { return }

        let categoryLimit = budget.categoryLimits[transaction.category] ?? 0
        guard categoryLimit > 0 else { return }

        let categoryExpense = getCategoryExpense(category: transaction.category)
        let percentage = categoryExpense / categoryLimit

        // 只在70%和90%阈值时发送通知
        if percentage >= 0.7 && percentage < 0.75 {
            NotificationManager.shared.scheduleBudgetWarning(category: transaction.category, percentage: percentage)
        } else if percentage >= 0.9 && percentage < 0.95 {
            NotificationManager.shared.scheduleBudgetWarning(category: transaction.category, percentage: percentage)
        }
    }

    // 检查自定义预算警告
    private func checkCustomBudgetWarnings(for transaction: Transaction) {
        guard transaction.isExpense && appSettings.budgetWarningEnabled else { return }

        // 检查所有活跃的自定义预算
        for customBudget in budget.customBudgets {
            guard customBudget.isActive else { continue }

            // 检查交易是否在自定义预算时间范围内
            guard transaction.date >= customBudget.startDate &&
                  transaction.date <= customBudget.endDate else { continue }

            let usedAmount = customBudget.getUsedAmount(from: transactions)
            let percentage = usedAmount / customBudget.totalLimit

            // 在70%和90%阈值时发送通知
            if percentage >= 0.7 && percentage < 0.75 {
                NotificationManager.shared.scheduleCustomBudgetWarning(
                    customBudget: customBudget,
                    percentage: percentage
                )
            } else if percentage >= 0.9 && percentage < 0.95 {
                NotificationManager.shared.scheduleCustomBudgetWarning(
                    customBudget: customBudget,
                    percentage: percentage
                )
            }
        }
    }
}

// MARK: - Voice Recognition Manager
class VoiceRecognitionManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recognizedText = ""
    @Published var errorMessage = ""
    
    private var speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    override init() {
        super.init()
        requestAuthorization()
    }
    
    func requestAuthorization() {
        // 请求语音识别权限
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("✅ 语音识别已授权")
                case .denied:
                    self.errorMessage = "语音识别权限被拒绝，请在设置中开启"
                    print("❌ 语音识别权限被拒绝")
                case .restricted:
                    self.errorMessage = "语音识别权限被限制"
                    print("❌ 语音识别权限被限制")
                case .notDetermined:
                    self.errorMessage = "语音识别权限未确定"
                    print("⚠️ 语音识别权限未确定")
                @unknown default:
                    self.errorMessage = "未知语音识别权限状态"
                    print("❌ 未知语音识别权限状态")
                }
            }
        }

        // 请求麦克风权限
        #if os(iOS)
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    print("✅ 麦克风权限已授权")
                } else {
                    self.errorMessage = "麦克风权限被拒绝，请在设置中开启"
                    print("❌ 麦克风权限被拒绝")
                }
            }
        }
        #endif
    }
    
    func startRecording() {
        print("🎤 开始录音...")

        if audioEngine.isRunning {
            stopRecording()
            return
        }

        // 检查语音识别器状态
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "语音识别不可用"
            print("❌ 语音识别器不可用")
            return
        }

        recognizedText = ""
        errorMessage = ""
        
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "音频会话设置失败"
            return
        }
        #endif
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else { return }
        
        recognitionRequest.shouldReportPartialResults = true
        
        guard let recognizer = speechRecognizer else {
            print("❌ 语音识别器为空")
            return
        }

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self.recognizedText = result.bestTranscription.formattedString
                    print("🔍 识别到文本: \(self.recognizedText)")
                }

                if let error = error {
                    self.errorMessage = "语音识别错误: \(error.localizedDescription)"
                    print("❌ 语音识别错误: \(error)")
                }

                if error != nil || result?.isFinal == true {
                    self.audioEngine.stop()
                    inputNode.removeTap(onBus: 0)
                    self.recognitionRequest = nil
                    self.recognitionTask = nil
                    self.isRecording = false
                    print("🔚 录音结束")
                }
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            errorMessage = "无法启动音频引擎"
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isRecording = false
    }
    
    // 解析多笔交易
    func parseMultipleTransactions(from text: String) -> [(amount: Double?, category: String?, note: String?, date: Date?, isExpense: Bool)] {
        print("🔄 开始解析多笔交易: \"\(text)\"")

        // 尝试找到所有真正的金额（排除日期中的数字）
        // 金额应该有明确的货币指示词或者是较大的数字
        let amountPatterns = [
            "[¥￥]\\d+(\\.\\d+)?",  // ¥符号开头：¥7、￥2500
            "\\d+(\\.\\d+)?[元块钱]",  // 带货币单位的数字
            "\\d{2,}(\\.\\d+)?(?![月日号])", // 两位以上数字且后面不跟月日号
        ]

        var amountMatches: [NSTextCheckingResult] = []

        for pattern in amountPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
                amountMatches.append(contentsOf: matches)
            }
        }

        // 去重并排序
        amountMatches = amountMatches.sorted { $0.range.location < $1.range.location }

        print("💰 发现 \(amountMatches.count) 个金额")
        for (i, match) in amountMatches.enumerated() {
            let range = Range(match.range, in: text)!
            let amountText = String(text[range])
            print("  金额\(i+1): '\(amountText)' at \(match.range.location)")
        }

        // 如果只有一个金额，检查是否有"各"字表示多笔相同金额的交易
        if amountMatches.count <= 1 {
            if text.contains("各") {
                print("📝 发现'各'字，可能是多笔相同金额交易")
                return parseEachTransaction(from: text)
            } else {
                print("📝 单笔交易，使用原始解析")
                let transaction = parseTransaction(from: text)
                return transaction.amount != nil ? [transaction] : []
            }
        }

        // 多个金额的情况，需要智能分割
        var segments: [String] = []

        // 方法1：基于关键分隔符分割
        let separators = ["，", ",", "还有", "另外", "然后", "接着", "再", " 和 "]

        // 找到最佳的分隔符
        var bestSeparator: String? = nil
        var maxSegments = 1

        for separator in separators {
            let testSegments = text.components(separatedBy: separator)
            if testSegments.count > maxSegments {
                maxSegments = testSegments.count
                bestSeparator = separator
            }
        }

        if let separator = bestSeparator {
            segments = text.components(separatedBy: separator)
            print("📊 使用分隔符 '\(separator)' 分割成 \(segments.count) 个片段: \(segments)")
        } else {
            print("📊 没有找到分隔符，使用智能分割")
            // 方法2：使用更智能的分割算法
            segments = intelligentSplit(text: text, amountMatches: amountMatches)
        }

        // 清理片段
        segments = segments.map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
                          .filter { !$0.isEmpty && $0.count > 1 }

        print("📊 清理后得到 \(segments.count) 个片段: \(segments)")

        // 解析每个片段
        var transactions: [(amount: Double?, category: String?, note: String?, date: Date?, isExpense: Bool)] = []
        for segment in segments {
            let transaction = parseTransaction(from: segment)
            // 只添加有金额的交易
            if transaction.amount != nil {
                transactions.append(transaction)
                print("✅ 解析成功: 金额=\(transaction.amount ?? 0), 分类=\(transaction.category ?? ""), 备注=\(transaction.note ?? ""), 日期=\(transaction.date?.description ?? "当前"), 类型=\(transaction.isExpense ? "支出" : "收入")")
            }
        }

        print("📈 共解析出 \(transactions.count) 笔交易")
        return transactions
    }

    // 按金额位置智能分割文本，每个金额对应一个独立片段
    private func splitByAmountPositions(text: String, amountMatches: [NSTextCheckingResult]) -> [String] {
        if amountMatches.count <= 1 {
            return [text]
        }

        var segments: [String] = []
        print("🔧 开始按\(amountMatches.count)个金额位置分割文本")

        // 为每个金额找到合理的上下文范围
        for (index, match) in amountMatches.enumerated() {
            let currentStart = match.range.location
            let currentEnd = match.range.location + match.range.length

            var segmentStart: Int
            var segmentEnd: Int

            if index == 0 {
                // 第一个金额：从开头开始
                segmentStart = 0
                // 结束点：到第二个金额开始前的合理位置
                if index + 1 < amountMatches.count {
                    let nextAmountStart = amountMatches[index + 1].range.location
                    // 寻找两个金额之间的分界点
                    segmentEnd = findBoundaryBetweenAmounts(text: text,
                                                          firstAmountEnd: currentEnd,
                                                          secondAmountStart: nextAmountStart)
                } else {
                    segmentEnd = text.count
                }
            } else {
                // 后续金额：从前一个分界点开始
                let prevAmountEnd = amountMatches[index - 1].range.location + amountMatches[index - 1].range.length
                segmentStart = findBoundaryBetweenAmounts(text: text,
                                                        firstAmountEnd: prevAmountEnd,
                                                        secondAmountStart: currentStart)

                // 结束点：如果有下一个金额，找到分界点；否则到文本末尾
                if index + 1 < amountMatches.count {
                    let nextAmountStart = amountMatches[index + 1].range.location
                    segmentEnd = findBoundaryBetweenAmounts(text: text,
                                                          firstAmountEnd: currentEnd,
                                                          secondAmountStart: nextAmountStart)
                } else {
                    segmentEnd = text.count
                }
            }

            // 确保边界合理
            segmentStart = max(0, segmentStart)
            segmentEnd = min(text.count, segmentEnd)

            if segmentStart < segmentEnd {
                let range = NSRange(location: segmentStart, length: segmentEnd - segmentStart)
                if let swiftRange = Range(range, in: text) {
                    let segment = String(text[swiftRange]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    // 检查片段是否包含金额（数字）
                    let containsAmount = segment.range(of: "\\d+(\\.\\d+)?", options: .regularExpression) != nil
                    if !segment.isEmpty && containsAmount {
                        segments.append(segment)
                        print("🔧 片段 \(index + 1): \"\(segment)\"")
                    }
                }
            }
        }

        print("🔧 通过金额位置分割得到 \(segments.count) 个有效片段")
        return segments
    }

    // 处理"各"字表示的多笔相同金额交易
    func parseEachTransaction(from text: String) -> [(amount: Double?, category: String?, note: String?, date: Date?, isExpense: Bool)] {
        print("🔄 解析'各'字交易: \"\(text)\"")

        // 提取金额
        let amountPattern = "\\d+(\\.\\d+)?"
        var amount: Double?
        if let range = text.range(of: amountPattern, options: .regularExpression) {
            amount = Double(text[range])
            print("💰 提取到金额: \(amount ?? 0)")
        }

        guard let validAmount = amount else {
            print("❌ 未找到有效金额")
            return []
        }

        // 查找"各"字之前的部分，寻找多个时间或活动
        let eachPosition = text.range(of: "各")
        let beforeEach: String
        if let eachRange = eachPosition {
            beforeEach = String(text[..<eachRange.lowerBound])
        } else {
            beforeEach = text
        }

        print("📝 '各'字前的内容: \"\(beforeEach)\"")

        // 寻找具体的时间标记（排除全局时间上下文）
        var timeMarkers: [String] = []
        let specificTimeKeywords = ["早饭", "早上", "中午", "午饭", "下午", "晚上", "晚饭"]  // 排除昨天、今天、明天
        let globalTimeKeywords = ["昨天", "今天", "明天"]  // 全局时间上下文

        for keyword in specificTimeKeywords {
            if beforeEach.contains(keyword) {
                timeMarkers.append(keyword)
            }
        }

        // 如果没有找到具体时间标记，但有全局时间关键词，只使用第一个
        if timeMarkers.isEmpty {
            for keyword in globalTimeKeywords {
                if beforeEach.contains(keyword) {
                    timeMarkers.append(keyword)
                    break  // 只取第一个全局时间
                }
            }
        }

        // 如果找到多个时间标记，为每个创建一笔交易
        if timeMarkers.count >= 2 {
            print("🕐 找到多个时间标记: \(timeMarkers)")
            var transactions: [(amount: Double?, category: String?, note: String?, date: Date?, isExpense: Bool)] = []

            for timeMarker in timeMarkers {
                // 构建包含完整上下文的虚拟片段进行解析
                // 从原始文本中提取活动描述（如"吃饭"）
                var activity = "吃饭"  // 默认活动
                let activityKeywords = ["吃饭", "用餐", "就餐", "早餐", "午餐", "晚餐", "买菜", "购物", "打车", "地铁", "公交"]

                for keyword in activityKeywords {
                    if beforeEach.contains(keyword) {
                        activity = keyword
                        break
                    }
                }

                // 构建完整的备注信息
                let fullNote = "\(timeMarker)\(activity)"
                let virtualSegment = "\(fullNote)\(validAmount)元"

                let transaction = parseTransaction(from: virtualSegment)
                if transaction.amount != nil || validAmount > 0 {
                    // 使用正确的备注信息
                    let finalTransaction = (
                        amount: validAmount,
                        category: transaction.category ?? "餐饮", // 默认分类
                        note: fullNote,  // 使用完整的备注
                        date: transaction.date,
                        isExpense: transaction.isExpense
                    )
                    transactions.append(finalTransaction)
                    print("✅ 创建交易: \(fullNote) - \(validAmount)元")
                }
            }

            return transactions
        } else {
            // 如果没有找到多个时间标记，检查是否有"和"或"跟"连接的活动
            let connectors = ["和", "跟"]
            for connector in connectors {
                if beforeEach.contains(connector) {
                    let parts = beforeEach.components(separatedBy: connector)
                    if parts.count >= 2 {
                        print("🔗 找到'\(connector)'连接的多个部分: \(parts)")
                        var transactions: [(amount: Double?, category: String?, note: String?, date: Date?, isExpense: Bool)] = []

                        for part in parts {
                            let trimmedPart = part.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                            if !trimmedPart.isEmpty {
                                // 如果部分内容没有活动描述，添加默认的"吃饭"
                                let hasActivity = trimmedPart.contains("饭") || trimmedPart.contains("餐") ||
                                                trimmedPart.contains("吃") || trimmedPart.contains("喝") ||
                                                trimmedPart.contains("买") || trimmedPart.contains("购")
                                let contextText = hasActivity ? trimmedPart : "\(trimmedPart)吃饭"

                                let virtualSegment = "\(contextText)\(validAmount)"
                                let transaction = parseTransaction(from: virtualSegment)
                                let finalTransaction = (
                                    amount: validAmount,
                                    category: transaction.category,
                                    note: transaction.note,
                                    date: transaction.date,
                                    isExpense: transaction.isExpense
                                )
                                transactions.append(finalTransaction)
                                print("✅ 创建交易: \(contextText) - \(validAmount)元, 日期: \(transaction.date?.description ?? "当前")")
                            }
                        }

                        return transactions
                    }
                }
            }
        }

        // 如果无法分割，返回单笔交易
        print("📝 无法分割，返回单笔交易")
        let transaction = parseTransaction(from: text)
        return transaction.amount != nil ? [transaction] : []
    }

    // 在两个金额之间找到合适的分界点
    private func findBoundaryBetweenAmounts(text: String, firstAmountEnd: Int, secondAmountStart: Int) -> Int {
        let searchStart = firstAmountEnd
        let searchEnd = secondAmountStart

        if searchStart >= searchEnd {
            return searchStart
        }

        // 在两个金额之间寻找语义分界点
        let searchRange = searchStart..<min(searchEnd, text.count)

        // 寻找时间词汇和其他可能的分界点
        let timeMarkers = ["早上", "中午", "下午", "晚上", "昨天", "今天", "明天"]
        let boundaryMarkers = ["上吃", "上喝", "上买", "上花", "块上", "元上"] // 处理语音识别错误

        for pos in searchRange {
            let remainingText = String(text.suffix(from: text.index(text.startIndex, offsetBy: pos)))

            // 检查时间标记
            for marker in timeMarkers {
                if remainingText.hasPrefix(marker) {
                    print("🎯 在位置\(pos)找到时间标记'\(marker)'作为分界点")
                    return pos
                }
            }

            // 检查边界标记（处理语音识别错误）
            for marker in boundaryMarkers {
                if remainingText.hasPrefix(marker) {
                    print("🎯 在位置\(pos)找到边界标记'\(marker)'作为分界点")
                    return pos
                }
            }
        }

        // 如果没找到时间标记，返回中点
        let midpoint = (searchStart + searchEnd) / 2
        print("🎯 使用中点位置\(midpoint)作为分界点")
        return midpoint
    }

    // 新的智能分割算法，专门处理语音识别的特殊情况
    private func intelligentSplit(text: String, amountMatches: [NSTextCheckingResult]) -> [String] {
        print("🧠 使用智能分割算法")

        if amountMatches.count <= 1 {
            return [text]
        }

        var segments: [String] = []

        // 对于2个金额的特殊处理
        if amountMatches.count == 2 {
            let firstAmountPos = amountMatches[0].range.location
            let secondAmountPos = amountMatches[1].range.location

            // 查找可能的分割点
            let midPoint = (firstAmountPos + amountMatches[0].range.length + secondAmountPos) / 2

            // 在中点附近寻找最佳分割位置
            var bestSplitPos = midPoint
            let searchStart = firstAmountPos + amountMatches[0].range.length
            let searchEnd = secondAmountPos

            // 寻找字符级别的分割点 - 时间关键词优先
            let timeKeywords = ["晚上", "下午", "早上", "中午", "上午"]
            let otherKeywords = ["上吃", "上买", "上花", "块上", "元上"]

            var foundTimeKeyword = false

            // 优先寻找时间关键词
            for pos in searchStart..<min(searchEnd, text.count) {
                let index = text.index(text.startIndex, offsetBy: pos)
                let remainingText = String(text[index...])

                for keyword in timeKeywords {
                    if remainingText.hasPrefix(keyword) {
                        bestSplitPos = pos
                        foundTimeKeyword = true
                        print("🎯 在位置\(pos)找到时间关键词'\(keyword)'")
                        break
                    }
                }

                if foundTimeKeyword {
                    break
                }
            }

            // 如果没找到时间关键词，再寻找其他关键词
            if !foundTimeKeyword {
                for pos in searchStart..<min(searchEnd, text.count) {
                    let index = text.index(text.startIndex, offsetBy: pos)
                    let remainingText = String(text[index...])

                    for keyword in otherKeywords {
                        if remainingText.hasPrefix(keyword) {
                            bestSplitPos = pos
                            print("🎯 在位置\(pos)找到其他关键词'\(keyword)'")
                            break
                        }
                    }
                }
            }

            // 如果没找到关键词，使用简单的规则
            if bestSplitPos == midPoint {
                // 查找"块"或"元"后面的位置
                let firstAmountEnd = firstAmountPos + amountMatches[0].range.length
                for pos in firstAmountEnd..<min(secondAmountPos, text.count) {
                    let index = text.index(text.startIndex, offsetBy: pos)
                    let char = text[index]
                    if char == "块" || char == "元" || char == "上" {
                        bestSplitPos = pos + 1
                        break
                    }
                }
            }

            // 分割文本
            if bestSplitPos > 0 && bestSplitPos < text.count {
                let firstSegment = String(text.prefix(bestSplitPos))
                let secondSegment = String(text.suffix(from: text.index(text.startIndex, offsetBy: bestSplitPos)))

                segments = [firstSegment, secondSegment]
                print("🔪 分割点位置: \(bestSplitPos)")
                print("  第一段: '\(firstSegment)'")
                print("  第二段: '\(secondSegment)'")
            }
        }

        // 如果分割失败，回退到原来的方法
        if segments.isEmpty {
            segments = splitByAmountPositions(text: text, amountMatches: amountMatches)
        }

        return segments
    }

    // 解析识别的文本（单笔交易）
    func parseTransaction(from text: String) -> (amount: Double?, category: String?, note: String?, date: Date?, isExpense: Bool) {
        print("🔍 解析单笔交易: \"\(text)\"")

        var amount: Double?
        var category: String?

        // 提取金额（智能避开日期中的数字）
        let amountPatterns = [
            "[¥￥]\\d+(\\.\\d+)?",  // ¥符号开头：¥7、￥2500
            "\\d+(\\.\\d+)?[元块钱]",  // 带货币单位：2500元
            "\\d{2,}(\\.\\d+)?(?![月日号])", // 两位以上数字且后面不是月日号：2500（但不匹配10日中的10）
        ]

        for pattern in amountPatterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                let amountText = String(text[range])
                // 清理货币单位，只保留数字部分
                let cleanAmountText = amountText.replacingOccurrences(of: "[¥￥元块钱]", with: "", options: .regularExpression)
                amount = Double(cleanAmountText)
                print("💰 智能提取金额: '\(amountText)' -> \(amount ?? 0)")
                break
            }
        }

        if amount == nil {
            print("⚠️ 未能提取到有效金额")
        }

        // 智能清理备注，保留关键信息
        var cleanNote = text

        // 去掉金额数字但保留上下文（使用通用的数字模式）
        let amountRegex = try? NSRegularExpression(pattern: "[¥￥]?\\d+(\\.\\d+)?[元块钱]?", options: [])
        if let regex = amountRegex {
            cleanNote = regex.stringByReplacingMatches(
                in: cleanNote,
                options: [],
                range: NSRange(location: 0, length: cleanNote.count),
                withTemplate: ""
            )
        }

        // 清理日期格式残留（去掉日期相关的文字）
        let dateCleanupPatterns = [
            "\\d{1,2}月\\d{1,2}[号日]",  // 9月10号、9月10日
            "\\d{1,2}月\\d{1,2}",       // 9月10
            "\\d{1,2}/\\d{1,2}",        // 9/10
            "\\d{1,2}-\\d{1,2}",        // 9-10
            "月日\\*+",                  // 月日**等残留字符
            "月日",                      // 单独的"月日"
            "号",                        // 单独的"号"
            "昨天", "今天", "明天", "前天", "后天", "大前天"  // 相对日期
        ]

        for pattern in dateCleanupPatterns {
            if let dateRegex = try? NSRegularExpression(pattern: pattern, options: []) {
                cleanNote = dateRegex.stringByReplacingMatches(
                    in: cleanNote,
                    options: [],
                    range: NSRange(location: 0, length: cleanNote.count),
                    withTemplate: ""
                )
            }
        }

        // 提取关键时间和场景信息
        let timeKeywords = ["早上", "中午", "下午", "晚上", "昨天", "今天", "明天"]
        let actionKeywords = ["吃饭", "喝", "买", "购买", "打车", "充值", "看电影", "购物"]
        let placeKeywords = ["超市", "餐厅", "商场", "地铁", "公交", "医院", "学校"]

        var keyInfo: [String] = []

        // 只保留当前文本片段中实际存在的关键词，避免重复
        let currentText = text  // 使用原始输入文本而不是cleanNote

        // 保留时间信息（只取第一个匹配的时间关键词）
        var timeFound = false
        for keyword in timeKeywords {
            if currentText.contains(keyword) && !timeFound {
                keyInfo.append(keyword)
                timeFound = true
                break  // 只取一个时间关键词
            }
        }

        // 保留动作信息（只取第一个匹配的动作关键词）
        var actionFound = false
        for keyword in actionKeywords {
            if currentText.contains(keyword) && !actionFound {
                keyInfo.append(keyword)
                actionFound = true
                break  // 只取一个动作关键词
            }
        }

        // 保留地点信息（只取第一个匹配的地点关键词）
        var placeFound = false
        for keyword in placeKeywords {
            if currentText.contains(keyword) && !placeFound {
                keyInfo.append(keyword)
                placeFound = true
                break  // 只取一个地点关键词
            }
        }

        // 如果有关键信息，生成简洁描述
        if !keyInfo.isEmpty {
            cleanNote = keyInfo.joined(separator: " ")
        } else {
            // 清理无意义的修饰词和残留字符
            let unwantedWords = ["块", "元", "¥", "￥", "花了", "支付", "了", "的", "。", "，", ",", "*", "**", "***", "月日"]
            for word in unwantedWords {
                cleanNote = cleanNote.replacingOccurrences(of: word, with: " ")
            }

            // 清理空格和无效字符
            cleanNote = cleanNote
                .components(separatedBy: CharacterSet.whitespacesAndNewlines)
                .filter { !$0.isEmpty && $0.count > 0 && !$0.contains("*") }
                .joined(separator: " ")
                .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }

        // 如果清理后为空或太短，生成更有意义的备注
        var finalNote = cleanNote
        if cleanNote.count < 2 {
            // 尝试从原文本中提取有意义的词汇
            let meaningfulWords = ["吃饭", "午餐", "晚餐", "早餐", "喝茶", "咖啡", "奶茶", "购物", "打车", "地铁", "公交"]
            var foundWord = false
            for word in meaningfulWords {
                if text.contains(word) {
                    finalNote = word
                    foundWord = true
                    break
                }
            }
            
            // 如果没找到有意义的词汇，根据分类生成默认备注
            if !foundWord {
                switch category {
                case "餐饮":
                    finalNote = "用餐"
                case "交通":
                    finalNote = "出行"
                case "购物":
                    finalNote = "购买商品"
                case "娱乐":
                    finalNote = "娱乐消费"
                case "生活":
                    finalNote = "生活用品"
                case "医疗":
                    finalNote = "医疗费用"
                case "教育":
                    finalNote = "学习费用"
                case "租房水电":
                    finalNote = "房租水电"
                default:
                    finalNote = "日常消费"
                }
            }
        }
        
        let note = finalNote
        print("📝 生成备注: \"\(note)\"")
        
        // 智能分类识别 - 按优先级匹配关键词
        // 具体关键词优先级高于通用关键词
        let priorityCategories = [
            ("餐饮", ["奶茶", "咖啡", "茶", "饮料", "吃饭", "午餐", "晚餐", "早餐", "饭", "菜", "餐厅", "外卖", "点餐", "聚餐", "宵夜", "零食", "小吃", "吃了", "吃", "喝了", "喝", "买吃的", "食物", "美食", "用餐", "就餐", "进餐"]),
            ("交通", [
                // 传统交通工具
                "地铁", "公交", "打车", "滴滴", "出租车", "火车", "高铁", "飞机",
                // 共享出行服务
                "共享单车", "摩拜", "哈啰", "青桔", "小蓝车", "ofo", "单车包月", "单车充值",
                "共享汽车", "GoFun", "EVCARD", "盼达", "car2go",
                // 交通卡充值场景  
                "充卡", "地铁充卡", "公交卡充值", "交通卡", "一卡通", "羊城通", "深圳通",
                "交通充值", "地铁充值", "公交充值",
                // 交通套餐服务
                "交通包月", "地铁月卡", "公交月卡", "交通季卡", "交通年卡",
                // 网约车平台
                "美团打车", "曹操出行", "神州专车", "首汽约车", "T3出行",
                // 票务相关
                "机票", "车票", "船票", "地铁票", "公交票", "高铁票", "动车票",
                // 汽车相关
                "加油", "油费", "停车费", "过路费", "高速费", "ETC", "洗车费",
                "汽车保养", "车辆维修", "汽车年检", "车险",
                // 出行费用
                "打车费", "车费", "路费", "交通费", "出行费", "通勤费", "班车费"
            ]),
            ("娱乐", ["电影", "游戏", "KTV", "唱歌", "旅游", "景点", "门票", "酒吧", "娱乐", "看电影", "演出", "音乐会"]),
            ("租房水电", ["房租", "租房", "租房子", "付房租", "交房租", "房租交了", "交了房租", "水电费", "电费", "水费", "燃气费", "取暖费", "物业费", "管理费", "房子租金", "租金"]),
            ("生活", ["话费", "网费", "生活用品", "洗衣", "理发", "美容", "按摩"]),
            ("医疗", ["医院", "看病", "药", "体检", "医疗", "挂号", "治疗", "医生"]),
            ("教育", ["学费", "培训", "课程", "书籍", "学习", "教育", "辅导", "考试"]),
            ("购物", [
                // 电商平台
                "淘宝", "京东", "拼多多", "抖音", "天猫", "苏宁", "唯品会", "小红书", "得物", "闲鱼",
                "美团", "饿了么", "盒马", "叮咚买菜", "多点", "永辉生活", "朴朴",
                // 国际电商
                "亚马逊", "ebay", "海淘", "考拉", "洋码头", "iHerb",
                // 垂直电商
                "当当", "网易严选", "小米有品", "华为商城", "Apple Store",
                // 线下购物
                "商场", "超市", "便利店", "商店", "市场", "店铺", "专卖店", "免税店",
                "宜家", "无印良品", "优衣库", "屈臣氏", "万达", "银泰", "大悦城",
                // 商品类别
                "衣服", "鞋子", "包包", "化妆品", "护肤品", "日用品", "电器", "手机", "电脑",
                "数码", "家具", "家电", "零食", "玩具", "文具", "配饰", "珠宝", "手表",
                // 购物行为
                "购物", "网购", "海淘", "代购", "团购", "秒杀", "抢购", "剁手"
            ]),
            ("其他", ["其他", "杂费", "礼物", "红包", "捐赠"])
        ]
        
        // 智能匹配预设分类
        func intelligentCategoryMatch() -> String? {
            // 排除误分类的场景
            let exclusions: [String: [String]] = [
                "交通": ["买单车", "买自行车", "购买单车", "健身卡", "游泳卡", "会员卡"], // 避免购买单车被误分类为交通
                "餐饮": ["买茶具", "买咖啡机", "茶叶", "咖啡豆"] // 避免购买饮品工具被误分类为餐饮
            ]

            // 按优先级顺序匹配预设分类
            for (categoryName, keywords) in priorityCategories {
                // 检查是否应该排除
                if let excludeKeywords = exclusions[categoryName] {
                    var shouldExclude = false
                    for excludeKeyword in excludeKeywords {
                        if text.contains(excludeKeyword) {
                            shouldExclude = true
                            break
                        }
                    }
                    if shouldExclude {
                        continue // 跳过这个分类
                    }
                }

                // 正常匹配逻辑
                for keyword in keywords {
                    if text.contains(keyword) {
                        print("📍 匹配到预设分类关键词: \"\(keyword)\" -> \(categoryName)")
                        return categoryName
                    }
                }
            }
            return nil
        }

        // 匹配用户自定义分类
        func matchCustomCategories() -> String? {
            // 获取所有用户自定义分类（排除默认分类）
            let defaultCategories = ["餐饮", "交通", "购物", "娱乐", "租房水电", "生活", "医疗", "教育", "其他"]
            let customCategories = DataManager.shared.categories.filter { !defaultCategories.contains($0) }

            print("📋 当前自定义分类: \(customCategories)")  // 调试日志

            // 按分类名长度排序，优先匹配较长的分类名（更具体）
            let sortedCategories = customCategories.sorted { $0.count > $1.count }

            // 先进行精确匹配
            for category in sortedCategories {
                print("🔎 尝试匹配分类: \"\(category)\"")  // 调试日志

                let lowercasedText = text.lowercased()
                let lowercasedCategory = category.lowercased()

                // 1. 完全匹配分类名称（忽略大小写）
                if lowercasedText.contains(lowercasedCategory) {
                    print("✨ 完全匹配成功: \(category)")
                    return category
                }

                // 2. 去掉空格后匹配
                let compactCategory = lowercasedCategory.replacingOccurrences(of: " ", with: "")
                if lowercasedText.contains(compactCategory) && compactCategory.count >= 2 {
                    print("✨ 紧凑匹配成功: \(category)")
                    return category
                }
            }

            // 再进行分词匹配
            for category in sortedCategories {
                // 3. 分割分类名称，匹配各个部分
                let categoryWords = category.components(separatedBy: Foundation.CharacterSet(charactersIn: " -_")).filter { $0.count >= 2 }

                // 优先匹配所有关键词都存在的情况
                var allWordsMatch = categoryWords.count > 0
                for word in categoryWords {
                    if !text.lowercased().contains(word.lowercased()) {
                        allWordsMatch = false
                        break
                    }
                }
                if allWordsMatch && categoryWords.count > 0 {
                    print("✨ 全部关键词匹配成功: \(category)")
                    return category
                }
            }

            // 最后进行单词匹配（但需要更严格的条件）
            for category in sortedCategories {
                // 4. 清理文本后匹配
                let cleanedText = text
                    .replacingOccurrences(of: "买", with: "")
                    .replacingOccurrences(of: "购买", with: "")
                    .replacingOccurrences(of: "花钱", with: "")
                    .replacingOccurrences(of: "支付", with: "")
                    .lowercased()

                // 如果分类名称在清理后的文本中完整出现
                if cleanedText.contains(category.lowercased()) {
                    print("✨ 清理后完整匹配成功: \(category)")
                    return category
                }

                // 5. 特殊情况：对于包含特定关键词的分类（如"ai"），即使有"买"也优先匹配
                let importantKeywords = ["ai", "工具", "学习", "课程", "培训"]
                for keyword in importantKeywords {
                    if category.lowercased().contains(keyword) && text.lowercased().contains(keyword) {
                        print("✨ 重要关键词匹配成功: \(keyword) -> \(category)")
                        return category
                    }
                }
            }

            return nil
        }

        // 优化匹配策略：优先匹配用户自定义分类（更具体），再匹配预设分类（更通用）
        print("🔍 语音识别文本: \"\(text)\"")  // 调试日志

        // 第一优先级：匹配用户自定义分类
        category = matchCustomCategories()
        if category != nil {
            print("✅ 匹配到自定义分类: \(category!)")
        }

        // 第二优先级：匹配预设分类
        if category == nil {
            category = intelligentCategoryMatch()
            if category != nil {
                print("✅ 匹配到预设分类: \(category!)")
            }
        }

        // 如果仍没有匹配到分类，默认使用"其他"
        if category == nil {
            category = "其他"
            print("⚠️ 未匹配到任何分类，使用默认分类: 其他")
        }

        // 判断是收入还是支出并智能分类
        var isExpense = true // 默认为支出

        // 扩展的收入关键词库，按分类组织
        let incomeKeywordsByCategory = [
            "工资薪酬": [
                "工资", "薪水", "薪酬", "月薪", "周薪", "日薪", "底薪", "基本工资", "加班费", "绩效工资",
                "年终奖", "季度奖", "月度奖", "奖金", "花红", "分红", "提成", "佣金", "回扣"
            ],
            "投资收益": [
                "投资收益", "股票", "股息", "分红", "利息", "理财收益", "基金收益", "债券利息",
                "定期利息", "活期利息", "红利", "收益", "盈利", "回报", "投资回报"
            ],
            "副业兼职": [
                "兼职", "副业", "外快", "接单", "代购", "微商", "直播", "带货", "自媒体",
                "写作", "翻译", "设计", "咨询", "培训", "家教", "代驾", "跑腿"
            ],
            "奖金补贴": [
                "奖学金", "助学金", "生活补贴", "交通补贴", "餐饮补贴", "通讯补贴", "住房补贴",
                "津贴", "补助", "补偿金", "赔偿金", "误工费", "营养费", "慰问金"
            ],
            "退款返现": [
                "退款", "退钱", "退费", "退回", "退了", "返钱", "返款", "返了", "返现", "回款",
                "报销", "还款", "退货", "退单", "取消订单", "撤销", "返还", "退还"
            ],
            "转账收入": [
                "转账收入", "收钱", "收到", "转入", "到账", "入账", "汇入", "汇款",
                "红包", "礼金", "压岁钱", "生日红包", "结婚红包", "满月红包"
            ],
            "其他收入": [
                "卖出", "卖掉", "售出", "出售", "变卖", "转让", "出租", "租金",
                "二手", "闲置", "收废品", "捡到", "中奖", "奖品", "礼品", "意外收入"
            ]
        ]

        // 注意：收入关键词已通过incomeKeywordsByCategory提供

        // 检查是否匹配收入关键词，同时进行智能收入分类
        var incomeCategory: String? = nil
        for (categoryName, keywords) in incomeKeywordsByCategory {
            for keyword in keywords {
                if text.contains(keyword) {
                    isExpense = false
                    incomeCategory = categoryName
                    print("💰 识别到收入关键词'\(keyword)', 设置为收入, 分类: \(categoryName)")
                    break
                }
            }
            if incomeCategory != nil { break }
        }

        // 如果识别为收入，更新分类为收入分类
        if !isExpense && incomeCategory != nil {
            category = incomeCategory
            print("📊 更新分类为收入分类: \(category!)")
        }

        // 解析日期信息
        var transactionDate: Date? = nil
        let dateKeywords = [
            "昨天": -1,
            "前天": -2,
            "大前天": -3,
            "今天": 0,
            "明天": 1,
            "后天": 2
        ]

        // 首先尝试解析具体日期（支持多种格式）
        print("🔍 开始解析日期，原始文本: \"\(text)\"")

        // 支持多种日期格式：X月X号、X月X日、X月X、以及常见语音识别变体
        let datePatterns = [
            #"(\d{1,2})月(\d{1,2})[号日]"#,  // 9月10号、9月10日
            #"(\d{1,2})月(\d{1,2})"#,        // 9月10
            #"(\d{1,2})/(\d{1,2})"#,         // 9/10
            #"(\d{1,2})-(\d{1,2})"#          // 9-10
        ]

        for pattern in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                if let match = matches.first {
                    let monthRange = Range(match.range(at: 1), in: text)!
                    let dayRange = Range(match.range(at: 2), in: text)!
                    let month = Int(String(text[monthRange]))!
                    let day = Int(String(text[dayRange]))!

                    print("🎯 正则匹配成功: \(month)月\(day)号")

                    let calendar = Calendar.current
                    let now = Date()
                    let currentYear = calendar.component(.year, from: now)
                    let currentMonth = calendar.component(.month, from: now)

                    var targetYear = currentYear
                    // 智能年份判断：
                    // 1. 如果月份大于当前月份，使用当前年
                    // 2. 如果月份小于当前月份，假设是下一年
                    // 3. 如果是同月，允许记录过去和未来的日期（不超过15天的差距）
                    if month < currentMonth {
                        targetYear += 1
                    } else if month == currentMonth {
                        let currentDay = calendar.component(.day, from: now)
                        // 如果是同月但日期相差超过15天，可能是跨年情况
                        if day < currentDay - 15 {
                            targetYear += 1
                        }
                        // 允许记录本月的任何日期（包括过去的日期）
                    }

                    var dateComponents = DateComponents()
                    dateComponents.year = targetYear
                    dateComponents.month = month
                    dateComponents.day = day
                    dateComponents.hour = calendar.component(.hour, from: now)
                    dateComponents.minute = calendar.component(.minute, from: now)

                    if let specificDate = calendar.date(from: dateComponents) {
                        transactionDate = specificDate
                        print("✅ 成功解析具体日期: \(month)月\(day)号 -> \(specificDate)")
                        break
                    }
                }
            }
        }

        if transactionDate != nil {
            print("📅 使用解析到的具体日期")
        } else {
            print("⚠️ 未能匹配到具体日期格式")
        }

        // 如果没有识别到具体日期，尝试相对日期
        if transactionDate == nil {
            let sortedKeywords = dateKeywords.sorted { $0.key.count > $1.key.count }

            for (keyword, dayOffset) in sortedKeywords {
                if text.contains(keyword) {
                    let calendar = Calendar.current
                    transactionDate = calendar.date(byAdding: .day, value: dayOffset, to: Date())
                    print("📅 识别到日期关键词'\(keyword)', 设置交易日期为: \(transactionDate?.description ?? "未知")")
                    break
                }
            }
        }

        // 如果没有识别到特定日期，使用当前日期
        if transactionDate == nil {
            transactionDate = Date()
            print("📅 未识别到特定日期，使用当前日期")
        }

        print("✅ 单笔交易解析完成: 金额=\(amount ?? 0), 分类=\(category ?? ""), 备注=\(note), 日期=\(transactionDate?.description ?? "未知"), 类型=\(isExpense ? "支出" : "收入")")
        return (amount, category, note, transactionDate, isExpense)
    }
}

// MARK: - Notification Manager
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    private init() {}

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func scheduleReminders(morningTime: String, afternoonTime: String, eveningTime: String) {
        // 清除现有的提醒
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "morning_reminder", "afternoon_reminder", "evening_reminder"
        ])

        // 上午提醒
        if let morningDate = timeStringToDate(morningTime) {
            scheduleNotification(
                identifier: "morning_reminder",
                title: "🌅 记账提醒",
                body: "早上好，记录一下吃早餐的花费吧~",
                date: morningDate,
                repeats: true
            )
        }

        // 下午提醒
        if let afternoonDate = timeStringToDate(afternoonTime) {
            scheduleNotification(
                identifier: "afternoon_reminder",
                title: "☕ 记账提醒",
                body: "下午茶时间，有什么小消费吗？",
                date: afternoonDate,
                repeats: true
            )
        }

        // 晚上提醒
        if let eveningDate = timeStringToDate(eveningTime) {
            scheduleNotification(
                identifier: "evening_reminder",
                title: "🌙 记账提醒",
                body: "今天过得怎么样，记录一下吧！",
                date: eveningDate,
                repeats: true
            )
        }
    }

    func scheduleBudgetWarning(category: String, percentage: Double) {
        let identifier = "budget_warning_\(category)"

        // 清除旧的警告
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])

        let title: String
        let body: String

        if percentage >= 0.9 {
            title = "⚠️ 预算超支警告"
            body = "\(category)分类已超出预算，记得理性消费哦~"
        } else {
            title = "🚨 预算提醒"
            body = "\(category)分类已使用\(Int(percentage * 100))%预算，注意合理消费哦 🌈"
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // 5秒后发送
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    // 自定义预算警告通知
    func scheduleCustomBudgetWarning(customBudget: CustomBudget, percentage: Double) {
        let identifier = "custom_budget_warning_\(customBudget.id.uuidString)"

        // 清除旧的警告
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])

        let title: String
        let body: String

        if percentage >= 0.9 {
            title = "⚠️ 自定义预算超支警告"
            body = "「\(customBudget.name)」预算已超出90%，当前使用\(Int(percentage * 100))%"
        } else {
            title = "🚨 自定义预算提醒"
            body = "「\(customBudget.name)」预算已使用\(Int(percentage * 100))%，注意合理消费哦 🌈"
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "CUSTOM_BUDGET_WARNING"

        // 添加操作按钮
        let viewAction = UNNotificationAction(
            identifier: "VIEW_BUDGET",
            title: "查看预算",
            options: []
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "知道了",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: "CUSTOM_BUDGET_WARNING",
            actions: [viewAction, dismissAction],
            intentIdentifiers: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])

        // 5秒后发送
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    // 自定义预算到期提醒
    func scheduleCustomBudgetExpiryReminder(customBudget: CustomBudget) {
        let calendar = Calendar.current
        let oneDayBefore = calendar.date(byAdding: .day, value: -1, to: customBudget.endDate)

        guard let reminderDate = oneDayBefore, reminderDate > Date() else { return }

        let identifier = "custom_budget_expiry_\(customBudget.id.uuidString)"

        // 清除旧的提醒
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "⏰ 自定义预算即将到期"
        content.body = "「\(customBudget.name)」将在明天结束，请及时查看使用情况"
        content.sound = .default

        let triggerDate = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    // 取消自定义预算相关的所有通知
    func cancelCustomBudgetNotifications(budgetId: UUID) {
        let identifiers = [
            "custom_budget_warning_\(budgetId.uuidString)",
            "custom_budget_expiry_\(budgetId.uuidString)"
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func scheduleWeeklyReport(totalExpense: Double) {
        let identifier = "weekly_report"

        let content = UNMutableNotificationContent()
        content.title = "📊 本周支出报告"
        content.body = "本周总支出 ¥\(String(format: "%.0f", totalExpense))，继续加油啊！"
        content.sound = .default

        // 每周日晚上8点
        var dateComponents = DateComponents()
        dateComponents.weekday = 1 // 周日
        dateComponents.hour = 20
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleNotification(identifier: String, title: String, body: String, date: Date, repeats: Bool) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func timeStringToDate(_ timeString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.date(from: timeString)
    }

    func checkNotificationStatus(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @State private var currentPage = 0

    var onboardingPages: [OnboardingPage] {
        return [
            OnboardingPage(
                title: "欢迎使用语音记账本",
                subtitle: "轻松记录每一笔支出",
                description: "只需说话，就能快速记录您的消费，让记账变得简单有趣",
                iconName: "mic.circle.fill",
                iconColor: .blue
            ),
            OnboardingPage(
                title: "智能语音识别",
                subtitle: "支持多种表达方式",
                description: "支持「中午吃饭10块」或「中午和晚上吃饭各15元」等自然语言表达",
                iconName: "waveform.circle.fill",
                iconColor: .green
            ),
            OnboardingPage(
                title: "游戏化体验",
                subtitle: "让记账充满乐趣",
                description: "解锁成就、维持连击，通过游戏化元素培养良好的记账习惯",
                iconName: "trophy.circle.fill",
                iconColor: .orange
            )
        ]
    }

    var body: some View {
        VStack {
            // 页面指示器
            HStack {
                Spacer()
                HStack(spacing: 8) {
                    ForEach(0..<onboardingPages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                Spacer()
            }
            .padding(.top, 50)

            // 页面内容
            TabView(selection: $currentPage) {
                ForEach(0..<onboardingPages.count, id: \.self) { index in
                    OnboardingPageView(page: onboardingPages[index])
                        .tag(index)
                }
            }
            #if os(iOS)
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            #endif

            // 底部按钮
            VStack(spacing: 16) {
                if currentPage == onboardingPages.count - 1 {
                    // 最后一页显示开始使用按钮
                    Button(action: {
                        showOnboarding = false
                    }) {
                        Text("开始使用")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                } else {
                    // 其他页面显示下一步和跳过
                    HStack {
                        Button("跳过") {
                            showOnboarding = false
                        }
                        .foregroundColor(.gray)

                        Spacer()

                        Button("下一步") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentPage += 1
                            }
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 50)
        }
        #if os(iOS)
        .background(Color(UIColor.systemBackground))
        #else
        .background(.background)
        #endif
    }
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let description: String
    let iconName: String
    let iconColor: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // 图标
            Image(systemName: page.iconName)
                .font(.system(size: 80))
                .foregroundColor(page.iconColor)

            // 文字内容
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineLimit(nil)
            }

            Spacer()
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @State private var selectedTab = 0
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false

    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView(showOnboarding: $showOnboarding)
            } else {
                TabView(selection: $selectedTab) {
                    HomeView()
                        .tabItem {
                            Image(systemName: "house.fill")
                            Text("首页")
                        }
                        .tag(0)

                    RecordsView()
                        .tabItem {
                            Image(systemName: "list.bullet")
                            Text("记录")
                        }
                        .tag(1)

                    BudgetView()
                        .tabItem {
                            Image(systemName: "chart.pie.fill")
                            Text("预算")
                        }
                        .tag(2)

                    AnalyticsView()
                        .tabItem {
                            Image(systemName: "chart.bar.fill")
                            Text("统计")
                        }
                        .tag(3)

                    SettingsView()
                        .tabItem {
                            Image(systemName: "gear")
                            Text("设置")
                        }
                        .tag(4)
                }
            }
        }
        .onAppear {
            // 如果用户没有完成引导，显示引导页
            if !hasCompletedOnboarding {
                showOnboarding = true
            }
        }
        .onChange(of: showOnboarding) { newValue in
            // 当引导页关闭时，标记为已完成引导
            if !newValue {
                hasCompletedOnboarding = true
            }
        }
    }
}

// MARK: - Home View
struct HomeView: View {
    @EnvironmentObject var dataManager: DataManager
    @StateObject private var voiceManager = VoiceRecognitionManager()
    @State private var showingAddTransaction = false
    @State private var manualAmount = ""
    @State private var selectedCategory = "餐饮"
    @State private var transactionNote = ""
    @State private var lastVoiceResult: [Transaction] = []
    @State private var showingVoiceResult = false
    @State private var showingSmartInsights = false
    @State private var latestInsights: [SmartInsight] = []

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 语音记账卡片
                    VStack(spacing: 15) {
                        Image(systemName: voiceManager.isRecording ? "mic.fill" : "mic")
                            .font(.system(size: 60))
                            .foregroundColor(voiceManager.isRecording ? .red : .blue)
                        
                        Text(voiceManager.isRecording ? "正在录音..." : "点击开始语音记账")
                            .font(.headline)
                        
                        if !voiceManager.recognizedText.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("识别内容：")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(voiceManager.recognizedText)
                                    .font(.body)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }

                        // 显示语音识别结果
                        if showingVoiceResult && !lastVoiceResult.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("添加成功")
                                        .font(.headline)
                                        .foregroundColor(.green)
                                    Spacer()
                                    Button("关闭") {
                                        showingVoiceResult = false
                                        lastVoiceResult = []
                                    }
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                }

                                ForEach(lastVoiceResult, id: \.id) { transaction in
                                    HStack {
                                        Image(systemName: transaction.isExpense ? "minus.circle.fill" : "plus.circle.fill")
                                            .foregroundColor(transaction.isExpense ? .red : .green)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(transaction.category)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Text(transaction.note)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Text((transaction.isExpense ? "-" : "+") + "¥" + String(format: "%.2f", transaction.amount))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(transaction.isExpense ? .red : .green)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(10)
                        }

                        // 显示错误信息
                        if !voiceManager.errorMessage.isEmpty {
                            Text(voiceManager.errorMessage)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(10)
                        }
                        
                        // 语音提示
                        if !voiceManager.isRecording && voiceManager.recognizedText.isEmpty {
                            VStack(spacing: 8) {
                                Text("💡 语音记账示例")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("💰 收入：\"发工资5000元\" \"股票分红200元\"")
                                    Text("💸 支出：\"午饭花了30元\" \"打车15块\"")
                                    Text("🔄 多笔：\"中午和晚上各花了20元\"")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }

                        Button(action: {
                            if voiceManager.isRecording {
                                voiceManager.stopRecording()
                                // 解析并添加多笔交易
                                print("🔍 开始解析语音文本: \"\(voiceManager.recognizedText)\"")
                                let parsedTransactions = voiceManager.parseMultipleTransactions(from: voiceManager.recognizedText)

                                print("🎯 解析结果: 发现 \(parsedTransactions.count) 笔交易")
                                for (idx, tx) in parsedTransactions.enumerated() {
                                    print("  交易\(idx+1): 金额=\(tx.amount ?? 0), 分类=\(tx.category ?? "未知"), 备注=\(tx.note ?? "")")
                                }

                                var addedTransactions: [Transaction] = []
                                for (index, parsed) in parsedTransactions.enumerated() {
                                    if let amount = parsed.amount {
                                        let transaction = Transaction(
                                            amount: amount,
                                            category: parsed.category ?? "其他",
                                            note: parsed.note ?? "",
                                            date: parsed.date ?? Date(),
                                            isExpense: parsed.isExpense
                                        )
                                        dataManager.addTransaction(transaction)
                                        addedTransactions.append(transaction)
                                        let dateFormatter = DateFormatter()
                                        dateFormatter.dateFormat = "M月d日"
                                        let dateString = dateFormatter.string(from: transaction.date)
                                        print("💾 添加第 \(index + 1) 笔交易: \(amount)元 - \(parsed.category ?? "其他") - \(dateString)")
                                    }
                                }

                                // 显示添加结果
                                if !addedTransactions.isEmpty {
                                    lastVoiceResult = addedTransactions
                                    showingVoiceResult = true

                                    // 3秒后自动隐藏结果
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        showingVoiceResult = false
                                    }
                                }

                                // 提供反馈
                                if parsedTransactions.count > 1 {
                                    print("🎉 成功添加 \(parsedTransactions.count) 笔交易")
                                } else if parsedTransactions.count == 1 {
                                    print("✅ 成功添加 1 笔交易")
                                } else {
                                    print("⚠️ 未能识别到有效的交易金额")
                                }
                            } else {
                                voiceManager.startRecording()
                            }
                        }) {
                            Text(voiceManager.isRecording ? "停止录音" : "开始录音")
                                .font(.headline)
                                .padding()
                                .frame(width: 200)
                                .background(voiceManager.isRecording ? Color.red : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(25)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(15)
                    
                    // 手动添加按钮
                    Button(action: { showingAddTransaction = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("手动添加记账")
                        }
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }

                    // 智能洞察卡片
                    if !latestInsights.isEmpty {
                        SmartInsightsCard(insights: latestInsights) {
                            showingSmartInsights = true
                        }
                    }

                    // 今日概览
                    TodaySummary()

                    // 连击激励卡片
                    StreakMotivationCard()

                    // 活跃自定义预算
                    ActiveCustomBudgets()

                    // 最近交易
                    RecentTransactions()
                }
                .padding()
            }
            .navigationTitle("语音记账")
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionView(isPresented: $showingAddTransaction)
            }
            .sheet(isPresented: $showingSmartInsights) {
                SmartInsightsDetailView(insights: latestInsights)
                    .environmentObject(dataManager)
            }
            .onAppear {
                loadSmartInsights()
            }
        }
    }

    private func loadSmartInsights() {
        latestInsights = dataManager.generateSmartInsights()
    }
}

// MARK: - Today Summary
struct TodaySummary: View {
    @EnvironmentObject var dataManager: DataManager
    
    var todayExpense: Double {
        dataManager.todayTransactions
            .filter { $0.isExpense }
            .reduce(0) { $0 + $1.amount }
    }

    var todayIncome: Double {
        dataManager.todayTransactions
            .filter { !$0.isExpense }
            .reduce(0) { $0 + $1.amount }
    }

    var monthlyIncome: Double {
        dataManager.thisMonthTransactions
            .filter { !$0.isExpense }
            .reduce(0) { $0 + $1.amount }
    }

    var remainingBudget: Double {
        dataManager.budget.monthlyLimit - dataManager.monthlyExpense
    }

    var todayNetIncome: Double {
        todayIncome - todayExpense
    }

    var monthlyNetIncome: Double {
        monthlyIncome - dataManager.monthlyExpense
    }

    var monthlySavingRate: Double {
        monthlyIncome > 0 ? (monthlyNetIncome / monthlyIncome) * 100 : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今日概览")
                .font(.headline)
            
            // 第一行：今日收支
            HStack(spacing: 8) {
                // 今日支出
                VStack(spacing: 4) {
                    Text("今日支出")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .minimumScaleFactor(0.8)
                    Text("¥" + String(format: "%.1f", todayExpense))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.red)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 30)

                // 今日收入
                VStack(spacing: 4) {
                    Text("今日收入")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .minimumScaleFactor(0.8)
                    Text("¥" + String(format: "%.1f", todayIncome))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.green)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }

            // 第二行：本月收支和预算
            HStack(spacing: 8) {
                // 本月支出
                VStack(spacing: 4) {
                    Text("本月支出")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .minimumScaleFactor(0.8)
                    Text("¥" + String(format: "%.1f", dataManager.monthlyExpense))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.orange)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 30)

                // 本月收入
                VStack(spacing: 4) {
                    Text("本月收入")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .minimumScaleFactor(0.8)
                    Text("¥" + String(format: "%.1f", monthlyIncome))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 30)

                // 剩余预算
                VStack(spacing: 4) {
                    Text("剩余预算")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .minimumScaleFactor(0.8)
                    Text("¥" + String(format: "%.1f", remainingBudget))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(remainingBudget > 0 ? .green : .red)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }

            // 第三行：净收入和储蓄率
            HStack(spacing: 8) {
                // 今日净收入
                VStack(spacing: 4) {
                    Text("今日净收入")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .minimumScaleFactor(0.8)
                    Text((todayNetIncome >= 0 ? "+" : "") + "¥" + String(format: "%.1f", todayNetIncome))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(todayNetIncome >= 0 ? .green : .red)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 30)

                // 本月储蓄率
                VStack(spacing: 4) {
                    Text("本月储蓄率")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .minimumScaleFactor(0.8)
                    Text(String(format: "%.1f", monthlySavingRate) + "%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(monthlySavingRate >= 0 ? .green : .red)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 30)

                // 连击天数
                VStack(spacing: 4) {
                    Text("连击天数")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .minimumScaleFactor(0.8)
                    HStack(spacing: 2) {
                        Text("🔥")
                            .font(.caption)
                        Text(String(dataManager.userStats.currentStreak))
                            .font(.subheadline)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.orange)
                        Text("天")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Streak Motivation Card
struct StreakMotivationCard: View {
    @EnvironmentObject var dataManager: DataManager

    var motivationMessage: String {
        let streak = dataManager.userStats.currentStreak
        switch streak {
        case 0:
            return "今天就开始记账吧！😊"
        case 1:
            return "太棒了！第一天完成！✨"
        case 2:
            return "很好！记账习惯正在养成💪"
        case 3..<7:
            return "继续加油！你已经连续\(streak)天了🔥"
        case 7..<15:
            return "了不起！\(streak)天的坚持真棒🏆"
        case 15..<30:
            return "习惯大师！\(streak)天的成果令人惊叹🎆"
        default:
            return "记账之王！\(streak)天连击无人能挑战👑"
        }
    }

    var nextMilestone: Int {
        let streak = dataManager.userStats.currentStreak
        if streak < 3 { return 3 }
        if streak < 7 { return 7 }
        if streak < 15 { return 15 }
        if streak < 30 { return 30 }
        return streak + 10 // 超过30天后，每10天为一个里程碑
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("连击激励")
                    .font(.headline)
                Spacer()
                Text("🎆")
                    .font(.title2)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(motivationMessage)
                    .font(.body)
                    .foregroundColor(.primary)

                if dataManager.userStats.currentStreak > 0 {
                    let progress = Double(dataManager.userStats.currentStreak) / Double(nextMilestone)
                    let remainingDays = nextMilestone - dataManager.userStats.currentStreak

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("连击进度")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("再堅持" + String(remainingDays) + "天解锁下个成就")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }

                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                            .scaleEffect(y: 1.5)

                        HStack {
                            Text(String(dataManager.userStats.currentStreak))
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Text(String(nextMilestone))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if dataManager.userStats.maxStreak > dataManager.userStats.currentStreak {
                    Text("最佳记录：" + String(dataManager.userStats.maxStreak) + "天 🎖️")
                        .font(.caption)
                        .foregroundColor(.purple)
                        .font(.system(size: 16, weight: .medium))
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.orange.opacity(0.1), Color.yellow.opacity(0.05)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Active Custom Budgets
struct ActiveCustomBudgets: View {
    @EnvironmentObject var dataManager: DataManager

    private var activeBudgets: [CustomBudget] {
        dataManager.getActiveCustomBudgets().sorted { budget1, budget2 in
            let stats1 = dataManager.getCustomBudgetStats(budget1)
            let stats2 = dataManager.getCustomBudgetStats(budget2)
            return stats1.percentage > stats2.percentage
        }
    }

    var body: some View {
        if !activeBudgets.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("活跃预算")
                        .font(.headline)
                    Spacer()
                    Text(String(activeBudgets.count) + "个进行中")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                ForEach(activeBudgets.prefix(2)) { budget in
                    ActiveCustomBudgetCard(budget: budget)
                }

                if activeBudgets.count > 2 {
                    HStack {
                        Spacer()
                        Text("还有" + String(activeBudgets.count - 2) + "个预算...")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color.blue.opacity(0.03))
            .cornerRadius(12)
        }
    }
}

struct ActiveCustomBudgetCard: View {
    let budget: CustomBudget
    @EnvironmentObject var dataManager: DataManager

    private var stats: (usedAmount: Double, percentage: Double, daysRemaining: Int) {
        dataManager.getCustomBudgetStats(budget)
    }

    private var progressColor: Color {
        if stats.percentage > 0.9 { return .red }
        if stats.percentage > 0.7 { return .orange }
        return .green
    }

    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")

        let calendar = Calendar.current
        if calendar.isDate(start, inSameDayAs: end) {
            // 同一天
            formatter.dateFormat = "M月d日"
            return formatter.string(from: start)
        } else if calendar.component(.year, from: start) == calendar.component(.year, from: end) {
            // 同一年
            formatter.dateFormat = "M月d日"
            let startStr = formatter.string(from: start)
            let endStr = formatter.string(from: end)
            return "\(startStr) - \(endStr)"
        } else {
            // 不同年
            formatter.dateFormat = "yyyy年M月d日"
            let startStr = formatter.string(from: start)
            let endStr = formatter.string(from: end)
            return "\(startStr) - \(endStr)"
        }
    }

    private var statusIcon: String {
        if stats.percentage > 0.9 {
            return "exclamationmark.triangle.fill"
        } else if stats.percentage > 0.7 {
            return "exclamationmark.circle.fill"
        }
        return "checkmark.circle.fill"
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(budget.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: statusIcon)
                        .foregroundColor(progressColor)
                        .font(.caption)
                }

                HStack {
                    Text("¥" + String(format: "%.0f", stats.usedAmount))
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("/")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥" + String(format: "%.0f", budget.totalLimit))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(String(stats.daysRemaining) + "天剩余")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // 显示时间段
                HStack {
                    Text(formatDateRange(start: budget.startDate, end: budget.endDate))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                ProgressView(value: stats.percentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
                    .scaleEffect(y: 0.8)
            }

            VStack(spacing: 2) {
                Text(String(Int(stats.percentage * 100)) + "%")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(progressColor)
                Text("已用")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 35)
        }
        .padding(8)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.05), radius: 2)
    }
}

// MARK: - Recent Transactions
struct RecentTransactions: View {
    @EnvironmentObject var dataManager: DataManager
    
    var recentTransactions: [Transaction] {
        Array(dataManager.transactions.sorted { $0.date > $1.date }.prefix(5))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近交易")
                .font(.headline)
            
            if recentTransactions.isEmpty {
                Text("暂无交易记录")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(recentTransactions) { transaction in
                    TransactionRow(transaction: transaction)
                }
            }
        }
    }
}

// MARK: - Transaction Row
struct TransactionRow: View {
    let transaction: Transaction
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "M-d HH:mm"
        return formatter
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(transaction.category)
                    .font(.headline)
                Text(transaction.note)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                let prefix = transaction.isExpense ? "-" : "+"
                let amountText = String(format: "%.2f", transaction.amount)
                Text(prefix + "¥" + amountText)
                    .font(.headline)
                    .foregroundColor(transaction.isExpense ? .red : .green)
                Text(dateFormatter.string(from: transaction.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - Add Transaction View
struct AddTransactionView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var dataManager: DataManager

    @State private var amount = ""
    @State private var selectedCategory = "餐饮"
    @State private var note = ""
    @State private var isExpense = true
    @State private var selectedDate = Date()
    @State private var smartRecommendations: [SmartCategoryRecommendation] = []
    @State private var anomalyAlert: AnomalyDetectionResult? = nil
    @State private var showingAnomalyAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("交易信息") {
                    TextField("金额", text: $amount)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .onChange(of: amount) { _ in
                            updateSmartRecommendations()
                        }

                    Picker("类型", selection: $isExpense) {
                        Text("支出").tag(true)
                        Text("收入").tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: isExpense) { newValue in
                        // 当切换收入/支出类型时，自动选择相应分类的第一个选项
                        if newValue {
                            // 切换到支出
                            selectedCategory = dataManager.expenseCategories.first ?? "其他"
                        } else {
                            // 切换到收入
                            selectedCategory = dataManager.incomeCategories.first ?? "其他收入"
                        }
                        updateSmartRecommendations()
                    }

                    Picker("分类", selection: $selectedCategory) {
                        ForEach(isExpense ? dataManager.expenseCategories : dataManager.incomeCategories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }

                    TextField("备注", text: $note)
                        .onChange(of: note) { _ in
                            updateSmartRecommendations()
                        }

                    DatePicker("日期", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                        .onChange(of: selectedDate) { _ in
                            updateSmartRecommendations()
                        }
                }

                // 智能推荐分类部分
                if !smartRecommendations.isEmpty {
                    Section("🧠 智能推荐") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("根据您的历史记录，推荐以下分类:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(smartRecommendations.prefix(3), id: \.category) { recommendation in
                                        SmartRecommendationCard(
                                            recommendation: recommendation,
                                            isSelected: selectedCategory == recommendation.category,
                                            onTap: {
                                                selectedCategory = recommendation.category
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("添加交易")
            .alert("⚠️ 异常提醒", isPresented: $showingAnomalyAlert) {
                Button("确认提交", role: .destructive) {
                    saveTransactionWithAnomalyConfirmed()
                }
                Button("重新检查", role: .cancel) {
                    // 用户可以重新检查输入
                }
            } message: {
                if let alert = anomalyAlert {
                    Text(alert.description + "\n\n" + alert.suggestions.joined(separator: "\n"))
                }
            }
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveTransactionWithAnomalyCheck()
                    }
                    .disabled(amount.isEmpty)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveTransactionWithAnomalyCheck()
                    }
                    .disabled(amount.isEmpty)
                }
                #endif
            }
        }
    }

    // 智能推荐更新方法
    private func updateSmartRecommendations() {
        guard let amountValue = Double(amount), amountValue > 0 else {
            smartRecommendations = []
            return
        }

        let recommendations = dataManager.getSmartCategoryRecommendations(
            amount: amountValue,
            description: note,
            time: selectedDate,
            isExpense: isExpense
        )
        smartRecommendations = recommendations
    }

    // 带异常检测的保存方法
    private func saveTransactionWithAnomalyCheck() {
        guard let amountValue = Double(amount) else { return }

        let transaction = Transaction(
            amount: amountValue,
            category: selectedCategory,
            note: note.isEmpty ? (isExpense ? "支出" : "收入") : note,
            date: selectedDate,
            isExpense: isExpense
        )

        // 进行异常检测
        if let anomaly = dataManager.detectAnomalies(for: transaction) {
            anomalyAlert = anomaly
            showingAnomalyAlert = true
        } else {
            saveTransaction(transaction)
        }
    }

    // 确认异常后保存
    private func saveTransactionWithAnomalyConfirmed() {
        guard let amountValue = Double(amount) else { return }

        let transaction = Transaction(
            amount: amountValue,
            category: selectedCategory,
            note: note.isEmpty ? (isExpense ? "支出" : "收入") : note,
            date: selectedDate,
            isExpense: isExpense
        )

        saveTransaction(transaction)
    }

    // 实际保存交易的方法
    private func saveTransaction(_ transaction: Transaction) {
        dataManager.addTransaction(transaction)

        // 学习用户偏好
        dataManager.learnFromTransaction(transaction)

        // 触发触觉反馈
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        #endif

        // 关闭视图
        isPresented = false
    }
}

// MARK: - Records View
struct RecordsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    
    var filteredTransactions: [Transaction] {
        var result = dataManager.transactions
        
        if !searchText.isEmpty {
            result = result.filter {
                $0.note.contains(searchText) || $0.category.contains(searchText)
            }
        }
        
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        
        return result.sorted { $0.date > $1.date }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 搜索栏
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("搜索交易", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal)
                    
                    // 分类筛选
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            CategoryFilterButton(
                                title: "全部",
                                isSelected: selectedCategory == nil,
                                action: { selectedCategory = nil }
                            )
                            
                            ForEach(dataManager.categories, id: \.self) { category in
                                CategoryFilterButton(
                                    title: category,
                                    isSelected: selectedCategory == category,
                                    action: { selectedCategory = category }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 统计信息
                    if !filteredTransactions.isEmpty {
                        HStack {
                            Text("共 " + String(filteredTransactions.count) + " 条记录")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            let totalAmount = filteredTransactions.reduce(0) { $0 + $1.amount }
                            let totalText = String(format: "%.2f", totalAmount)
                            Text("总计: ¥" + totalText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    
                    // 交易记录列表
                    if filteredTransactions.isEmpty {
                        // 空状态
                        VStack(spacing: 20) {
                            Image(systemName: "tray")
                                .font(.system(size: 50))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("暂无交易记录")
                                .font(.headline)
                                .foregroundColor(.gray)
                            Text("开始语音记账或手动添加交易")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 50)
                    } else {
                        // 显示所有交易记录
                        ForEach(filteredTransactions) { transaction in
                            SimpleTransactionRow(transaction: transaction)
                                .padding(.horizontal)
                                .onTapGesture {
                                    // 预留：点击查看详情
                                }
                        }
                    }
                    
                    // 底部间距
                    Spacer(minLength: 100)
                }
                .padding(.top)
            }
            .navigationTitle("交易记录")
        }
    }
}

// MARK: - Simple Transaction Row
struct SimpleTransactionRow: View {
    let transaction: Transaction
    @EnvironmentObject var dataManager: DataManager
    @State private var showingDeleteAlert = false
    
    private var categoryIcon: String {
        switch transaction.category {
        case "餐饮": return "fork.knife"
        case "交通": return "car.fill"
        case "购物": return "bag.fill"
        case "娱乐": return "gamecontroller.fill"
        case "生活": return "house.fill"
        case "医疗": return "cross.case.fill"
        case "教育": return "book.fill"
        default: return "ellipsis.circle.fill"
        }
    }
    
    private var categoryColor: Color {
        switch transaction.category {
        case "餐饮": return .orange
        case "交通": return .blue
        case "购物": return .green
        case "娱乐": return .purple
        case "生活": return Color(red: 0.6, green: 0.4, blue: 0.2)
        case "医疗": return .red
        case "教育": return Color(red: 0.0, green: 0.7, blue: 1.0)
        default: return .gray
        }
    }
    
    var body: some View {
        HStack {
            // 分类图标
            Image(systemName: categoryIcon)
                .font(.title2)
                .foregroundColor(categoryColor)
                .frame(width: 40, height: 40)
                .background(categoryColor.opacity(0.1))
                .clipShape(Circle())
            
            // 交易信息
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.category)
                    .font(.headline)
                Text(transaction.note)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text(DateFormatter.transactionDisplay.string(from: transaction.date))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 金额
            let prefix = transaction.isExpense ? "-" : "+"
            let amountText = String(format: "%.2f", transaction.amount)
            Text(prefix + "¥" + amountText)
                .font(.headline)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(transaction.isExpense ? .red : .green)
        }
        .padding()
        #if os(iOS)
        .background(Color(UIColor.systemBackground))
        #else
        .background(.background)
        #endif
        .cornerRadius(10)
        .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 2)
        .contextMenu {
            Button(action: {
                dataManager.deleteTransaction(transaction)
            }) {
                Label("删除", systemImage: "trash")
            }
        }
    }
}

// MARK: - Date Formatter Extension
extension DateFormatter {
    static let transactionDisplay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
}

// MARK: - Category Filter Button
struct CategoryFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(15)
        }
    }
}

// MARK: - Budget View
struct BudgetView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var editingBudget = false
    @State private var newMonthlyLimit = ""
    @State private var showingAddCustomBudget = false
    
    var budgetProgress: Double {
        min(dataManager.monthlyExpense / dataManager.budget.monthlyLimit, 1.0)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 月度预算
                    VStack(spacing: 15) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("本月预算")
                                    .font(.headline)
                                Text("(分类预算自动汇总)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("设置分类预算") { editingBudget = true }
                                .font(.subheadline)
                        }
                        
                        Text("¥" + String(format: "%.0f", dataManager.budget.monthlyLimit))
                            .font(.largeTitle)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.blue)
                        
                        ProgressView(value: budgetProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: budgetProgress > 0.8 ? .red : .blue))
                        
                        HStack {
                            VStack {
                                Text("已用")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("¥" + String(format: "%.2f", dataManager.monthlyExpense))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.red)
                            }
                            
                            Spacer()
                            
                            VStack {
                                Text("剩余")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                let remainingAmount = dataManager.budget.monthlyLimit - dataManager.monthlyExpense
                                Text("¥" + String(format: "%.2f", remainingAmount))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.green)
                            }
                            
                            Spacer()
                            
                            VStack {
                                Text("使用率")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(Int(budgetProgress * 100)) + "%")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(15)

                    // 自定义预算
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("自定义预算")
                                .font(.headline)
                            Spacer()
                            Button("添加预算") {
                                showingAddCustomBudget = true
                            }
                            .font(.subheadline)
                        }

                        if dataManager.budget.customBudgets.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "calendar.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue.opacity(0.6))
                                Text("暂无自定义预算")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("点击\"添加预算\"创建短期预算计划")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        } else {
                            ForEach(dataManager.getAllCustomBudgets(), id: \.id) { customBudget in
                                CustomBudgetCard(customBudget: customBudget)
                                    .environmentObject(dataManager)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(15)

                    // 分类预算
                    VStack(alignment: .leading, spacing: 15) {
                        Text("分类预算")
                            .font(.headline)

                        ForEach(dataManager.expenseCategories, id: \.self) { category in
                            let limit = dataManager.budget.categoryLimits[category] ?? 0
                            CategoryBudgetRow(
                                category: category,
                                limit: limit,
                                used: dataManager.getCategoryExpense(category: category)
                            )
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(15)
                }
                .padding()
            }
            .navigationTitle("预算管理")
            .sheet(isPresented: $editingBudget) {
                EditBudgetView(isPresented: $editingBudget)
            }
            .sheet(isPresented: $showingAddCustomBudget) {
                AddCustomBudgetView()
            }
        }
    }
}

// MARK: - Custom Budget Card
struct CustomBudgetCard: View {
    let customBudget: CustomBudget
    @EnvironmentObject var dataManager: DataManager
    @State private var showDeleteAlert = false

    var usedAmount: Double {
        customBudget.getUsedAmount(from: dataManager.transactions)
    }

    var progress: Double {
        min(usedAmount / customBudget.totalLimit, 1.0)
    }

    var progressColor: Color {
        if progress > 0.9 { return .red }
        if progress > 0.7 { return .orange }
        return .green
    }

    var statusIcon: String {
        if !customBudget.isActive {
            return "clock.badge.xmark"
        } else if progress > 0.9 {
            return "exclamationmark.triangle.fill"
        } else if progress > 0.7 {
            return "exclamationmark.circle.fill"
        }
        return "checkmark.circle.fill"
    }

    var statusColor: Color {
        if !customBudget.isActive { return .secondary }
        return progressColor
    }

    var daysRemaining: Int {
        dataManager.daysRemaining(until: customBudget.endDate)
    }

    func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")

        let calendar = Calendar.current
        if calendar.isDate(start, inSameDayAs: end) {
            // 同一天
            formatter.dateFormat = "M月d日"
            return formatter.string(from: start)
        } else if calendar.component(.year, from: start) == calendar.component(.year, from: end) {
            // 同一年
            formatter.dateFormat = "M月d日"
            let startStr = formatter.string(from: start)
            let endStr = formatter.string(from: end)
            return "\(startStr) - \(endStr)"
        } else {
            // 不同年
            formatter.dateFormat = "yyyy年M月d日"
            let startStr = formatter.string(from: start)
            let endStr = formatter.string(from: end)
            return "\(startStr) - \(endStr)"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // 头部信息
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: statusIcon)
                            .foregroundColor(statusColor)
                        Text(customBudget.name)
                            .font(.system(size: 16, weight: .semibold))
                    }

                    if let description = customBudget.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if customBudget.isActive {
                        Text(String(daysRemaining) + " 天剩余")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("已结束")
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Text(formatDateRange(start: customBudget.startDate, end: customBudget.endDate))
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("¥" + String(format: "%.0f", customBudget.totalLimit))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }

            // 进度条
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: progressColor))

            // 统计信息
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("已用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥" + String(format: "%.2f", usedAmount))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.red)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("剩余")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    let remaining = customBudget.totalLimit - usedAmount
                    Text("¥" + String(format: "%.2f", remaining))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.green)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("使用率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(Int(progress * 100)) + "%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(progressColor)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(customBudget.isActive ? Color.white : Color.gray.opacity(0.1))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .opacity(customBudget.isActive ? 1.0 : 0.7)
        .contextMenu {
            if !customBudget.isActive {
                Button("删除", role: .destructive) {
                    showDeleteAlert = true
                }
            }
        }
        .alert("删除预算", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                dataManager.deleteCustomBudget(customBudget)
            }
        } message: {
            Text("确定要删除「" + customBudget.name + "」预算吗？此操作不可撤销。")
        }
    }
}

// MARK: - Category Budget Row
struct CategoryBudgetRow: View {
    let category: String
    let limit: Double
    let used: Double
    
    var progress: Double {
        limit > 0 ? min(used / limit, 1.0) : 0
    }
    
    var progressColor: Color {
        if progress > 0.9 { return .red }
        if progress > 0.7 { return .orange }
        return .blue
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(category)
                    .font(.system(size: 16, weight: .medium))
                Spacer()
                if limit > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        let usedText = String(format: "%.0f", used)
                        let limitText = String(format: "%.0f", limit)
                        Text("¥" + usedText + " / ¥" + limitText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(String(Int(progress * 100)) + "%")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(progressColor)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("未设置预算")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .italic()
                        Text("0%")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            if limit > 0 {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 6)
                    .cornerRadius(3)
                    .overlay(
                        Text("点击设置预算以启用进度跟踪")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    )
            }
        }
    }
}

// MARK: - Edit Budget View
struct EditBudgetView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var dataManager: DataManager
    @State private var categoryLimits: [String: String] = [:]
    
    // 计算分类预算总和
    var calculatedTotalBudget: Double {
        return categoryLimits.compactMap { Double($0.value) }.reduce(0, +)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("分类预算设置") {
                    ForEach(dataManager.expenseCategories, id: \.self) { category in
                        HStack {
                            Text(category)
                                .font(.subheadline)
                            Spacer()
                            TextField("0", text: Binding(
                                get: { categoryLimits[category] ?? "" },
                                set: { categoryLimits[category] = $0 }
                            ))
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                            Text("元")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                
                Section("预算汇总") {
                    HStack {
                        Text("月度总预算")
                            .font(.headline)
                        Spacer()
                        Text("¥" + String(format: "%.0f", calculatedTotalBudget))
                            .font(.title2)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                    
                    if calculatedTotalBudget == 0 {
                        Text("请设置各分类预算")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        Text("各分类预算自动累计为月度总预算")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("快速设置") {
                    VStack(spacing: 12) {
                        Text("推荐预算分配（基于¥3000总预算）")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("应用推荐分配") {
                            categoryLimits = [
                                "餐饮": "900",  // 30%
                                "交通": "450",  // 15%
                                "购物": "600",  // 20%
                                "娱乐": "300",  // 10%
                                "生活": "450",  // 15%
                                "医疗": "150",  // 5%
                                "教育": "120",  // 4%
                                "其他": "30"    // 1%
                            ]
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.vertical, 8)
                }

                // 底部按钮区域
                Section {
                    HStack(spacing: 20) {
                        Button("取消") {
                            isPresented = false
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
#if os(iOS)
                        .background(Color(UIColor.systemGray5))
#else
                        .background(Color(NSColor.controlBackgroundColor))
#endif
                        .foregroundColor(.primary)
                        .cornerRadius(10)

                        Button("保存") {
                            // 保存分类预算
                            for (category, limitStr) in categoryLimits {
                                if let limit = Double(limitStr), limit > 0 {
                                    dataManager.budget.categoryLimits[category] = limit
                                } else {
                                    dataManager.budget.categoryLimits[category] = 0
                                }
                            }

                            // 清理不存在的分类预算
                            let validCategories = Set(dataManager.expenseCategories)
                            dataManager.budget.categoryLimits = dataManager.budget.categoryLimits.filter { validCategories.contains($0.key) }

                            // 自动计算并设置月度总预算
                            dataManager.budget.monthlyLimit = calculatedTotalBudget

                            // 保存数据到本地
                            dataManager.saveData()

                            isPresented = false
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("预算设置")
        }
        .onAppear {
            // 初始化分类预算数据
            for category in dataManager.expenseCategories {
                let limit = dataManager.budget.categoryLimits[category] ?? 0
                categoryLimits[category] = limit > 0 ? "\(Int(limit))" : ""
            }
        }
    }
}

// MARK: - Add Custom Budget View
struct AddCustomBudgetView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss

    @State private var budgetName: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var totalLimit: String = ""
    @State private var description: String = ""
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""

    private var isFormValid: Bool {
        !budgetName.trimmingCharacters(in: .whitespaces).isEmpty &&
        startDate < endDate &&
        !totalLimit.isEmpty &&
        Double(totalLimit) != nil &&
        (Double(totalLimit) ?? 0) > 0
    }

    private var nameIsDuplicate: Bool {
        dataManager.isCustomBudgetNameDuplicate(budgetName.trimmingCharacters(in: .whitespaces), excludingId: nil)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("预算信息")) {
                    TextField("预算名称", text: $budgetName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    if nameIsDuplicate && !budgetName.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("预算名称已存在")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section(header: Text("预算时间")) {
                    DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())

                    DatePicker("结束日期", selection: $endDate, in: startDate..., displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())

                    HStack {
                        Text("预算天数")
                        Spacer()
                        let duration = budgetDuration(start: startDate, end: endDate)
                        Text(String(duration) + " 天")
                            .foregroundColor(.secondary)
                    }
                }

                Section(header: Text("预算限制")) {
                    HStack {
                        Text("¥")
                        TextField("总预算限制", text: $totalLimit)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }

                    if !totalLimit.isEmpty && (Double(totalLimit) ?? 0) <= 0 {
                        Text("预算金额必须大于0")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section(header: Text("备注 (可选)")) {
                    TextField("预算描述", text: $description)
                        .lineLimit(3)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                Section {
                    Button("创建预算") {
                        createCustomBudget()
                    }
                    .disabled(!isFormValid || nameIsDuplicate)
                    .foregroundColor(isFormValid && !nameIsDuplicate ? .blue : .gray)
                }
            }
            .navigationTitle("新建自定义预算")
            #if os(iOS)
.navigationBarTitleDisplayMode(.inline)
#endif
            // Toolbar temporarily disabled for compilation
            .alert("提示", isPresented: $showingAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                // 设置默认结束日期为7天后
                endDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate) ?? startDate
            }
        }
    }

    /// 计算预算持续天数（包含起始和结束日期）
    private func budgetDuration(start: Date, end: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end))
        return (components.day ?? 0) + 1
    }

    private func createCustomBudget() {
        guard isFormValid && !nameIsDuplicate else { return }

        guard let limitAmount = Double(totalLimit) else {
            showAlert(message: "请输入有效的预算金额")
            return
        }

        let trimmedName = budgetName.trimmingCharacters(in: .whitespaces)
        let trimmedDescription = description.trimmingCharacters(in: .whitespaces)

        let customBudget = CustomBudget(
            name: trimmedName,
            startDate: startDate,
            endDate: endDate,
            totalLimit: limitAmount,
            categoryLimits: nil,
            description: trimmedDescription.isEmpty ? nil : trimmedDescription
        )

        dataManager.addCustomBudget(customBudget)

        // 安排到期提醒通知
        NotificationManager.shared.scheduleCustomBudgetExpiryReminder(customBudget: customBudget)

        dismiss()
    }

    private func showAlert(message: String) {
        alertMessage = message
        showingAlert = true
    }
}

// MARK: - Analytics View Helper Components
struct MonthlyOverviewSection: View {
    let monthlyExpense: Double
    let monthlyIncome: Double
    let netIncome: Double
    let dailyAverageExpense: Double
    let expenseCount: Int
    let incomeCount: Int

    var body: some View {
        VStack(spacing: 20) {
            Text("本月收支总览")
                .font(.headline)

            HStack(spacing: 30) {
                VStack(spacing: 8) {
                    Text("支出")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥" + String(format: "%.0f", monthlyExpense))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.red)
                }

                Divider().frame(height: 40)

                VStack(spacing: 8) {
                    Text("收入")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥" + String(format: "%.0f", monthlyIncome))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.green)
                }

                Divider().frame(height: 40)

                VStack(spacing: 8) {
                    Text("净收支")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text((netIncome >= 0 ? "+" : "") + "¥" + String(format: "%.0f", abs(netIncome)))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(netIncome >= 0 ? .green : .orange)
                }
            }

            HStack {
                VStack {
                    Text("日均支出")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥" + String(format: "%.2f", dailyAverageExpense))
                        .font(.system(size: 14, weight: .semibold))
                }

                Spacer()

                VStack {
                    Text("支出笔数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(expenseCount))
                        .font(.system(size: 14, weight: .semibold))
                }

                Spacer()

                VStack {
                    Text("收入笔数")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(incomeCount))
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
    }
}

struct CategoryExpensesSection: View {
    let categoryExpenses: [(String, Double)]
    let totalExpense: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("分类支出")
                .font(.headline)

            ForEach(categoryExpenses, id: \.0) { category, expense in
                HStack {
                    Text(category)
                        .font(.system(size: 16, weight: .medium))

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("¥" + String(format: "%.2f", expense))
                            .font(.system(size: 16, weight: .semibold))
                        Text(String(totalExpense > 0 ? Int((expense / totalExpense) * 100) : 0) + "%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 5)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
    }
}

struct CategoryIncomesSection: View {
    let categoryIncomes: [(String, Double)]
    let monthlyIncome: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("收入分类")
                .font(.headline)

            ForEach(categoryIncomes, id: \.0) { category, income in
                HStack {
                    Text(category)
                        .font(.system(size: 16, weight: .medium))

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("+¥" + String(format: "%.2f", income))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.green)
                        Text(String(monthlyIncome > 0 ? Int((income / monthlyIncome) * 100) : 0) + "%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 5)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
    }
}

struct IncomeExpenseChartSection: View {
    let monthlyIncome: Double
    let monthlyExpense: Double
    let netIncome: Double
    let savingRate: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("收支对比")
                .font(.headline)

            HStack(spacing: 20) {
                VStack(spacing: 5) {
                    GeometryReader { geometry in
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 60, height: geometry.size.height)

                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green)
                                .frame(width: 60, height: calculateBarHeight(monthlyIncome, monthlyExpense, geometry.size.height))
                        }
                    }
                    .frame(height: 120)

                    Text("收入")
                        .font(.caption)
                    Text("¥" + String(format: "%.0f", monthlyIncome))
                        .font(.caption2)
                        .foregroundColor(.green)
                }

                VStack(spacing: 5) {
                    GeometryReader { geometry in
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 60, height: geometry.size.height)

                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red)
                                .frame(width: 60, height: calculateBarHeight(monthlyExpense, monthlyIncome, geometry.size.height))
                        }
                    }
                    .frame(height: 120)

                    Text("支出")
                        .font(.caption)
                    Text("¥" + String(format: "%.0f", monthlyExpense))
                        .font(.caption2)
                        .foregroundColor(.red)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 10) {
                    Text("本月结余")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text((netIncome >= 0 ? "+" : "") + "¥" + String(format: "%.2f", netIncome))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(netIncome >= 0 ? .green : .red)

                    Divider()

                    Text("结余率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f", savingRate) + "%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(savingRate >= 0 ? .green : .red)
                }
            }
            .padding(.vertical, 10)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(15)
    }

    func calculateBarHeight(_ value: Double, _ otherValue: Double, _ maxHeight: CGFloat) -> CGFloat {
        let maxAmount = max(value, otherValue)
        return maxAmount > 0 ? (value / maxAmount) * maxHeight : 0
    }
}

// MARK: - Analytics View
struct AnalyticsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingAdvancedAnalytics = false

    var categoryExpenses: [(String, Double)] {
        dataManager.categories.compactMap { category in
            let expense = dataManager.getCategoryExpense(category: category)
            return expense > 0 ? (category, expense) : nil
        }
    }

    var totalExpense: Double {
        categoryExpenses.reduce(0) { $0 + $1.1 }
    }

    var sortedCategoryExpenses: [(String, Double)] {
        categoryExpenses.sorted { $0.1 > $1.1 }
    }

    var monthlyIncome: Double {
        dataManager.thisMonthTransactions
            .filter { !$0.isExpense }
            .reduce(0) { $0 + $1.amount }
    }

    var categoryIncomes: [(String, Double)] {
        var incomes: [String: Double] = [:]
        for transaction in dataManager.thisMonthTransactions where !transaction.isExpense {
            incomes[transaction.category, default: 0] += transaction.amount
        }
        return incomes.compactMap { $0.value > 0 ? ($0.key, $0.value) : nil }.sorted { $0.1 > $1.1 }
    }

    var netIncome: Double {
        monthlyIncome - dataManager.monthlyExpense
    }

    var savingRate: Double {
        monthlyIncome > 0 ? (netIncome / monthlyIncome) * 100 : 0
    }

    var expenseTransactionCount: Int {
        dataManager.thisMonthTransactions.filter { $0.isExpense }.count
    }

    var incomeTransactionCount: Int {
        dataManager.thisMonthTransactions.filter { !$0.isExpense }.count
    }

    func expensePercentage(_ expense: Double) -> String {
        let percentage = totalExpense > 0 ? Int((expense / totalExpense) * 100) : 0
        return String(percentage) + "%"
    }

    func incomePercentage(_ income: Double) -> String {
        let percentage = monthlyIncome > 0 ? Int((income / monthlyIncome) * 100) : 0
        return String(percentage) + "%"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 高级分析入口卡片
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .foregroundColor(.blue)
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("高级分析")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Text("收入趋势 • 智能洞察 • 预测分析")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(action: {
                                showingAdvancedAnalytics = true
                            }) {
                                HStack {
                                    Text("查看")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBlue).opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemBlue).opacity(0.3), lineWidth: 1)
                            )
                    )

                    // 使用子视图组件显示月度总览
                    MonthlyOverviewSection(
                        monthlyExpense: dataManager.monthlyExpense,
                        monthlyIncome: monthlyIncome,
                        netIncome: netIncome,
                        dailyAverageExpense: dataManager.dailyAverageExpense,
                        expenseCount: expenseTransactionCount,
                        incomeCount: incomeTransactionCount
                    )

                    // 使用子视图组件显示收支对比图表
                    IncomeExpenseChartSection(
                        monthlyIncome: monthlyIncome,
                        monthlyExpense: dataManager.monthlyExpense,
                        netIncome: netIncome,
                        savingRate: savingRate
                    )

                    // 简化的分类支出
                    CategoryExpensesSection(
                        categoryExpenses: sortedCategoryExpenses,
                        totalExpense: totalExpense
                    )

                    // 简化的收入分类
                    if !categoryIncomes.isEmpty {
                        CategoryIncomesSection(
                            categoryIncomes: categoryIncomes,
                            monthlyIncome: monthlyIncome
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("数据统计")
        }
        .sheet(isPresented: $showingAdvancedAnalytics) {
            AdvancedAnalyticsView()
                .environmentObject(dataManager)
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @AppStorage("voiceEnabled") private var voiceEnabled = true
    @AppStorage("budgetReminder") private var budgetReminder = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var showingClearAlert = false
    @State private var showingCategoryManager = false
    @State private var showOnboarding = false
    
    var body: some View {
        NavigationView {
            List {
                Section("语音设置") {
                    Toggle("启用语音识别", isOn: $voiceEnabled)
                }
                
                Section("预算设置") {
                    Toggle("预算提醒", isOn: $budgetReminder)
                }

                Section("通知设置") {
                    NavigationLink(destination: NotificationSettingsView()) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.red)
                            VStack(alignment: .leading) {
                                Text("提醒通知")
                                Text(dataManager.appSettings.notificationsEnabled ? "已开启" : "已关闭")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section("应用引导") {
                    Button(action: {
                        showOnboarding = true
                    }) {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundColor(.blue)
                            Text("重新显示使用引导")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                }

                Section("成就系统") {
                    NavigationLink(destination: AchievementView()) {
                        HStack {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading) {
                                Text("成就徽章")
                                Text("已解锁 " + String(dataManager.achievements.filter { $0.isUnlocked }.count) + "/" + String(dataManager.achievements.count))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if dataManager.userStats.currentStreak > 0 {
                                VStack {
                                    Text("🔥")
                                    Text(String(dataManager.userStats.currentStreak))
                                        .font(.caption)
                                        .font(.system(size: 18, weight: .bold))
                                }
                            }
                        }
                    }
                }
                
                Section("分类管理") {
                    NavigationLink(destination: CategoryManagerView()) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                            Text("管理分类")
                        }
                    }
                    
                    HStack {
                        Text("当前分类数")
                        Spacer()
                        Text(String(dataManager.categories.count))
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("数据管理") {
                    NavigationLink(destination: ExportDataView()) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text("数据导出")
                                Text("导出记账数据为 CSV 或文本格式")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Button(action: { showingClearAlert = true }) {
                        Text("清空所有数据")
                            .foregroundColor(.red)
                    }
                }
                
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("1.0.8")
                                .foregroundColor(.secondary)
                            Text("试用版")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    HStack {
                        Text("记录总数")
                        Spacer()
                        Text(String(dataManager.transactions.count))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("分类数量")
                        Spacer()
                        Text(String(dataManager.categories.count))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("支持系统")
                        Spacer()
                        Text("iOS 14.0+")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .alert(isPresented: $showingClearAlert) {
                Alert(
                    title: Text("清空数据"),
                    message: Text("确定要清空所有交易记录吗？此操作不可恢复。"),
                    primaryButton: .destructive(Text("清空")) {
                        dataManager.transactions.removeAll()
                        dataManager.saveData()
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            }
            .sheet(isPresented: $showOnboarding) {
                OnboardingView(showOnboarding: $showOnboarding)
            }
        }
    }
}

// MARK: - Category Manager View
struct CategoryManagerView: View {
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.presentationMode) var presentationMode
    @State private var newCategoryName = ""
    @State private var showingDeleteAlert = false
    @State private var selectedCategory = ""
    @State private var editingCategory: String? = nil
    @State private var editingCategoryName = ""
    @State private var isManagingExpenseCategories = true
    
    var body: some View {
        List {
            Section("分类类型") {
                Picker("分类类型", selection: $isManagingExpenseCategories) {
                    Text("支出分类").tag(true)
                    Text("收入分类").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            Section("添加新分类") {
                HStack {
                    TextField("输入分类名称", text: $newCategoryName)
                    Button("添加") {
                        if !newCategoryName.isEmpty {
                            dataManager.addCategory(newCategoryName, isExpense: isManagingExpenseCategories)
                            newCategoryName = ""
                        }
                    }
                    .disabled(newCategoryName.isEmpty)
                }
            }
            
            Section(isManagingExpenseCategories ? "支出分类" : "收入分类") {
                ForEach(isManagingExpenseCategories ? dataManager.expenseCategories : dataManager.incomeCategories, id: \.self) { category in
                    HStack {
                        if editingCategory == category {
                            TextField("分类名称", text: $editingCategoryName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        } else {
                            Text(category)
                                .font(.subheadline)
                        }
                        
                        Spacer()
                        
                        // 显示使用此分类的交易数量
                        if dataManager.transactions.filter({ $0.category == category }).count > 0 {
                            Text(String(dataManager.transactions.filter { $0.category == category }.count) + "条记录")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if editingCategory == category {
                            Button("保存") {
                                if !editingCategoryName.isEmpty && editingCategoryName != category {
                                    dataManager.updateCategory(oldName: category, newName: editingCategoryName)
                                }
                                editingCategory = nil
                            }
                            .foregroundColor(.green)
                            .font(.caption)
                            
                            Button("取消") {
                                editingCategory = nil
                            }
                            .foregroundColor(.red)
                            .font(.caption)
                        } else {
                            Button("编辑") {
                                editingCategory = category
                                editingCategoryName = category
                            }
                            .foregroundColor(.blue)
                            .font(.caption)
                        }
                    }
                    .contextMenu {
                        Button("重命名") {
                            editingCategory = category
                            editingCategoryName = category
                        }
                        
                        Button("删除") {
                            selectedCategory = category
                            showingDeleteAlert = true
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            
            Section("使用说明") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("• 点击'编辑'可直接修改分类名")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• 长按分类可显示快捷菜单")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• 有交易记录的分类不能删除")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• 重命名会自动更新所有记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("分类管理")
        // Toolbar disabled for compilation
        .alert(isPresented: $showingDeleteAlert) {
            let hasTransactions = dataManager.transactions.contains { $0.category == selectedCategory }
            if hasTransactions {
                return Alert(
                    title: Text("删除分类"),
                    message: Text("此分类还有交易记录，无法删除。请先删除或修改相关交易。"),
                    dismissButton: .default(Text("确定"))
                )
            } else {
                return Alert(
                    title: Text("删除分类"),
                    message: Text("确定要删除分类'" + selectedCategory + "'吗？"),
                    primaryButton: .destructive(Text("删除")) {
                        dataManager.deleteCategory(selectedCategory)
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            }
        }
    }
}

// MARK: - Debug Helper Extension
extension DataManager {
    // 手动触发修正函数（调试用）
    func debugFixRefunds() {
        print("🔧 手动触发退款记录修正...")
        fixOldRefundRecords()
    }
}

// MARK: - Notification Settings View
struct NotificationSettingsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var showingPermissionAlert = false

    var body: some View {
        NavigationView {
            List {
                Section("通知权限") {
                    HStack {
                        Text("通知权限")
                        Spacer()
                        Button(dataManager.appSettings.notificationsEnabled ? "已授权" : "请求授权") {
                            if !dataManager.appSettings.notificationsEnabled {
                                requestNotificationPermission()
                            }
                        }
                        .foregroundColor(dataManager.appSettings.notificationsEnabled ? .green : .blue)
                    }

                    Text("请允许 VoiceBudget 发送通知，以便提醒您记账和预算管理")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if dataManager.appSettings.notificationsEnabled {
                    Section("记账提醒") {
                        Toggle("上午提醒", isOn: Binding(
                            get: { dataManager.appSettings.morningReminderEnabled },
                            set: { newValue in
                                dataManager.appSettings.morningReminderEnabled = newValue
                                updateReminders()
                                dataManager.saveData()
                            }
                        ))

                        if dataManager.appSettings.morningReminderEnabled {
                            HStack {
                                Text("上午时间")
                                Spacer()
                                Text(dataManager.appSettings.morningReminderTime)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Toggle("下午提醒", isOn: Binding(
                            get: { dataManager.appSettings.afternoonReminderEnabled },
                            set: { newValue in
                                dataManager.appSettings.afternoonReminderEnabled = newValue
                                updateReminders()
                                dataManager.saveData()
                            }
                        ))

                        if dataManager.appSettings.afternoonReminderEnabled {
                            HStack {
                                Text("下午时间")
                                Spacer()
                                Text(dataManager.appSettings.afternoonReminderTime)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Toggle("晚上提醒", isOn: Binding(
                            get: { dataManager.appSettings.eveningReminderEnabled },
                            set: { newValue in
                                dataManager.appSettings.eveningReminderEnabled = newValue
                                updateReminders()
                                dataManager.saveData()
                            }
                        ))

                        if dataManager.appSettings.eveningReminderEnabled {
                            HStack {
                                Text("晚上时间")
                                Spacer()
                                Text(dataManager.appSettings.eveningReminderTime)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Section("预算警告") {
                        Toggle("预算警告通知", isOn: Binding(
                            get: { dataManager.appSettings.budgetWarningEnabled },
                            set: { newValue in
                                dataManager.appSettings.budgetWarningEnabled = newValue
                                dataManager.saveData()
                            }
                        ))

                        Text("当支出达到预算70%和90%时，会发送提醒通知")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Section("其他通知") {
                        Toggle("周报通知", isOn: Binding(
                            get: { dataManager.appSettings.weeklyReportEnabled },
                            set: { newValue in
                                dataManager.appSettings.weeklyReportEnabled = newValue
                                if newValue {
                                    // 计算本周支出并设置通知
                                    let weeklyExpense = calculateWeeklyExpense()
                                    NotificationManager.shared.scheduleWeeklyReport(totalExpense: weeklyExpense)
                                }
                                dataManager.saveData()
                            }
                        ))

                        Text("每周日晚上8点发送周支出报告")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("通知设置")
            .onAppear {
                checkNotificationStatus()
            }
            .alert(isPresented: $showingPermissionAlert) {
                Alert(
                    title: Text("通知权限"),
                    message: Text("请在设置中允许 VoiceBudget 发送通知"),
                    dismissButton: .default(Text("好的"))
                )
            }
        }
    }

    private func requestNotificationPermission() {
        NotificationManager.shared.requestAuthorization { granted in
            dataManager.appSettings.notificationsEnabled = granted
            dataManager.saveData()

            if granted {
                updateReminders()
            } else {
                showingPermissionAlert = true
            }
        }
    }

    private func checkNotificationStatus() {
        NotificationManager.shared.checkNotificationStatus { authorized in
            dataManager.appSettings.notificationsEnabled = authorized
            dataManager.saveData()
        }
    }

    private func updateReminders() {
        guard dataManager.appSettings.notificationsEnabled else { return }

        let morningTime = dataManager.appSettings.morningReminderEnabled ? dataManager.appSettings.morningReminderTime : ""
        let afternoonTime = dataManager.appSettings.afternoonReminderEnabled ? dataManager.appSettings.afternoonReminderTime : ""
        let eveningTime = dataManager.appSettings.eveningReminderEnabled ? dataManager.appSettings.eveningReminderTime : ""

        NotificationManager.shared.scheduleReminders(
            morningTime: morningTime,
            afternoonTime: afternoonTime,
            eveningTime: eveningTime
        )
    }

    private func calculateWeeklyExpense() -> Double {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        return dataManager.transactions
            .filter { $0.date >= weekAgo && $0.isExpense }
            .reduce(0) { $0 + $1.amount }
    }
}

// MARK: - Achievement View
struct AchievementView: View {
    @EnvironmentObject var dataManager: DataManager

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 统计卡片
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("当前连击")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(dataManager.userStats.currentStreak) + " 天")
                                    .font(.title2)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.orange)
                            }

                            Spacer()

                            VStack(alignment: .trailing) {
                                Text("最长连击")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(dataManager.userStats.maxStreak) + " 天")
                                    .font(.title2)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                        }

                        Divider()

                        HStack {
                            VStack(alignment: .leading) {
                                Text("总记账次数")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(dataManager.userStats.totalTransactions))
                                    .font(.title2)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.green)
                            }

                            Spacer()

                            VStack(alignment: .trailing) {
                                Text("已解锁成就")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(dataManager.achievements.filter { $0.isUnlocked }.count) + "/" + String(dataManager.achievements.count))
                                    .font(.title2)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                    .padding()
#if os(iOS)
                    .background(Color(UIColor.systemGray6))
#else
                    .background(Color(NSColor.controlColor))
#endif
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // 成就列表
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        ForEach(dataManager.achievements) { achievement in
                            AchievementCard(achievement: achievement)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("成就徽章")
            .alert(isPresented: $dataManager.showAchievementAlert) {
                if let achievement = dataManager.newAchievement {
                    return Alert(
                        title: Text("🏆 成就解锁！"),
                        message: Text("恭喜您获得\"" + achievement.name + "\"成就！\n" + achievement.description),
                        dismissButton: .default(Text("太棒了！"))
                    )
                } else {
                    return Alert(title: Text("成就解锁"))
                }
            }
        }
    }
}

struct AchievementCard: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 8) {
            Text(achievement.icon)
                .font(.system(size: 40))
                .opacity(achievement.isUnlocked ? 1.0 : 0.3)

            Text(achievement.name)
                .font(.headline)
                .foregroundColor(achievement.isUnlocked ? .primary : .secondary)

            Text(achievement.description)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .lineLimit(2)

            if achievement.isUnlocked, let unlockedAt = achievement.unlockedAt {
                Text("解锁日期")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(DateFormatter.short.string(from: unlockedAt))
                    .font(.caption2)
                    .foregroundColor(.blue)
            } else {
                Text("未解锁")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 140)
        .background(achievement.isUnlocked ? Color.blue.opacity(0.1) : {
#if os(iOS)
            return Color(UIColor.systemGray6)
#else
            return Color(NSColor.controlColor)
#endif
        }())
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(achievement.isUnlocked ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .scaleEffect(achievement.isUnlocked ? 1.0 : 0.95)
        .animation(.easeInOut(duration: 0.2), value: achievement.isUnlocked)
    }
}

// MARK: - Extensions
extension DateFormatter {
    static let short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
}

// MARK: - Export Data View
struct ExportDataView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedDateRange: ExportData.DateRange = .thisMonth
    @State private var selectedFormat: ExportData.ExportFormat = .csv
    @State private var showingActivityView = false
    @State private var exportedFileURL: URL?
    @State private var previewData: String = ""
    @State private var showingPreview = false

    var filteredTransactions: [Transaction] {
        dataManager.getTransactionsForExport(dateRange: selectedDateRange)
    }

    var totalExpense: Double {
        filteredTransactions.filter { $0.isExpense }.reduce(0) { $0 + $1.amount }
    }

    var totalIncome: Double {
        filteredTransactions.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 数据统计卡片
                    VStack(spacing: 12) {
                        Text("导出数据预览")
                            .font(.headline)

                        HStack {
                            VStack {
                                Text(String(filteredTransactions.count))
                                    .font(.title2)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.blue)
                                Text("交易数量")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            Divider()
                                .frame(height: 40)

                            VStack {
                                Text("¥" + String(format: "%.0f", totalExpense))
                                    .font(.title2)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.red)
                                Text("支出总金额")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)

                            Divider()
                                .frame(height: 40)

                            VStack {
                                Text("¥" + String(format: "%.0f", totalIncome))
                                    .font(.title2)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.green)
                                Text("收入总金额")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
#if os(iOS)
                    .background(Color(UIColor.systemGray6))
#else
                    .background(Color(NSColor.controlColor))
#endif
                    .cornerRadius(12)

                    // 选择选项
                    VStack(alignment: .leading, spacing: 16) {
                        Text("导出设置")
                            .font(.headline)

                        // 时间范围选择
                        VStack(alignment: .leading, spacing: 8) {
                            Text("时间范围")
                                .font(.subheadline)
                                .font(.system(size: 16, weight: .medium))

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                ForEach(ExportData.DateRange.allCases, id: \.self) { range in
                                    Button(action: { selectedDateRange = range }) {
                                        Text(range.displayName)
                                            .font(.caption)
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                            .frame(maxWidth: .infinity)
                                            .background(selectedDateRange == range ? Color.blue : {
#if os(iOS)
                                                return Color(UIColor.systemGray5)
#else
                                                return Color(NSColor.controlBackgroundColor)
#endif
                                            }())
                                            .foregroundColor(selectedDateRange == range ? .white : .primary)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }

                        // 文件格式选择
                        VStack(alignment: .leading, spacing: 8) {
                            Text("文件格式")
                                .font(.subheadline)
                                .font(.system(size: 16, weight: .medium))

                            HStack(spacing: 12) {
                                ForEach(ExportData.ExportFormat.allCases, id: \.self) { format in
                                    Button(action: { selectedFormat = format }) {
                                        HStack {
                                            Image(systemName: selectedFormat == format ? "checkmark.circle.fill" : "circle")
                                            Text(format.displayName)
                                        }
                                        .foregroundColor(selectedFormat == format ? .blue : .primary)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                    .padding()
#if os(iOS)
                    .background(Color(UIColor.systemGray6))
#else
                    .background(Color(NSColor.controlColor))
#endif
                    .cornerRadius(12)

                    // 操作按钮
                    VStack(spacing: 12) {
                        Button(action: previewExportData) {
                            HStack {
                                Image(systemName: "eye")
                                Text("预览数据")
                            }
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .disabled(filteredTransactions.isEmpty)

                        Button(action: exportData) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("导出数据")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(filteredTransactions.isEmpty ? Color.gray : Color.green)
                            .cornerRadius(10)
                        }
                        .disabled(filteredTransactions.isEmpty)
                    }

                    if filteredTransactions.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("所选时间范围内没有数据")
                                .foregroundColor(.secondary)
                            Text("请选择其他时间范围或先添加一些交易记录")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
                    }
                }
                .padding()
            }
            .navigationTitle("数据导出")
            .sheet(isPresented: $showingActivityView) {
                if let fileURL = exportedFileURL {
                    #if os(iOS)
                    ActivityViewController(activityItems: [fileURL])
                    #endif
                }
            }
            .sheet(isPresented: $showingPreview) {
                NavigationView {
                    ScrollView {
                        Text(previewData)
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                    }
                    .navigationTitle("数据预览")
                    // Toolbar disabled for compilation
                }
            }
        }
    }

    private func previewExportData() {
        switch selectedFormat {
        case .csv:
            previewData = dataManager.exportDataAsCSV(transactions: filteredTransactions)
        case .txt:
            previewData = dataManager.exportDataAsText(transactions: filteredTransactions)
        }
        showingPreview = true
    }

    private func exportData() {
        let fileName = "VoiceBudget_\(selectedDateRange.rawValue)_\(Date().timeIntervalSince1970).\(selectedFormat.fileExtension)"
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentDirectory.appendingPathComponent(fileName)

        let content: String
        switch selectedFormat {
        case .csv:
            content = dataManager.exportDataAsCSV(transactions: filteredTransactions)
        case .txt:
            content = dataManager.exportDataAsText(transactions: filteredTransactions)
        }

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            exportedFileURL = fileURL
            showingActivityView = true
        } catch {
            print("导出失败: \(error.localizedDescription)")
        }
    }
}

// MARK: - Activity View Controller
#if os(iOS)
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - Phase 3: Advanced Analytics Data Models

// 收入趋势分析数据模型
struct IncomeTrendData: Codable {
    let monthlyData: [MonthlyIncomeData]
    let quarterlyData: [QuarterlyIncomeData]
    let growthRate: Double
    let stability: IncomeStability
    let prediction: IncomePrediction

    struct MonthlyIncomeData: Codable {
        let month: String
        let income: Double
        let expenseRatio: Double
        let transactionCount: Int
    }

    struct QuarterlyIncomeData: Codable {
        let quarter: String
        let income: Double
        let growthRate: Double
    }

    struct IncomeStability: Codable {
        let score: Double // 0-100, 100为最稳定
        let volatility: Double // 波动率
        let consistencyRating: String // "稳定", "波动", "不稳定"
    }

    struct IncomePrediction: Codable {
        let nextMonthIncome: Double
        let confidence: Double
        let trend: String // "上升", "下降", "稳定"
    }
}

// 收支对比分析数据模型
struct AdvancedComparisonData: Codable {
    let categoryComparisons: [CategoryComparison]
    let monthlyComparisons: [MonthlyComparison]
    let savingRateTrend: [SavingRatePoint]
    let expenseOptimization: ExpenseOptimization

    struct CategoryComparison: Codable {
        let category: String
        let currentAmount: Double
        let previousAmount: Double
        let changeRate: Double
        let trend: String
        let isIncome: Bool
    }

    struct MonthlyComparison: Codable {
        let month: String
        let income: Double
        let expense: Double
        let netIncome: Double
        let savingRate: Double
    }

    struct SavingRatePoint: Codable {
        let date: String
        let rate: Double
    }

    struct ExpenseOptimization: Codable {
        let highestExpenseCategory: String
        let optimizationSuggestions: [String]
        let potentialSavings: Double
    }
}

// 收入预期管理数据模型
struct IncomeExpectationData: Codable {
    let goals: [IncomeGoal]
    let achievements: [GoalAchievement]
    let recommendations: [IncomeRecommendation]

    struct IncomeGoal: Codable {
        let id: UUID
        let category: String
        let targetAmount: Double
        let currentAmount: Double
        let timeframe: String
        let progress: Double
    }

    struct GoalAchievement: Codable {
        let goalId: UUID
        let achievedAt: Date
        let finalAmount: Double
        let overachievement: Double
    }

    struct IncomeRecommendation: Codable {
        let type: String
        let description: String
        let potentialIncrease: Double
        let priority: Int
    }
}

// MARK: - Phase 3: Advanced Analytics Manager Extension

extension DataManager {

    // MARK: - 收入趋势分析功能

    /// 分析收入趋势数据
    func analyzeIncomeTrends() -> IncomeTrendData {
        let monthlyData = generateMonthlyIncomeData()
        let quarterlyData = generateQuarterlyIncomeData()
        let growthRate = calculateIncomeGrowthRate()
        let stability = analyzeIncomeStability()
        let prediction = predictFutureIncome()

        return IncomeTrendData(
            monthlyData: monthlyData,
            quarterlyData: quarterlyData,
            growthRate: growthRate,
            stability: stability,
            prediction: prediction
        )
    }

    /// 生成月度收入数据
    private func generateMonthlyIncomeData() -> [IncomeTrendData.MonthlyIncomeData] {
        let calendar = Calendar.current
        let now = Date()
        var monthlyData: [IncomeTrendData.MonthlyIncomeData] = []

        // 获取过去6个月的数据
        for i in 0..<6 {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now) else { continue }

            let monthTransactions = transactions.filter {
                calendar.isDate($0.date, equalTo: monthDate, toGranularity: .month)
            }

            let monthIncome = monthTransactions.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount }
            let monthExpense = monthTransactions.filter { $0.isExpense }.reduce(0) { $0 + $1.amount }
            let expenseRatio = monthIncome > 0 ? (monthExpense / monthIncome) * 100 : 0
            let transactionCount = monthTransactions.count

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年M月"
            let monthString = formatter.string(from: monthDate)

            monthlyData.append(IncomeTrendData.MonthlyIncomeData(
                month: monthString,
                income: monthIncome,
                expenseRatio: expenseRatio,
                transactionCount: transactionCount
            ))
        }

        return monthlyData.reversed() // 按时间正序排列
    }

    /// 生成季度收入数据
    private func generateQuarterlyIncomeData() -> [IncomeTrendData.QuarterlyIncomeData] {
        let calendar = Calendar.current
        let now = Date()
        var quarterlyData: [IncomeTrendData.QuarterlyIncomeData] = []

        // 获取过去4个季度的数据
        for i in 0..<4 {
            guard let quarterStart = calendar.date(byAdding: .month, value: -i*3, to: now) else { continue }
            guard let quarterEnd = calendar.date(byAdding: .month, value: -(i-1)*3, to: quarterStart) else { continue }

            let quarterTransactions = transactions.filter {
                $0.date >= quarterStart && $0.date < quarterEnd && !$0.isExpense
            }

            let quarterIncome = quarterTransactions.reduce(0) { $0 + $1.amount }

            // 计算与上季度的增长率
            let previousQuarterStart = calendar.date(byAdding: .month, value: -3, to: quarterStart) ?? quarterStart
            let previousQuarterTransactions = transactions.filter {
                $0.date >= previousQuarterStart && $0.date < quarterStart && !$0.isExpense
            }
            let previousQuarterIncome = previousQuarterTransactions.reduce(0) { $0 + $1.amount }
            let growthRate = previousQuarterIncome > 0 ? ((quarterIncome - previousQuarterIncome) / previousQuarterIncome) * 100 : 0

            let year = calendar.component(.year, from: quarterStart)
            let month = calendar.component(.month, from: quarterStart)
            let quarter = (month - 1) / 3 + 1
            let quarterString = "\(year)年Q\(quarter)"

            quarterlyData.append(IncomeTrendData.QuarterlyIncomeData(
                quarter: quarterString,
                income: quarterIncome,
                growthRate: growthRate
            ))
        }

        return quarterlyData.reversed()
    }

    /// 计算收入增长率
    private func calculateIncomeGrowthRate() -> Double {
        let calendar = Calendar.current
        let now = Date()

        // 当月收入
        let currentMonthIncome = transactions.filter {
            calendar.isDate($0.date, equalTo: now, toGranularity: .month) && !$0.isExpense
        }.reduce(0) { $0 + $1.amount }

        // 上月收入
        guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) else { return 0 }
        let lastMonthIncome = transactions.filter {
            calendar.isDate($0.date, equalTo: lastMonth, toGranularity: .month) && !$0.isExpense
        }.reduce(0) { $0 + $1.amount }

        if lastMonthIncome > 0 {
            return ((currentMonthIncome - lastMonthIncome) / lastMonthIncome) * 100
        }
        return 0
    }

    /// 分析收入稳定性
    private func analyzeIncomeStability() -> IncomeTrendData.IncomeStability {
        let monthlyData = generateMonthlyIncomeData()
        let incomes = monthlyData.map { $0.income }

        guard incomes.count > 1 else {
            return IncomeTrendData.IncomeStability(score: 50, volatility: 0, consistencyRating: "数据不足")
        }

        // 计算标准差和平均值
        let average = incomes.reduce(0, +) / Double(incomes.count)
        let variance = incomes.map { pow($0 - average, 2) }.reduce(0, +) / Double(incomes.count)
        let standardDeviation = sqrt(variance)

        // 计算变异系数作为波动率
        let volatility = average > 0 ? (standardDeviation / average) * 100 : 0

        // 计算稳定性评分 (0-100)
        let stabilityScore = max(0, min(100, 100 - volatility))

        // 确定稳定性等级
        let consistencyRating: String
        if stabilityScore >= 80 {
            consistencyRating = "稳定"
        } else if stabilityScore >= 60 {
            consistencyRating = "较稳定"
        } else if stabilityScore >= 40 {
            consistencyRating = "波动"
        } else {
            consistencyRating = "不稳定"
        }

        return IncomeTrendData.IncomeStability(
            score: stabilityScore,
            volatility: volatility,
            consistencyRating: consistencyRating
        )
    }

    /// 预测未来收入
    private func predictFutureIncome() -> IncomeTrendData.IncomePrediction {
        let monthlyData = generateMonthlyIncomeData()
        let incomes = monthlyData.map { $0.income }

        guard incomes.count >= 3 else {
            return IncomeTrendData.IncomePrediction(
                nextMonthIncome: 0,
                confidence: 0,
                trend: "数据不足"
            )
        }

        // 简单线性回归预测
        let n = Double(incomes.count)
        let x = Array(1...incomes.count).map { Double($0) }
        let y = incomes

        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).map { $0 * $1 }.reduce(0, +)
        let sumXX = x.map { $0 * $0 }.reduce(0, +)

        let slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
        let intercept = (sumY - slope * sumX) / n

        let nextMonthIncome = slope * (n + 1) + intercept

        // 计算预测置信度
        let predictions = x.map { slope * $0 + intercept }
        let errors = zip(y, predictions).map { abs($0 - $1) }
        let meanError = errors.reduce(0, +) / Double(errors.count)
        let confidence = max(0, min(100, 100 - (meanError / (sumY / n)) * 100))

        // 确定趋势
        let trend: String
        if slope > 100 {
            trend = "上升"
        } else if slope < -100 {
            trend = "下降"
        } else {
            trend = "稳定"
        }

        return IncomeTrendData.IncomePrediction(
            nextMonthIncome: max(0, nextMonthIncome),
            confidence: confidence,
            trend: trend
        )
    }

    // MARK: - 收支对比分析增强

    /// 高级收支对比分析
    func analyzeAdvancedComparison() -> AdvancedComparisonData {
        let categoryComparisons = generateCategoryComparisons()
        let monthlyComparisons = generateMonthlyComparisons()
        let savingRateTrend = generateSavingRateTrend()
        let expenseOptimization = analyzeExpenseOptimization()

        return AdvancedComparisonData(
            categoryComparisons: categoryComparisons,
            monthlyComparisons: monthlyComparisons,
            savingRateTrend: savingRateTrend,
            expenseOptimization: expenseOptimization
        )
    }

    /// 生成分类对比数据
    private func generateCategoryComparisons() -> [AdvancedComparisonData.CategoryComparison] {
        let calendar = Calendar.current
        let now = Date()

        guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) else { return [] }

        var comparisons: [AdvancedComparisonData.CategoryComparison] = []

        // 分析支出分类
        for category in expenseCategories {
            let currentAmount = getCategoryAmountForMonth(category: category, date: now, isExpense: true)
            let previousAmount = getCategoryAmountForMonth(category: category, date: lastMonth, isExpense: true)
            let changeRate = previousAmount > 0 ? ((currentAmount - previousAmount) / previousAmount) * 100 : 0

            let trend: String
            if changeRate > 5 {
                trend = "上升"
            } else if changeRate < -5 {
                trend = "下降"
            } else {
                trend = "稳定"
            }

            comparisons.append(AdvancedComparisonData.CategoryComparison(
                category: category,
                currentAmount: currentAmount,
                previousAmount: previousAmount,
                changeRate: changeRate,
                trend: trend,
                isIncome: false
            ))
        }

        // 分析收入分类
        for category in incomeCategories {
            let currentAmount = getCategoryAmountForMonth(category: category, date: now, isExpense: false)
            let previousAmount = getCategoryAmountForMonth(category: category, date: lastMonth, isExpense: false)
            let changeRate = previousAmount > 0 ? ((currentAmount - previousAmount) / previousAmount) * 100 : 0

            let trend: String
            if changeRate > 5 {
                trend = "上升"
            } else if changeRate < -5 {
                trend = "下降"
            } else {
                trend = "稳定"
            }

            comparisons.append(AdvancedComparisonData.CategoryComparison(
                category: category,
                currentAmount: currentAmount,
                previousAmount: previousAmount,
                changeRate: changeRate,
                trend: trend,
                isIncome: true
            ))
        }

        return comparisons
    }

    /// 获取指定月份分类金额
    private func getCategoryAmountForMonth(category: String, date: Date, isExpense: Bool) -> Double {
        let calendar = Calendar.current
        return transactions.filter {
            calendar.isDate($0.date, equalTo: date, toGranularity: .month) &&
            $0.category == category &&
            $0.isExpense == isExpense
        }.reduce(0) { $0 + $1.amount }
    }

    /// 生成月度对比数据
    private func generateMonthlyComparisons() -> [AdvancedComparisonData.MonthlyComparison] {
        let calendar = Calendar.current
        let now = Date()
        var comparisons: [AdvancedComparisonData.MonthlyComparison] = []

        // 获取过去6个月的对比数据
        for i in 0..<6 {
            guard let monthDate = calendar.date(byAdding: .month, value: -i, to: now) else { continue }

            let monthTransactions = transactions.filter {
                calendar.isDate($0.date, equalTo: monthDate, toGranularity: .month)
            }

            let income = monthTransactions.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount }
            let expense = monthTransactions.filter { $0.isExpense }.reduce(0) { $0 + $1.amount }
            let netIncome = income - expense
            let savingRate = income > 0 ? (netIncome / income) * 100 : 0

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年M月"
            let monthString = formatter.string(from: monthDate)

            comparisons.append(AdvancedComparisonData.MonthlyComparison(
                month: monthString,
                income: income,
                expense: expense,
                netIncome: netIncome,
                savingRate: savingRate
            ))
        }

        return comparisons.reversed()
    }

    /// 生成储蓄率趋势数据
    private func generateSavingRateTrend() -> [AdvancedComparisonData.SavingRatePoint] {
        let monthlyComparisons = generateMonthlyComparisons()
        return monthlyComparisons.map {
            AdvancedComparisonData.SavingRatePoint(date: $0.month, rate: $0.savingRate)
        }
    }

    /// 分析支出优化建议
    private func analyzeExpenseOptimization() -> AdvancedComparisonData.ExpenseOptimization {
        let categoryExpenses = expenseCategories.map { category in
            (category, getCategoryExpense(category: category))
        }.sorted { $0.1 > $1.1 }

        let highestExpenseCategory = categoryExpenses.first?.0 ?? "无"
        let highestAmount = categoryExpenses.first?.1 ?? 0

        var suggestions: [String] = []
        var potentialSavings: Double = 0

        // 基于数据生成优化建议
        if highestAmount > monthlyExpense * 0.3 {
            suggestions.append("考虑减少\(highestExpenseCategory)支出，占比过高")
            potentialSavings += highestAmount * 0.1
        }

        // 检查异常高的分类支出
        for (category, amount) in categoryExpenses.prefix(3) {
            if amount > 0 {
                let avgAmount = monthlyExpense / Double(expenseCategories.count)
                if amount > avgAmount * 2 {
                    suggestions.append("关注\(category)支出，建议制定预算限制")
                    potentialSavings += amount * 0.05
                }
            }
        }

        // 检查小额频繁支出
        let smallTransactions = transactions.filter { $0.isExpense && $0.amount < 50 && isCurrentMonth($0.date) }
        if smallTransactions.count > 20 {
            suggestions.append("减少小额支出频次，积少成多")
            potentialSavings += smallTransactions.reduce(0) { $0 + $1.amount } * 0.3
        }

        if suggestions.isEmpty {
            suggestions.append("当前支出结构合理，继续保持")
        }

        return AdvancedComparisonData.ExpenseOptimization(
            highestExpenseCategory: highestExpenseCategory,
            optimizationSuggestions: suggestions,
            potentialSavings: potentialSavings
        )
    }

    // MARK: - 收入预期管理

    /// 分析收入预期数据
    func analyzeIncomeExpectations() -> IncomeExpectationData {
        let goals = generateIncomeGoals()
        let achievements = generateGoalAchievements()
        let recommendations = generateIncomeRecommendations()

        return IncomeExpectationData(
            goals: goals,
            achievements: achievements,
            recommendations: recommendations
        )
    }

    // MARK: - Phase 3: Smart Learning System Data Models

    // 用户偏好学习数据模型
    struct UserLearningData: Codable {
        var categoryPreferences: [String: CategoryPreference] = [:]
        var timePatterns: [TimePattern] = []
        var amountPatterns: [AmountPattern] = []
        var behaviorModel: BehaviorModel = BehaviorModel()
        var lastLearningUpdate: Date = Date()

        struct CategoryPreference: Codable {
            let category: String
            var frequency: Int = 0
            var averageAmount: Double = 0
            var lastUsed: Date = Date()
            var confidence: Double = 0
            let isIncome: Bool

            init(category: String, isIncome: Bool) {
                self.category = category
                self.frequency = 0
                self.averageAmount = 0
                self.lastUsed = Date()
                self.confidence = 0
                self.isIncome = isIncome
            }
        }

        struct TimePattern: Codable {
            let hour: Int
            let weekday: Int
            let category: String
            var frequency: Int = 0
            let isIncome: Bool

            init(hour: Int, weekday: Int, category: String, isIncome: Bool) {
                self.hour = hour
                self.weekday = weekday
                self.category = category
                self.frequency = 0
                self.isIncome = isIncome
            }
        }

        struct AmountPattern: Codable {
            let amountRange: String // "0-50", "50-100", "100-500", "500+"
            let category: String
            var frequency: Int = 0
            let isIncome: Bool

            init(amountRange: String, category: String, isIncome: Bool) {
                self.amountRange = amountRange
                self.category = category
                self.frequency = 0
                self.isIncome = isIncome
            }
        }

        struct BehaviorModel: Codable {
            var dailyTransactionCount: Double = 0
            var preferredRecordingTime: Int = 18 // 默认18点
            var averageTransactionAmount: Double = 0
            var recordingConsistency: Double = 0
            var categoryDiversity: Double = 0
        }
    }

    // 注意：SmartCategoryRecommendation已在文件顶部定义，此处不重复定义

    // 注意：AnomalyDetectionResult已在文件顶部定义，此处不重复定义

    // 注意：SmartInsight已在文件顶部定义，此处不重复定义

    // MARK: - 用户偏好学习系统

    /// 获取用户学习数据
    private var userLearningData: UserLearningData {
        get {
            let decoder = JSONDecoder()
            return loadDataItem(UserLearningData.self, key: "userLearningData", decoder: decoder, defaultValue: UserLearningData(), itemName: "用户学习数据")
        }
        set {
            let encoder = JSONEncoder()
            saveDataItem(newValue, key: "userLearningData", encoder: encoder, itemName: "用户学习数据")
        }
    }

    /// 学习用户偏好
    func learnFromTransaction(_ transaction: Transaction) {
        var learningData = userLearningData

        // 更新分类偏好
        updateCategoryPreference(&learningData, transaction: transaction)

        // 更新时间模式
        updateTimePattern(&learningData, transaction: transaction)

        // 更新金额模式
        updateAmountPattern(&learningData, transaction: transaction)

        // 更新行为模型
        updateBehaviorModel(&learningData, transaction: transaction)

        learningData.lastLearningUpdate = Date()
        userLearningData = learningData
    }

    /// 更新分类偏好
    private func updateCategoryPreference(_ learningData: inout UserLearningData, transaction: Transaction) {
        let key = "\(transaction.category)_\(transaction.isExpense ? "expense" : "income")"

        if var preference = learningData.categoryPreferences[key] {
            preference.frequency += 1
            preference.averageAmount = (preference.averageAmount * Double(preference.frequency - 1) + transaction.amount) / Double(preference.frequency)
            preference.lastUsed = transaction.date
            preference.confidence = min(100, Double(preference.frequency) * 2.5)
            learningData.categoryPreferences[key] = preference
        } else {
            var newPreference = UserLearningData.CategoryPreference(
                category: transaction.category,
                isIncome: !transaction.isExpense
            )
            newPreference.frequency = 1
            newPreference.averageAmount = transaction.amount
            newPreference.lastUsed = transaction.date
            newPreference.confidence = 2.5
            learningData.categoryPreferences[key] = newPreference
        }
    }

    /// 更新时间模式
    private func updateTimePattern(_ learningData: inout UserLearningData, transaction: Transaction) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: transaction.date)
        let weekday = calendar.component(.weekday, from: transaction.date)

        if let index = learningData.timePatterns.firstIndex(where: {
            $0.hour == hour && $0.weekday == weekday && $0.category == transaction.category && $0.isIncome == !transaction.isExpense
        }) {
            learningData.timePatterns[index].frequency += 1
        } else {
            var newPattern = UserLearningData.TimePattern(
                hour: hour,
                weekday: weekday,
                category: transaction.category,
                isIncome: !transaction.isExpense
            )
            newPattern.frequency = 1
            learningData.timePatterns.append(newPattern)
        }

        // 保持时间模式数组大小合理
        if learningData.timePatterns.count > 200 {
            let sortedPatterns = learningData.timePatterns.sorted { $0.frequency > $1.frequency }
            learningData.timePatterns = Array(sortedPatterns.prefix(200))
        }
    }

    /// 更新金额模式
    private func updateAmountPattern(_ learningData: inout UserLearningData, transaction: Transaction) {
        let amountRange: String
        switch transaction.amount {
        case 0...50:
            amountRange = "0-50"
        case 50...100:
            amountRange = "50-100"
        case 100...500:
            amountRange = "100-500"
        default:
            amountRange = "500+"
        }

        if let index = learningData.amountPatterns.firstIndex(where: {
            $0.amountRange == amountRange && $0.category == transaction.category && $0.isIncome == !transaction.isExpense
        }) {
            learningData.amountPatterns[index].frequency += 1
        } else {
            var newAmountPattern = UserLearningData.AmountPattern(
                amountRange: amountRange,
                category: transaction.category,
                isIncome: !transaction.isExpense
            )
            newAmountPattern.frequency = 1
            learningData.amountPatterns.append(newAmountPattern)
        }

        // 保持金额模式数组大小合理
        if learningData.amountPatterns.count > 150 {
            let sortedPatterns = learningData.amountPatterns.sorted { $0.frequency > $1.frequency }
            learningData.amountPatterns = Array(sortedPatterns.prefix(150))
        }
    }

    /// 更新行为模型
    private func updateBehaviorModel(_ learningData: inout UserLearningData, transaction: Transaction) {
        let calendar = Calendar.current

        // 更新偏好记录时间
        let totalTransactions = transactions.count
        if totalTransactions > 0 {
            let timeSum = transactions.reduce(0) { sum, t in
                sum + calendar.component(.hour, from: t.date)
            }
            learningData.behaviorModel.preferredRecordingTime = timeSum / totalTransactions
        }

        // 更新平均交易金额
        learningData.behaviorModel.averageTransactionAmount = (learningData.behaviorModel.averageTransactionAmount * Double(totalTransactions - 1) + transaction.amount) / Double(totalTransactions)

        // 更新分类多样性
        let uniqueCategories = Set(transactions.map { $0.category }).count
        learningData.behaviorModel.categoryDiversity = Double(uniqueCategories)

        // 更新记录一致性（基于连击天数）
        learningData.behaviorModel.recordingConsistency = min(100, Double(userStats.currentStreak) * 5)
    }

    // MARK: - 智能分类推荐系统

    /// 智能推荐分类
    func getSmartCategoryRecommendation(amount: Double, description: String, time: Date = Date()) -> SmartCategoryRecommendation? {
        let learningData = userLearningData
        var scores: [String: Double] = [:]

        // 基于时间模式评分
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)
        let weekday = calendar.component(.weekday, from: time)

        for pattern in learningData.timePatterns {
            if pattern.hour == hour && pattern.weekday == weekday {
                let key = "\(pattern.category)_\(pattern.isIncome ? "income" : "expense")"
                scores[key, default: 0] += Double(pattern.frequency) * 0.3
            }
        }

        // 基于金额模式评分
        let amountRange: String
        switch amount {
        case 0...50: amountRange = "0-50"
        case 50...100: amountRange = "50-100"
        case 100...500: amountRange = "100-500"
        default: amountRange = "500+"
        }

        for pattern in learningData.amountPatterns {
            if pattern.amountRange == amountRange {
                let key = "\(pattern.category)_\(pattern.isIncome ? "income" : "expense")"
                scores[key, default: 0] += Double(pattern.frequency) * 0.4
            }
        }

        // 基于频率评分
        for (key, preference) in learningData.categoryPreferences {
            scores[key, default: 0] += preference.confidence * 0.3
        }

        // 基于描述关键词匹配（简化实现）
        scores = enhanceScoresWithKeywords(scores: scores, description: description)

        // 选择最高分的推荐
        guard let bestMatch = scores.max(by: { $0.value < $1.value }),
              bestMatch.value > 10 else {
            return nil
        }

        let parts = bestMatch.key.components(separatedBy: "_")
        guard parts.count == 2 else { return nil }

        let category = parts[0]
        let isIncome = parts[1] == "income"

        // 生成备选分类
        let alternatives = scores
            .filter { $0.key != bestMatch.key && $0.value > bestMatch.value * 0.6 }
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key.components(separatedBy: "_")[0] }

        let reason = generateRecommendationReason(category: category, isIncome: isIncome, time: time, amount: amount)

        return SmartCategoryRecommendation(
            category: category,
            confidence: min(100, bestMatch.value),
            reason: reason,
            isIncome: isIncome,
            alternativeCategories: Array(alternatives)
        )
    }

    /// 使用关键词增强评分
    private func enhanceScoresWithKeywords(scores: [String: Double], description: String) -> [String: Double] {
        var enhancedScores = scores

        // 关键词映射
        let keywordMappings: [String: [(category: String, isIncome: Bool)]] = [
            "吃饭": [("餐饮", false)],
            "午餐": [("餐饮", false)],
            "晚餐": [("餐饮", false)],
            "咖啡": [("餐饮", false)],
            "打车": [("交通", false)],
            "地铁": [("交通", false)],
            "公交": [("交通", false)],
            "买": [("购物", false)],
            "购物": [("购物", false)],
            "工资": [("工资薪酬", true)],
            "薪水": [("工资薪酬", true)],
            "收入": [("工资薪酬", true)],
            "奖金": [("奖金补贴", true)],
            "退款": [("退款返现", true)],
            "返现": [("退款返现", true)]
        ]

        for (keyword, mappings) in keywordMappings {
            if description.contains(keyword) {
                for mapping in mappings {
                    let key = "\(mapping.category)_\(mapping.isIncome ? "income" : "expense")"
                    enhancedScores[key, default: 0] += 20.0
                }
            }
        }

        return enhancedScores
    }

    /// 生成推荐原因
    private func generateRecommendationReason(category: String, isIncome: Bool, time: Date, amount: Double) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: time)

        if hour >= 11 && hour <= 13 && category == "餐饮" {
            return "基于午餐时间模式"
        } else if hour >= 18 && hour <= 20 && category == "餐饮" {
            return "基于晚餐时间模式"
        } else if hour >= 7 && hour <= 9 && category == "交通" {
            return "基于通勤时间模式"
        } else if isIncome && category.contains("工资") {
            return "基于收入类型识别"
        } else {
            return "基于历史使用习惯"
        }
    }

    // MARK: - 异常检测系统

    /// 检测交易异常
    func detectAnomalies(for transaction: Transaction) -> AnomalyDetectionResult? {
        var anomalies: [AnomalyDetectionResult] = []

        // 检测异常金额
        if let amountAnomaly = detectAmountAnomaly(transaction) {
            anomalies.append(amountAnomaly)
        }

        // 检测异常时间
        if let timeAnomaly = detectTimeAnomaly(transaction) {
            anomalies.append(timeAnomaly)
        }

        // 检测重复交易
        if let duplicateAnomaly = detectDuplicateTransaction(transaction) {
            anomalies.append(duplicateAnomaly)
        }

        // 检测分类异常
        if let categoryAnomaly = detectCategoryAnomaly(transaction) {
            anomalies.append(categoryAnomaly)
        }

        // 返回最高严重级别的异常
        return anomalies.max { $0.severity.rawValue < $1.severity.rawValue }
    }

    /// 检测异常金额
    private func detectAmountAnomaly(_ transaction: Transaction) -> AnomalyDetectionResult? {
        let similarTransactions = transactions.filter {
            $0.category == transaction.category && $0.isExpense == transaction.isExpense
        }

        guard similarTransactions.count >= 3 else { return nil }

        let amounts = similarTransactions.map { $0.amount }
        let average = amounts.reduce(0, +) / Double(amounts.count)
        let variance = amounts.map { pow($0 - average, 2) }.reduce(0, +) / Double(amounts.count)
        let standardDeviation = sqrt(variance)

        let deviation = abs(transaction.amount - average)
        let zScore = standardDeviation > 0 ? deviation / standardDeviation : 0

        if zScore > 3.0 { // 超过3个标准差
            let severity: AnomalyDetectionResult.AnomalySeverity
            if zScore > 5.0 {
                severity = .critical
            } else if zScore > 4.0 {
                severity = .high
            } else {
                severity = .medium
            }

            return AnomalyDetectionResult(
                transactionId: transaction.id,
                anomalyType: .unusualAmount,
                severity: severity,
                description: "金额异常：¥\(String(format: "%.2f", transaction.amount))，平均值为¥\(String(format: "%.2f", average))",
                suggestions: [
                    "请确认金额是否正确",
                    "检查是否输入了小数点位置错误",
                    "考虑是否需要调整分类"
                ],
                confidence: min(100, zScore * 20)
            )
        }

        return nil
    }

    /// 检测异常时间
    private func detectTimeAnomaly(_ transaction: Transaction) -> AnomalyDetectionResult? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: transaction.date)

        // 检测深夜记账（0-5点）
        if hour >= 0 && hour <= 5 {
            return AnomalyDetectionResult(
                transactionId: transaction.id,
                anomalyType: .unusualTime,
                severity: .medium,
                description: "深夜记账：\(hour):00",
                suggestions: [
                    "确认记账时间是否正确",
                    "考虑是否应该记录在前一天"
                ],
                confidence: 70
            )
        }

        return nil
    }

    /// 检测重复交易
    private func detectDuplicateTransaction(_ transaction: Transaction) -> AnomalyDetectionResult? {
        let recentTransactions = transactions.filter {
            abs($0.date.timeIntervalSince(transaction.date)) < 300 && // 5分钟内
            $0.id != transaction.id
        }

        let duplicates = recentTransactions.filter {
            abs($0.amount - transaction.amount) < 0.01 &&
            $0.category == transaction.category &&
            $0.isExpense == transaction.isExpense
        }

        if !duplicates.isEmpty {
            return AnomalyDetectionResult(
                transactionId: transaction.id,
                anomalyType: .duplicateTransaction,
                severity: .high,
                description: "可能的重复交易：相同金额、分类和时间",
                suggestions: [
                    "检查是否重复记录了同一笔交易",
                    "确认金额和分类信息"
                ],
                confidence: 85
            )
        }

        return nil
    }

    /// 检测分类异常
    private func detectCategoryAnomaly(_ transaction: Transaction) -> AnomalyDetectionResult? {
        // 简化实现：检查分类是否存在于预定义列表中
        let validCategories = transaction.isExpense ? expenseCategories : incomeCategories

        if !validCategories.contains(transaction.category) {
            return AnomalyDetectionResult(
                transactionId: transaction.id,
                anomalyType: .categoryMismatch,
                severity: .low,
                description: "分类不在预定义列表中：\(transaction.category)",
                suggestions: [
                    "检查分类名称是否正确",
                    "考虑使用标准分类名称"
                ],
                confidence: 60
            )
        }

        return nil
    }

    // MARK: - 智能推荐系统

    /// 获取智能分类推荐
    func getSmartCategoryRecommendations(amount: Double, description: String, time: Date, isExpense: Bool) -> [SmartCategoryRecommendation] {
        var recommendations: [SmartCategoryRecommendation] = []
        let availableCategories = isExpense ? expenseCategories : incomeCategories

        // 基于金额范围推荐
        for category in availableCategories {
            let categoryTransactions = transactions.filter {
                $0.category == category && $0.isExpense == isExpense
            }

            if !categoryTransactions.isEmpty {
                let averageAmount = categoryTransactions.reduce(0) { $0 + $1.amount } / Double(categoryTransactions.count)
                let confidence = 1.0 - abs(amount - averageAmount) / max(amount, averageAmount)

                if confidence > 0.3 {
                    recommendations.append(SmartCategoryRecommendation(
                        category: category,
                        confidence: confidence,
                        reason: "基于您的历史消费模式推荐",
                        isIncome: !isExpense
                    ))
                }
            }
        }

        // 基于描述关键词推荐
        let keywords = description.lowercased().components(separatedBy: .whitespaces)
        for keyword in keywords {
            for category in availableCategories {
                if category.lowercased().contains(keyword) || keyword.contains(category.lowercased()) {
                    recommendations.append(SmartCategoryRecommendation(
                        category: category,
                        confidence: 0.8,
                        reason: "基于描述关键词匹配",
                        isIncome: !isExpense
                    ))
                }
            }
        }

        // 去重并排序
        var uniqueRecommendations: [SmartCategoryRecommendation] = []
        for recommendation in recommendations {
            if !uniqueRecommendations.contains(where: { $0.category == recommendation.category }) {
                uniqueRecommendations.append(recommendation)
            }
        }

        return uniqueRecommendations.sorted { $0.confidence > $1.confidence }.prefix(3).map { $0 }
    }

    // MARK: - 智能洞察生成

    /// 生成智能洞察
    func generateSmartInsights() -> [SmartInsight] {
        var insights: [SmartInsight] = []

        // 生成支出模式洞察
        insights.append(contentsOf: generateSpendingPatternInsights())

        // 生成收入机会洞察
        insights.append(contentsOf: generateIncomeOpportunityInsights())

        // 生成预算优化洞察
        insights.append(contentsOf: generateBudgetOptimizationInsights())

        // 生成习惯改进洞察
        insights.append(contentsOf: generateHabitImprovementInsights())

        return insights.sorted { $0.priority < $1.priority }
    }

    /// 生成支出模式洞察
    private func generateSpendingPatternInsights() -> [SmartInsight] {
        var insights: [SmartInsight] = []

        // 分析最大支出分类
        let categoryExpenses = expenseCategories.map { category in
            (category, getCategoryExpense(category: category))
        }.sorted { $0.1 > $1.1 }

        if let topCategory = categoryExpenses.first, topCategory.1 > monthlyExpense * 0.4 {
            insights.append(SmartInsight(
                title: "支出集中度过高",
                description: "\(topCategory.0)占总支出的\(String(format: "%.1f", (topCategory.1 / monthlyExpense) * 100))%，建议分散支出风险",
                type: .spendingPattern,
                priority: 1,
                actionable: true,
                potentialBenefit: "提高财务灵活性"
            ))
        }

        return insights
    }

    /// 生成收入机会洞察
    private func generateIncomeOpportunityInsights() -> [SmartInsight] {
        var insights: [SmartInsight] = []

        let monthlyIncome = transactions.filter { !$0.isExpense && isCurrentMonth($0.date) }.reduce(0) { $0 + $1.amount }

        if monthlyIncome < 5000 {
            insights.append(SmartInsight(
                title: "收入增长机会",
                description: "当前月收入较低，考虑开发副业或兼职收入",
                type: .incomeOpportunity,
                priority: 2,
                actionable: true,
                potentialBenefit: "增加收入来源"
            ))
        }

        return insights
    }

    /// 生成预算优化洞察
    private func generateBudgetOptimizationInsights() -> [SmartInsight] {
        var insights: [SmartInsight] = []

        let budgetUsage = monthlyExpense / budget.monthlyLimit
        if budgetUsage > 0.9 {
            insights.append(SmartInsight(
                title: "预算即将超支",
                description: "本月预算使用已达\(String(format: "%.1f", budgetUsage * 100))%，建议控制支出",
                type: .budgetOptimization,
                priority: 1,
                actionable: true,
                potentialBenefit: "避免超支"
            ))
        }

        return insights
    }

    /// 生成习惯改进洞察
    private func generateHabitImprovementInsights() -> [SmartInsight] {
        var insights: [SmartInsight] = []

        if userStats.currentStreak < 3 {
            insights.append(SmartInsight(
                title: "记账习惯需加强",
                description: "当前连击天数较短，建议坚持每日记账",
                type: .habitImprovement,
                priority: 3,
                actionable: true,
                potentialBenefit: "养成良好记账习惯"
            ))
        }

        return insights
    }

    /// 生成收入目标
    private func generateIncomeGoals() -> [IncomeExpectationData.IncomeGoal] {
        var goals: [IncomeExpectationData.IncomeGoal] = []

        // 为主要收入分类创建目标
        for category in incomeCategories {
            let currentAmount = getCategoryAmountForMonth(category: category, date: Date(), isExpense: false)
            let targetAmount = currentAmount * 1.1 // 目标增长10%
            let progress = targetAmount > 0 ? (currentAmount / targetAmount) * 100 : 0

            goals.append(IncomeExpectationData.IncomeGoal(
                id: UUID(),
                category: category,
                targetAmount: targetAmount,
                currentAmount: currentAmount,
                timeframe: "月度",
                progress: min(100, progress)
            ))
        }

        return goals
    }

    /// 生成目标达成记录
    private func generateGoalAchievements() -> [IncomeExpectationData.GoalAchievement] {
        // 这里可以存储和检索用户的历史目标达成记录
        // 暂时返回空数组，实际实现中会从持久化存储中读取
        return []
    }

    /// 生成收入建议
    private func generateIncomeRecommendations() -> [IncomeExpectationData.IncomeRecommendation] {
        var recommendations: [IncomeExpectationData.IncomeRecommendation] = []

        let monthlyIncome = transactions.filter { !$0.isExpense && isCurrentMonth($0.date) }.reduce(0) { $0 + $1.amount }
        let categoryIncomes = incomeCategories.map { category in
            (category, getCategoryAmountForMonth(category: category, date: Date(), isExpense: false))
        }.sorted { $0.1 > $1.1 }

        // 基于数据生成建议
        if monthlyIncome < 3000 {
            recommendations.append(IncomeExpectationData.IncomeRecommendation(
                type: "增收",
                description: "考虑开发副业收入来源",
                potentialIncrease: 1000,
                priority: 1
            ))
        }

        if categoryIncomes.first?.1 ?? 0 > monthlyIncome * 0.8 {
            recommendations.append(IncomeExpectationData.IncomeRecommendation(
                type: "多样化",
                description: "收入来源过于单一，建议多样化收入结构",
                potentialIncrease: monthlyIncome * 0.2,
                priority: 2
            ))
        }

        recommendations.append(IncomeExpectationData.IncomeRecommendation(
            type: "记录",
            description: "保持规律记账，更好地追踪收入变化",
            potentialIncrease: 0,
            priority: 3
        ))

        return recommendations
    }
}

// MARK: - Phase 3: Advanced Analytics Views

// 高级统计分析主视图
struct AdvancedAnalyticsView: View {
    @EnvironmentObject var dataManager: DataManager
    @State private var selectedTab = 0

    var body: some View {
        NavigationView {
            VStack {
                Picker("分析类型", selection: $selectedTab) {
                    Text("收入趋势").tag(0)
                    Text("收支对比").tag(1)
                    Text("收入目标").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                TabView(selection: $selectedTab) {
                    IncomeTrendAnalysisView()
                        .tag(0)
                    AdvancedComparisonView()
                        .tag(1)
                    IncomeExpectationView()
                        .tag(2)
                }
                #if os(iOS)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                #endif
            }
            .navigationTitle("高级分析")
            #if os(iOS)
.navigationBarTitleDisplayMode(.large)
#endif
        }
    }
}

// 收入趋势分析视图
struct IncomeTrendAnalysisView: View {
    @EnvironmentObject var dataManager: DataManager

    var trendData: IncomeTrendData {
        dataManager.analyzeIncomeTrends()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 收入预测卡片
                IncomePredictionCard(prediction: trendData.prediction)

                // 收入稳定性评估
                IncomeStabilityCard(stability: trendData.stability)

                // 月度收入趋势
                MonthlyIncomeTrendCard(monthlyData: trendData.monthlyData)

                // 季度对比
                QuarterlyIncomeCard(quarterlyData: trendData.quarterlyData, growthRate: trendData.growthRate)
            }
            .padding()
        }
    }
}

// 收入预测卡片
struct IncomePredictionCard: View {
    let prediction: IncomeTrendData.IncomePrediction

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "crystal.ball")
                    .foregroundColor(.blue)
                Text("收入预测")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text(prediction.trend)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(trendColor(for: prediction.trend))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("预计下月收入")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("¥" + String(format: "%.0f", prediction.nextMonthIncome))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("预测可信度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", prediction.confidence))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
#if os(iOS)
        .background(Color(UIColor.systemGray6))
#else
        .background(Color(NSColor.controlColor))
#endif
        .cornerRadius(12)
    }

    private func trendColor(for trend: String) -> Color {
        switch trend {
        case "上升": return .green
        case "下降": return .red
        default: return .orange
        }
    }
}

// 收入稳定性卡片
struct IncomeStabilityCard: View {
    let stability: IncomeTrendData.IncomeStability

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.purple)
                Text("收入稳定性")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text(stability.consistencyRating)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(stabilityColor(for: stability.score))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("稳定性评分")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f/100", stability.score))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(stabilityColor(for: stability.score))
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("收入波动率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", stability.volatility))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
            }

            // 稳定性进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
#if os(iOS)
                        .fill(Color(UIColor.systemGray4))
#else
                        .fill(Color(NSColor.controlColor))
#endif
                        .frame(height: 8)

                    Rectangle()
                        .fill(stabilityColor(for: stability.score))
                        .frame(width: geometry.size.width * (stability.score / 100), height: 8)
                }
                .cornerRadius(4)
            }
            .frame(height: 8)
        }
        .padding()
#if os(iOS)
        .background(Color(UIColor.systemGray6))
#else
        .background(Color(NSColor.controlColor))
#endif
        .cornerRadius(12)
    }

    private func stabilityColor(for score: Double) -> Color {
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else if score >= 40 { return .orange }
        else { return .red }
    }
}

// 月度收入趋势卡片
struct MonthlyIncomeTrendCard: View {
    let monthlyData: [IncomeTrendData.MonthlyIncomeData]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.green)
                Text("月度收入趋势")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            if monthlyData.isEmpty {
                Text("暂无足够数据")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(Array(monthlyData.suffix(3)), id: \.month) { data in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(data.month)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("¥" + String(format: "%.0f", data.income))
                                .font(.body)
                                .fontWeight(.semibold)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("支出比")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f%%", data.expenseRatio))
                                .font(.caption)
                                .foregroundColor(data.expenseRatio > 80 ? .red : .orange)
                        }

                        VStack(alignment: .trailing) {
                            Text("笔数")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(data.transactionCount)")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
#if os(iOS)
        .background(Color(UIColor.systemGray6))
#else
        .background(Color(NSColor.controlColor))
#endif
        .cornerRadius(12)
    }
}

// 季度收入卡片
struct QuarterlyIncomeCard: View {
    let quarterlyData: [IncomeTrendData.QuarterlyIncomeData]
    let growthRate: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundColor(.blue)
                Text("季度收入分析")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("月增长率")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.1f%%", growthRate))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(growthRate >= 0 ? .green : .red)
            }

            if quarterlyData.isEmpty {
                Text("暂无足够数据")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(Array(quarterlyData.suffix(2)), id: \.quarter) { data in
                    HStack {
                        Text(data.quarter)
                            .font(.body)
                            .fontWeight(.medium)
                        Spacer()
                        Text("¥" + String(format: "%.0f", data.income))
                            .font(.body)
                            .fontWeight(.semibold)
                        Text(String(format: "%.1f%%", data.growthRate))
                            .font(.caption)
                            .foregroundColor(data.growthRate >= 0 ? .green : .red)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
    #if os(iOS)
                        .background(Color(UIColor.systemGray5))
#else
                        .background(Color(NSColor.controlBackgroundColor))
#endif
                            .cornerRadius(4)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
#if os(iOS)
        .background(Color(UIColor.systemGray6))
#else
        .background(Color(NSColor.controlColor))
#endif
        .cornerRadius(12)
    }
}

// 高级收支对比视图
struct AdvancedComparisonView: View {
    @EnvironmentObject var dataManager: DataManager

    var comparisonData: AdvancedComparisonData {
        dataManager.analyzeAdvancedComparison()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 月度收支趋势
                MonthlyComparisonChart(monthlyComparisons: comparisonData.monthlyComparisons)

                // 分类变化分析
                CategoryChangesCard(categoryComparisons: comparisonData.categoryComparisons)

                // 储蓄率趋势
                SavingRateTrendCard(savingRateTrend: comparisonData.savingRateTrend)

                // 支出优化建议
                ExpenseOptimizationCard(optimization: comparisonData.expenseOptimization)
            }
            .padding()
        }
    }
}

// 月度收支对比图表
struct MonthlyComparisonChart: View {
    let monthlyComparisons: [AdvancedComparisonData.MonthlyComparison]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundColor(.blue)
                Text("月度收支趋势")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            if monthlyComparisons.isEmpty {
                Text("暂无数据")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                // 简化的图表显示最近3个月
                ForEach(Array(monthlyComparisons.suffix(3)), id: \.month) { comparison in
                    VStack(spacing: 8) {
                        HStack {
                            Text(comparison.month)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text("净收入: ¥" + String(format: "%.0f", comparison.netIncome))
                                .font(.caption)
                                .foregroundColor(comparison.netIncome >= 0 ? .green : .red)
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading) {
                                Text("收入")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text("¥" + String(format: "%.0f", comparison.income))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(alignment: .center) {
                                Text("支出")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                Text("¥" + String(format: "%.0f", comparison.expense))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)

                            VStack(alignment: .trailing) {
                                Text("储蓄率")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text(String(format: "%.1f%%", comparison.savingRate))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .padding()
#if os(iOS)
                    .background(Color(UIColor.systemGray6))
#else
                    .background(Color(NSColor.controlColor))
#endif
                    .cornerRadius(8)
                }
            }
        }
        .padding()
#if os(iOS)
        .background(Color(UIColor.systemGray5))
#else
        .background(Color(NSColor.controlBackgroundColor))
#endif
        .cornerRadius(12)
    }
}

// 分类变化分析卡片
struct CategoryChangesCard: View {
    let categoryComparisons: [AdvancedComparisonData.CategoryComparison]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundColor(.orange)
                Text("分类变化分析")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            // 显示变化最大的前5个分类
            let significantChanges = categoryComparisons
                .filter { abs($0.changeRate) > 5 }
                .sorted { abs($0.changeRate) > abs($1.changeRate) }
                .prefix(5)

            if significantChanges.isEmpty {
                Text("各分类支出相对稳定")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(Array(significantChanges), id: \.category) { comparison in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(comparison.category)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(comparison.isIncome ? "收入" : "支出")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text(String(format: "%.1f%%", comparison.changeRate))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(comparison.changeRate >= 0 ? .green : .red)
                            Text(comparison.trend)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
#if os(iOS)
        .background(Color(UIColor.systemGray6))
#else
        .background(Color(NSColor.controlColor))
#endif
        .cornerRadius(12)
    }
}

// 储蓄率趋势卡片
struct SavingRateTrendCard: View {
    let savingRateTrend: [AdvancedComparisonData.SavingRatePoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "percent")
                    .foregroundColor(.green)
                Text("储蓄率趋势")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            if savingRateTrend.isEmpty {
                Text("暂无数据")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                let rateSum = savingRateTrend.map { $0.rate }.reduce(0, +)
                let avgSavingRate = rateSum / Double(savingRateTrend.count)

                HStack {
                    Text("平均储蓄率")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.1f%%", avgSavingRate))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(avgSavingRate >= 20 ? .green : avgSavingRate >= 10 ? .orange : .red)
                }
                .padding()
        #if os(iOS)
        .background(Color(UIColor.systemGray5))
#else
        .background(Color(NSColor.controlBackgroundColor))
#endif
                .cornerRadius(8)

                // 显示最近3个月的储蓄率
                ForEach(Array(savingRateTrend.suffix(3)), id: \.date) { point in
                    HStack {
                        Text(point.date)
                            .font(.caption)
                        Spacer()
                        Text(String(format: "%.1f%%", point.rate))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(point.rate >= 20 ? .green : point.rate >= 10 ? .orange : .red)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
#if os(iOS)
        .background(Color(UIColor.systemGray6))
#else
        .background(Color(NSColor.controlColor))
#endif
        .cornerRadius(12)
    }
}

// 支出优化建议卡片
struct ExpenseOptimizationCard: View {
    let optimization: AdvancedComparisonData.ExpenseOptimization

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb")
                    .foregroundColor(.yellow)
                Text("支出优化建议")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            if optimization.potentialSavings > 0 {
                HStack {
                    Text("潜在节省金额")
                        .font(.subheadline)
                    Spacer()
                    Text("¥" + String(format: "%.0f", optimization.potentialSavings))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .padding()
        #if os(iOS)
        .background(Color(UIColor.systemGray5))
#else
        .background(Color(NSColor.controlBackgroundColor))
#endif
                .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("主要支出分类: \(optimization.highestExpenseCategory)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                ForEach(optimization.optimizationSuggestions, id: \.self) { suggestion in
                    HStack(alignment: .top) {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text(suggestion)
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding()
#if os(iOS)
        .background(Color(UIColor.systemGray6))
#else
        .background(Color(NSColor.controlColor))
#endif
        .cornerRadius(12)
    }
}

// 收入预期管理视图
struct IncomeExpectationView: View {
    @EnvironmentObject var dataManager: DataManager

    var expectationData: IncomeExpectationData {
        dataManager.analyzeIncomeExpectations()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 收入目标进度
                IncomeGoalsCard(goals: expectationData.goals)

                // 收入建议
                IncomeRecommendationsCard(recommendations: expectationData.recommendations)
            }
            .padding()
        }
    }
}

// 收入目标卡片
struct IncomeGoalsCard: View {
    let goals: [IncomeExpectationData.IncomeGoal]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.blue)
                Text("收入目标进度")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            if goals.isEmpty {
                Text("暂无收入目标")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(goals.filter { $0.targetAmount > 0 }, id: \.id) { goal in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(goal.category)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(goal.timeframe)目标")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("¥" + String(format: "%.0f", goal.currentAmount))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("/ ¥" + String(format: "%.0f", goal.targetAmount))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.1f%%", goal.progress))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(goal.progress >= 100 ? .green : .blue)
                        }

                        // 进度条
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
#if os(iOS)
                                    .fill(Color(UIColor.systemGray4))
#else
                                    .fill(Color(NSColor.controlColor))
#endif
                                    .frame(height: 6)

                                Rectangle()
                                    .fill(goal.progress >= 100 ? Color.green : Color.blue)
                                    .frame(width: geometry.size.width * min(goal.progress / 100, 1.0), height: 6)
                            }
                            .cornerRadius(3)
                        }
                        .frame(height: 6)
                    }
                    .padding()
#if os(iOS)
                    .background(Color(UIColor.systemGray6))
#else
                    .background(Color(NSColor.controlColor))
#endif
                    .cornerRadius(8)
                }
            }
        }
        .padding()
#if os(iOS)
        .background(Color(UIColor.systemGray5))
#else
        .background(Color(NSColor.controlBackgroundColor))
#endif
        .cornerRadius(12)
    }
}

// 收入建议卡片
struct IncomeRecommendationsCard: View {
    let recommendations: [IncomeExpectationData.IncomeRecommendation]


    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star")
                    .foregroundColor(.orange)
                Text("收入提升建议")
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            ForEach(Array(recommendations.enumerated()), id: \.offset) { index, recommendation in
                HStack(alignment: .top, spacing: 12) {
                    VStack {
                        Text("\(recommendation.priority)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(priorityColor(for: recommendation.priority))
                            .clipShape(Circle())
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(recommendation.type)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)

                        Text(recommendation.description)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)

                        if recommendation.potentialIncrease > 0 {
                            Text("潜在增收: ¥" + String(format: "%.0f", recommendation.potentialIncrease))
                                .font(.caption)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }
                    }

                    Spacer()
                }
                .padding()
        #if os(iOS)
        .background(Color(UIColor.systemGray6))
#else
        .background(Color(NSColor.controlColor))
#endif
                .cornerRadius(8)
            }
        }
        .padding()
#if os(iOS)
        .background(Color(UIColor.systemGray5))
#else
        .background(Color(NSColor.controlBackgroundColor))
#endif
        .cornerRadius(12)
    }

    private func priorityColor(for priority: Int) -> Color {
        switch priority {
        case 1: return .red
        case 2: return .orange
        default: return .blue
        }
    }
}

// MARK: - Smart Recommendation Card
struct SmartRecommendationCard: View {
    let recommendation: SmartCategoryRecommendation
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                HStack {
                    Text(recommendation.category)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .primary)

                    Spacer()

                    Text(String(format: "%.0f%%", recommendation.confidence * 100))
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }

                Text(recommendation.reason)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : {
#if os(iOS)
                        return Color(UIColor.systemGray6)
#else
                        return Color(NSColor.controlColor)
#endif
                    }())
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(0.3), lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 120)
    }
}

// MARK: - Smart Insights Card
struct SmartInsightsCard: View {
    let insights: [SmartInsight]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "brain")
                        .foregroundColor(.purple)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("🧠 智能洞察")
                            .font(.headline)
                            .foregroundColor(.primary)

                        Text("发现 \(insights.count) 条新洞察")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.caption)
                }

                if let firstInsight = insights.first {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(firstInsight.type.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)

                        Text(firstInsight.description)
                            .font(.subheadline)
                            .lineLimit(2)
                            .foregroundColor(.primary)
                    }
                }

                if insights.count > 1 {
                    Text("还有 \(insights.count - 1) 条洞察...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
    #if os(iOS)
        .background(Color(UIColor.systemGray6))
#else
        .background(Color(NSColor.controlColor))
#endif
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Smart Insights Detail View
struct SmartInsightsDetailView: View {
    let insights: [SmartInsight]
    @EnvironmentObject var dataManager: DataManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(insights, id: \.id) { insight in
                        SmartInsightDetailCard(insight: insight)
                    }

                    if insights.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "brain")
                                .font(.system(size: 50))
                                .foregroundColor(.gray.opacity(0.5))

                            Text("暂无智能洞察")
                                .font(.headline)
                                .foregroundColor(.gray)

                            Text("使用一段时间后，系统会为您生成个性化的理财洞察")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 50)
                    }
                }
                .padding()
            }
            .navigationTitle("智能洞察")
            #if os(iOS)
.navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .confirmationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                #endif
            }
        }
    }
}

// MARK: - Smart Insight Detail Card
struct SmartInsightDetailCard: View {
    let insight: SmartInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(priorityColor(for: insight.priority))
                    .frame(width: 8, height: 8)

                Text(insight.type.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)

                Spacer()

                Text(formatDate(insight.generatedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(insight.description)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            if !insight.actionSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("💡 建议行动:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)

                    ForEach(insight.actionSuggestions, id: \.self) { suggestion in
                        HStack(alignment: .top) {
                            Text("•")
                                .foregroundColor(.blue)
                            Text(suggestion)
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if insight.potentialSaving > 0 {
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(.green)
                        .font(.caption)

                    Text("潜在节省: ¥" + String(format: "%.0f", insight.potentialSaving))
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
#if os(iOS)
        .background(Color(UIColor.systemGray6))
#else
        .background(Color(NSColor.controlColor))
#endif
        .cornerRadius(12)
    }

    private func priorityColor(for priority: Int) -> Color {
        switch priority {
        case 1: return .red
        case 2: return .orange
        default: return .blue
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(DataManager.shared)
    }
}
