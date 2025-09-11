import Foundation

/// 预算仓储协议
/// 定义预算数据访问的标准接口
public protocol BudgetRepository {
    
    // MARK: - CRUD Operations
    
    /// 创建预算
    /// - Parameter budget: 要创建的预算实体
    /// - Returns: 创建成功的预算实体
    /// - Throws: 创建失败时抛出错误
    func createBudget(_ budget: BudgetEntity) async throws -> BudgetEntity
    
    /// 根据ID获取预算
    /// - Parameter id: 预算ID
    /// - Returns: 查找到的预算实体，如果不存在则返回nil
    /// - Throws: 查询失败时抛出错误
    func getBudget(by id: UUID) async throws -> BudgetEntity?
    
    /// 获取当前激活的预算
    /// - Returns: 当前激活的预算实体，如果不存在则返回nil
    /// - Throws: 查询失败时抛出错误
    func getCurrentBudget() async throws -> BudgetEntity?
    
    /// 获取指定周期的预算
    /// - Parameters:
    ///   - period: 预算周期类型
    ///   - date: 指定日期，默认为当前日期
    /// - Returns: 指定周期的预算实体，如果不存在则返回nil
    /// - Throws: 查询失败时抛出错误
    func getBudget(
        for period: BudgetEntity.BudgetPeriod,
        containing date: Date
    ) async throws -> BudgetEntity?
    
    /// 查询预算列表
    /// - Parameters:
    ///   - period: 预算周期，为nil时不筛选周期
    ///   - isActive: 是否激活，为nil时不筛选激活状态
    ///   - limit: 查询数量限制，为nil时不限制数量
    ///   - offset: 查询偏移量，默认为0
    /// - Returns: 符合条件的预算列表
    /// - Throws: 查询失败时抛出错误
    func fetchBudgets(
        period: BudgetEntity.BudgetPeriod?,
        isActive: Bool?,
        limit: Int?,
        offset: Int
    ) async throws -> [BudgetEntity]
    
    /// 更新预算
    /// - Parameter budget: 要更新的预算实体
    /// - Returns: 更新成功的预算实体
    /// - Throws: 更新失败时抛出错误
    func updateBudget(_ budget: BudgetEntity) async throws -> BudgetEntity
    
    /// 删除预算
    /// - Parameter id: 要删除的预算ID
    /// - Throws: 删除失败时抛出错误
    func deleteBudget(id: UUID) async throws
    
    // MARK: - Budget Usage and Statistics
    
    /// 获取预算使用情况
    /// - Parameters:
    ///   - budgetID: 预算ID
    ///   - upToDate: 统计截止日期，默认为当前日期
    /// - Returns: 预算使用情况
    /// - Throws: 查询失败时抛出错误
    func getBudgetUsage(
        budgetID: UUID,
        upToDate: Date
    ) async throws -> BudgetUsage
    
    /// 获取分类预算使用情况
    /// - Parameters:
    ///   - budgetID: 预算ID
    ///   - upToDate: 统计截止日期，默认为当前日期
    /// - Returns: 各分类的预算使用情况
    /// - Throws: 查询失败时抛出错误
    func getCategoryBudgetUsage(
        budgetID: UUID,
        upToDate: Date
    ) async throws -> [CategoryBudgetUsage]
    
    /// 获取预算执行趋势
    /// - Parameter budgetID: 预算ID
    /// - Returns: 预算执行趋势数据
    /// - Throws: 查询失败时抛出错误
    func getBudgetExecutionTrend(budgetID: UUID) async throws -> [BudgetExecutionData]
    
    // MARK: - Budget Validation
    
    /// 检查是否可修改预算
    /// - Parameter budgetID: 预算ID
    /// - Returns: 是否可以修改
    /// - Throws: 检查失败时抛出错误
    func canModifyBudget(budgetID: UUID) async throws -> Bool
    
    /// 验证预算分配是否合理
    /// - Parameter budget: 要验证的预算实体
    /// - Returns: 验证结果
    /// - Throws: 验证失败时抛出错误
    func validateBudgetAllocation(_ budget: BudgetEntity) async throws -> BudgetValidationResult
    
