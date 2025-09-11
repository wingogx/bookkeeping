import Foundation
import Combine

/// 交易记录仓储协议（Combine版本）
/// 为当前实现提供兼容的协议定义
public protocol TransactionRepositoryProtocol {
    
    // MARK: - CRUD Operations
    
    /// 创建交易记录
    /// - Parameter entity: 交易实体
    /// - Returns: 创建后的实体的Publisher
    func create(_ entity: TransactionEntity) -> AnyPublisher<TransactionEntity, Error>
    
    /// 根据ID查找交易记录
    /// - Parameter id: 交易记录ID
    /// - Returns: 交易实体的Publisher（可能为nil）
    func findById(_ id: UUID) -> AnyPublisher<TransactionEntity?, Error>
    
    /// 查找所有交易记录
    /// - Returns: 交易实体数组的Publisher
    func findAll() -> AnyPublisher<[TransactionEntity], Error>
    
    /// 按日期范围查找交易记录
    /// - Parameters:
    ///   - startDate: 开始日期
    ///   - endDate: 结束日期
    /// - Returns: 交易实体数组的Publisher
    func findByDateRange(_ startDate: Date, _ endDate: Date) -> AnyPublisher<[TransactionEntity], Error>
    
    /// 按分类查找交易记录
    /// - Parameter categoryID: 分类ID
    /// - Returns: 交易实体数组的Publisher
    func findByCategory(_ categoryID: String) -> AnyPublisher<[TransactionEntity], Error>
    
    // MARK: - Update & Delete
    
    /// 更新交易记录
    /// - Parameter entity: 更新后的交易实体
    /// - Returns: 更新后的实体的Publisher
    func update(_ entity: TransactionEntity) -> AnyPublisher<TransactionEntity, Error>
    
    /// 删除交易记录（软删除）
    /// - Parameter id: 要删除的交易记录ID
    /// - Returns: 删除操作结果的Publisher
    func delete(_ id: UUID) -> AnyPublisher<Void, Error>
    
    // MARK: - Statistics
    
    /// 获取指定分类和日期范围的总金额
    /// - Parameters:
    ///   - categoryID: 分类ID
    ///   - startDate: 开始日期
    ///   - endDate: 结束日期
    /// - Returns: 总金额的Publisher
    func getTotalByCategory(_ categoryID: String, startDate: Date, endDate: Date) -> AnyPublisher<Decimal, Error>
    
    /// 获取指定日期范围的总金额
    /// - Parameters:
    ///   - startDate: 开始日期
    ///   - endDate: 结束日期
    /// - Returns: 总金额的Publisher
    func getTotalByDateRange(_ startDate: Date, _ endDate: Date) -> AnyPublisher<Decimal, Error>
    
    /// 获取分类统计信息
    /// - Parameters:
    ///   - startDate: 开始日期
    ///   - endDate: 结束日期
    /// - Returns: 分类统计数组的Publisher
    func getCategoryStatistics(_ startDate: Date, _ endDate: Date) -> AnyPublisher<[CategoryStatistic], Error>
    
    // MARK: - Search
    
    /// 根据描述搜索交易记录
    /// - Parameter searchText: 搜索文本
    /// - Returns: 搜索结果的Publisher
    func searchByDescription(_ searchText: String) -> AnyPublisher<[TransactionEntity], Error>
}