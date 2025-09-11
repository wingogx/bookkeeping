import Foundation
import Combine

/// 交易记录仓储协议
/// 定义交易记录数据访问的标准接口
public protocol TransactionRepository {
    
    // MARK: - CRUD Operations
    
    /// 创建交易记录
    /// - Parameter transaction: 要创建的交易记录实体
    /// - Returns: 创建成功的交易记录实体
    /// - Throws: 创建失败时抛出错误
    func createTransaction(_ transaction: TransactionEntity) async throws -> TransactionEntity
    
    /// 根据ID获取交易记录
    /// - Parameter id: 交易记录ID
    /// - Returns: 查找到的交易记录实体，如果不存在则返回nil
    /// - Throws: 查询失败时抛出错误
    func getTransaction(by id: UUID) async throws -> TransactionEntity?
    
    /// 查询交易记录列表
    /// - Parameters:
    ///   - startDate: 开始日期，为nil时不限制开始日期
    ///   - endDate: 结束日期，为nil时不限制结束日期
    ///   - categoryID: 分类ID，为nil时不按分类筛选
    ///   - source: 记录来源，为nil时不按来源筛选
    ///   - limit: 查询数量限制，为nil时不限制数量
    ///   - offset: 查询偏移量，默认为0
    /// - Returns: 符合条件的交易记录列表
    /// - Throws: 查询失败时抛出错误
    func fetchTransactions(
        startDate: Date?,
        endDate: Date?,
        categoryID: String?,
        source: TransactionEntity.TransactionSource?,
        limit: Int?,
        offset: Int
    ) async throws -> [TransactionEntity]
    
    /// 更新交易记录
    /// - Parameter transaction: 要更新的交易记录实体
    /// - Returns: 更新成功的交易记录实体
    /// - Throws: 更新失败时抛出错误
    func updateTransaction(_ transaction: TransactionEntity) async throws -> TransactionEntity
    
    /// 软删除交易记录
    /// - Parameter id: 要删除的交易记录ID
    /// - Throws: 删除失败时抛出错误
    func deleteTransaction(id: UUID) async throws
    
    /// 硬删除交易记录
    /// - Parameter id: 要彻底删除的交易记录ID
    /// - Throws: 删除失败时抛出错误
    func permanentlyDeleteTransaction(id: UUID) async throws
    
    // MARK: - Batch Operations
    
    /// 批量创建交易记录
    /// - Parameter transactions: 要创建的交易记录列表
    /// - Returns: 创建成功的交易记录列表
    /// - Throws: 批量创建失败时抛出错误
    func batchCreateTransactions(_ transactions: [TransactionEntity]) async throws -> [TransactionEntity]
    
    /// 批量更新交易记录
    /// - Parameter transactions: 要更新的交易记录列表
    /// - Returns: 更新成功的交易记录列表
    /// - Throws: 批量更新失败时抛出错误
    func batchUpdateTransactions(_ transactions: [TransactionEntity]) async throws -> [TransactionEntity]
    
    // MARK: - Statistics and Analytics
    
    /// 获取交易统计摘要
    /// - Parameters:
    ///   - startDate: 统计开始日期
    ///   - endDate: 统计结束日期
    ///   - categoryID: 分类ID，为nil时统计所有分类
    /// - Returns: 交易统计摘要
    /// - Throws: 统计失败时抛出错误
    func getTransactionSummary(
        startDate: Date,
        endDate: Date,
        categoryID: String?
    ) async throws -> TransactionSummary
    
    /// 获取分类支出统计
    /// - Parameters:
    ///   - startDate: 统计开始日期
    ///   - endDate: 统计结束日期
    /// - Returns: 按分类统计的支出数据
    /// - Throws: 统计失败时抛出错误
    func getCategoryExpenseStatistics(
        startDate: Date,
        endDate: Date
    ) async throws -> [CategoryExpenseStatistics]
    
