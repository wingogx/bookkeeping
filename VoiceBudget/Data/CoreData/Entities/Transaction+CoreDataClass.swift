import Foundation
import CoreData

/// Transaction实体扩展
/// 提供便利方法和计算属性
@objc(Transaction)
public class Transaction: NSManagedObject {
    
    /// 格式化金额显示
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: amount ?? 0) ?? "¥0.00"
    }
    
    /// 是否为今日记录
    var isToday: Bool {
        guard let date = date else { return false }
        return Calendar.current.isDateInToday(date)
    }
    
    /// 是否为本周记录
    var isThisWeek: Bool {
        guard let date = date else { return false }
        return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    /// 是否为本月记录
    var isThisMonth: Bool {
        guard let date = date else { return false }
        return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month)
    }
    
    /// 便利初始化方法
    /// - Parameters:
    ///   - context: Core Data上下文
    ///   - amount: 金额
    ///   - categoryID: 分类ID
    ///   - categoryName: 分类名称
    ///   - source: 记录来源
    convenience init(context: NSManagedObjectContext, amount: Decimal, categoryID: String, categoryName: String, source: String) {
        self.init(context: context)
        self.id = UUID()
        self.amount = NSDecimalNumber(decimal: amount)
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.source = source
        self.date = Date()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isDeleted = false
        self.syncStatus = "pending"
    }
}