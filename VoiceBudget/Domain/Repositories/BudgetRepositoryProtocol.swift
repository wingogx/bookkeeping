import Foundation
import Combine

/// 预算仓储协议（Combine版本）
/// 为当前实现提供兼容的协议定义
public protocol BudgetRepositoryProtocol {
    
    // MARK: - CRUD Operations
    
    /// 创建预算
    /// - Parameter entity: 预算实体
    /// - Returns: 创建后的实体的Publisher
    func create(_ entity: BudgetEntity) -> AnyPublisher<BudgetEntity, Error>
    
    /// 根据ID查找预算
    /// - Parameter id: 预算ID
    /// - Returns: 预算实体的Publisher（可能为nil）
    func findById(_ id: UUID) -> AnyPublisher<BudgetEntity?, Error>
    
    /// 查找所有预算
    /// - Returns: 预算实体数组的Publisher
    func findAll() -> AnyPublisher<[BudgetEntity], Error>
    
    /// 查找当前有效的预算
    /// - Returns: 当前预算实体的Publisher（可能为nil）
    func findActiveBudget() -> AnyPublisher<BudgetEntity?, Error>
    
    /// 按日期范围查找预算
    /// - Parameters:
    ///   - startDate: 开始日期
    ///   - endDate: 结束日期
    /// - Returns: 预算实体数组的Publisher
    func findByDateRange(_ startDate: Date, _ endDate: Date) -> AnyPublisher<[BudgetEntity], Error>
    
    // MARK: - Update & Delete
    
    /// 更新预算
    /// - Parameter entity: 更新后的预算实体
    /// - Returns: 更新后的实体的Publisher
    func update(_ entity: BudgetEntity) -> AnyPublisher<BudgetEntity, Error>
    
    /// 删除预算
    /// - Parameter id: 要删除的预算ID
    /// - Returns: 删除操作结果的Publisher
    func delete(_ id: UUID) -> AnyPublisher<Void, Error>
    
    // MARK: - Statistics
    
    /// 获取预算使用情况
    /// - Parameter budgetId: 预算ID
    /// - Returns: 预算使用统计的Publisher
    func getBudgetUsage(_ budgetId: UUID) -> AnyPublisher<BudgetUsage, Error>
}

// MARK: - Supporting Types
public struct BudgetUsage {
    public let budgetId: UUID
    public let totalBudget: Decimal
    public let usedAmount: Decimal
    public let remainingAmount: Decimal
    public let usagePercentage: Double
    public let categoryBreakdown: [String: Decimal]
    
    public init(
        budgetId: UUID,
        totalBudget: Decimal,
        usedAmount: Decimal,
        remainingAmount: Decimal,
        usagePercentage: Double,
        categoryBreakdown: [String: Decimal]
    ) {
        self.budgetId = budgetId
        self.totalBudget = totalBudget
        self.usedAmount = usedAmount
        self.remainingAmount = remainingAmount
        self.usagePercentage = usagePercentage
        self.categoryBreakdown = categoryBreakdown
    }
}