    /// 获取日支出趋势数据
    /// - Parameters:
    ///   - startDate: 开始日期
    ///   - endDate: 结束日期
    /// - Returns: 日支出趋势数据
    /// - Throws: 获取失败时抛出错误
    func getDailyExpenseTrend(
        startDate: Date,
        endDate: Date
    ) async throws -> [DailyExpenseData]
    
    // MARK: - Search and Filter
    
    /// 搜索交易记录
    /// - Parameters:
    ///   - searchText: 搜索文本（在备注和分类名称中搜索）
    ///   - limit: 结果数量限制，默认为50
    /// - Returns: 符合搜索条件的交易记录列表
    /// - Throws: 搜索失败时抛出错误
    func searchTransactions(
        searchText: String,
        limit: Int
    ) async throws -> [TransactionEntity]
    
    /// 获取最近的交易记录
    /// - Parameter limit: 数量限制，默认为10
    /// - Returns: 最近的交易记录列表
    /// - Throws: 查询失败时抛出错误
    func getRecentTransactions(limit: Int) async throws -> [TransactionEntity]
    
    // MARK: - Data Management
    
    /// 获取记录总数
    /// - Returns: 交易记录总数（不包括已删除的记录）
    /// - Throws: 查询失败时抛出错误
    func getTotalTransactionCount() async throws -> Int
    
    /// 清理已删除的记录（硬删除超过30天的软删除记录）
    /// - Throws: 清理失败时抛出错误
    func cleanupDeletedTransactions() async throws
    
    /// 导出交易记录
    /// - Parameters:
    ///   - startDate: 开始日期
    ///   - endDate: 结束日期
    ///   - format: 导出格式
    /// - Returns: 导出的数据
    /// - Throws: 导出失败时抛出错误
    func exportTransactions(
        startDate: Date,
        endDate: Date,
        format: ExportFormat
    ) async throws -> Data
}

// MARK: - Supporting Types

/// 交易统计摘要
public struct TransactionSummary: Codable {
    public let totalAmount: Decimal
    public let transactionCount: Int
    public let averageAmount: Decimal
    public let maxAmount: Decimal
    public let minAmount: Decimal
    public let periodStartDate: Date
    public let periodEndDate: Date
    
    public init(
        totalAmount: Decimal,
        transactionCount: Int,
        averageAmount: Decimal,
        maxAmount: Decimal,
        minAmount: Decimal,
        periodStartDate: Date,
        periodEndDate: Date
    ) {
        self.totalAmount = totalAmount
        self.transactionCount = transactionCount
        self.averageAmount = averageAmount
        self.maxAmount = maxAmount
        self.minAmount = minAmount
        self.periodStartDate = periodStartDate
        self.periodEndDate = periodEndDate
    }
}

/// 分类支出统计
public struct CategoryExpenseStatistics: Codable, Identifiable {
    public let id: String
    public let categoryID: String
    public let categoryName: String
    public let totalAmount: Decimal
    public let transactionCount: Int
    public let percentage: Double
    public let averageAmount: Decimal
    
    public init(
        categoryID: String,
        categoryName: String,
        totalAmount: Decimal,
        transactionCount: Int,
        percentage: Double,
        averageAmount: Decimal
    ) {
        self.id = categoryID
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.totalAmount = totalAmount
        self.transactionCount = transactionCount
        self.percentage = percentage
        self.averageAmount = averageAmount
    }
}

/// 日支出数据
public struct DailyExpenseData: Codable, Identifiable {
    public let id: String
    public let date: Date
    public let totalAmount: Decimal
    public let transactionCount: Int
    
    public init(date: Date, totalAmount: Decimal, transactionCount: Int) {
        self.id = ISO8601DateFormatter().string(from: date)
        self.date = date
        self.totalAmount = totalAmount
        self.transactionCount = transactionCount
    }
}

/// 导出格式
public enum ExportFormat: String, CaseIterable {
    case csv = "csv"
    case json = "json"
    case xlsx = "xlsx"
}

// MARK: - Type Aliases for Compatibility
/// 类型别名，用于解决命名冲突
public typealias TransactionRepositoryProtocol = TransactionRepository