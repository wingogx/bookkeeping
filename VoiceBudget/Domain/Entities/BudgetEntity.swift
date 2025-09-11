import Foundation

/// 预算领域实体
/// 表示一个预算周期的业务概念
public struct BudgetEntity: Codable, Identifiable, Equatable {
    
    // MARK: - Properties
    
    /// 唯一标识符
    public let id: UUID
    
    /// 总预算金额
    public let totalAmount: Decimal
    
    /// 预算周期
    public let period: BudgetPeriod
    
    /// 开始日期
    public let startDate: Date
    
    /// 结束日期
    public let endDate: Date
    
    /// 修改次数
    public let modificationCount: Int
    
    /// 是否激活
    public let isActive: Bool
    
    /// 创建时间
    public let createdAt: Date
    
    /// 最后修改时间
    public let updatedAt: Date
    
    /// 分类预算分配
    public let categories: [BudgetCategoryAllocation]
    
    // MARK: - Enums
    
    /// 预算周期
    public enum BudgetPeriod: String, Codable, CaseIterable {
        case week = "week"   // 周预算
        case month = "month" // 月预算
        
        /// 获取当前周期的开始日期
        public func startDate(from date: Date = Date()) -> Date {
            let calendar = Calendar.current
            switch self {
            case .week:
                return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
            case .month:
                return calendar.dateInterval(of: .month, for: date)?.start ?? date
            }
        }
        
        /// 获取当前周期的结束日期
        public func endDate(from date: Date = Date()) -> Date {
            let calendar = Calendar.current
            switch self {
            case .week:
                return calendar.dateInterval(of: .weekOfYear, for: date)?.end ?? date
            case .month:
                return calendar.dateInterval(of: .month, for: date)?.end ?? date
            }
        }
    }
    
    /// 预算状态
    public enum BudgetStatus {
        case safe       // 使用率 < 80%
        case warning    // 使用率 80% - 100%
        case exceeded   // 使用率 > 100%
    }
    
    // MARK: - Nested Types
    
    /// 分类预算分配
    public struct BudgetCategoryAllocation: Codable, Equatable {
        public let categoryID: String
        public let categoryName: String
        public let allocatedAmount: Decimal
        public let icon: String
        public let color: String
        
        public init(categoryID: String, categoryName: String, allocatedAmount: Decimal, icon: String, color: String) {
            self.categoryID = categoryID
            self.categoryName = categoryName
            self.allocatedAmount = allocatedAmount
            self.icon = icon
            self.color = color
        }
    }
    
    // MARK: - Initializer
    
    /// 初始化预算实体
    /// - Parameters:
    ///   - id: 唯一标识符，如果为nil则自动生成
    ///   - totalAmount: 总预算金额
    ///   - period: 预算周期
    ///   - startDate: 开始日期，默认根据周期自动计算
    ///   - endDate: 结束日期，默认根据周期自动计算
    ///   - modificationCount: 修改次数，默认为0
    ///   - isActive: 是否激活，默认为true
    ///   - createdAt: 创建时间，默认为当前时间
    ///   - updatedAt: 更新时间，默认为当前时间
    ///   - categories: 分类预算分配，默认为空数组
    public init(
        id: UUID? = nil,
        totalAmount: Decimal,
        period: BudgetPeriod,
        startDate: Date? = nil,
        endDate: Date? = nil,
        modificationCount: Int = 0,
        isActive: Bool = true,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        categories: [BudgetCategoryAllocation] = []
    ) {
        self.id = id ?? UUID()
        self.totalAmount = totalAmount
        self.period = period
        self.startDate = startDate ?? period.startDate()
        self.endDate = endDate ?? period.endDate()
        self.modificationCount = modificationCount
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.categories = categories
    }
    
    // MARK: - Business Logic
    
    /// 预算修改限制（每个周期最多2次）
    public static let maxModificationCount = 2
    
    /// 是否可以修改
    public var canModify: Bool {
        return modificationCount < Self.maxModificationCount
    }
    
    /// 是否在当前周期内
    public var isCurrentPeriod: Bool {
        let now = Date()
        return now >= startDate && now <= endDate
    }
    
    /// 获取分类预算分配总额
    public var totalAllocatedAmount: Decimal {
        return categories.reduce(0) { $0 + $1.allocatedAmount }
    }
    
    /// 获取未分配的预算金额
    public var unallocatedAmount: Decimal {
        return totalAmount - totalAllocatedAmount
    }
    
    /// 验证预算分配是否合理（总分配不超过总预算）
    public var isValidAllocation: Bool {
        return totalAllocatedAmount <= totalAmount
    }
    
    /// 计算预算使用率
    /// - Parameter usedAmount: 已使用金额
    /// - Returns: 使用率百分比
    public func usagePercentage(with usedAmount: Decimal) -> Double {
        guard totalAmount > 0 else { return 0 }
        return Double(truncating: NSDecimalNumber(decimal: usedAmount / totalAmount))
    }
    
    /// 获取预算状态
    /// - Parameter usedAmount: 已使用金额
    /// - Returns: 预算状态
    public func status(with usedAmount: Decimal) -> BudgetStatus {
        let percentage = usagePercentage(with: usedAmount)
        if percentage > 1.0 {
            return .exceeded
        } else if percentage > 0.8 {
            return .warning
        } else {
            return .safe
        }
    }
    
    /// 创建修改后的预算实体
    /// - Parameters:
    ///   - totalAmount: 新的总预算金额
    ///   - categories: 新的分类预算分配
    /// - Returns: 修改后的预算实体，如果超过修改限制则返回nil
    public func modified(totalAmount: Decimal? = nil, categories: [BudgetCategoryAllocation]? = nil) -> BudgetEntity? {
        guard canModify else { return nil }
        
        return BudgetEntity(
            id: self.id,
            totalAmount: totalAmount ?? self.totalAmount,
            period: self.period,
            startDate: self.startDate,
            endDate: self.endDate,
            modificationCount: self.modificationCount + 1,
            isActive: self.isActive,
            createdAt: self.createdAt,
            updatedAt: Date(),
            categories: categories ?? self.categories
        )
    }
    
    /// 停用预算
    /// - Returns: 停用后的预算实体
    public func deactivated() -> BudgetEntity {
        return BudgetEntity(
            id: self.id,
            totalAmount: self.totalAmount,
            period: self.period,
            startDate: self.startDate,
            endDate: self.endDate,
            modificationCount: self.modificationCount,
            isActive: false,
            createdAt: self.createdAt,
            updatedAt: Date(),
            categories: self.categories
        )
    }
}