    /// 检查预算是否存在冲突
    /// - Parameter budget: 要检查的预算实体
    /// - Returns: 是否存在冲突（同一周期内是否已有激活的预算）
    /// - Throws: 检查失败时抛出错误
    func checkBudgetConflict(_ budget: BudgetEntity) async throws -> Bool
    
    // MARK: - Budget Management
    
    /// 停用所有其他预算并激活指定预算
    /// - Parameter budgetID: 要激活的预算ID
    /// - Throws: 操作失败时抛出错误
    func activateBudget(id: UUID) async throws
    
    /// 停用预算
    /// - Parameter budgetID: 要停用的预算ID
    /// - Throws: 操作失败时抛出错误
    func deactivateBudget(id: UUID) async throws
    
    /// 克隆预算到下一个周期
    /// - Parameter budgetID: 要克隆的预算ID
    /// - Returns: 新创建的预算实体
    /// - Throws: 克隆失败时抛出错误
    func cloneBudgetToNextPeriod(budgetID: UUID) async throws -> BudgetEntity
    
    // MARK: - Data Analysis
    
    /// 获取预算历史分析
    /// - Parameters:
    ///   - period: 分析的周期类型
    ///   - count: 分析的周期数量，默认为6
    /// - Returns: 预算历史分析数据
    /// - Throws: 分析失败时抛出错误
    func getBudgetHistoryAnalysis(
        period: BudgetEntity.BudgetPeriod,
        count: Int
    ) async throws -> BudgetHistoryAnalysis
    
    /// 生成预算建议
    /// - Parameters:
    ///   - period: 预算周期
    ///   - baseOnHistory: 是否基于历史数据，默认为true
    /// - Returns: 预算建议
    /// - Throws: 生成失败时抛出错误
    func generateBudgetSuggestion(
        for period: BudgetEntity.BudgetPeriod,
        baseOnHistory: Bool
    ) async throws -> BudgetSuggestion
}

// MARK: - Supporting Types

/// 预算使用情况
public struct BudgetUsage: Codable {
    public let budgetID: UUID
    public let totalBudget: Decimal
    public let usedAmount: Decimal
    public let remainingAmount: Decimal
    public let usagePercentage: Double
    public let status: BudgetStatus
    public let daysRemaining: Int
    public let averageDailySpent: Decimal
    public let projectedTotal: Decimal
    public let isOnTrack: Bool
    
    public init(
        budgetID: UUID,
        totalBudget: Decimal,
        usedAmount: Decimal,
        remainingAmount: Decimal,
        usagePercentage: Double,
        status: BudgetStatus,
        daysRemaining: Int,
        averageDailySpent: Decimal,
        projectedTotal: Decimal,
        isOnTrack: Bool
    ) {
        self.budgetID = budgetID
        self.totalBudget = totalBudget
        self.usedAmount = usedAmount
        self.remainingAmount = remainingAmount
        self.usagePercentage = usagePercentage
        self.status = status
        self.daysRemaining = daysRemaining
        self.averageDailySpent = averageDailySpent
        self.projectedTotal = projectedTotal
        self.isOnTrack = isOnTrack
    }
}

/// 预算状态
public enum BudgetStatus: String, Codable {
    case safe = "safe"           // 安全：使用率 < 80%
    case warning = "warning"     // 警告：使用率 80% - 100%
    case exceeded = "exceeded"   // 超支：使用率 > 100%
}

/// 分类预算使用情况
public struct CategoryBudgetUsage: Codable, Identifiable {
    public let id: String
    public let categoryID: String
    public let categoryName: String
    public let allocatedAmount: Decimal
    public let usedAmount: Decimal
    public let remainingAmount: Decimal
    public let usagePercentage: Double
    public let status: BudgetStatus
    public let transactionCount: Int
    
    public init(
        categoryID: String,
        categoryName: String,
        allocatedAmount: Decimal,
        usedAmount: Decimal,
        remainingAmount: Decimal,
        usagePercentage: Double,
        status: BudgetStatus,
        transactionCount: Int
    ) {
        self.id = categoryID
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.allocatedAmount = allocatedAmount
        self.usedAmount = usedAmount
        self.remainingAmount = remainingAmount
        self.usagePercentage = usagePercentage
        self.status = status
        self.transactionCount = transactionCount
    }
}

