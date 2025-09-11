import Foundation
import CoreData

/// Budget实体扩展
/// 提供便利方法和计算属性
@objc(Budget)
public class Budget: NSManagedObject {
    
    /// 预算使用金额
    var usedAmount: Decimal {
        guard let transactions = transactions else { return 0 }
        return transactions.compactMap { ($0 as? Transaction)?.amount?.decimalValue }
            .reduce(0, +)
    }
    
    /// 预算剩余金额
    var remainingAmount: Decimal {
        return (totalAmount?.decimalValue ?? 0) - usedAmount
    }
    
    /// 预算使用百分比
    var usagePercentage: Double {
        guard let total = totalAmount?.decimalValue, total > 0 else { return 0 }
        return Double(truncating: NSDecimalNumber(decimal: usedAmount / total))
    }
    
    /// 是否超支
    var isOverBudget: Bool {
        return usedAmount > (totalAmount?.decimalValue ?? 0)
    }
    
    /// 是否可以修改（检查修改次数限制）
    var canModify: Bool {
        return modificationCount < 2
    }
    
    /// 预算状态
    enum BudgetStatus {
        case safe       // 使用率 < 80%
        case warning    // 使用率 80% - 100%
        case exceeded   // 使用率 > 100%
    }
    
    /// 获取预算状态
    var status: BudgetStatus {
        let percentage = usagePercentage
        if percentage > 1.0 {
            return .exceeded
        } else if percentage > 0.8 {
            return .warning
        } else {
            return .safe
        }
    }
    
    /// 便利初始化方法
    /// - Parameters:
    ///   - context: Core Data上下文
    ///   - totalAmount: 总预算金额
    ///   - period: 预算周期（week/month）
    convenience init(context: NSManagedObjectContext, totalAmount: Decimal, period: String) {
        self.init(context: context)
        self.id = UUID()
        self.totalAmount = NSDecimalNumber(decimal: totalAmount)
        self.period = period
        
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        
        // 根据周期设置开始和结束日期
        let calendar = Calendar.current
        if period == "week" {
            // 设置为本周一到周日
            self.startDate = calendar.dateInterval(of: .weekOfYear, for: now)?.start
            self.endDate = calendar.dateInterval(of: .weekOfYear, for: now)?.end
        } else {
            // 设置为本月1日到月末
            self.startDate = calendar.dateInterval(of: .month, for: now)?.start
            self.endDate = calendar.dateInterval(of: .month, for: now)?.end
        }
        
        self.isActive = true
        self.modificationCount = 0
    }
    
    /// 修改预算
    /// - Parameter newAmount: 新的预算金额
    /// - Returns: 是否修改成功
    @discardableResult
    func modify(totalAmount newAmount: Decimal) -> Bool {
        guard canModify else { return false }
        
        self.totalAmount = NSDecimalNumber(decimal: newAmount)
        self.modificationCount += 1
        self.updatedAt = Date()
        
        return true
    }
}