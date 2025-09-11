import Foundation

/// 交易记录领域实体
/// 表示一笔记账记录的业务概念
public struct TransactionEntity: Codable, Identifiable, Equatable {
    
    // MARK: - Properties
    
    /// 唯一标识符
    public let id: UUID
    
    /// 金额（以人民币计）
    public let amount: Decimal
    
    /// 分类ID
    public let categoryID: String
    
    /// 分类名称
    public let categoryName: String
    
    /// 备注信息
    public let note: String?
    
    /// 交易时间
    public let date: Date
    
    /// 创建时间
    public let createdAt: Date
    
    /// 最后修改时间
    public let updatedAt: Date
    
    /// 记录来源
    public let source: TransactionSource
    
    /// 是否已删除
    public let isDeleted: Bool
    
    /// 同步状态
    public let syncStatus: SyncStatus
    
    // MARK: - Enums
    
    /// 交易记录来源
    public enum TransactionSource: String, Codable, CaseIterable {
        case voice = "voice"     // 语音记账
        case photo = "photo"     // 拍照记账
        case manual = "manual"   // 手动记账
        case auto = "auto"       // 自动记账
    }
    
    /// 同步状态
    public enum SyncStatus: String, Codable {
        case pending = "pending" // 等待同步
        case synced = "synced"   // 已同步
        case failed = "failed"   // 同步失败
    }
    
    // MARK: - Initializer
    
    /// 初始化交易实体
    /// - Parameters:
    ///   - id: 唯一标识符，如果为nil则自动生成
    ///   - amount: 交易金额
    ///   - categoryID: 分类ID
    ///   - categoryName: 分类名称
    ///   - note: 备注信息
    ///   - date: 交易时间，默认为当前时间
    ///   - source: 记录来源
    ///   - createdAt: 创建时间，默认为当前时间
    ///   - updatedAt: 更新时间，默认为当前时间
    ///   - isDeleted: 是否已删除，默认为false
    ///   - syncStatus: 同步状态，默认为pending
    public init(
        id: UUID? = nil,
        amount: Decimal,
        categoryID: String,
        categoryName: String,
        note: String? = nil,
        date: Date = Date(),
        source: TransactionSource,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isDeleted: Bool = false,
        syncStatus: SyncStatus = .pending
    ) {
        self.id = id ?? UUID()
        self.amount = amount
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.note = note
        self.date = date
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.syncStatus = syncStatus
    }
    
    // MARK: - Business Logic
    
    /// 验证金额是否有效（大于0）
    public var isValidAmount: Bool {
        return amount > 0
    }
    
    /// 是否为今日记录
    public var isToday: Bool {
        return Calendar.current.isDateInToday(date)
    }
    
    /// 是否为本周记录
    public var isThisWeek: Bool {
        return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    /// 是否为本月记录
    public var isThisMonth: Bool {
        return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month)
    }
    
    /// 格式化金额显示
    public var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "¥0.00"
    }
    
    /// 创建更新后的实体（不可变实体的更新方式）
    /// - Parameters:
    ///   - amount: 新金额
    ///   - categoryID: 新分类ID
    ///   - categoryName: 新分类名称
    ///   - note: 新备注
    ///   - syncStatus: 新同步状态
    /// - Returns: 更新后的实体
    public func updated(
        amount: Decimal? = nil,
        categoryID: String? = nil,
        categoryName: String? = nil,
        note: String? = nil,
        syncStatus: SyncStatus? = nil
    ) -> TransactionEntity {
        return TransactionEntity(
            id: self.id,
            amount: amount ?? self.amount,
            categoryID: categoryID ?? self.categoryID,
            categoryName: categoryName ?? self.categoryName,
            note: note ?? self.note,
            date: self.date,
            source: self.source,
            createdAt: self.createdAt,
            updatedAt: Date(), // 更新时间为当前时间
            isDeleted: self.isDeleted,
            syncStatus: syncStatus ?? self.syncStatus
        )
    }
    
    /// 软删除实体
    /// - Returns: 标记为删除的实体
    public func deleted() -> TransactionEntity {
        return TransactionEntity(
            id: self.id,
            amount: self.amount,
            categoryID: self.categoryID,
            categoryName: self.categoryName,
            note: self.note,
            date: self.date,
            source: self.source,
            createdAt: self.createdAt,
            updatedAt: Date(),
            isDeleted: true,
            syncStatus: .pending
        )
    }
}