/// 预算执行数据
public struct BudgetExecutionData: Codable, Identifiable {
    public let id: String
    public let date: Date
    public let cumulativeSpent: Decimal
    public let dailySpent: Decimal
    public let remainingBudget: Decimal
    public let targetCumulativeSpent: Decimal
    
    public init(
        date: Date,
        cumulativeSpent: Decimal,
        dailySpent: Decimal,
        remainingBudget: Decimal,
        targetCumulativeSpent: Decimal
    ) {
        self.id = ISO8601DateFormatter().string(from: date)
        self.date = date
        self.cumulativeSpent = cumulativeSpent
        self.dailySpent = dailySpent
        self.remainingBudget = remainingBudget
        self.targetCumulativeSpent = targetCumulativeSpent
    }
}

/// 预算验证结果
public struct BudgetValidationResult: Codable {
    public let isValid: Bool
    public let errors: [ValidationError]
    public let warnings: [ValidationWarning]
    
    public init(isValid: Bool, errors: [ValidationError], warnings: [ValidationWarning]) {
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
    
    public struct ValidationError: Codable {
        public let code: String
        public let message: String
        
        public init(code: String, message: String) {
            self.code = code
            self.message = message
        }
    }
    
    public struct ValidationWarning: Codable {
        public let code: String
        public let message: String
        
        public init(code: String, message: String) {
            self.code = code
            self.message = message
        }
    }
}

/// 预算历史分析
public struct BudgetHistoryAnalysis: Codable {
    public let period: BudgetEntity.BudgetPeriod
    public let averageSpent: Decimal
    public let averageBudget: Decimal
    public let averageUsageRate: Double
    public let successRate: Double // 不超支的周期占比
    public let trend: BudgetTrend
    public let categoryAnalysis: [CategoryHistoryAnalysis]
    
    public init(
        period: BudgetEntity.BudgetPeriod,
        averageSpent: Decimal,
        averageBudget: Decimal,
        averageUsageRate: Double,
        successRate: Double,
        trend: BudgetTrend,
        categoryAnalysis: [CategoryHistoryAnalysis]
    ) {
        self.period = period
        self.averageSpent = averageSpent
        self.averageBudget = averageBudget
        self.averageUsageRate = averageUsageRate
        self.successRate = successRate
        self.trend = trend
        self.categoryAnalysis = categoryAnalysis
    }
}

/// 预算趋势
public enum BudgetTrend: String, Codable {
    case increasing = "increasing"   // 支出增加
    case decreasing = "decreasing"   // 支出减少
    case stable = "stable"          // 支出稳定
}

/// 分类历史分析
public struct CategoryHistoryAnalysis: Codable {
    public let categoryID: String
    public let categoryName: String
    public let averageSpent: Decimal
    public let averageAllocation: Decimal
    public let averageUsageRate: Double
    public let trend: BudgetTrend
    
    public init(
        categoryID: String,
        categoryName: String,
        averageSpent: Decimal,
        averageAllocation: Decimal,
        averageUsageRate: Double,
        trend: BudgetTrend
    ) {
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.averageSpent = averageSpent
        self.averageAllocation = averageAllocation
        self.averageUsageRate = averageUsageRate
        self.trend = trend
    }
}

/// 预算建议
public struct BudgetSuggestion: Codable {
    public let suggestedTotalAmount: Decimal
    public let categoryAllocations: [BudgetEntity.BudgetCategoryAllocation]
    public let reasoning: String
    public let confidenceScore: Double // 0-1之间，表示建议的可信度
    public let basedOnPeriods: Int // 基于多少个历史周期
    
    public init(
        suggestedTotalAmount: Decimal,
        categoryAllocations: [BudgetEntity.BudgetCategoryAllocation],
        reasoning: String,
        confidenceScore: Double,
        basedOnPeriods: Int
    ) {
        self.suggestedTotalAmount = suggestedTotalAmount
        self.categoryAllocations = categoryAllocations
        self.reasoning = reasoning
        self.confidenceScore = confidenceScore
        self.basedOnPeriods = basedOnPeriods
    }
}